# 设计约束与关键仿真要求。

## 顶层规格

| 项目 | 约束 / 结果 |
|---|---|
| 应用 | 56 Gb/s PAM-4 接收机 |
| 工艺 | 12 nm FinFET |
| 架构 | 28 GS/s 32 通道 TI-SAR ADC |
| 交织层级 | `2 x 2 x 8` |
| 子 ADC | 875 MS/s, 7-bit + 1-bit redundancy |
| 输入共模 | 550 mV |
| 差分摆幅 | 600 mVpp |
| 目标 ENOB | >= 5.5-bit |
| 目标 SFDR | >= 45 dBc |
| 前仿真结果 | Near Nyquist: ENOB > 6-bit, SFDR > 46 dBc |
| 核心功耗 | 88.31 mW，不含片外 DSP |
| Walden FoM | 48.6 fJ/conv-step |

## 模块约束总表

| 模块 | 系统作用 | 重点性能要求 | 必需关键仿真 |
|---|---|---|---|
| 输入缓冲器 | 隔离输入端并驱动 Rank-1 采样器 | 带宽、线性度、输出共模、headroom、功耗、PVT 鲁棒性 | DC 工作区；DC 传输；带载 AC；SFDR vs. input frequency；PVT 静态功耗与 headroom |
| Rank-1 采样器 | 第一级主采样保持，决定输入线性度和主采样窗口 | 自举速度、导通电阻、采样线性度、关断耦合、过压可靠性 | 自举瞬态；关键节点电压；导通提前量；采样开关 SFDR vs. input frequency；参考结构对比 |
| 子缓冲器 | 驱动每组 8 个子 SAR ADC 的采样负载 | 输出阻抗、压摆率、阶跃建立、CMFB 稳定性、输出共模、功耗 | DC 工作区；DC 传输；Nyquist 附近输出阻抗；slew-rate；最大阶跃建立；CMFB stb；PVT 功耗/headroom |
| 采样前端整体 | 给 DSP 校准提供 AFE 失配预算 | 32 通道 offset/gain mismatch、相对 CH0 的 worst-case 统计 | 32 通道分层交织 transient；zero-input offset Monte Carlo；quasi-static gain Monte Carlo |
| Rank-2 采样器 | 子 SAR ADC 输入采样开关 | 升压速度、导通电阻、采样窗口、可靠性、与 CDAC 负载联合建立 | 时钟升压 transient；PVT 导通电阻；关键节点可靠性；接 CDAC 负载 transient |
| CDAC | 采样电容阵列与逐次逼近 DAC | 电容失配、INL/DNL 风险、总采样电容、上极板寄生、位切换建立、共模稳定 | 单位电容 Monte Carlo；版图寄生提取；各位切换 transient；理想基准驱动下建立时间；switching common-mode 检查 |
| 基准缓冲器 | 驱动 CDAC 最坏码字切换 | 输出阻抗、PSRR、最坏码字瞬态恢复、去耦电容/功耗折中、基准失配 | DC 工作区；internal loop stb；PSRR；worst-code Vref transient；PVT settling；decap/Ibias trade-off；Vref mismatch Monte Carlo |
| Strong ARM 比较器 | SAR 判决核心 | 输入共模折中、输入等效噪声、offset、判决时间、能耗、PVT 裕量 | VCM sweep trade-off；TT transient；noise；offset Monte Carlo / binary-search offset；PVT decision time and energy |
| SAR 动态逻辑 | 保存判决结果并驱动 CDAC 开关 | 动态节点保持、比较结果锁存、逻辑传播延迟、异步 loop delay、转换时序裕量 | dynamic logic transient；asynchronous loop transient；DAC settling before compare；R-Ladder delay tune sweep；full sub-SAR corner timing |
| 多相时钟 | 产生 4 相主采样与 32 相子采样时钟 | 相位顺序、占空比、非交叠、相邻采样间隔、PVT 鲁棒性 | 4-phase transient；32-phase transient；duty/non-overlap measurement；phase sequence adjuster verification；PVT transient |
| DCDL | 接收 DSP skew 码并调节主采样相位 | 覆盖范围、步进、单调性、线性度、PVT 最坏情况、闭环稳定性 | delay vs. code across corners；range/resolution extraction；monotonicity check；behavioral step-size equivalence；AMS closed-loop skew calibration |
| 顶层 ADC | 证明 32 路重组后满足接收机动态指标 | SNDR、SFDR、ENOB、功耗分布、近 Nyquist 性能、校准后性能 | top-level transient；FFT dynamic test vs. input frequency；PVT SNDR/SFDR/ENOB；power distribution；calibrated mismatch scenario |

## 采样前端约束

### 输入缓冲器

| 类别 | 要求 |
|---|---|
| 结构与负载 | 源跟随器；1.2 V 标称供电；负载按 Rank-1 采样开关最差 `45 ohm` 导通电阻和 `80 fF` 采样电容建模 |
| 带宽 | 不同 corner 下带载带宽需大于 22 GHz；TT 为 24.0 GHz |
| 线性度 | 目标输入频率范围内 SFDR > 48 dB；必须覆盖 SFDR vs. input frequency |
| 共模与裕量 | 输出共模约 737 mV 至 835 mV；headroom 最差约 44 mV，需要 PVT 检查 |
| 功耗 | 单路约 7.29 mW 至 8.20 mW |
| 必需仿真 | MOS 工作区、DC 传输、带载 AC、SFDR 扫频、PVT 功耗/headroom |

### Rank-1 采样器

| 类别 | 要求 |
|---|---|
| 结构 | 全分裂自举开关，X/Y 节点分离，X 仅用于自举主开关 |
| 采样窗口 | 第一级主采样窗口约 70 ps |
| 自举电容 | 24 fF |
| 速度 | 相比参考自举结构，自举电压提升约 130 mV，开关导通提前 > 6.5 ps |
| 可靠性 | 1 V 供电下关键节点 X 约 1.5 V，需要确认不触发可靠性问题 |
| 线性度 | 必须做采样开关 SFDR vs. input frequency，并与参考开关结构对比 |
| 必需仿真 | 自举瞬态、关键节点电压、导通提前量、采样 SFDR、关断耦合/馈通检查 |

### 子缓冲器

| 类别 | 要求 |
|---|---|
| 结构与负载 | 全差分 Class-AB SSF；后级按 `40 ohm + 120 fF` 建模 |
| 输出阻抗 | Nyquist 附近小于 40 ohm；PVT 仿真范围 23 ohm 至 37 ohm |
| 压摆率 | 差分压摆率约 27.2 V/ns 至 32.9 V/ns |
| 阶跃响应 | 最大阶跃在 80 ps 内建立到 1/2 LSB 精度，低于约 120 ps 子采样窗口 |
| CMFB | CMFB 相位裕度大于 80 deg；TT 为 85 deg |
| 输出共模 | 约 479 mV 至 525 mV，需要覆盖比较器输入共模需求 |
| 功耗 | 约 2.29 mW 至 2.52 mW |
| 必需仿真 | MOS 工作区、DC 传输、输出阻抗、slew-rate、最大阶跃建立、CMFB stb、PVT 功耗/headroom |

### 采样前端整体失配

| 类别 | 要求 |
|---|---|
| 仿真对象 | `2 x 2 x 8` 分层交织器，末端接入子 SAR ADC 采样电容而非完整子 SAR ADC |
| Offset 测试 | 输入差分置零，提取 32 通道第二级采样结束时刻电容差分电压 |
| Gain 测试 | 输入端施加准静态差分信号，提取各通道采样结果并计算等效增益 |
| 参考通道 | 数字校准以 CH0 为参考 |
| Offset 预算 | 99.7% 分位约 14 mV |
| Gain 预算 | 99.7% 分位约 0.4% |
| 必需仿真 | zero-input offset Monte Carlo、quasi-static gain Monte Carlo、相对 CH0 worst-case 统计 |

## 子 SAR ADC 约束

### Rank-2 采样器

| 类别 | 要求 |
|---|---|
| 结构 | 时钟升压采样开关 |
| 供电与电容 | 1 V 供电；升压电容 20 fF |
| 导通电阻 | 不同 corner 下 <= 40 ohm |
| 负载 | 驱动 CDAC，等效总采样电容约 120 fF |
| 必需仿真 | 时钟升压 transient、PVT 导通电阻、关键节点可靠性、接 CDAC 负载 transient |

### CDAC

| 类别 | 要求 |
|---|---|
| 结构 | 恒定共模、分裂电容、单调开关切换 |
| 冗余 | 4C 后重复插入 4C，实现 1-bit redundancy |
| 单位电容 | 0.5 fF；加入冗余后理论下限约 0.35 fF |
| 采样总电容 | 含版图寄生后约 120 fF |
| 上极板寄生 | 约占总电容 1/2 |
| 建立 | MSB 侧使用 ulvt MOS 管；理想基准驱动下各位建立时间 < 18 ps |
| 失配贡献 | CDAC 总电容大小失配对增益失配贡献约 5% |
| 必需仿真 | 单位电容 MC、版图寄生提取、各位切换 transient、理想基准驱动建立、switching common-mode 检查 |

### 基准缓冲器

| 类别 | 要求 |
|---|---|
| 结构 | 基于 SSF 的基准缓冲器 |
| 基准范围 | 550 mV 至 650 mV；目标约 600 mV |
| 去耦电容 | 4.5 pF |
| PSRR | 高频退化后仍低于 -25 dB |
| 最坏码字恢复 | 基准从 606 mV 下跌到 598 mV；MSB 比较前恢复到 601.7 mV，误差约 5 mV |
| 冗余覆盖 | MSB 阶段 redundancy 提供约 14 mV 容错；第五次比较前不同 corner 误差 < 2 mV |
| 失配贡献 | 基准电压失配对增益失配贡献约 8% |
| 必需仿真 | DC 工作区、internal loop stb、PSRR、worst-code Vref transient、PVT settling、decap/Ibias trade-off、Vref mismatch Monte Carlo |

### Strong ARM 比较器

| 类别 | 要求 |
|---|---|
| 结构 | Strong ARM 动态比较器 |
| 供电 | 0.8 V 标称；PVT 覆盖 0.75 V 至 0.85 V |
| 输入共模 | 500 mV |
| 0.5 LSB | 2.34 mV |
| TT 指标 | noise 1.22 mV；decision time 18.5 ps；energy 20.4 fJ |
| 最慢判决 | SS 0 C 下约 24.8 ps |
| 失调预算 | 3 sigma 约 18 mV，计入 OS 校准范围 |
| 必需仿真 | VCM sweep trade-off、TT transient、noise、offset Monte Carlo / binary-search offset、PVT decision time and energy |

### SAR 动态逻辑与异步时钟

| 类别 | 要求 |
|---|---|
| SAR 逻辑 | TSPC 动态触发器链 |
| 数据保持 | 单次转换完成后立即锁存，缩短动态节点悬空时间 |
| 异步时钟 | 比较器复位环路作为关键路径覆盖 CDAC 建立时间 |
| 延迟调节 | R-Ladder DAC 调节 Loop Delay Tune 与动态逻辑 Q 信号延迟 |
| 整体时序 | 最慢 corner 下单次转换仍留有 84 ps 以上裕量 |
| 必需仿真 | dynamic logic transient、asynchronous loop transient、DAC settling before compare、R-Ladder delay tune sweep、full sub-SAR corner timing |

## 多相时钟与 DCDL 约束

| 类别 | 要求 |
|---|---|
| 输入时钟 | 14 GHz 差分时钟 |
| 第一级时钟 | CML 二分频产生 4 相 7 GHz 主采样时钟 |
| 第二级时钟 | 每个主相位生成 8 路 875 MHz 子采样时钟，合成 32 相 |
| 相邻采样边沿 | 理想间隔 35.7 ps |
| 占空比 | 4 相主时钟约 41%；子采样时钟约 11%，小于 1/8 以保证非交叠 |
| 相位顺序 | Phase Sequence Adjuster 必须保证 32 相固定顺序 |
| DCDL 结构 | 可调负载电容型数控延迟链 |
| DCDL 控制 | 低 3 bit 二进制，高 15 bit 温度计码，等效约 7-bit 分辨率 |
| DCDL 范围 | 所需约 +/-3.37 ps；前仿真最小单边覆盖约 3.81 ps |
| DCDL 步进 | 最差约 87 fs |
| 必需仿真 | 4-phase transient、32-phase transient、duty/non-overlap measurement、phase sequence adjuster verification、DCDL delay vs. code across corners、AMS closed-loop skew calibration |

## 顶层动态性能与功耗约束

| 类别 | 要求 |
|---|---|
| 验证对象 | 32 路 TI-SAR ADC 重组输出，而非单个子 ADC 独立动态测试 |
| 输入设置 | 差分正弦，共模 550 mV，幅度约 +/-295 mV |
| FFT 点数 | 1024 |
| 动态指标 | 不同输入频率下提取 SNDR、SFDR、ENOB |
| 近 Nyquist TT | ENOB > 6-bit，SFDR > 46 dBc |
| 代表值 | SNDR 35.6 dB，SFDR 49.3 dBc |
| 功耗 | Core power 88.31 mW；单通道 SAR ADC 1.22 mW |
| 必需仿真 | top-level transient、FFT dynamic test vs. input frequency、PVT SNDR/SFDR/ENOB、power distribution、校准后 mismatch scenario |

## 失配预算

| 失配项 | 数值 | 用途 |
|---|---:|---|
| 采样前端失调 | 14 mV | OS 校准覆盖范围输入之一 |
| 采样前端增益失配 | 0.4% | Gain 校准覆盖范围输入之一 |
| 基准电压失配贡献 | 8% | 子 ADC 增益失配预算 |
| CDAC 总电容失配贡献 | 5% | 子 ADC 增益失配预算 |
| 比较器失调贡献 | 18 mV | OS 校准覆盖范围输入之一 |
| 主相位时序偏斜 | 约 +/-3.37 ps | DCDL 覆盖范围设计依据 |

## 约束传递关系

采样前端的带宽、线性度和时序偏斜会直接限制系统级近 Nyquist 输入下的 SFDR/ENOB。子 SAR ADC 的 CDAC、基准、比较器和异步逻辑共同决定单通道 875 MS/s 是否有足够转换裕量。DCDL 覆盖范围和步进需要与 `dsp/` 中 MAD Skew 检测算法匹配，保证后台闭环既能覆盖残余 skew，又不会因步进过粗导致稳态误差过大。
