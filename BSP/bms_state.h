#ifndef __BMS_STATE_H
#define __BMS_STATE_H

#include "bms_data.h"

/* 状态机初始化 */
void BMS_StateMachine_Init(BMS_Handle_t *bms);

/* 状态机主调度 —— 每周期调用一次 */
void BMS_StateMachine_Run(BMS_Handle_t *bms);

/* CAN 数据上报 */
void BMS_CAN_Report(BMS_Handle_t *bms);

/* UART 串口屏数据上报 */
void BMS_UART_Report(BMS_Handle_t *bms);

/* 串口命令解析入口 */
void BMS_ParseUARTCommand(BMS_Handle_t *bms);

#endif
