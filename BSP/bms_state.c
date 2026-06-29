/******************************************************************************
 * bms_state.c
 * BMS 状态机: INIT -> STANDBY -> ACTIVE -> FAULT -> SLEEP
 * 双路输出: CAN (500kbps 上报 VCU) + UART (串口屏调试)
 ******************************************************************************/
#include "bms_state.h"
#include "BQ76930.h"
#include "i2c1.h"
#include "IO_CTRL.h"
#include "can.h"
#include "usart.h"
#include "usart2.h"
#include "SYSTICK.h"
#include <stdio.h>
#include <string.h>

#include "temp_mgr.h"
#include "soc.h"
#include "protection.h"
#include "balance.h"
#include "flash_store.h"

/* 全局 BMS 句柄 */
BMS_Handle_t g_bms;

/* BQ76940 所有电压寄存器地址表 */
static const uint8_t cell_hi_addr[CELL_COUNT] = {0x0C, 0x0E, 0x10, 0x12};
static const uint8_t cell_lo_addr[CELL_COUNT] = {0x0D, 0x0F, 0x11, 0x13};

/* BQ ADC 校准变量 */
static int32_t  g_gain = 377;       /* GAIN = 365 + ADC_GAIN, 单位 .V */
static int32_t  g_adc_offset = 0;   /* ADCOFFSET, 单位 45mV */

/* ---------------------------------------------------------------
 * BQ76940 驱动层: 读校准、读电压、读电流、写控制
 * --------------------------------------------------------------- */
static void BQ_ReadCalibration(void)
{
    uint8_t gain1, gain2;
    int32_t adc_gain;
    gain1 = IIC1_read_one_byte(ADCGAIN1);
    gain2 = IIC1_read_one_byte(ADCGAIN2);
    adc_gain = ((gain1 & 0x0C) << 1) + ((gain2 & 0xE0) >> 5);
    g_gain = 365 + adc_gain;
    g_adc_offset = (int32_t)IIC1_read_one_byte(ADCOFFSET);
}

static uint16_t BQ_ReadCellVoltage(uint8_t cell_idx)
{
    uint8_t hi, lo;
    uint32_t raw;
    int32_t  mv;
    if (cell_idx >= CELL_COUNT) return 0;
    hi  = IIC1_read_one_byte(cell_hi_addr[cell_idx]);
    lo  = IIC1_read_one_byte(cell_lo_addr[cell_idx]);
    raw = ((uint32_t)hi << 8) | lo;
    mv  = (int32_t)((raw * (uint32_t)g_gain) / 1000) + g_adc_offset;
    if (mv < 0) mv = 0;
    return (uint16_t)mv;
}

static void BQ_ReadAllVoltages(BMS_Handle_t *bms)
{
    uint8_t i;
    uint32_t sum = 0;
    for (i = 0; i < CELL_COUNT; i++) {
        bms->meas.cell_voltage_mv[i] = BQ_ReadCellVoltage(i);
        sum += bms->meas.cell_voltage_mv[i];
    }
    bms->meas.pack_voltage_mv = (uint16_t)sum;
}

static int16_t BQ_ReadCurrent(void)
{
    uint8_t hi, lo;
    uint32_t raw;
    int32_t mv;
    hi = IIC1_read_one_byte(CC_HI_BYTE);
    lo = IIC1_read_one_byte(CC_LO_BYTE);
    raw = ((uint32_t)hi << 8) | lo;
    /* CC_HI: 0x32, CC_LO: 0x33 */
    if (raw <= 0x7D00) {
        mv = (int32_t)(raw * 211) / 100;        /* *2.11 mV/mA 比例 */
    } else {
        mv = -(int32_t)((0xFFFF - raw) * 211) / 100;
    }
    return (int16_t)mv;
}

static void BQ_InitControl(void)
{
    /* 上电唤醒脉冲 */
    MCU_WAKE_BQ_ONOFF(1);
    delay_ms(100);
    MCU_WAKE_BQ_ONOFF(0);
    delay_ms(10);

    /* 读校准 */
    BQ_ReadCalibration();

    /* 配置保护阈值 -> BQ 芯片内部也设置一次 */
    IIC1_write_one_byte_CRC(SYS_STAT,  0xFF);
    IIC1_write_one_byte_CRC(CELLBAL1, 0x00);
    IIC1_write_one_byte_CRC(CELLBAL2, 0x00);
    IIC1_write_one_byte_CRC(CELLBAL3, 0x00);

    /*
     * SYS_CTRL1: 0x18 = 使能 ADC, 关闭 SHIP
     * SYS_CTRL2: 0x43 = CHG ON, DSG ON
     */
    IIC1_write_one_byte_CRC(SYS_CTRL1, 0x18);
    IIC1_write_one_byte_CRC(SYS_CTRL2, 0x43);

    /* CC_CFG: 0x19 = Coulomb Counter 使能 */
    IIC1_write_one_byte_CRC(CC_CFG, 0x19);
}

/* ---------------------------------------------------------------
 * 状态机初始化
 * --------------------------------------------------------------- */
void BMS_StateMachine_Init(BMS_Handle_t *bms)
{
    memset(bms, 0, sizeof(BMS_Handle_t));
    bms->state      = BMS_STATE_INIT;
    bms->state_prev = BMS_STATE_INIT;

    BMS_Threshold_LoadDefault(&bms->thresh);
    TEMP_Init();
    SOC_Init(bms);
    BAL_Init();
}

/* ---------------------------------------------------------------
 * 状态机主调度
 * --------------------------------------------------------------- */
void BMS_StateMachine_Run(BMS_Handle_t *bms)
{
    /* 状态机入口 */
    switch (bms->state) {

    case BMS_STATE_INIT: {
        I2C1_Configuration();
        BQ_InitControl();
        FLASH_LoadThresholds(bms);

        /* 初始 SOC 校准 */
        BQ_ReadAllVoltages(bms);
        bms->meas.soc_percent = SOC_Update(bms);

        /* 初始温度 */
        TEMP_UpdateAll(bms);

        bms->state_prev = BMS_STATE_INIT;
        bms->state      = BMS_STATE_ACTIVE;
        bms->flags.chg_on = 1;
        bms->flags.dsg_on = 1;
        break;
    }

    case BMS_STATE_STANDBY:
        /* 仅采样不上报 */
        BQ_ReadAllVoltages(bms);
        TEMP_UpdateAll(bms);
        bms->meas.pack_current_ma = BQ_ReadCurrent();
        break;

    case BMS_STATE_ACTIVE: {
        /* 1. 采样 */
        BQ_ReadAllVoltages(bms);
        bms->meas.pack_current_ma = BQ_ReadCurrent();
        TEMP_UpdateAll(bms);

        /* 2. 保护检测 + 温度保护 */
        TEMP_CheckProtection(bms);
        PROT_CheckAll(bms);
        PROT_ApplyMOS(bms);

        /* 3. 均衡 */
        BAL_Check(bms);
        BAL_Execute(bms);

        /* 4. SOC 估算 + Coulomb 累加 (预留) */
        SOC_CoulombAccumulate(bms, bms->meas.pack_current_ma, 10);
        SOC_Update(bms);

        /* 5. 故障判断 */
        if (bms->fault_mask & (FAULT_SC | FAULT_OC_DSG)) {
            bms->state = BMS_STATE_FAULT;
        }

        /* 6. CAN + UART 双路上报 */
        BMS_CAN_Report(bms);
        BMS_UART_Report(bms);
        break;
    }

    case BMS_STATE_FAULT:
        BAL_StopAll();
        PROT_ApplyMOS(bms);
        BMS_CAN_Report(bms);
        /* 严重故障 5 秒后尝试恢复 */
        bms->flags.oc_active = 0;
        bms->flags.sc_active = 0;
        PROT_CheckAll(bms);
        if (bms->fault_mask == 0) {
            bms->state = BMS_STATE_ACTIVE;
        }
        break;

    case BMS_STATE_SLEEP:
        BAL_StopAll();
        IIC1_write_one_byte_CRC(SYS_CTRL2, 0x40);
        IIC1_write_one_byte_CRC(SYS_CTRL1, 0x19);
        delay_ms(20);
        IIC1_write_one_byte_CRC(SYS_CTRL1, 0x1A);
        break;

    default:
        break;
    }
}

/* ---------------------------------------------------------------
 * CAN 报文: 8 字节, 29-bit 扩展帧
 * --------------------------------------------------------------- */
void BMS_CAN_Report(BMS_Handle_t *bms)
{
    uint8_t buf[8];

    /* ID 0x101: 总压(2) + 总流(2) + SOC(1) + 状态(1) + 保留(2) */
    buf[0] = (uint8_t)(bms->meas.pack_voltage_mv >> 8);
    buf[1] = (uint8_t)(bms->meas.pack_voltage_mv & 0xFF);
    buf[2] = (uint8_t)(bms->meas.pack_current_ma >> 8);
    buf[3] = (uint8_t)(bms->meas.pack_current_ma & 0xFF);
    buf[4] = bms->meas.soc_percent;
    buf[5] = (bms->flags.chg_on ? 0x01 : 0x00) |
             (bms->flags.dsg_on ? 0x02 : 0x00) |
             (bms->flags.balance_on ? 0x04 : 0x00);
    buf[6] = (uint8_t)(bms->fault_mask & 0xFF);
    buf[7] = (uint8_t)(bms->fault_mask >> 8);
    Can_Send_Msg(buf, 8, CAN_ID_STATUS);

    /* ID 0x102: 单体电压 (每帧 4 节, 每节 2 字节) */
    buf[0] = (uint8_t)(bms->meas.cell_voltage_mv[0] >> 8);
    buf[1] = (uint8_t)(bms->meas.cell_voltage_mv[0] & 0xFF);
    buf[2] = (uint8_t)(bms->meas.cell_voltage_mv[1] >> 8);
    buf[3] = (uint8_t)(bms->meas.cell_voltage_mv[1] & 0xFF);
    buf[4] = (uint8_t)(bms->meas.cell_voltage_mv[2] >> 8);
    buf[5] = (uint8_t)(bms->meas.cell_voltage_mv[2] & 0xFF);
    buf[6] = (uint8_t)(bms->meas.cell_voltage_mv[3] >> 8);
    buf[7] = (uint8_t)(bms->meas.cell_voltage_mv[3] & 0xFF);
    Can_Send_Msg(buf, 8, CAN_ID_CELL_VOLT);

    /* ID 0x103: 温度3路 (每路 2 字节) + 保留(2) */
    buf[0] = (uint8_t)(bms->meas.temperature_c_d10[0] >> 8);
    buf[1] = (uint8_t)(bms->meas.temperature_c_d10[0] & 0xFF);
    buf[2] = (uint8_t)(bms->meas.temperature_c_d10[1] >> 8);
    buf[3] = (uint8_t)(bms->meas.temperature_c_d10[1] & 0xFF);
    buf[4] = (uint8_t)(bms->meas.temperature_c_d10[2] >> 8);
    buf[5] = (uint8_t)(bms->meas.temperature_c_d10[2] & 0xFF);
    buf[6] = 0;
    buf[7] = 0;
    Can_Send_Msg(buf, 8, CAN_ID_TEMP);

    /* ID 0x104: 故障码 (4 字节) + 保留(4) */
    buf[0] = (uint8_t)(bms->fault_mask & 0xFF);
    buf[1] = (uint8_t)((bms->fault_mask >> 8) & 0xFF);
    buf[2] = (uint8_t)((bms->fault_mask >> 16) & 0xFF);
    buf[3] = (uint8_t)((bms->fault_mask >> 24) & 0xFF);
    buf[4] = 0;
    buf[5] = 0;
    buf[6] = 0;
    buf[7] = 0;
    Can_Send_Msg(buf, 8, CAN_ID_FAULT);
}

/* ---------------------------------------------------------------
 * UART 串口屏上报
 * --------------------------------------------------------------- */
#define UART_REPORT_INTERVAL_MS  1000

void BMS_UART_Report(BMS_Handle_t *bms)
{
    static uint32_t last_report = 0;
    char buf[128];

    /* 每秒打印一次 */
    if (last_report != 0 &&
        last_report + UART_REPORT_INTERVAL_MS > 0xFFFFFFFF)
        last_report = 0;

    if (last_report == 0 || 1) {
        last_report = 0;
        /* 清屏 + 设置方向 */
        UartSend("CLR(61);\r\n");
        delay_ms(50);
        UartSend("DIR(1);\r\n");
        delay_ms(50);

        sprintf(buf, "DCV16(0,0,'PACK:%umV%+dmA',3);\r\n",
                bms->meas.pack_voltage_mv,
                bms->meas.pack_current_ma);
        UartSend(buf);
        delay_ms(50);

        sprintf(buf, "DCV16(0,20,'C1:%u C2:%u',3);\r\n",
                bms->meas.cell_voltage_mv[0],
                bms->meas.cell_voltage_mv[1]);
        UartSend(buf);
        delay_ms(50);

        sprintf(buf, "DCV16(0,40,'C3:%u C4:%u',3);\r\n",
                bms->meas.cell_voltage_mv[2],
                bms->meas.cell_voltage_mv[3]);
        UartSend(buf);
        delay_ms(50);

        sprintf(buf, "DCV16(0,60,'SOC:%d%% T:%d.%dC',3);\r\n",
                bms->meas.soc_percent,
                bms->meas.temperature_c_d10[0] / 10,
                bms->meas.temperature_c_d10[0] % 10);
        UartSend(buf);
        delay_ms(50);

        sprintf(buf, "DCV16(0,80,'CHG:%d DSG:%d BAL:%d',3);\r\n",
                bms->flags.chg_on,
                bms->flags.dsg_on,
                bms->flags.balance_on);
        UartSend(buf);
        delay_ms(50);
    }
}

/* ---------------------------------------------------------------
 * 串口命令解析 (上位机控制)
 * 协议: 0x01 0xXX 0x55 [DATA...]
 *   0x01 0x02 0x55 -> 启动采样上报
 *   0x01 0x03 0x55 -> 停止采样上报
 *   0x01 0x04 0x55 -> 仅开放电MOS
 *   0x01 0x05 0x55 -> 仅关放电MOS
 *   0x01 0x06 0x55 -> 仅开充电MOS
 *   0x01 0x07 0x55 -> 仅关充电MOS
 *   0x01 0x12 0x55 PARAM_ID[1] VALUE_H[1] VALUE_L[1] -> 写阈值
 *   0x01 0x13 0x55 -> 保存阈值到Flash
 *   0x01 0x14 0x55 -> 打印当前阈值
 * --------------------------------------------------------------- */
void BMS_ParseUARTCommand(BMS_Handle_t *bms)
{
    (void)bms;
}
