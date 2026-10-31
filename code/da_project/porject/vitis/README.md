# RF47 startup application

`rf47_init` programs the board LMK04828 with the vendor 200 MHz profile,
starts all four RF-DAC tiles at 8 GSPS, performs DAC multi-tile sync, and then
enables the QSFP/Aurora to four-component bipolar NRZ data path through the PL control
registers. The external connector mapping is XI on TX0/TX1, XQ on TX2/TX3,
YI on TX4/TX5, and YQ on TX6/TX7. The odd channel is the sample-by-sample
two's-complement negative of the even channel. Each component runs at
4 Gbaud with two DAC samples per symbol; RRC pulse shaping is disabled.
This application initializes QSFP information mode. The separately archived
long-PRBS firmware also supports RF47-local BER replay. Select a matched
BIT/ELF pair from the root firmware manifest; do not infer replay capability
from this initialization application alone.

Build after the Vivado XSA has been generated:

```powershell
xsct.bat build_vitis.tcl
```

The resulting executable is `output/rf47_init.elf`.

Program the bitstream and start the initialization application over JTAG:

```powershell
powershell -ExecutionPolicy Bypass -File program_and_run.ps1
```

The RF-DAC waveform starts only after the bitstream and `rf47_init.elf` have
been loaded, the QSFP Aurora channel is up, and valid 512-byte KU115 frames
have filled the receive buffer.
# RF47 初始化与在线校准

`program_and_run.ps1` 下载带运行时校准功能的 bitstream 和初始化 ELF。上电默认使用 QSFP 正式数据，TX0～TX7 延迟均为 0。

切换到本地方波：

```powershell
.\set_source_mode.ps1 -Mode square
```

切回 QSFP：

```powershell
.\set_source_mode.ps1 -Mode qsfp
```

一次写入八路延迟码：

```powershell
.\set_lane_delays.ps1 -DelayCodes 0,0,0,0,0,0,0,0
```

延迟码 bit6:5 是 0～3 个整数样点，bit4:0 是 0～31 个分数相位。8 GSPS 下名义延迟为：

```text
delay_ps = 125 * integer + 125 * fraction / 32
```

读取当前模式、延迟和固件版本：

```powershell
.\read_runtime_calibration.ps1
```

scripts会暂停数据、写寄存器、等待配置跨时钟域完成并恢复输出，不需要重新生成或重新下载 bitstream。
