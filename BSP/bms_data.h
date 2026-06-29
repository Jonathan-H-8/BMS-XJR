#ifndef __BMS_DATA_H
#define __BMS_DATA_H

#include "stdint.h"

/* ================================================================
   电池组配置 — 2P4S
   ================================================================ */
#define CELL_COUNT           4
#define TEMP_SENSOR_COUNT    3
#define NOMINAL_CELL_MV      3200
#define PACK_FULL_MV         (CELL_COUNT * 3600)
#define PACK_EMPTY_MV        (CELL_COUNT * 2800)

/* ================================================================
   BQ769X0 扩展寄存器 (覆盖 BQ76930.h 未定义的 VC11~VC15)
   ================================================================ */
#define VC11_HI_BYTE  0x20
#define VC11_LO_BYTE  0x21
#define VC12_HI_BYTE  0x22
#define VC12_LO_BYTE  0x23
#define VC13_HI_BYTE  0x24
#define VC13_LO_BYTE  0x25
#define VC14_HI_BYTE  0x26
#define VC14_LO_BYTE  0x27
#define VC15_HI_BYTE  0x28
#define VC15_LO_BYTE  0x29

/* ================================================================
   BMS 主状态枚举
   ================================================================ */
typedef enum {
    BMS_STATE_INIT      = 0x00,    /* 上电初始化, 唤醒BQ, 加载配置 */
    BMS_STATE_STANDBY   = 0x01,    /* 待机, 只采样不控MOS */
    BMS_STATE_PRECHARGE = 0x02,    /* 预充电 */
    BMS_STATE_ACTIVE    = 0x03,    /* 正常运行 */
    BMS_STATE_FAULT     = 0x04,    /* 故障状态, 全关MOS, 等待恢复 */
    BMS_STATE_SLEEP     = 0x05,    /* 休眠 / SHIP 模式 */
} BMS_State_t;

/* ================================================================
   故障码位定义 (fault_mask 位域)
   ================================================================ */
#define FAULT_OV         (1UL << 0)
#define FAULT_UV         (1UL << 1)
#define FAULT_OC_CHG     (1UL << 2)
#define FAULT_OC_DSG     (1UL << 3)
#define FAULT_SC         (1UL << 4)
#define FAULT_OT         (1UL << 5)
#define FAULT_OPEN_CELL  (1UL << 6)
#define FAULT_TEMP_SENS  (1UL << 7)

/* ================================================================
   温度通道索引
   ================================================================ */
#define TEMP_CH_BATTERY   0
#define TEMP_CH_MOSFET    1
#define TEMP_CH_AMBIENT   2

/* ================================================================
   实时测量数据
   ================================================================ */
typedef struct {
    uint16_t cell_voltage_mv[CELL_COUNT];
    uint16_t pack_voltage_mv;
    int16_t  pack_current_ma;
    int16_t  temperature_c_d10[TEMP_SENSOR_COUNT];  /* °C ×10 */
    uint8_t  soc_percent;
} BMS_Measurement_t;

/* ================================================================
   安时积分法 (Coulomb Counting) 变量预留
   第一阶段用 OCV 查表法校准 SOC，之后可切换到库仑计数
   ================================================================ */
typedef struct {
    uint32_t total_capacity_mAs;       /* 电池组额定容量 (mA·s) */
    int32_t  current_accumulated_mAs;  /* 累计充放电量 */
    int32_t  last_current_ma;          /* 上一次电流值 */
    uint32_t last_tick_ms;             /* 上一次积分时间戳 */
    uint8_t  cc_enable;                /* 库仑计数功能使能 */
    uint8_t  cc_first_valid;           /* 首次有效校准标志 */
} BMS_CoulombCnt_t;

/* ================================================================
   可配置保护阈值 (掉电保存至Flash)
   ================================================================ */
typedef struct {
    uint16_t ov_thresh_mv;          /* 过压阈值       (默认 3650) */
    uint16_t ov_recovery_mv;        /* 过压恢复       (默认 3450) */
    uint16_t ov_delay_ms;           /* 过压确认延时   (默认 2000) */
    uint16_t uv_thresh_mv;          /* 欠压阈值        (默认 2500) */
    uint16_t uv_recovery_mv;        /* 欠压恢复        (默认 2700) */
    uint16_t uv_delay_ms;           /* 欠压确认延时    (默认 2000) */
    uint16_t oc_dsg_thresh_ma;      /* 放电过流        (默认 20000) */
    uint16_t oc_chg_thresh_ma;      /* 充电过流        (默认 8000)  */
    uint16_t oc_delay_ms;           /* 过流确认延时    (默认 1000)  */
    uint16_t sc_thresh_ma;          /* 短路保护        (默认 40000) */
    uint16_t sc_delay_us;           /* 短路确认延时    (默认 400)   */
    int16_t  ot_dsg_thresh_c_d10;   /* 过温放电阈值    (默认 650) 即65.0°C */
    int16_t  ot_chg_thresh_c_d10;   /* 过温充电阈值    (默认 550) 即55.0°C */
    int16_t  ot_recovery_c_d10;     /* 过温恢复        (默认 500) 即50.0°C */
    int16_t  ut_thresh_c_d10;       /* 低温保护        (默认 -100)即-10.0°C */
    int16_t  ut_recovery_c_d10;     /* 低温恢复        (默认 -50) 即-5.0°C */
    uint16_t balance_thresh_mv;     /* 均衡开启压差    (默认 20) */
    uint16_t balance_min_mv;        /* 均衡最小电压    (默认 3000) */
} BMS_Threshold_t;

/* ================================================================
   系统实时标志位 (位域压缩)
   ================================================================ */
typedef struct {
    /* 报警标志 */
    uint8_t ov_active  : 1;
    uint8_t uv_active  : 1;
    uint8_t oc_active  : 1;
    uint8_t sc_active  : 1;
    uint8_t ot_active  : 1;
    uint8_t ut_active  : 1;
    /* MOS 实际状态 */
    uint8_t chg_on     : 1;
    uint8_t dsg_on     : 1;
    uint8_t balance_on : 1;
    /* 系统状态 */
    uint8_t sys_enable : 1;    /* 系统使能 (上位机下发) */
    uint8_t reserved   : 5;
    uint8_t fault_level;       /* 0=正常, 1=可恢复, 2=严重 */
} BMS_Flags_t;

/* ================================================================
   BMS 主句柄 — 汇集所有运行时数据
   ================================================================ */
typedef struct {
    BMS_Measurement_t  meas;
    BMS_Threshold_t    thresh;
    BMS_Flags_t        flags;
    BMS_CoulombCnt_t   coulomb;
    BMS_State_t        state;
    uint32_t           fault_mask;
    uint32_t           uptime_ms;
    uint8_t            state_prev;
} BMS_Handle_t;

/* ================================================================
   CAN 帧 ID 定义
   ================================================================ */
#define CAN_ID_STATUS       0x101
#define CAN_ID_CELL_VOLT    0x102
#define CAN_ID_TEMP         0x103
#define CAN_ID_FAULT        0x104

/* 默认阈值 */
void BMS_Threshold_LoadDefault(BMS_Threshold_t *thresh);

#endif
