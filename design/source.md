# 源工程与资料来源

## Virtuoso 原工程路径

- 服务器工程打开：`cd ~/Projects/tsmc12/ICT_work`后按原命令打开 Cadence

## 模块目录映射

| 本仓库模块 | library / cellview |
|---|---|
| 输入缓冲器 | `ict_tsmcN12_adc/input_buf` |
| 第一级采样自举开关 | `ict_tsmcN12_adc/rank1_sam` |
| 子缓冲器 | `ict_tsmcN12_adc/sub_buf` |
| 第二级采样时钟升压 | `ict_tsmcN12_adc/rank2_sam` |
| 理想 CDAC | `ict_tsmcN12_adc/cdac_ideal` |
| CDAC 版图参考 | `./adc/cdac` |
| 动态逻辑单元 | `ict_tsmcN12_adc/dl_unit` |
| SAR 逻辑 | `ict_tsmcN12_adc/sar` |
| 基准缓冲器 | `ict_tsmcN12_adc/ref_buf` |
| 比较器 | `ict_tsmcN12_adc/comparator` |
| 子 SAR ADC | `ict_tsmcN12_adc/sub_ad` |
| 多相时钟 | `ict_tsmcN12_adc/clock`|
| CML 分频器 | `ict_tsmcN12_adc/cml_div2`|
| 非重叠时钟生成器| `ict_tsmcN12_adc/non_overlapping` |
| CMOS 分频器 | `ict_tsmcN12_adc/cmos_div8`|
| 8 相时钟生成器 | `ict_tsmcN12_adc/gen_clock8`|
| 占空比调节电路 | `ict_tsmcN12_adc/duty_adj`|
| DCDL 电路 | `ict_tsmcN12_adc/dcdl`|
| 顶层设计 | `ict_tsmcN12_adc/ti-adc`|
| 理想 DEC | `ict_tsmcN12_adc/dec` |
| 理想减法器 | `ict_tsmcN12_adc/minus_ideal`|
| 理想 MUX | `ict_tsmcN12_adc/mux_ideal`|

## 论文来源

设计文档主要依据 `C:\Users\15062\Desktop\nju_paper\nju_paper.tex`：

- 第 3 章：TI-SAR ADC 关键技术论证，包括交织器、缓冲器、采样开关、校准算法、单通道 SAR ADC。
- 第 4 章：32 通道 TI-SAR ADC 设计验证，包括模块电路、前仿真、DCDL、校准接口和顶层动态性能。
- 第 5 章：主要工作总结和后续限制。

## 图片来源

- `design/schematic/` 中图片为 Cadence/Virtuoso 原理图截图。
- `design/schematic/paper/` 中图片从 `C:\Users\15062\Desktop\nju_paper\figures` 按交付需要复制，主要是论文工程中的架构图、电路图和模块框图。
- `design/sim/` 中图片从 `C:\Users\15062\Desktop\nju_paper\figures` 按交付需要复制，主要是模块级与顶层仿真结果。
- `design/ref/` 仅保存设计参考文献与资料说明，不存放图片。

## 交付边界

本仓库中的图片和 Markdown 文档用于项目交付说明，不替代原 Cadence 工程数据库。若需重新仿真、改版图或导出网表，应以服务器 Virtuoso 工程为准。
