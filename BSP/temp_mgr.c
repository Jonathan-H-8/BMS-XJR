/******************************************************************************
 * temp_mgr.c
 * 3通道温度管理: BQ_TS1(电池包), BQ_TS2(MOS), STM32_ADC(环境)
 * EMA 滤波防抖 + 高低温保护
 ******************************************************************************/
#include "temp_mgr.h"
#include "BQ76930.h"
#include "stm32f10x_adc.h"
#include "stm32f10x_gpio.h"
#include "stm32f10x_rcc.h"
#include "i2c1.h"
#include "math.h"
#include "usart.h"
#include <stdio.h>

/* ---- BQ76940 NTC 参数 (103AT) ---- */
#define NTC_RP          10000.0f
#define NTC_T2          298.15f
#define NTC_BX          3380.0f
#define NTC_KA          273.15f

/* ---- EMA 滤波器状态 ---- */
static int16_t ema_temp[TEMP_SENSOR_COUNT];
static uint8_t ema_inited = 0;

/* ---- ADC 初始化标志 ---- */
static uint8_t adc_inited = 0;

/* ---------------------------------------------------------------
 * NTC 电阻 -> 温度 (.C ×10)
 * --------------------------------------------------------------- */
static int16_t NTC_ResToTemp(float Rt)
{
    float temp_k;
    if (Rt <= 0.1f)  return -400;   /* -40.0.C */
    if (Rt >= 1e6f)  return -400;
    temp_k = 1.0f / (1.0f / NTC_T2 + (float)log((double)(Rt / NTC_RP)) / NTC_BX);
    return (int16_t)((temp_k - NTC_KA + 0.5f) * 10.0f);
}

/* ---------------------------------------------------------------
 * BQ76940 原始 ADC -> 温度 (.C ×10)
 * TS 寄存器 14 位值 V_TS = raw * 382 uV
 * NTC 分压: V_TS = 3.3 * R_PULLUP / (R_NTC + R_PULLUP)??
 * 实际: BQ 内部使用 18k (or 10k) 上拉到 REGOUT(3.3V)
 * 根据现有代码, 使用 10k 上拉, REGOUT=3.3V
 * Rt = Rpullup * Vts / (Vregout - Vts)
 *    = 10000 * (raw * 382e-6) / (3.3 - raw * 382e-6)
 * --------------------------------------------------------------- */
static int16_t BQ_TempConvert(uint16_t raw_adc)
{
    float vts, rt;
    vts = (float)raw_adc * 0.000382f;       /* 382 uV/LSB */
    if (vts >= 3.29f)  return 1200;          /* 短路 -> 120.C */
    if (vts <= 0.01f)  return -400;          /* 开路 -> -40.C */
    rt = 10000.0f * vts / (3.30f - vts);
    return NTC_ResToTemp(rt);
}

/* ---------------------------------------------------------------
 * STM32 ADC 读取环境温度 (绑定 MCU 内部温度传感器)
 * 这里使用软件触发 ADC1 单次转换
 * --------------------------------------------------------------- */
static void ADC_InitIfNeeded(void)
{
    ADC_InitTypeDef       ADC_InitStructure;
    GPIO_InitTypeDef      GPIO_InitStructure;

    if (adc_inited) return;
    adc_inited = 1;

    RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOB | RCC_APB2Periph_ADC1,
                           ENABLE);

    GPIO_InitStructure.GPIO_Pin  = GPIO_Pin_0;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AIN;
    GPIO_Init(GPIOB, &GPIO_InitStructure);

    RCC_ADCCLKConfig(RCC_PCLK2_Div6);
    ADC_DeInit(ADC1);
    ADC_InitStructure.ADC_Mode               = ADC_Mode_Independent;
    ADC_InitStructure.ADC_ScanConvMode       = DISABLE;
    ADC_InitStructure.ADC_ContinuousConvMode = DISABLE;
    ADC_InitStructure.ADC_ExternalTrigConv   = ADC_ExternalTrigConv_None;
    ADC_InitStructure.ADC_DataAlign          = ADC_DataAlign_Right;
    ADC_InitStructure.ADC_NbrOfChannel       = 1;
    ADC_Init(ADC1, &ADC_InitStructure);
    ADC_Cmd(ADC1, ENABLE);

    ADC_ResetCalibration(ADC1);
    while (ADC_GetResetCalibrationStatus(ADC1));
    ADC_StartCalibration(ADC1);
    while (ADC_GetCalibrationStatus(ADC1));
}

static uint16_t ADC_ReadChannel(uint8_t channel)
{
    ADC_RegularChannelConfig(ADC1, channel, 1, ADC_SampleTime_239Cycles5);
    ADC_SoftwareStartConvCmd(ADC1, ENABLE);
    while (!ADC_GetFlagStatus(ADC1, ADC_FLAG_EOC));
    return ADC_GetConversionValue(ADC1);
}

/* ---------------------------------------------------------------
 * 环境温度: 使用 STM32 内部温度传感器 (ADC_Channel_16)
 * V_sensor = ADC * Vref / 4096
 * Temp = (V25 - V_sensor) / Avg_Slope + 25
 * --------------------------------------------------------------- */
static int16_t STM32_ReadInternalTemp(void)
{
    uint16_t adc_val;
    float    v_sensor, temp_c;
    adc_val   = ADC_ReadChannel(ADC_Channel_16);
    v_sensor  = (float)adc_val * 3.30f / 4096.0f;
    temp_c    = (1.43f - v_sensor) * 1000.0f / 4.3f + 25.0f;
    return (int16_t)(temp_c * 10.0f);
}

/* ---------------------------------------------------------------
 * 公共接口
 * --------------------------------------------------------------- */
void TEMP_Init(void)
{
    uint8_t i;
    ADC_InitIfNeeded();
    for (i = 0; i < TEMP_SENSOR_COUNT; i++) {
        ema_temp[i] = 250;   /* 默认 25.0.C */
    }
    ema_inited = 1;
}

uint16_t TEMP_ReadRaw(uint8_t channel)
{
    uint8_t hi, lo;
    switch (channel) {
    case TEMP_CH_BATTERY:
        hi = IIC1_read_one_byte(TS1_HI_BYTE);
        lo = IIC1_read_one_byte(TS1_LO_BYTE);
        return ((uint16_t)hi << 8) | lo;
    case TEMP_CH_MOSFET:
        hi = IIC1_read_one_byte(TS2_HI_BYTE);
        lo = IIC1_read_one_byte(TS2_LO_BYTE);
        return ((uint16_t)hi << 8) | lo;
    case TEMP_CH_AMBIENT:
        return STM32_ReadInternalTemp();
    default:
        return TEMP_RAW_INVALID;
    }
}

int16_t TEMP_ReadFiltered(uint8_t channel)
{
    if (channel >= TEMP_SENSOR_COUNT) return 250;
    return ema_temp[channel];
}

void TEMP_UpdateAll(BMS_Handle_t *bms)
{
    int16_t raw_temp, new_val;
    uint8_t i;

    if (!ema_inited) TEMP_Init();

    for (i = 0; i < TEMP_SENSOR_COUNT; i++) {
        if (i == TEMP_CH_AMBIENT) {
            raw_temp = STM32_ReadInternalTemp();
        } else {
            uint16_t raw = TEMP_ReadRaw(i);
            raw_temp = BQ_TempConvert(raw);
        }

        /* EMA 滤波: val = alpha * raw + (1 - alpha) * prev */
        new_val = (int16_t)(
            ((int32_t)raw_temp * TEMP_EMA_ALPHA_NUM +
             (int32_t)ema_temp[i] *
                 (TEMP_EMA_ALPHA_DEN - TEMP_EMA_ALPHA_NUM))
            / TEMP_EMA_ALPHA_DEN);

        ema_temp[i] = new_val;
        bms->meas.temperature_c_d10[i] = new_val;
    }
}

uint32_t TEMP_CheckProtection(BMS_Handle_t *bms)
{
    uint32_t fault = 0;
    int16_t  batt = bms->meas.temperature_c_d10[TEMP_CH_BATTERY];
    int16_t  mosf = bms->meas.temperature_c_d10[TEMP_CH_MOSFET];
    int16_t  ambi = bms->meas.temperature_c_d10[TEMP_CH_AMBIENT];
    int16_t  max_temp = batt;
    int16_t  min_temp = batt;
    BMS_Threshold_t *t = &bms->thresh;

    if (mosf > max_temp) max_temp = mosf;
    if (ambi > max_temp) max_temp = ambi;
    if (mosf < min_temp) min_temp = mosf;
    if (ambi < min_temp) min_temp = ambi;

    /* 过温检测 (充电/放电区别) */
    if (max_temp > t->ot_dsg_thresh_c_d10) {
        fault |= FAULT_OT;
    }
    /* 低温检测 (充电时不允许低温充电) */
    if (min_temp < t->ut_thresh_c_d10) {
        /*
         * 低温只关 CHG, DISCHG 不受限
         * 但为了安全，故障信息上也记录
         */
        if (bms->flags.chg_on) {
            fault |= FAULT_OT;  /* 复用 OT 通道, 实际语义为温度异常 */
        }
    }

    if (fault != 0) {
        bms->flags.ot_active = 1;
    } else {
        bms->flags.ot_active = 0;
    }

    return fault;
}

void TEMP_PrintDebug(BMS_Handle_t *bms)
{
    char buf[128];
    sprintf(buf, "Batt:%d.%d'C MOS:%d.%d'C Amb:%d.%d'C\r\n",
            bms->meas.temperature_c_d10[0] / 10,
            bms->meas.temperature_c_d10[0] % 10,
            bms->meas.temperature_c_d10[1] / 10,
            bms->meas.temperature_c_d10[1] % 10,
            bms->meas.temperature_c_d10[2] / 10,
            bms->meas.temperature_c_d10[2] % 10);
    UartSend(buf);
}
