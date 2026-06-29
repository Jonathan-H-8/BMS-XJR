# AGENTS.md — BMS (FSAE XJRT)

## Project overview

Battery Management System for Formula SAE electric race car. STM32F103RBT6 MCU + TI BQ76940 AFE, written in C using Keil MDK-ARM.

## Build & flash

- **No Makefile or CMake**. Project file: `BMS开发板/BQ76940含均衡发货资料 20250420/3.程序/1.BQ76940.../BMS_s940/Project/MDK-ARM/BMS_DEMO.uvprojx`
- Toolchain: MDK4.72A / IAR6.30 with STM32F10x_StdPeriph_Driver V3.50
- Flash via J-Link or serial (FlyMcu.exe in `芯片资料其它资料/STM32串口下载软件/`)
- Output hex: `Project/MDK-ARM/obj/BMS_DEMO.hex`
- Watchdog: 4s IWDG, fed in main loop

## Source layout

```
BSP/           — application code (new modules + original drivers)
Project/       — main.c, stm32f10x_it.c, MDK-ARM project
Libraries/     — STM32 stdperiph + CMSIS (do not modify)
```

### Key BSP files (application code)

| File | Role |
|------|------|
| `BQ76930.h/c` | Original BQ769x0 register definitions, cell read, balance, protect |
| `i2c1.c/h` | Software bit-bang I2C, device addr `0x08`, PB8=SCL, PB9=SDA |
| `i2c2.c/h` | Secondary I2C for EEPROM, PB6=SCL, PB7=SDA |
| `IO_CTRL.h` | GPIO pin definitions (BQ wake=PB5, etc.) |
| `bms_data.h` | All data structures, register addrs VC11-VC15, fault codes, CAN IDs |
| `bms_state.c/h` | State machine (INIT→ACTIVE→FAULT→SLEEP), CAN/UART reporting |
| `protection.c/h` | OV/UV/OC/SC/OT protection with delay debounce |
| `balance.c/h` | Cell balancing via CELLBAL1-3 registers |
| `temp_mgr.c/h` | 3-channel temp (BQ TS1, TS2, STM32 ADC), EMA filter |
| `soc.c/h` | OCV lookup table + Coulomb counting reserve variables |
| `flash_store.c/h` | Threshold persistence to internal Flash (last page) |
| `can.c/h` | CAN init 500kbps, 29-bit extended IDs, `Can_Send_Msg(buf,len,appid)` |
| `usart.h/c` | UART1 115200 for host commands + serial LCD |
| `usart2.h/c` | UART2 9600 for debug output |

## Hardware interface at a glance

- **BQ76940 I2C addr**: `0x08` (7-bit)
- **Cell voltage**: VC1=0x0C/0x0D ... VC4=0x12/0x13 (14-bit ADC, mV = raw * GAIN/1000 + offset)
- **Current**: CC_HI=0x32, CC_LO=0x33 (mA = raw * 2.11, with 4mΩ shunt @ 8x gain)
- **Temperature**: TS1=0x2C/0x2D, TS2=0x2E/0x2F (NTC 103AT, B=3380)
- **CHG/DSG MOS**: SYS_CTRL2 (0x05), bit0=CHG, bit1=DSG
- **Balance**: CELLBAL1(0x01), CELLBAL2(0x02), CELLBAL3(0x03)
- **Wake**: pulse PB5 high 100ms then low

## Display/CAN host tools

- CAN上位机: `BMS开发板/.../4.上位机软件/CAN上位机/Debug/USBCAN_Demo.exe`
- TTL上位机: `BMS开发板/.../4.上位机软件/TTL上位机/11.BMS上位机（配15串20210522）.exe`
- Serial LCD: JC018-QQVGA 2.2" UART screen, DCV16 commands

## UART command protocol

All commands: `0x01 0xXX 0x55 [data...]` via UART1 115200
- `0x02` enable, `0x03` disable reporting
- `0x04`/`0x05` DSG on/off, `0x06`/`0x07` CHG on/off
- `0x12` write threshold param, `0x13` save to Flash, `0x14` print, `0x15` reset defaults

## Conventions

- Chinese comments throughout (GB2312 encoding in Keil)
- Software I2C, not hardware peripheral — timing depends on `delay_ms` / `I2C_delay`
- New modules follow existing naming: `lower_case.c` for implementation, `lower_case.h` for interface
- All BQ register writes should use `IIC1_write_one_byte_CRC()` which appends CRC8
