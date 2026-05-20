# TI-SAR ADC 项目说明



## 版本说明

| 版本号 | 日期 | 作者 | 修改内容 |
|--------|------|------|----------|
| v1.0 | 2026-05-19 | lijiahui | TI-SAR ADC 初版 |

## 文件结构

```
ti-adc-project/
├── readme.md                  # 项目说明
├── todo.md                    # 待完善部分
├── design/                    # 电路设计
│   ├── schematic/             #   原理图 (Cadence Virtuoso)
│   ├── cons/                  #   设计约束
│   ├── sim/                   #   仿真 (SPICE / Spectre)
│   └── ref/                   #   参考资料
├── dsp/                       # 校准算法
│   ├── matlab/                #   MATLAB 建模与仿真
│   └── verilog/               #   DSP Verilog 代码 
|       |—— rtl/               #        RTL 校准代码
|       |—— tb/                #        testbench
|       |—— build/             #        result
|       |—— run_sim.ps1        #        RTL 仿真 PS 脚本
|       └—— script             #        仿真支持 .m 脚本
└── spec.md                      # 规格书
```
