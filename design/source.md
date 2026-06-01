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

- 另提供非差分形式非 Class AB 结构的超级源跟随器作为子缓冲器的结构，功耗更大 `ict_tsmcN12_adc/sub_buf_version2`