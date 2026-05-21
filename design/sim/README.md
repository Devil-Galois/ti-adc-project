# 仿真结果索引

本目录整理 ADC 设计关键模块和顶层动态性能的前仿真图片与结论。图片来自论文工程 `C:\Users\15062\Desktop\nju_paper\figures`，已按电路模块重新归类，便于脱离论文目录阅读。

## 模块分类

| 子目录 | 内容 |
|---|---|
| `input-buffer/` | 输入缓冲器 DC、AC、SFDR 仿真 |
| `rank-1-th/` | Rank-1 全分裂自举采样器瞬态与线性度 |
| `sub-buffer/` | 子缓冲器 DC、CMFB 稳定性、阶跃建立 |
| `frontend-mismatch/` | 分层采样前端 offset/gain Monte Carlo 失配统计 |
| `rank-2-th/` | 子 SAR 输入采样开关时钟升压瞬态 |
| `reference-buffer/` | 基准缓冲器 DC、stb、PSRR、最坏码字瞬态、失配统计 |
| `comparator/` | Strong ARM 比较器输入共模折中与 TT 瞬态 |
| `sar-logic/` | SAR 动态逻辑、异步时钟、子 SAR 整体时序 |
| `clock/` | 4 相/32 相时钟瞬态与主相位 skew 统计 |
| `dcdl/` | DCDL 延迟覆盖范围与控制码关系 |
| `top-level/` | 32 路 TI-SAR ADC 顶层动态性能与功耗分布 |

## 顶层结论

系统级仿真使用 32 路重组后的 ADC 输出进行动态性能评估。输入为差分正弦信号，共模 550 mV，幅度约 +/-295 mV，FFT 点数 1024。TT corner 近 Nyquist 输入时，ENOB 仍高于 6-bit，SFDR 高于 46 dBc；代表性能为 SNDR 35.6 dB、SFDR 49.3 dBc、核心功耗 88.31 mW、Walden FoM 48.6 fJ/conv-step。
