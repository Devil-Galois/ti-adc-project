# 原理图与电路图索引

本目录保存 ADC 设计关键模块的 Cadence/Virtuoso 原理图截图，以及从论文原工程 `C:\Users\15062\Desktop\nju_paper\figures` 复制来的电路图/结构图。图片用于交付说明和模块定位，不替代原工程数据库。

## 采样前端

| 模块 | 图片 | 说明 |
|---|---|---|
| 输入缓冲器 | ![input buffer](input-buffer.png) | 源跟随器输入缓冲，驱动 Rank-1 自举采样器 |
| Rank-1 采样器 | ![rank-1 th](rank-1-th.png) | 全分裂自举开关，用于第一级采样保持 |
| 子缓冲器 | ![sub buffer](sub-buffer.png) | 全差分 Class-AB 超级源跟随器，驱动 8 个子 SAR ADC |

## 子 SAR ADC

| 模块 | 图片 | 说明 |
|---|---|---|
| Rank-2 时钟升压/采样 | ![ck booster](ck-booster.png) | 子 SAR 前端采样开关的时钟升压电路 |
| CDAC 原理图 | ![cdac](cdac.png) | 恒定共模、分裂电容、单调开关切换 CDAC |
| CDAC layout | ![cdac layout](cdac_layout.png) | CDAC 版图截图，用于寄生电容估计 |
| 基准缓冲器 | ![reference buffer](reference-buffer.png) | 基于 SSF 的基准缓冲器 |
| 比较器 | ![comparator](comparator.png) | Strong ARM 动态比较器 |

## 时钟链路

| 模块 | 图片 | 说明 |
|---|---|---|
| CML 分频器 | ![cml divider](clock/cml-divider.png) | 14 GHz 差分时钟二分频 |
| CML-to-CMOS | ![cml2cmos](clock/cml2cmos.png) | 时钟电平转换 |
| Div8 | ![div8](clock/div8.png) | 第二级 8 相子时钟生成相关分频 |
| Duty adjust | ![duty adjust](clock/duty-adj.png) | 子采样时钟占空比调节 |
| Reset mux | ![rst mux](clock/rst-mux.png) | 相位顺序调整与复位选择 |
| Shift register x8 | ![shift reg](clock/shift_regx8.png) | 8 相子时钟移位寄存器链 |

## 论文原工程电路图

这些图片来自论文工程，用于补充已有 Cadence 截图中缺少的结构级电路图和模块框图。

| 模块 | 图片 | 说明 |
|---|---|---|
| 顶层结构 | ![top overview](paper/top-overview.jpg) | 28 GS/s TI-SAR ADC 顶层结构 |
| 输入缓冲器 | ![paper input buffer](paper/input-buffer-schematic.jpg) | 论文工程中的输入缓冲器电路图 |
| Rank-1 采样器 | ![paper rank1](paper/rank-1-bootstrap-schematic.jpg) | 全分裂自举开关电路图 |
| 子缓冲器 | ![paper sub buffer](paper/sub-buffer-schematic.jpg) | Class-AB SSF 子缓冲器电路图 |
| 子 SAR 架构 | ![paper sub sar](paper/sub-sar-architecture.jpg) | 875 MS/s 子 SAR ADC 结构框图 |
| Rank-2 时钟升压 | ![paper ck booster](paper/rank-2-ck-booster-schematic.jpg) | 子 SAR 采样开关时钟升压电路 |
| CDAC | ![paper cdac](paper/sub-sar-cdac-schematic.jpg) | 分裂电容恒定共模 CDAC |
| 基准缓冲器 | ![paper ref buffer](paper/reference-buffer-schematic.jpg) | 基于 SSF 的基准缓冲器 |
| Strong ARM 比较器 | ![paper comparator](paper/strong-arm-comparator-schematic.jpg) | Strong ARM 动态比较器 |
| 动态逻辑 | ![paper dynamic logic](paper/dynamic-logic-schematic.jpg) | SAR 动态逻辑单元 |
| 异步时钟 | ![paper async clock](paper/async-clock-schematic.jpg) | 异步比较/复位时钟产生电路 |
| 4 相时钟 | ![paper 4 phase](paper/clock-4phase-architecture.jpg) | 4 相 7 GHz 主采样时钟产生电路 |
| 32 相时钟 | ![paper 32 phase](paper/clock-32phase-architecture.jpg) | 32 相 875 MHz 子采样时钟产生电路 |
| DCDL | ![paper dcdl](paper/dcdl-schematic.jpg) | 可调负载电容型 DCDL 电路 |
