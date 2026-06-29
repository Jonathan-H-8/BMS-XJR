#ifndef __BALANCE_H
#define __BALANCE_H

#include "stdint.h"
#include "bms_data.h"

/* 均衡管理初始化 */
void BAL_Init(void);

/* 检测是否需要均衡, 更新 bms->flags.balance_on */
void BAL_Check(BMS_Handle_t *bms);

/* 应用均衡控制到 BQ76940 硬件 (考虑非相邻串约束) */
void BAL_Execute(BMS_Handle_t *bms);

/* 强制停止所有均衡 */
void BAL_StopAll(void);

/* 获取当前最大/最小电压串的索引和电压值 */
void BAL_GetMinMax(BMS_Handle_t *bms,
                   uint8_t *idx_max, uint16_t *volt_max,
                   uint8_t *idx_min, uint16_t *volt_min);

#endif
