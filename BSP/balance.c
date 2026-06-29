/******************************************************************************
 * balance.c
 * 均衡管理: 压差判断 + 启停控制 + 非相邻串安全约束
 * BQ76940 CELLBAL 寄存器位映射:
 *   CELLBAL1 bit0~4 -> 电池1~5
 *   CELLBAL2 bit0~4 -> 电池6~10
 *   CELLBAL3 bit0~4 -> 电池11~15
 ******************************************************************************/
#include "balance.h"
#include "BQ76930.h"
#include "i2c1.h"

/* 上一次均衡位, 防止重复写 I2C */
static uint32_t last_bal_bits = 0;

void BAL_Init(void)
{
    BAL_StopAll();
    last_bal_bits = 0;
}

/* ---- 获取最大/最小电压串索引 ---- */
void BAL_GetMinMax(BMS_Handle_t *bms,
                   uint8_t *idx_max, uint16_t *volt_max,
                   uint8_t *idx_min, uint16_t *volt_min)
{
    uint8_t i;
    *idx_max  = 0;
    *idx_min  = 0;
    *volt_max = bms->meas.cell_voltage_mv[0];
    *volt_min = bms->meas.cell_voltage_mv[0];
    for (i = 1; i < CELL_COUNT; i++) {
        if (bms->meas.cell_voltage_mv[i] > *volt_max) {
            *volt_max = bms->meas.cell_voltage_mv[i];
            *idx_max  = i;
        }
        if (bms->meas.cell_voltage_mv[i] > 0 &&
            bms->meas.cell_voltage_mv[i] < *volt_min) {
            *volt_min = bms->meas.cell_voltage_mv[i];
            *idx_min  = i;
        }
    }
}

/* ---- 均衡条件判断 ---- */
void BAL_Check(BMS_Handle_t *bms)
{
    uint8_t  idx_max, idx_min;
    uint16_t volt_max, volt_min;
    uint16_t diff;

    /* 故障状态禁止均衡 */
    if (bms->state == BMS_STATE_FAULT ||
        bms->state == BMS_STATE_SLEEP) {
        bms->flags.balance_on = 0;
        return;
    }

    BAL_GetMinMax(bms, &idx_max, &volt_max, &idx_min, &volt_min);
    diff = volt_max - volt_min;

    if (diff > bms->thresh.balance_thresh_mv &&
        volt_min > bms->thresh.balance_min_mv) {
        bms->flags.balance_on = 1;
    } else {
        bms->flags.balance_on = 0;
    }
}

/* ---- 检查两串是否可以同时均衡 (BQ76940 非相邻约束) ---- */
static uint8_t BAL_CanCoexist(uint8_t a, uint8_t b)
{
    if (a == b) return 1;
    if (a > b) { uint8_t t = a; a = b; b = t; }
    return (b - a) >= 2;
}

/* ---- 硬件均衡控制 ---- */
void BAL_Execute(BMS_Handle_t *bms)
{
    uint8_t  i;
    uint32_t bal_bitmap = 0;
    uint8_t  b1 = 0, b2 = 0, b3 = 0;

    if (!bms->flags.balance_on) {
        BAL_StopAll();
        last_bal_bits = 0;
        return;
    }

    /* 找到最高电压串, 开启均衡 */
    uint8_t  idx_max;
    uint16_t volt_max;
    uint8_t  idx_min;
    uint16_t volt_min;

    BAL_GetMinMax(bms, &idx_max, &volt_max, &idx_min, &volt_min);

    /* 仅均衡最高电压串 */
    bal_bitmap = (1UL << idx_max);

    if (bal_bitmap == last_bal_bits) return;
    last_bal_bits = bal_bitmap;

    b1 = (uint8_t)(bal_bitmap & 0x1F);
    b2 = (uint8_t)((bal_bitmap >> 5) & 0x1F);
    b3 = (uint8_t)((bal_bitmap >> 10) & 0x1F);

    IIC1_write_one_byte_CRC(CELLBAL1, b1);
    IIC1_write_one_byte_CRC(CELLBAL2, b2);
    IIC1_write_one_byte_CRC(CELLBAL3, b3);
}

/* ---- 全关均衡 ---- */
void BAL_StopAll(void)
{
    IIC1_write_one_byte_CRC(CELLBAL1, 0x00);
    IIC1_write_one_byte_CRC(CELLBAL2, 0x00);
    IIC1_write_one_byte_CRC(CELLBAL3, 0x00);
    last_bal_bits = 0;
}
