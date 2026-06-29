/******************************************************************************
 * flash_store.c
 * 阈值持久化: 掉电保存 + 上电自动加载
 * 使用 STM32F103 内部 Flash (最后一页)
 ******************************************************************************/
#include "flash_store.h"
#include "stm32f10x_flash.h"
#include "usart.h"
#include <string.h>

/* Flash 布局 (每页 1KB = 1024 字节):
 * +0x000: magic_number (uint16_t)
 * +0x002: BMS_Threshold_t
 * +0x040: reserved
 */
#define THRESH_OFFSET      0x002

/* ---- 辅助: Flash 写一个字 (32-bit) ---- */
static void FLASH_WriteWord(uint32_t addr, uint32_t data)
{
    FLASH_Unlock();
    FLASH_ProgramWord(addr, data);
    FLASH_Lock();
}

/* ---- 辅助: Flash 读一个字 ---- */
static uint32_t FLASH_ReadWord(uint32_t addr)
{
    return *(volatile uint32_t *)(addr);
}

/* ---- 擦除整页 ---- */
static void FLASH_ErasePageSafe(uint32_t addr)
{
    FLASH_Unlock();
    FLASH_ErasePage(addr);
    FLASH_Lock();
}

/* ---- 上电加载阈值 ---- */
void FLASH_LoadThresholds(BMS_Handle_t *bms)
{
    uint16_t magic;
    uint32_t base = FLASH_BASE_ADDR;

    magic = (uint16_t)(FLASH_ReadWord(base) & 0xFFFF);

    if (magic == FLASH_MAGIC_NUMBER) {
        /* Flash 数据有效, 逐字段加载 */
        uint32_t *src = (uint32_t *)(base + THRESH_OFFSET);
        uint32_t *dst = (uint32_t *)(&bms->thresh);
        uint8_t i;
        uint8_t count = sizeof(BMS_Threshold_t) / 4;
        if (sizeof(BMS_Threshold_t) % 4) count++;

        for (i = 0; i < count; i++) {
            dst[i] = FLASH_ReadWord((uint32_t)(src + i));
        }
    } else {
        /* 首次上电或数据损坏, 加载默认值 */
        BMS_Threshold_LoadDefault(&bms->thresh);
        FLASH_SaveThresholds(bms);
    }
}

/* ---- 保存阈值到 Flash ---- */
void FLASH_SaveThresholds(BMS_Handle_t *bms)
{
    uint32_t base = FLASH_BASE_ADDR;
    uint32_t *src = (uint32_t *)(&bms->thresh);
    uint8_t i;
    uint8_t count = sizeof(BMS_Threshold_t) / 4;
    if (sizeof(BMS_Threshold_t) % 4) count++;

    FLASH_ErasePageSafe(base);

    /* 写魔数 */
    FLASH_WriteWord(base, (uint32_t)FLASH_MAGIC_NUMBER);

    /* 写阈值结构体 */
    for (i = 0; i < count; i++) {
        FLASH_WriteWord(base + THRESH_OFFSET + i * 4, src[i]);
    }
}

/* ---- 串口修改单个阈值 ---- */
/* 参数 ID 定义 */
enum {
    PARAM_OV_THRESH = 0,
    PARAM_OV_RECOVERY,
    PARAM_OV_DELAY,
    PARAM_UV_THRESH,
    PARAM_UV_RECOVERY,
    PARAM_UV_DELAY,
    PARAM_OC_DSG,
    PARAM_OC_CHG,
    PARAM_OC_DELAY,
    PARAM_SC_THRESH,
    PARAM_SC_DELAY,
    PARAM_OT_DSG,
    PARAM_OT_CHG,
    PARAM_OT_RECOV,
    PARAM_UT_THRESH,
    PARAM_UT_RECOV,
    PARAM_BAL_THRESH,
    PARAM_BAL_MIN,
};

uint8_t FLASH_ParseThresholdCmd(BMS_Handle_t *bms, uint8_t param_id,
                                uint16_t value)
{
    switch (param_id) {
    case PARAM_OV_THRESH:   bms->thresh.ov_thresh_mv = value; break;
    case PARAM_OV_RECOVERY: bms->thresh.ov_recovery_mv = value; break;
    case PARAM_OV_DELAY:    bms->thresh.ov_delay_ms = value; break;
    case PARAM_UV_THRESH:   bms->thresh.uv_thresh_mv = value; break;
    case PARAM_UV_RECOVERY: bms->thresh.uv_recovery_mv = value; break;
    case PARAM_UV_DELAY:    bms->thresh.uv_delay_ms = value; break;
    case PARAM_OC_DSG:      bms->thresh.oc_dsg_thresh_ma = value; break;
    case PARAM_OC_CHG:      bms->thresh.oc_chg_thresh_ma = value; break;
    case PARAM_OC_DELAY:    bms->thresh.oc_delay_ms = value; break;
    case PARAM_SC_THRESH:   bms->thresh.sc_thresh_ma = value; break;
    case PARAM_SC_DELAY:    bms->thresh.sc_delay_us = value; break;
    case PARAM_OT_DSG:      bms->thresh.ot_dsg_thresh_c_d10 = (int16_t)value; break;
    case PARAM_OT_CHG:      bms->thresh.ot_chg_thresh_c_d10 = (int16_t)value; break;
    case PARAM_OT_RECOV:    bms->thresh.ot_recovery_c_d10 = (int16_t)value; break;
    case PARAM_UT_THRESH:   bms->thresh.ut_thresh_c_d10 = (int16_t)value; break;
    case PARAM_UT_RECOV:    bms->thresh.ut_recovery_c_d10 = (int16_t)value; break;
    case PARAM_BAL_THRESH:  bms->thresh.balance_thresh_mv = value; break;
    case PARAM_BAL_MIN:     bms->thresh.balance_min_mv = value; break;
    default: return 0;
    }
    FLASH_SaveThresholds(bms);
    return 1;
}

void FLASH_PrintThresholds(BMS_Handle_t *bms)
{
    char buf[128];
    (void)bms;
    sprintf(buf, "OV:%dmV/%dmV UV:%dmV/%dmV\r\n",
            bms->thresh.ov_thresh_mv, bms->thresh.ov_recovery_mv,
            bms->thresh.uv_thresh_mv, bms->thresh.uv_recovery_mv);
    UartSend(buf);
    sprintf(buf, "OC_D:%dmA OC_C:%dmA SC:%dmA\r\n",
            bms->thresh.oc_dsg_thresh_ma,
            bms->thresh.oc_chg_thresh_ma,
            bms->thresh.sc_thresh_ma);
    UartSend(buf);
    sprintf(buf, "OT_D:%d.%d'C OT_C:%d.%d'C UT:%d.%d'C\r\n",
            bms->thresh.ot_dsg_thresh_c_d10 / 10,
            bms->thresh.ot_dsg_thresh_c_d10 % 10,
            bms->thresh.ot_chg_thresh_c_d10 / 10,
            bms->thresh.ot_chg_thresh_c_d10 % 10,
            bms->thresh.ut_thresh_c_d10 / 10,
            bms->thresh.ut_thresh_c_d10 % 10);
    UartSend(buf);
    sprintf(buf, "Bal_diff:%dmV Bal_min:%dmV\r\n",
            bms->thresh.balance_thresh_mv,
            bms->thresh.balance_min_mv);
    UartSend(buf);
}
