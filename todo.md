# To Do List

- adc_model.m 中需要加入对校准后的 ADC 模型的扫频动态测试方法
- adc_model.m 中需要加入模拟 CDAC 建立过程的方法，用以权衡冗余的插入位置与大小
- adc_model.m 中没有把 AFE 和 子 ADC 的增益失配贡献分开
- ./dsp/verilog/rtl 中针对时序需要插入流水线
- SRAM 控制器
- ADC 工作执行状态机
- ping-pang 寄存器写 SRAM 数据
- sub-buffer 需要替换 1G 电阻为长 NMOS 电阻后仿真工作区
- sub-buffer 偏置方案
- 理想电容替换为 MOM/MOS 电容
- 寄存器地址设置（手工调试使用）
- reference-buffer 面积待优化