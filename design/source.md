# 源工程与资料来源

## Virtuoso 原工程路径

- 服务器工程目录：`/nfs/home/yangliqiong/Projects/tsmcN12/adc/`

## 模块目录映射

| 本仓库模块 | Virtuoso / 原工程路径 |
|---|---|
| input-buffer | `./TIADCproject#2dTest/input#2dbuffer` |
| rank-1-th | `./TIADCproject#2dTest/bs` |
| sub-buffer | `./TIADCproject#2dTest/sub#2dbuffer` |
| rank-2-th | `./TIADCproject#2dTest/ckbooster` |
| cdac-layout | `./../TI_SAR_ADC/ict_adc_12nm/LU_CAP` |
| cdac-schematic | `./adc/cdac` |
| sub-ad | `./TIADCproject#2dTest/sub#2dad#2dtest` |
| top-level | `./TIADCproject#2dTest/top#2dtest` |
| t-coil | `./TIADCproject#2dTest/tcoil` |

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
