#ifndef __FLASH_STORE_H
#define __FLASH_STORE_H

#include "stdint.h"
#include "bms_data.h"

/* Flash 存储基地址 (64KB Flash, 页大小 1KB, 使用最后一页) */
#define FLASH_BASE_ADDR     0x0800F800
#define FLASH_MAGIC_NUMBER  0xB5A4    /* 校验魔数 */

/* 初始化 Flash 存储: 上电时读取阈值, 若无效则加载默认值 */
void FLASH_LoadThresholds(BMS_Handle_t *bms);

/* 将当前阈值写入 Flash (持久化) */
void FLASH_SaveThresholds(BMS_Handle_t *bms);

/* 串口命令解析: 修改单个阈值项 */
uint8_t FLASH_ParseThresholdCmd(BMS_Handle_t *bms, uint8_t param_id,
                                uint16_t value);

/* 读取阈值 ID 列表 (供上位机查询) */
void FLASH_PrintThresholds(BMS_Handle_t *bms);

#endif
