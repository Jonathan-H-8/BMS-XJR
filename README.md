- [ ] 第一步建立 CubeMX HAL 工程，只验证 LED、UART、时钟；然后配置 PB8/PB9 的 I2C1 Remap，先保证 STM32 能和 BQ7692003 通信。

- [ ] 第二步只实现 BQ_ReadRegister()、BQ_WriteRegister() 和 CRC8，能正确读取 SYS_STAT 就算第一关通过。

- [ ] 第三步实现 ADCGAIN、ADCOFFSET、VC1/VC2/VC3/VC5，串口打印四节单体电压。

- [ ] 第四步实现 CC 电流读取，并针对你的 1 mΩ 分流器进行零点和增益校准；TI 给出的 CC LSB 约为 8.44 µV，因此 1 mΩ 时理论上约为 8.44 mA/LSB，而旧工程的约 2.11 mA/LSB 实际对应 4 mΩ。 

- [ ] 第五步配置 BQ 硬件 OV/UV/OCD/SCD，初始保持 CHG/DSG 关闭，确认数据全部合理后再开放 MOS。

- [ ] 第六步加入 INIT → ACTIVE → FAULT → SLEEP 状态机。

- [ ] 第七步接 CAN 500 kbps，把总压、电流、四节电压、温度、故障码发给 VCU。

- [ ] 第八步再加入 SOC、被动均衡、AT24C02 参数保存和 IWDG。最后才做故障注入测试，包括单体过压、欠压、过流、断 NTC、I2C 断线和 CAN bus-off。
