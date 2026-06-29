/******************************************************************************
 * protection.c
 * 保护逻辑: OV, UV, OC, SC, OT 检测 + MOS 决策 + 延时消抖
 ******************************************************************************/
#include "protection.h"
#include "BQ76930.h"
#include "i2c1.h"

/* ---- 保护延时计数器 ---- */
typedef struct {
    uint16_t ov_cnt;
    uint16_t uv_cnt;
    uint16_t oc_cnt;
    uint16_t ot_cnt;
} prot_delay_t;

static prot_delay_t prot_dly;

/* 默认阈值 */
void BMS_Threshold_LoadDefault(BMS_Threshold_t *thresh)
{
    thresh->ov_thresh_mv          = 3650;
    thresh->ov_recovery_mv        = 3450;
    thresh->ov_delay_ms           = 2000;
    thresh->uv_thresh_mv          = 2500;
    thresh->uv_recovery_mv        = 2700;
    thresh->uv_delay_ms           = 2000;
    thresh->oc_dsg_thresh_ma      = 20000;
    thresh->oc_chg_thresh_ma      = 8000;
    thresh->oc_delay_ms           = 100;
    thresh->sc_thresh_ma          = 40000;
    thresh->sc_delay_us           = 400;
    thresh->ot_dsg_thresh_c_d10   = 650;
    thresh->ot_chg_thresh_c_d10   = 550;
    thresh->ot_recovery_c_d10     = 500;
    thresh->ut_thresh_c_d10       = -100;
    thresh->ut_recovery_c_d10     = -50;
    thresh->balance_thresh_mv     = 20;
    thresh->balance_min_mv        = 3000;
}

/* ---- OV 检测 ---- */
uint32_t PROT_CheckOV(BMS_Handle_t *bms)
{
    uint8_t i;
    uint32_t fault = 0;
    for (i = 0; i < CELL_COUNT; i++) {
        if (bms->meas.cell_voltage_mv[i] >
            bms->thresh.ov_thresh_mv) {
            fault |= FAULT_OV;
            break;
        }
    }
    if (fault) {
        prot_dly.ov_cnt++;
        if (prot_dly.ov_cnt * 10 >= bms->thresh.ov_delay_ms) {
            bms->flags.ov_active = 1;
        }
    } else {
        if (bms->flags.ov_active) {
            uint8_t all_recovered = 1;
            for (i = 0; i < CELL_COUNT; i++) {
                if (bms->meas.cell_voltage_mv[i] >
                    bms->thresh.ov_recovery_mv) {
                    all_recovered = 0;
                    break;
                }
            }
            if (all_recovered) bms->flags.ov_active = 0;
        }
        prot_dly.ov_cnt = 0;
    }
    return (bms->flags.ov_active) ? FAULT_OV : 0;
}

/* ---- UV 检测 ---- */
uint32_t PROT_CheckUV(BMS_Handle_t *bms)
{
    uint8_t i;
    uint32_t fault = 0;
    for (i = 0; i < CELL_COUNT; i++) {
        if (bms->meas.cell_voltage_mv[i] > 0 &&
            bms->meas.cell_voltage_mv[i] <
            bms->thresh.uv_thresh_mv) {
            fault |= FAULT_UV;
            break;
        }
    }
    if (fault) {
        prot_dly.uv_cnt++;
        if (prot_dly.uv_cnt * 10 >= bms->thresh.uv_delay_ms) {
            bms->flags.uv_active = 1;
        }
    } else {
        if (bms->flags.uv_active) {
            uint8_t all_recovered = 1;
            for (i = 0; i < CELL_COUNT; i++) {
                if (bms->meas.cell_voltage_mv[i] > 0 &&
                    bms->meas.cell_voltage_mv[i] <
                    bms->thresh.uv_recovery_mv) {
                    all_recovered = 0;
                    break;
                }
            }
            if (all_recovered) bms->flags.uv_active = 0;
        }
        prot_dly.uv_cnt = 0;
    }
    return (bms->flags.uv_active) ? FAULT_UV : 0;
}

/* ---- OC 检测 ---- */
uint32_t PROT_CheckOC(BMS_Handle_t *bms)
{
    uint32_t fault = 0;
    int16_t  current_abs = bms->meas.pack_current_ma;
    if (current_abs < 0) current_abs = -current_abs;

    if (current_abs > bms->thresh.oc_dsg_thresh_ma ||
        (bms->meas.pack_current_ma < 0 &&
         -bms->meas.pack_current_ma > bms->thresh.oc_chg_thresh_ma)) {
        fault |= FAULT_OC_DSG;
        prot_dly.oc_cnt++;
        if (prot_dly.oc_cnt * 10 >= bms->thresh.oc_delay_ms) {
            bms->flags.oc_active = 1;
        }
    } else {
        bms->flags.oc_active = 0;
        prot_dly.oc_cnt = 0;
    }
    return (bms->flags.oc_active) ?
           (FAULT_OC_DSG | FAULT_OC_CHG) : 0;
}

/* ---- SC 检测 (无延时, 即时触发) ---- */
uint32_t PROT_CheckSC(BMS_Handle_t *bms)
{
    int16_t current_abs = bms->meas.pack_current_ma;
    if (current_abs < 0) current_abs = -current_abs;
    if (current_abs > bms->thresh.sc_thresh_ma) {
        bms->flags.sc_active = 1;
        return FAULT_SC;
    }
    bms->flags.sc_active = 0;
    return 0;
}

/* ---- OT 检测 (由 temp_mgr 完成, 此处为兼容保留) ---- */
uint32_t PROT_CheckOT(BMS_Handle_t *bms)
{
    return (bms->flags.ot_active) ? FAULT_OT : 0;
}

/* ---- 综合检测 ---- */
void PROT_CheckAll(BMS_Handle_t *bms)
{
    uint32_t fault = 0;
    fault |= PROT_CheckOV(bms);
    fault |= PROT_CheckUV(bms);
    fault |= PROT_CheckOC(bms);
    fault |= PROT_CheckSC(bms);
    fault |= PROT_CheckOT(bms);
    bms->fault_mask = fault;
}

/* ---- MOS 状态决策 ---- */
uint8_t PROT_UpdateMOSState(BMS_Handle_t *bms)
{
    uint8_t chg = 1, dsg = 1;

    /* 过压 -> 关充电 */
    if (bms->flags.ov_active) chg = 0;
    /* 欠压 -> 关放电 */
    if (bms->flags.uv_active) dsg = 0;
    /* 过流 -> 全关 */
    if (bms->flags.oc_active) { chg = 0; dsg = 0; }
    /* 短路 -> 全关 */
    if (bms->flags.sc_active) { chg = 0; dsg = 0; }
    /* 过温放电 -> 关放电, 过温充电 -> 关充电 */
    if (bms->flags.ot_active) {
        int16_t max_temp = bms->meas.temperature_c_d10[0];
        int16_t min_temp = max_temp;
        uint8_t i;
        for (i = 1; i < TEMP_SENSOR_COUNT; i++) {
            if (bms->meas.temperature_c_d10[i] > max_temp)
                max_temp = bms->meas.temperature_c_d10[i];
            if (bms->meas.temperature_c_d10[i] < min_temp)
                min_temp = bms->meas.temperature_c_d10[i];
        }
        if (max_temp > bms->thresh.ot_dsg_thresh_c_d10) dsg = 0;
        if (max_temp > bms->thresh.ot_chg_thresh_c_d10)  chg = 0;
        if (min_temp < bms->thresh.ut_thresh_c_d10)      chg = 0;
    }

    bms->flags.chg_on = chg;
    bms->flags.dsg_on = dsg;

    return (chg ? 0x01 : 0x00) | (dsg ? 0x02 : 0x00) | 0x40;
}

/* ---- 硬件写入 ---- */
void PROT_ApplyMOS(BMS_Handle_t *bms)
{
    uint8_t ctrl2 = PROT_UpdateMOSState(bms);
    IIC1_write_one_byte_CRC(SYS_CTRL2, ctrl2);
}

/* ---- 延时计数器 ---- */
void PROT_DelayTick(BMS_Handle_t *bms)
{
    (void)bms;
}
