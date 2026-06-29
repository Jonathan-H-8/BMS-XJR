#ifndef __TEMP_MGR_H
#define __TEMP_MGR_H

#include "stdint.h"
#include "bms_data.h"

/* 温度滤波器参数 */
#define TEMP_EMA_ALPHA_NUM    2       /* 分子 */
#define TEMP_EMA_ALPHA_DEN    8       /* 分母 -> alpha = 0.25 */
#define TEMP_RAW_INVALID      0xFFFF

/* 温度管理初始化 */
void TEMP_Init(void);

/* 读取单个温度通道原始 ADC (供过滤使用) */
uint16_t TEMP_ReadRaw(uint8_t channel);

/* 读取过滤后的温度值 (单位: °C ×10) */
int16_t TEMP_ReadFiltered(uint8_t channel);

/* 一次采样并更新所有通道的EMA滤波器 —— 每周期调用一次 */
void TEMP_UpdateAll(BMS_Handle_t *bms);

/* 检查温度保护，返回触发的fault位 */
uint32_t TEMP_CheckProtection(BMS_Handle_t *bms);

/* ASCII打印温度调试信息 (UART) */
void TEMP_PrintDebug(BMS_Handle_t *bms);

#endif
