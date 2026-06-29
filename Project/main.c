/******************** (C) BMS 2P4S FSAE  ********************************
 * 文件名  : main.c
 * 描述    : BMS 主程序入口
 * 版本    : V4.0 (模块化重构)
 * 作者    : XJRT BMS Team
 * 日期    : 2025-06
 * 硬件    : STM32F103RBT6 + BQ76940
 * 架构    : 驱动层 -> 保护逻辑层 -> 状态机层
 **********************************************************************************/

#include "stm32f10x.h"
#include "led.h"
#include "wdg.h"
#include "SYSTICK.h"
#include "usart.h"
#include "usart2.h"
#include "i2c.h"
#include "i2c1.h"
#include "BQ76930.h"
#include "IO_CTRL.h"
#include <stdio.h>
#include "can.h"
#include "stm32f10x_it.h"

#include "bms_data.h"
#include "bms_state.h"
#include "temp_mgr.h"
#include "soc.h"
#include "protection.h"
#include "balance.h"
#include "flash_store.h"

/* -------------------------------------------------------------------
 * BMS 全局句柄 (在 bms_state.c 中定义)
 * ------------------------------------------------------------------- */
extern BMS_Handle_t g_bms;

/* -------------------------------------------------------------------
 * 串口接收相关
 * ------------------------------------------------------------------- */
extern unsigned char ucUSART1_ReceiveDataBuffer[];
unsigned char BMS_DATA_FLAG;

/* -------------------------------------------------------------------
 * UART 命令处理 (兼容原接口 + 新增 Flash/阈值命令)
 * ------------------------------------------------------------------- */
static void RECEIVE_DATA_DEAL(void)
{
    uint8_t param_id;
    uint16_t value;

    if (Get_USART1_StopFlag() != USART1_STOP_TRUE) return;

    if (ucUSART1_ReceiveDataBuffer[0] == 0x01 &&
        ucUSART1_ReceiveDataBuffer[2] == 0x55) {

        switch (ucUSART1_ReceiveDataBuffer[1]) {

        case 0x02:   /* 启动上报 */
            BMS_DATA_FLAG = 1;
            LEDXToggle(5);
            break;

        case 0x03:   /* 停止上报 */
            BMS_DATA_FLAG = 0;
            LEDXToggle(5);
            break;

        case 0x04:   /* 仅开放电 MOS */
            LEDXToggle(5);
            g_bms.flags.dsg_on = 1;
            IIC1_write_one_byte_CRC(SYS_CTRL2, 0x43);
            break;

        case 0x05:   /* 仅关放电 MOS */
            LEDXToggle(5);
            g_bms.flags.dsg_on = 0;
            IIC1_write_one_byte_CRC(SYS_CTRL2, 0x41);
            break;

        case 0x06:   /* 仅开充电 MOS */
            LEDXToggle(5);
            g_bms.flags.chg_on = 1;
            IIC1_write_one_byte_CRC(SYS_CTRL2, 0x43);
            break;

        case 0x07:   /* 仅关充电 MOS */
            LEDXToggle(5);
            g_bms.flags.chg_on = 0;
            IIC1_write_one_byte_CRC(SYS_CTRL2, 0x42);
            break;

        case 0x12:   /* 写阈值参数 */
            LEDXToggle(5);
            param_id = ucUSART1_ReceiveDataBuffer[3];
            value = ((uint16_t)ucUSART1_ReceiveDataBuffer[4] << 8) |
                    ucUSART1_ReceiveDataBuffer[5];
            FLASH_ParseThresholdCmd(&g_bms, param_id, value);
            UartSend("Threshold updated\r\n");
            break;

        case 0x13:   /* 保存阈值 */
            LEDXToggle(5);
            FLASH_SaveThresholds(&g_bms);
            UartSend("Threshold saved to Flash\r\n");
            break;

        case 0x14:   /* 打印阈值 */
            LEDXToggle(5);
            FLASH_PrintThresholds(&g_bms);
            break;

        case 0x15:   /* 加载默认阈值 */
            LEDXToggle(5);
            BMS_Threshold_LoadDefault(&g_bms.thresh);
            FLASH_SaveThresholds(&g_bms);
            UartSend("Default thresholds loaded\r\n");
            break;

        default:
            break;
        }
    }
    Set_USART1_StopFlag(USART1_STOP_FALSE);
}

/* -------------------------------------------------------------------
 * 主函数
 * ------------------------------------------------------------------- */
int main(void)
{
    u8 canbuf[8];

    /* 1. 硬件初始化 */
    SYSTICK_Init();
    NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);
    delay_ms(1000);

    uart_init(115200);
    USART2_Config();

    LED_GPIO_Config();
    IO_CTRL_Config();

    I2C1_Configuration();
    CAN_Mode_Init(CAN_SJW_1tq, CAN_BS2_8tq, CAN_BS1_9tq, 4,
                  CAN_Mode_Normal);

    /* 2. BMS 状态机初始化 */
    BMS_StateMachine_Init(&g_bms);
    LED4_ONOFF(1);

    /* 3. 看门狗 (4 秒) */
    IWDG_Init(6, 1250);

    /* 4. 主循环 */
    while (1)
    {
        IWDG_Feed();
        LEDXToggle(1);

        /* CAN 接收 */
        Can_Receive_Msg(canbuf);

        /* UART 命令处理 */
        RECEIVE_DATA_DEAL();

        /* 状态机主调度 */
        BMS_StateMachine_Run(&g_bms);

        /* 延时 (约 10ms 一周期) */
        delay_ms(10);
    }
}

/*********************************************************************************************************
      END FILE
*********************************************************************************************************/
