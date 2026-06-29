/******************************************************************************
 * soc.c
 * SOC 估算模块
 * 第一阶段: OCV 电压查表法 (LFP 电池)
 * 预留接口: Coulomb Counting 安时积分法
 ******************************************************************************/
#include "soc.h"

/* LFP 电池 OCV-SOC 表 (21点, 步长 5%) */
static const uint16_t ocv_table[21][2] = {
    {0,   2800}, {5,   2950}, {10,  3050},
    {15,  3150}, {20,  3190}, {25,  3210},
    {30,  3220}, {35,  3230}, {40,  3240},
    {45,  3250}, {50,  3270}, {55,  3280},
    {60,  3290}, {65,  3300}, {70,  3310},
    {75,  3320}, {80,  3350}, {85,  3380},
    {90,  3430}, {95,  3500}, {100, 3600},
};

uint8_t SOC_EstimateByOCV(uint16_t cell_avg_mv)
{
    uint8_t i;
    if (cell_avg_mv <= ocv_table[0][1])   return 0;
    if (cell_avg_mv >= ocv_table[20][1])  return 100;
    for (i = 0; i < 20; i++) {
        if (cell_avg_mv <= ocv_table[i + 1][1])
            return ocv_table[i][0];
    }
    return 100;
}

void SOC_Init(BMS_Handle_t *bms)
{
    bms->coulomb.total_capacity_mAs    = 60000UL * 3600UL;  /* 60Ah */
    bms->coulomb.current_accumulated_mAs = 0;
    bms->coulomb.last_current_ma         = 0;
    bms->coulomb.last_tick_ms            = 0;
    bms->coulomb.cc_enable               = 0;
    bms->coulomb.cc_first_valid          = 0;
}

uint8_t SOC_Update(BMS_Handle_t *bms)
{
    uint32_t sum_mv = 0;
    uint8_t  i, valid = 0;

    for (i = 0; i < CELL_COUNT; i++) {
        if (bms->meas.cell_voltage_mv[i] > 500) {
            sum_mv += bms->meas.cell_voltage_mv[i];
            valid++;
        }
    }
    if (valid == 0) return bms->meas.soc_percent;

    if (bms->coulomb.cc_enable && bms->coulomb.cc_first_valid) {
        if (bms->coulomb.current_accumulated_mAs >= 0) {
            int32_t used = (int32_t)bms->coulomb.total_capacity_mAs
                         - bms->coulomb.current_accumulated_mAs;
            if (used > (int32_t)bms->coulomb.total_capacity_mAs)
                used = (int32_t)bms->coulomb.total_capacity_mAs;
            if (used < 0) used = 0;
            bms->meas.soc_percent = (uint8_t)(
                used * 100ULL / bms->coulomb.total_capacity_mAs);
        }
    } else {
        bms->meas.soc_percent = SOC_EstimateByOCV(sum_mv / valid);
    }
    return bms->meas.soc_percent;
}

void SOC_CoulombAccumulate(BMS_Handle_t *bms, int16_t current_ma,
                           uint32_t delta_ms)
{
    if (!bms->coulomb.cc_enable) return;
    bms->coulomb.current_accumulated_mAs +=
        (int32_t)current_ma * (int32_t)delta_ms / 1000;
}

void SOC_SetCapacity(BMS_Handle_t *bms, uint32_t capacity_mah)
{
    bms->coulomb.total_capacity_mAs = (uint32_t)capacity_mah * 3600UL;
}
