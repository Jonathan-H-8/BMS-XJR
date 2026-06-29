#ifndef __SOC_H
#define __SOC_H

#include "stdint.h"
#include "bms_data.h"

/* SOC 估算方法 */
typedef enum {
    SOC_METHOD_OCV_TABLE  = 0,   /* 电压查表法 */
    SOC_METHOD_COULOMB    = 1,   /* 安时积分法 */
    SOC_METHOD_KALMAN     = 2,   /* 扩展卡尔曼 (预留) */
} SOC_Method_t;

/* 初始化 SOC 模块 */
void SOC_Init(BMS_Handle_t *bms);

/* 执行一次 SOC 更新，返回百分比 0~100 */
uint8_t SOC_Update(BMS_Handle_t *bms);

/* 基于 OCV 电压计算 SOC (用于上电校准 / 静置时) */
uint8_t SOC_EstimateByOCV(uint16_t cell_avg_mv);

/* 安时积分累加 (预留接口, 当 cc_enable==1 时调用) */
void SOC_CoulombAccumulate(BMS_Handle_t *bms, int16_t current_ma, uint32_t delta_ms);

/* 设置电池组总容量 (mAh) */
void SOC_SetCapacity(BMS_Handle_t *bms, uint32_t capacity_mah);

#endif
