# 源工程与资料来源

## Virtuoso 原工程路径

- 服务器工程打开：`cd ~/Projects/tsmc12/ICT_work`后按原命令打开 Cadence

## 模块目录映射

| 本仓库模块 | library / cellview | 完成情况 |
|---|---|---|
| 输入缓冲器 | `ict_tsmcN12_adc/input_buf` |sch|
| 第一级采样自举开关 | `ict_tsmcN12_adc/rank1_sam` |sch|
| 子缓冲器 | `ict_tsmcN12_adc/sub_buf` |sch|
| 第二级采样时钟升压 | `ict_tsmcN12_adc/rank2_sam` |sch|
| 理想 CDAC | `ict_tsmcN12_adc/cdac_ideal` |sch|
| CDAC 版图参考 | `ict_tsmcN12_adc/cdac` |layout|
| 动态逻辑单元 | `ict_tsmcN12_adc/dl_unit` |sch|
| SAR 逻辑 | `ict_tsmcN12_adc/sar` |sch|
| 基准缓冲器 | `ict_tsmcN12_adc/ref_buf` |sch|
| 比较器 | `ict_tsmcN12_adc/comparator` |sch|
| 子 SAR ADC | `ict_tsmcN12_adc/sub_ad` |sch|
| 多相时钟 | `ict_tsmcN12_adc/clock`|sch|
| CML 分频器 | `ict_tsmcN12_adc/cml_div2`|sch|
| 非重叠时钟生成器| `ict_tsmcN12_adc/non_overlapping` |sch|
| CMOS 分频器 | `ict_tsmcN12_adc/cmos_div8`|sch|
| 8 相时钟生成器 | `ict_tsmcN12_adc/gen_clock8`|sch|
| 占空比调节电路 | `ict_tsmcN12_adc/duty_adj`|sch|
| DCDL 电路 | `ict_tsmcN12_adc/dcdl`|sch|
| DCDL 编码器| `ict_tsmcN12_adc/dcdl_code`|verilogA|
| 理想 DEC | `ict_tsmcN12_adc/dec` |verilogA|
| 理想减法器 | `ict_tsmcN12_adc/minus_ideal`|verilogA|
| 理想 MUX | `ict_tsmcN12_adc/mux_ideal`|

- 顶层模块和仿真自行搭建
- 另提供非差分形式非 Class AB 结构的超级源跟随器作为子缓冲器的结构，功耗更大 `ict_tsmcN12_adc/sub_buf_version2`