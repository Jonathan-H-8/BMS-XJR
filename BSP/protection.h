#ifndef __PROTECTION_H
#define __PROTECTION_H

#include "stdint.h"
#include "bms_data.h"

/* 保护条件检测 —— 返回新产生的 fault_mask */
uint32_t PROT_CheckOV(BMS_Handle_t *bms);
uint32_t PROT_CheckUV(BMS_Handle_t *bms);
uint32_t PROT_CheckOC(BMS_Handle_t *bms);
uint32_t PROT_CheckSC(BMS_Handle_t *bms);
uint32_t PROT_CheckOT(BMS_Handle_t *bms);

/* 一次调用所有保护检测, 更新 bms->fault_mask 和 bms->flags */
void PROT_CheckAll(BMS_Handle_t *bms);

/* 根据标志位和故障位决策 CHG/DSG 输出, 返回需要写 SYS_CTRL2 的值 */
uint8_t PROT_UpdateMOSState(BMS_Handle_t *bms);

/* 将 MOS 状态写入 BQ76940 硬件 */
void PROT_ApplyMOS(BMS_Handle_t *bms);

/* 延时计数器 (每1ms调用一次或在调度中累加) */
void PROT_DelayTick(BMS_Handle_t *bms);

#endif
