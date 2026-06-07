# 设计参考文献与资料说明

本目录保存 ADC 模拟/系统设计相关参考资料说明。图片类资料放在 `design/schematic/` 或 `design/sim/`，不放在本目录。参考文献主要来自论文工程 `C:\Users\15062\Desktop\nju_paper\ref.bib` 与 `nju_paper.tex` 中的模块论证章节。

## 架构、TI-ADC 与系统指标

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| 时间交织 ADC 基本架构 | Black W. C., Hodges D. A. "Time interleaved converter arrays", JSSC, 1980. DOI: 10.1109/JSSC.1980.1051512 | TI-ADC 基本模型与通道失配问题来源 |
| 高速 ADC 与 TI-ADC 设计权衡 | Razavi B. *Analysis and Design of Data Converters*, Cambridge University Press, 2025. DOI: 10.1017/9781009602266 | ADC 指标、FoM、采样抖动、架构选择依据 |
| 交织 ADC 设计考虑 | Razavi B. "Design Considerations for Interleaved ADCs", JSSC, 2013. DOI: 10.1109/JSSC.2013.2258814 | 交织路数、功耗-速度折中、时序/带宽失配分析 |
| 高采样率 Nyquist ADC 综述 | Manganaro G. "An Introduction to High Sample Rate Nyquist Analog-to-Digital Converters", OJSSCS, 2022. DOI: 10.1109/OJSSCS.2022.3212028 | 高速 ADC 架构与工程约束背景 |
| PAM-4 接收机 ADC 实践 | Upadhyaya P. et al. "A Fully Adaptive 19-58-Gb/s PAM-4 and 9.5-29-Gb/s NRZ Wireline Transceiver With Configurable ADC", JSSC, 2019. DOI: 10.1109/JSSC.2018.2875091 | 56 Gb/s PAM-4 中 32-way TI-SAR 的系统实践参考 |
| 112 Gb/s PAM-4 ADC 接收机 | Krupnik Y. et al. "112-Gb/s PAM4 ADC-Based SERDES Receiver With Resonant AFE for Long-Reach Channels", JSSC, 2020. DOI: 10.1109/JSSC.2019.2959511 | 高速 ADC-DSP receiver 的 AFE/ADC 系统集成参考 |

## 分层交织与采样前端

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| Master T&H + TI-SAR | Le Tual S. et al. "A 20GHz-BW 6b 10GS/s 32mW Time-Interleaved SAR ADC with Master T&H in 28nm UTBB FDSOI Technology", ISSCC, 2014. DOI: 10.1109/ISSCC.2014.6757479 | 统一采样前端降低 skew/带宽失配的路线参考 |
| 层级交织与高速 SAR | Kull L. et al. "A 24-to-72GS/s 8b Time-Interleaved SAR ADC...", ISSCC, 2018. DOI: 10.1109/ISSCC.2018.8310332 | 高速多路 TI-SAR 的交织组织和 Nyquist 性能参考 |
| 56 GS/s 分层交织 ADC | Sun N. et al. 相关 56 GS/s 8b TI-ADC 工作，论文中引用为 `pm-adc-req` | 两级 T&H / 分层交织结构与 PAM-4 ADC 要求参考 |
| 72 GS/s Pipeline-SAR | Zhang Y. et al. "A 72GS/s 9b Time-Interleaved Pipeline-SAR ADC...", ISSCC, 2025. DOI: 10.1109/ISSCC49661.2025.10904672 | `M-N-K` 层级交织模型、输入缓冲、分裂自举开关、高频 SFDR 参考 |
| 38 GS/s Pipelined-SAR | Zhu Y. et al. "A 38-GS/s 7-bit Pipelined-SAR ADC With Speed-Enhanced Bootstrapped Switch...", JSSC, 2023. DOI: 10.1109/JSSC.2023.3268238 | 采样开关速度增强、level shifting 与高速输入性能参考 |
| 输入缓冲线性化与 dither | Cao Y. et al. "A 12GS/s 12b 4x Time-Interleaved Pipelined ADC...", ISSCC, 2024. DOI: 10.1109/ISSCC49657.2024.10454350 | 输入缓冲线性化与全局 dither 注入校准参考 |
| Dither-based TI-SAR | Tao Y. et al. "A 4.8GS/s 7-ENoB Time-Interleaved SAR ADC...", ISSCC, 2024. DOI: 10.1109/ISSCC49657.2024.10454299 | 输入缓冲 dither 注入、时序校准与比较器失调校准参考 |

## 输入缓冲器与子缓冲器

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| 模拟基础与 SSF | Gray P. R. et al. *Analysis and Design of Analog Integrated Circuits*, Wiley, 2024 | 源跟随器、超级源跟随器、小信号输出阻抗与稳定性分析 |
| Class-AB SSF | Lopez-Martin A. J. et al. "Power-efficient analog design based on the class AB super source follower", IJCTA, 2012. DOI: 10.1002/cta.776 | 子缓冲器 Class-AB SSF 结构、低输出阻抗、高摆率设计依据 |
| FVF/LDO 缓冲器参考 | Surkanti P. R. et al. "Flipped Voltage Follower Based LDO Voltage Regulators: A Tutorial Overview", VLSID, 2018 | FVF 低输出阻抗结构对比 |
| FVF 稳定与输出阻抗 | `fvf-design-analysis`, `fvf-rout-analysis` in `ref.bib` | FVF 与 SSF 方案取舍：轻载稳定性、输出阻抗、驱动能力 |
| 高速 AFE 实践 | Krupnik Y. et al., JSSC 2020；Zhang Y. et al., ISSCC 2025 | PAM-4 receiver AFE、输入缓冲与分层交织中间缓冲的工程参考 |

## 采样开关与时钟升压

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| 自举采样基本设计 | Razavi B. "The Design of a Bootstrapped Sampling Circuit", SSCM, 2021. DOI: 10.1109/MSSC.2020.3036143 | Rank-1 自举开关原理、线性度和导通电阻信号相关性 |
| 自举采样早期参考 | Razavi B. "The Bootstrapped Switch", SSCM, 2015. DOI: 10.1109/MSSC.2015.2449714 | 自举开关基础拓扑参考 |
| 单调开关 SAR | Liu C.-C. et al. "A 10-bit 50-MS/s SAR ADC With a Monotonic Capacitor Switching Procedure", JSSC, 2010. DOI: 10.1109/JSSC.2010.2042254 | SAR CDAC 单调开关和自举采样参考 |
| PMOS 自举采样 | Yonar A. S. et al. "An 8-bit 56GS/s 64x Time-Interleaved ADC...", VLSI, 2022. DOI: 10.1109/VLSITechnologyandCir46769.2022.9830308 | PMOS 自举和高速前端采样参考 |
| 分离自举节点 | Ramkaj A. T. et al. "A 5-GS/s ... Passive-Sampling Time-Interleaved Three-Stage Pipelined-SAR ADC", JSSC, 2020. DOI: 10.1109/JSSC.2019.2960476 | 分离自举节点、降低寄生的采样器参考 |
| 预充电 X 节点/高速自举 | Zhu Y. et al., JSSC 2023 | Speed-enhanced bootstrapped switch 参考 |
| 交叉 PMOS 升压 | Cho T. B., Gray P. R. "A 10 b, 20 Msample/s, 35 mW pipeline A/D converter", JSSC, 1995. DOI: 10.1109/4.364429 | Rank-2 时钟升压电路的早期电荷泵参考 |
| 改进型升压与 skew 校准 ADC | Gu M. et al. "A 3.7mW 11b 1GS/s TI-SAR ADC...", ESSCIRC, 2023. DOI: 10.1109/ESSCIRC59616.2023.10268795 | 低压时钟升压与时序校准原型参考 |
| 高速异步 LU SAR | Bheemisetti C. et al. "A 7-Bit 1.75-GS/s ... Loop-Unrolled Fully Asynchronous SAR ADC", JSSC, 2025. DOI: 10.1109/JSSC.2024.3449115 | 高速 Rank-2 采样、全异步 SAR 速度上限参考 |

## CDAC、切换策略与基准缓冲器

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| 传统电荷重分配 ADC | Suarez R. E., Gray P. R., Hodges D. A. "All-MOS charge-redistribution analog-to-digital conversion techniques. II", JSSC, 1975. DOI: 10.1109/JSSC.1975.1050630 | CDAC 电荷重分配基础 |
| 单调切换 | Liu C.-C. et al., JSSC 2010. DOI: 10.1109/JSSC.2010.2042254 | 低能耗 CDAC 单调切换基础 |
| Vcm-based switching | Zhu Y. et al. "A 10-bit 100-MS/s Reference-Free SAR ADC in 90 nm CMOS", JSSC, 2010. DOI: 10.1109/JSSC.2010.2048498 | 共模稳定切换策略对比 |
| 双向单调切换 | Sanyal A., Sun N. "SAR ADC architecture with 98% reduction in switching energy...", Electronics Letters, 2013. DOI: 10.1049/el.2012.3900 | 低能耗切换策略对比 |
| 分裂电容阵列 DAC | Ginsburg B. P., Chandrakasan A. P. "500-MS/s 5-bit ADC in 65-nm CMOS With Split Capacitor Array DAC", JSSC, 2007. DOI: 10.1109/JSSC.2007.892169 | 分裂电容 CDAC 结构参考 |
| SAR ADC 低功耗综述 | Tang X. et al. "Low-Power SAR ADC Design: Overview and Survey...", TCAS-I, 2022. DOI: 10.1109/TCSI.2022.3166792 | CDAC 切换能耗和结构对比 |
| CDAC 匹配与 INL/DNL | 黄禹佳. 《中高速逐次逼近型模数转换器关键技术的研究》, 东南大学, 2023 | 单位电容选择、INL/DNL 失配估计 |
| 基准误差分析 | Li C. et al. "Analysis of Reference Error in High-Speed SAR ADCs With Capacitive DAC", TCAS-I, 2019. DOI: 10.1109/TCSI.2018.2861835 | 基准缓冲器、去耦电容、最坏码字纹波建模 |
| 本地 Reservoir 参考方案 | Shen J. et al. "A 12GS/s 9b 16x Time-Interleaved SAR ADC in 16nm FinFET", ISSCC, 2025. DOI: 10.1109/ISSCC49661.2025.10904660 | 后续优化可参考的本地 reservoir capacitor 方案 |

## 比较器、SAR 逻辑与速度增强

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| StrongARM latch | Razavi B. "The StrongARM Latch", SSCM, 2015. DOI: 10.1109/MSSC.2015.2418155 | Strong ARM 比较器再生过程、速度与失调分析 |
| Double-tail comparator | Schinkel D. et al. "A Double-Tail Latch-Type Voltage Sense Amplifier...", ISSCC, 2007. DOI: 10.1109/ISSCC.2007.373420 | 比较器结构对比 |
| Offset 仿真方法 | Gines A. J. et al. "Closed-loop simulation method for evaluation of static offset in discrete-time comparators", ICECS, 2014. DOI: 10.1109/ICECS.2014.7050041 | 二分/闭环 offset 仿真方法 |
| C2MOS 逻辑 | Suzuki Y. et al. "Clocked CMOS calculator circuitry", JSSC, 1973. DOI: 10.1109/JSSC.1973.1050440 | 动态逻辑结构参考 |
| TSPC 逻辑 | Yuan J., Svensson C. "High-speed CMOS circuit technique", JSSC, 1989. DOI: 10.1109/4.16303 | TSPC 动态触发器链参考 |
| 异步 SAR 动态逻辑 | Harpe P. J. A. et al. "A 26 uW 8 Bit 10 MS/s Asynchronous SAR ADC...", JSSC, 2011. DOI: 10.1109/JSSC.2011.2143870 | 异步 SAR 动态逻辑和低功耗控制链参考 |
| Alternate comparator SAR | Kull L. et al. "A 3.1 mW 8b 1.2 GS/s Single-Channel Asynchronous SAR ADC...", JSSC, 2013. DOI: 10.1109/JSSC.2013.2279571 | 比较器交替工作提升速度参考 |
| 多 bit/cycle SAR | Chan C.-H. et al. "A 3.8mW 8b 1GS/s 2b/Cycle Interleaving SAR ADC...", VLSI, 2012. DOI: 10.1109/VLSIC.2012.6243802 | 减少比较周期的速度增强路线 |
| 1-then-2 / 2-then-3 SAR | Chan C.-H. et al., JSSC 2018. DOI: 10.1109/JSSC.2017.2785349；Li D. et al., JSSC 2020. DOI: 10.1109/JSSC.2020.3011753 | 冗余、多阈值和后台 offset 校准的高速 SAR 参考 |
| Partial loop-unrolled SAR | Nani C. et al. "A 5-Nm 60-GS/s 7b 64-Way TI Partial Loop Unrolled SAR ADC...", JSSC, 2025. DOI: 10.1109/JSSC.2024.3517333 | 部分循环展开、冗余与比较器 offset 后台跟踪参考 |
| 冗余 SAR | Kuttner F. "A 1.2V 10b 20MSample/s non-binary SAR ADC...", ISSCC, 2002. DOI: 10.1109/ISSCC.2002.992993 | 非二进制冗余设计参考 |
| Binary-scaled error compensation | Liu C.-C. et al. "A 10b 100MS/s 1.13mW SAR ADC with binary-scaled error compensation", ISSCC, 2010. DOI: 10.1109/ISSCC.2010.5433970 | 插入式冗余/误差补偿参考 |

## 多相时钟、DCDL 与通道失配校准

| 主题 | 参考资料 | 设计用途 |
|---|---|---|
| CML 分频器 | 黄兆磊. 《频率综合器中分频器的研究与设计》, 复旦大学, 2011 | 14 GHz 差分时钟 CML 二分频和多相时钟参考 |
| OS/Gain 后台校准 | Hsu C.-C. et al. "An 11b 800MS/s Time-Interleaved ADC with Digital Background Calibration", ISSCC, 2007. DOI: 10.1109/ISSCC.2007.373495 | EMA/LMS 类通道统计校准工程参考 |
| TI-ADC 后台校准 | El-Chammas M., Murmann B. *Background Calibration of Time-Interleaved Data Converters*, Springer, 2012. DOI: 10.1007/978-1-4614-1511-4_5 | 后台校准收敛、模拟延迟线和相位生成参考 |
| OS/Gain/Skew 提取 | Azizian S., Ehsanian M. "Generalized Method for Extraction of Offset, Gain, and Timing Skew Errors...", TCAS-II, 2020. DOI: 10.1109/TCSII.2019.2937815 | 参考通道法误差提取参考 |
| 全数字 timing 校准 | Chen S. et al. "All-Digital Calibration of Timing Mismatch Error...", IEEE TVLSI, 2017. DOI: 10.1109/TVLSI.2017.2703141 | 数字域 timing mismatch 估计与修正参考 |
| 数字滤波 timing 校准 | Guo M. et al. "A 1.6-GS/s ... TI-SAR ADC Achieving 54.2-dB SNDR...", JSSC, 2020. DOI: 10.1109/JSSC.2019.2945298 | 数字微分/滤波 timing 校准参考 |
| 时序校准综述 | Gu M. et al. "Timing-Skew Calibration Techniques in Time-Interleaved ADCs", OJSSCS, 2025. DOI: 10.1109/OJSSCS.2024.3519486 | autocorrelation / reference-channel / reference-signal 校准分类 |
| MAD timing-skew 校准 | Gu M. et al. "A 3.7mW 11b 1GS/s TI-SAR ADC...", ESSCIRC, 2023. DOI: 10.1109/ESSCIRC59616.2023.10268795 | MAD/相关检测与 DCDL 闭环校准参考 |
| Dither-based skew 校准 | Tao Y. et al., ISSCC 2024. DOI: 10.1109/ISSCC49657.2024.10454299 | 参考信号注入法和后台 timing-skew 校准参考 |
| Global dither injection | Cao Y. et al., ISSCC 2024. DOI: 10.1109/ISSCC49657.2024.10454350 | 输入统计无关的 skew 校准参考 |
