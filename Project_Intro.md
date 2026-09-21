# BMS — 4S2P (2P4S) 12V 电池管理系统 (FSAE XJRT)

基于 **STM32F103C8T6** + **TI BQ76920 (BQ7692003PWR)** 的 4 串磷酸铁锂 (LFP) 电池管理系统，面向 Formula SAE 电动赛车的 12V 低压电池组。

- **电池组**: 4 串 2 并 (4S2P / 2P4S) 磷酸铁锂 (LFP)，额定 12.8V
- **AFE**: TI BQ7692003PWR（BQ76920，3~5 节，TSSOP-20）
- **MCU**: STM32F103C8T6 核心板模块（立创地阔星，64KB Flash / 20KB RAM / 72MHz）
- **通信**: CAN 500kbps（29-bit 扩展帧，上报 VCU）+ UART1 115200（串口屏 + 上位机调试）
- **开发环境**: Keil MDK-ARM (.uvprojx)，STM32F10x_StdPeriph_Driver V3.50 + CMSIS

> ⚠️ **固件适配状态（重要）**：当前固件由厂商 **BQ76940 参考设计（BMS_s940）** 迁移而来，**正在适配到 BQ76920 硬件**。部分驱动仍是 BQ76940 遗留（15 节、双器件、TS2、W25Qxx 等），见文末「固件适配 TODO」章节。硬件接口以本文为准。

---

## 目标硬件速览（新板，来自 PCB/原理图）

| 项目 | 值 |
|---|---|
| AFE 型号 | BQ7692003PWR（BQ76920） |
| AFE 关键参数 | 3~5 节；LDO(REGOUT)=**3.3V**；CRC=**必须**；I2C 地址 **0x08** (7-bit) |
| MCU | STM32F103C8T6 核心板（40-pin 排针引出 GPIO） |
| 电源 | 12V → MP9486AGN-Z 降压 → 5V（R37=240k/R38=10k，VFB=0.2V → 5.0V）；核心板自带 3.3V LDO |
| CAN | TJA1050T 收发器（5V 供电） |
| 掉电存储 | AT24C02C EEPROM（2Kbit，I2C） |
| 电芯抽头连接器 | U2（5P PH：`+12V / C3+ / C2+ / C1+ / AGND`，直连电芯抽头，给外挂主动均衡板用） |
| 验证/监测连接器 | U7（5P PH：`VC5 / VC3 / VC2 / VC1 / VC0`，经 1kΩ，只读电压用） |
| 采样电阻 | 1mΩ（R17，3W，2512） |
| 电芯输入电阻 | R22~R26 = **1kΩ**（0603） |
| 电芯滤波电容 | C12~C15 = 100nF |
| 保护 MOS | Q5/Q6 = HY3210B（N-MOS，100V/120A，共漏背靠背） |
| 温度 | TS1（CN3 外接 NTC，R7=33kΩ，C6=1nF）；BQ76920 无 TS2 |

### 电芯连接（4 节配置，符合 TI 数据手册表 8-1）

| VC 引脚 | 接法 | 读取的电压 |
|---|---|---|
| VC0 (pin17) | B−（电芯1负极） | — |
| VC1 (pin16) | 电芯1正极（R25） | **CELL1 = VC1−VC0** |
| VC2 (pin15) | 电芯2正极（R24） | **CELL2 = VC2−VC1** |
| VC3 (pin14) | 电芯3正极（R23） | **CELL3 = VC3−VC2** |
| VC4 (pin13) | **与 VC3 短接** | （短接，读≈0） |
| VC5 (pin12) | 电芯4正极 = +12V（R22） | **CELL4 = VC5−VC3** |

> 关键点：**第 4 节电压要从 VC5 (0x14/0x15) 读**，不是 VC4。这是 BQ76920 4 节接法的官方要求（VC4–VC3 short）。

---

## 目录结构

```
AI Project/
├── BSP/              应用层代码 (驱动 + 逻辑 + 状态机)
│   ├── *.c / *.h     C 源文件 / 头文件
├── Project/          工程文件
│   ├── main.c        主程序入口
│   ├── stm32f10x_it.c/h  中断服务例程
│   ├── stm32f10x_conf.h  外设头文件配置
│   └── MDK-ARM/      Keil uVision 项目文件 (.uvprojx)
├── Libraries/        STM32 标准外设库 + CMSIS (不做修改)
├── config/           IAR 链接脚本 (.icf)
├── doc/              文档
├── AGENTS.md         AI 助手项目指引
└── Project_Intro.md  本文件
```

---

## BSP 文件详解

### 硬件驱动层 — 直接操作 MCU 外设 / BQ76920 寄存器

| 文件 | 功能描述 | 适配状态 |
|---|---|---|
| **BQ76930.c / .h** | BQ769x0 芯片驱动：寄存器定义、各通道电压采样、电流采样、温度采样、均衡、MOS 控制、保护、系统状态。**原为 BQ76940 驱动（15 节、双器件）** | ⚠️ 需裁剪到 BQ76920 |
| **i2c1.c / .h** | BQ76920 I2C 驱动 — 软件 bit-bang I2C，PB8(SCL)/PB9(SDA)，器件地址 `0x08`，提供 `IIC1_read_one_byte()` / `IIC1_write_one_byte_CRC()`（带 CRC8，多项式 `0x07`） | ✅ |
| **i2c2.c / .h** | EEPROM I2C 驱动 — PB6(SCL)/PB7(SDA)，用于 AT24C02C | ✅（器件型号从 AT24C08 改为 AT24C02C） |
| **i2c.c / .h** | 通用 I2C 驱动 — `IIC_read_one_byte()` / `IIC_write_one_byte()` | ✅ |
| **IO_CTRL.c / .h** | GPIO 引脚定义 — BQ 唤醒、电源、状态输入等宏定义 | ✅ |
| **can.c / .h** | CAN 通信驱动 — 500kbps，29-bit 扩展帧 ID，`Can_Send_Msg(buf,len,appid)` / `Can_Receive_Msg(buf)` | ✅ |
| **usart.c / .h** | UART1 通信驱动 — 115200，上位机命令 + 串口屏(LCD) | ✅ |
| **usart2.c / .h** | UART2 通信驱动 — 9600，调试输出 | ✅ |
| **spi.c / .h** | SPI 驱动 — 原用于 W25Qxx | ⚠️ 新板无 W25Qxx，可移除 |
| **w25qxx.c / .h** | W25Qxx Flash 驱动 | ⚠️ 新板无此器件，可移除 |
| **wdg.c / .h** | 独立看门狗 IWDG — 4 秒超时，主循环喂狗 | ✅ |
| **led.c / .h** | LED 指示 — 板载 LED 控制 | ✅ |
| **systick.c / .h** | SysTick 滴答定时器 — `delay_ms()` | ✅ |
| **timer.c / .h** | TIM2 定时器 — 周期调度 | ✅ |

### 业务逻辑层 — 采样转换 / 保护算法 / 均衡策略

| 文件 | 功能描述 |
|---|---|
| **bms_data.h** | 核心数据结构 — `BMS_Handle_t` 主句柄：`BMS_Measurement_t`（4 路单体电压/总压/总流/3 路温度/SOC）、`BMS_Threshold_t`（18 个阈值）、`BMS_Flags_t`（位域标志）、`BMS_CoulombCnt_t`（安时积分预留）、状态枚举 `BMS_State_t`、故障码位域、CAN ID (0x101~0x104)。`CELL_COUNT=4` 已配置 |
| **temp_mgr.c / .h** | 温度管理 — 3 通道：BQ TS1 / BQ TS2 / STM32 ADC。EMA 滤波，NTC 103AT 换算 | ⚠️ BQ76920 无 TS2，需裁剪 |
| **soc.c / .h** | SOC 估算 — 21 点 OCV 查表法 (LFP 2800~3600mV) + 预留库仑计数接口 | ✅ |
| **protection.c / .h** | 保护逻辑 — OV/UV/OC/SC/OT 延时消抖 + MOS 决策，写 `SYS_CTRL2` (0x05) | ✅ |
| **balance.c / .h** | 均衡管理 — 压差判断 + 非相邻串约束，写 `CELLBAL1` | ⚠️ 只保留 CELLBAL1（BQ76920 仅 5 节） |
| **flash_store.c / .h** | 阈值持久化 — MCU 内部 Flash 最后页 | ⚠️ C8T6=64KB，最后页地址需从 128KB(RBT6) 改过来 |

### 状态机层 — 系统调度 / 通信上报

| 文件 | 功能描述 |
|---|---|
| **bms_state.c / .h** | 状态机 + 双路上报：`BMS_StateMachine_Init()` 初始化、`BMS_StateMachine_Run()` 主循环调度、状态转换 `INIT → ACTIVE ↔ FAULT → SLEEP`、`BMS_CAN_Report()`（4 帧）、`BMS_UART_Report()`（串口屏 DCV16） |

### 工程入口

| 文件 | 功能描述 |
|---|---|
| **Project/main.c** | 主程序入口 — 外设初始化 → BMS 状态机初始化 → 主循环（喂狗 + CAN 接收 + UART 命令处理 + 状态机调度，约 10ms/周期） |

---

## 状态机流程图

```
        ┌──────────────┐
        │    INIT     │   上电: 唤醒BQ76920, I2C校准, Flash读阈值, OCV初始SOC
        └──────┬───────┘
               │ 初始化完成
               ▼
        ┌──────────────┐
        │   ACTIVE    │ ←── 正常运行循环:
        └──────┬───────┘     · 采样(电压/电流/温度)
               │             · 保护检测(OV/UV/OC/SC/OT)
      ┌────────┴────────┐    · MOS 控制 (SYS_CTRL2)
      ▼                 │    · 均衡管理 (CELLBAL1)
 ┌──────────┐           │    · SOC 估算
 │  FAULT  │────────────┘    · CAN + UART 上报
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
| `0x02` | 启动上报 | 开始周期性 CAN+UART 上报 |
| `0x03` | 停止上报 | 停止上报 |
| `0x04` | DSG ON | 开启放电 MOS |
| `0x05` | DSG OFF | 关闭放电 MOS |
| `0x06` | CHG ON | 开启充电 MOS |
| `0x07` | CHG OFF | 关闭充电 MOS |
| `0x12` | 写阈值 | `[PARAM_ID] [VALUE_H] [VALUE_L]` |
| `0x13` | 保存阈值 | 持久化到 Flash |
| `0x14` | 打印阈值 | UART 输出当前所有阈值 |
| `0x15` | 恢复默认 | 恢复出厂默认阈值并保存 |

MOS 控制寄存器 `SYS_CTRL2` (0x05)：bit0=CHG，bit1=DSG（`main.c` 中 0x43=全开 / 0x41=关DSG / 0x42=关CHG，注意还含 bit6 其他控制位）。

---

## BQ76920 寄存器快速参考

| 地址 | 宏名 | 功能 |
|---|---|---|
| 0x00 | `SYS_STAT` | 系统状态 (UV=bit3, OV=bit2, SCD=bit1, OCD=bit0) |
| 0x01 | `CELLBAL1` | **均衡控制（BQ76920 仅此一个，bit0~4 → 串1~5）** |
| 0x04 | `SYS_CTRL1` | 系统控制 (ADC 使能 / SHIP 模式) |
| **0x05** | **`SYS_CTRL2`** | **MOS 控制 (bit0=CHG, bit1=DSG)** |
| 0x06~0x08 | `PROTECT1~3` | 保护配置 (SCD/OCD 阈值和延时) |
| 0x09 / 0x0A | `OV_TRIP` / `UV_TRIP` | OV/UV 保护阈值 |
| 0x0B | `CC_CFG` | 库仑计配置 |
| 0x0C~0x11 | `VC1`~`VC3` | 单体电压 1~3（14 位 ADC） |
| 0x12~0x13 | `VC4` | **与 VC3 短接，读≈0，不要用** |
| **0x14~0x15** | **`VC5`** | **第 4 节电压（14 位 ADC）** |
| 0x2A~0x2B | `BAT` | 总压 |
| 0x2C~0x2D | `TS1` | 温度传感器（BQ76920 仅此一路） |
| 0x32~0x33 | `CC_HI` / `CC_LO` | 库仑计（电流 ADC） |
| 0x50 / 0x51 / 0x59 | `ADCGAIN1` / `ADCOFFSET` / `ADCGAIN2` | ADC 校准参数 |

> BQ76920 无 TS2（0x2E/0x2F 寄存器虽在 map 中但无对应引脚，读值无效）。VC6~VC15 及 CELLBAL2/3 对 BQ76920 无意义。

---

## 关键换算公式

```
电压(mV) = (raw_14bit × GAIN) / 1000 + ADC_offset
  其中 GAIN = 365 + ADC_GAIN (ADC_GAIN 读取自 0x50/0x59)   [与 BQ76940 相同，BQ76920 也适用]

电流(mA) = raw_CC × K
  ⚠️ 采样电阻已从 4mΩ 改为 1mΩ，K 需重新标定：
     原 4mΩ 时 K≈2.11 → 1mΩ 时 K≈2.11×4≈8.44 (与 CC_CFG 增益有关，需实测标定)

温度(°C) = 1 / (1/298.15 + ln(Rt/10000)/3380) − 273.15    [NTC 103AT, B=3380]
  Rt 的换算依赖具体分压电路（BQ76920 内部 18kΩ 上拉到 3.3V + 外部 NTC + R7=33kΩ），需按实际电路标定
```

---

## 固件适配 TODO（从 BQ76940 迁移到 BQ76920 的待办）

1. **裁剪 AFE 驱动** `BQ76930.c/h`：只保留 VC0~VC5、TS1、CELLBAL1、单器件；删除 VC6~VC15、TS2、双器件/级联函数（`BQ_2_config`、`WAKE_ALL_DEVICE` 等）。
2. **第 4 节电压**：采样函数改用 `VC5 (0x14/0x15)`，不要把 VC4 当第 4 节。
3. **电流换算**：`Get_BQ_Current()` 的系数按 1mΩ 重新标定（≈×4）。
4. **温度**：`temp_mgr.c` 去掉 TS2 通道（BQ76920 无 TS2），保留 TS1 + 可选 STM32 ADC 环境温度。
5. **均衡**：`balance.c` 只写 `CELLBAL1`，串数 1~4。
6. **Flash 地址**：`flash_store.c` 最后页地址按 C8T6（64KB，末页 0x0800F800）改，MCU 型号从 RBT6 改为 C8T6。
7. **EEPROM**：`i2c2` 对应 AT24C02C（2Kbit）。
8. **删除无用驱动**：`spi.c`、`w25qxx.c`（新板无 W25Qxx）。
9. **`main.c` 头部注释**：更新为 STM32F103C8T6 + BQ76920。

---

## 开发说明

1. **打开项目**: Keil MDK 打开 `Project/MDK-ARM/BMS_DEMO.uvprojx`（目标器件需改为 STM32F103C8T6）
2. **添加新文件**: Keil IDE 中右键 BSP 组 → Add Existing Files to Group
3. **烧录**: J-Link 或串口 (FlyMcu.exe) 烧录 `Project/MDK-ARM/obj/BMS_DEMO.hex`
4. **调试串口**: UART1 115200 bps, 8N1
5. **看门狗**: 4 秒 IWDG, 主循环 `while(1)` 中必须喂狗
6. **BQ76920 唤醒**: 上电后需在 TS1 引脚给出上升沿（BOOT 信号），板上 KEY1 按键即为此设计
