# BMS — 2P4S 电池管理系统 (FSAE XJRT)

基于 **STM32F103RBT6** + **TI BQ76940** 的电池管理系统，面向 Formula SAE 电动赛车。

- **电池组**: 2并4串 (2P4S) 磷酸铁锂 (LFP) 电芯
- **通信**: CAN 500kbps (上报 VCU) + UART 115200 (串口屏 + 上位机调试)
- **开发环境**: Keil MDK-ARM (.uvprojx) / IAR
- **MCU 库**: STM32F10x_StdPeriph_Driver V3.50 + CMSIS

---

## 目录结构

```
BMS_s940/
├── BSP/             应用层代码 (驱动 + 逻辑 + 状态机)
│   ├── *.c          C 源文件
│   └── *.h          头文件
├── Project/         工程文件
│   ├── main.c       主程序入口
│   ├── stm32f10x_it.c/h  中断服务例程
│   ├── stm32f10x_conf.h  外设头文件配置
│   └── MDK-ARM/     Keil uVision 项目文件 (.uvprojx)
├── Libraries/       STM32 标准外设库 + CMSIS (不做修改)
├── config/          IAR 链接脚本 (.icf)
├── doc/             文档
└── AGENTS.md        AI 助手项目指引
```

---

## BSP 文件详解

### 硬件驱动层 — 直接操作 MCU 外设 / BQ76940 寄存器

<!-- ===== 硬件接口 ===== -->

| 文件 | 行数 | 功能描述 |
|---|---|---|
| **i2c1.c / .h** | 356 | **BQ76940 I2C 驱动** — 软件 bit-bang I2C，PB8(SCL) / PB9(SDA)，器件地址 `0x08`。提供 `IIC1_read_one_byte()`、`IIC1_write_one_byte_CRC()`（带 CRC8 校验，多项式 `0x07`） |
| **i2c2.c / .h** | 323 | **EEPROM I2C 驱动** — PB6(SCL) / PB7(SDA)，用于 AT24C08 EEPROM |
| **i2c.c / .h** | 336 | **通用 I2C 驱动** — `IIC_read_one_byte()` / `IIC_write_one_byte()`，用于 AT24C08 读写 |
| **BQ76930.c / .h** | 1282 | **BQ76940 芯片驱动** — 原始寄存器定义 + 各通道电压采样(`Get_Battery1`~`Get_Battery15`)、电流采样(`Get_BQ_Current`)、温度采样(`Get_BQ1_1_Temp`)、均衡控制(`Battery1_Balance`~`Battery15_Balance`)、MOS 控制(`Only_Open_CHG`/`Only_Close_DSG` 等)、保护设置(`OV_UV_1_PROTECT`)、系统状态读取 |
| **IO_CTRL.c / .h** | 42 | **GPIO 引脚定义** — BQ 唤醒(PB5)、QB 电源(PA0)、D 电源(PA1)、状态输入(PB12) 等宏定义 |
| **can.c / .h** | 154 | **CAN 通信驱动** — 500kbps, 29-bit 扩展帧 ID, `Can_Send_Msg(buf,len,appid)` / `Can_Receive_Msg(buf)` |
| **usart.c / .h** | 352 | **UART1 通信驱动** — 115200 bps, 用于上位机命令交互 + 串口屏(LCD)控制 |
| **usart2.c / .h** | 484 | **UART2 通信驱动** — 9600 bps, 用于调试输出 |
| **spi.c / .h** | 120 | **SPI 驱动** — 用于 W25Qxx Flash 存储器 |
| **wdg.c / .h** | 38 | **独立看门狗 IWDG** — 4 秒超时, 主循环喂狗 |
| **led.c / .h** | 72 | **LED 指示** — 板载 4 个 LED 控制 |
| **systick.c / .h** | 52 | **SysTick 滴答定时器** — 提供 `delay_ms()` 延时 |
| **timer.c / .h** | 171 | **TIM2 定时器** — 100ms 中断, 用于周期调度 |
| **w25qxx.c / .h** | 298 | **W25Qxx Flash 驱动** — SPI 外扩 Flash 读写 |

### 业务逻辑层 — 采样转换 / 保护算法 / 均衡策略

<!-- ===== 逻辑 ===== -->

| 文件 | 行数 | 功能描述 |
|---|---|---|
| **bms_data.h** | 154 | **核心数据结构** — 定义 `BMS_Handle_t` 主句柄，包含：<br>— `BMS_Measurement_t`：4 路单体电压、总压、总流、3 路温度、SOC<br>— `BMS_Threshold_t`：18 个可配置保护阈值 (OV/UV/OC/SC/OT/UT/Balance)<br>— `BMS_Flags_t`：11 个位域标志 (告警 + MOS 状态 + 系统状态)<br>— `BMS_CoulombCnt_t`：安时积分法预留变量 (`total_capacity_mAs` / `current_accumulated_mAs` 等)<br>— 状态枚举 `BMS_State_t` (INIT/STANDBY/PRECHARGE/ACTIVE/FAULT/SLEEP)<br>— 故障码位域定义 (FAULT_OV / UV / OC / SC / OT / OPEN_CELL / TEMP_SENS)<br>— CAN 帧 ID 定义 (0x101~0x104) |
| **temp_mgr.c / .h** | 234 | **温度管理** — 3 通道采样：<br>— BQ TS1 (0x2C/0x2D) → 电池包温度<br>— BQ TS2 (0x2E/0x2F) → MOS 散热片温度<br>— STM32 内部 ADC (通道 16) → 环境温度<br>— EMA 低通滤波 (α = 0.25)<br>— NTC 103AT 热敏电阻换算 (B=3380, Rp=10kΩ)<br>— 高低温保护检测 |
| **soc.c / .h** | 82 | **SOC 估算** — 第一阶段：21 点 OCV 查表法 (LFP 电池, 2800~3600mV)<br>— 预留 `SOC_CoulombAccumulate()` 安时积分接口<br>— `BMS_CoulombCnt_t` 变量在 `bms_data.h` 中定义 |
| **protection.c / .h** | 212 | **保护逻辑** — 延时消抖 + MOS 决策：<br>— `PROT_CheckOV()` / `PROT_CheckUV()` — 逐串电压检测，防抖恢复<br>— `PROT_CheckOC()` — 放电过流 / 充电过流<br>— `PROT_CheckSC()` — 短路保护<br>— `PROT_UpdateMOSState()` — 根据标志位决策 CHG/DSG 输出<br>— `PROT_ApplyMOS()` — 写入 `SYS_CTRL2` 寄存器 (0x05) |
| **balance.c / .h** | 121 | **均衡管理** — 压差判断 + 非相邻串安全约束：<br>— 最高电压串均衡，压差 > 阈值时开启<br>— BQ76940 限制：相邻串不能同时均衡<br>— 写入 `CELLBAL1` / `CELLBAL2` / `CELLBAL3` 寄存器 |
| **flash_store.c / .h** | 162 | **阈值持久化** — MCU 内部 Flash 最后页：<br>— 上电 `FLASH_LoadThresholds()` — 魔数校验后加载，无效则写默认值<br>— `FLASH_SaveThresholds()` — 擦除整页后写入<br>— `FLASH_ParseThresholdCmd()` — 上位机串口单字段修改<br>— 18 个阈值参数均支持在线配置 |

### 状态机层 — 系统调度 / 通信上报

<!-- ===== 状态机 ===== -->

| 文件 | 行数 | 功能描述 |
|---|---|---|
| **bms_state.c / .h** | 350 | **状态机 + 双路上报**：<br>— `BMS_StateMachine_Init()` — 初始化所有子模块<br>— `BMS_StateMachine_Run()` — 主循环调度 (10ms/周期)<br>— 状态间转换：`INIT → ACTIVE ↔ FAULT → SLEEP`<br>— `BMS_CAN_Report()` — CAN 发送 4 帧报文 (0x101~0x104)<br>— `BMS_UART_Report()` — 串口屏 DCV16 指令刷新<br> |

### 工程入口

<!-- ===== 主入口 ===== -->

| 文件 | 行数 | 功能描述 |
|---|---|---|
| **Project/main.c** | 178 | **主程序入口** — 外设初始化 → BMS 状态机初始化 → 主循环(看门狗喂狗 + CAN 接收 + UART 命令处理 + 状态机调度) |

---

## 状态机流程图

```
        ┌──────────────┐
        │    INIT     │   上电: 唤醒BQ76940, I2C校准, Flash读阈值, OCV初始SOC
        └──────┬───────┘
               │ 初始化完成
               ▼
        ┌──────────────┐
        │   ACTIVE    │ ←── 正常运行循环:
        └──────┬───────┘     · 采样(电压/电流/温度)
               │             · 保护检测(OV/UV/OC/SC/OT)
      ┌────────┴────────┐    · MOS 控制 (SYS_CTRL2)
      │                 │    · 均衡管理 (CELLBAL1~3)
      ▼                 │    · SOC 估算
 ┌──────────┐           │    · CAN + UART 上报
 │  FAULT  │────────────┘
 └────┬─────┘ 故障消除后恢复
      │严重故障
      ▼
 ┌──────────┐
 │  SLEEP  │   SHIP 低功耗模式
 └──────────┘
```

---

## CAN 报文协议 (29-bit 扩展帧, 500kbps)

| CAN ID | 方向 | DLC | 数据内容 |
|---|---|---|---|
| **0x101** | BMS → VCU | 8 | 总压(2B) + 总流(2B) + SOC(1B) + MOS状态(1B) + 故障码(2B) |
| **0x102** | BMS → VCU | 8 | 单体电压 C1(2B) + C2(2B) + C3(2B) + C4(2B) |
| **0x103** | BMS → VCU | 8 | 温度 T_Batt(2B) + T_MOS(2B) + T_Amb(2B) + 保留(2B) |
| **0x104** | BMS → VCU | 8 | fault_mask(4B) + 保留(4B) |

---

## UART 命令协议 (115200 bps)

所有命令格式: `0x01 0xXX 0x55 [DATA...]`

| 命令字节 | 功能 | 说明 |
|---|---|---|
| `0x02` | 启动上报 | BMS 开始周期性 CAN+UART 上报 |
| `0x03` | 停止上报 | BMS 停止上报 |
| `0x04` | DSG ON | 开启放电 MOS |
| `0x05` | DSG OFF | 关闭放电 MOS |
| `0x06` | CHG ON | 开启充电 MOS |
| `0x07` | CHG OFF | 关闭充电 MOS |
| `0x12` | 写阈值 | `[PARAM_ID] [VALUE_H] [VALUE_L]` — 立即修改阈值 |
| `0x13` | 保存阈值 | 将当前阈值持久化到 Flash |
| `0x14` | 打印阈值 | UART 输出当前所有阈值 |
| `0x15` | 恢复默认 | 恢复出厂默认阈值并保存 |

---

## BQ76940 寄存器快速参考

| 地址 | 宏名 | 功能 |
|---|---|---|
| 0x00 | `SYS_STAT` | 系统状态 (UV=bit3, OV=bit2, SCD=bit1, OCD=bit0) |
| 0x01~0x03 | `CELLBAL1~3` | 均衡控制 (bit0~4 → 串1~5/6~10/11~15) |
| 0x04 | `SYS_CTRL1` | 系统控制 (ADC 使能 / SHIP 模式) |
| **0x05** | **`SYS_CTRL2`** | **MOS 控制 (bit0=CHG, bit1=DSG)** |
| 0x06~0x08 | `PROTECT1~3` | 保护配置 (SCD/OCD 阈值和延时) |
| 0x09~0x0A | `OV_TRIP` / `UV_TRIP` | OV/UV 保护阈值 |
| 0x0B | `CC_CFG` | 库仑计配置 |
| 0x0C~0x13 | `VC1_LO/HI` ~ `VC4_LO/HI` | **4 路单体电压 ADC (14位)** |
| 0x2C~0x2F | `TS1` / `TS2` | 温度传感器 |
| 0x32~0x33 | `CC_HI` / `CC_LO` | **库仑计 (电流 ADC)** |
| 0x50~0x51, 0x59 | `ADCGAIN1` / `ADCOFFSET` / `ADCGAIN2` | ADC 校准参数 |

---

## 关键换算公式

```
电压(mV) = (raw_14bit × GAIN) / 1000 + ADC_offset
  其中 GAIN = 365 + ADC_GAIN (ADC_GAIN 读取自 0x50/0x59)

电流(mA) = raw_CC × 2.11  (4mΩ 采样电阻, 8 倍增益)
  方向: raw ≤ 0x7D00 → 放电; raw > 0x7D00 → 充电(取补码)

温度(°C) = 1 / (1/298.15 + ln(Rt/10000)/3380) − 273.15
  Rt = 10000 × V_TS / (3.3 − V_TS), V_TS = raw × 382μV
```

---

## 开发说明

1. **打开项目**: 用 Keil MDK 打开 `Project/MDK-ARM/BMS_DEMO.uvprojx`
2. **添加新文件**: 在 Keil IDE 中右键 BSP 组 → Add Existing Files to Group
3. **烧录**: 通过 J-Link 或串口 (FlyMcu.exe) 烧录 `Project/MDK-ARM/obj/BMS_DEMO.hex`
4. **调试串口**: UART1 115200 bps, 8N1
5. **看门狗**: 4 秒 IWDG, 主循环 `while(1)` 中必须喂狗
