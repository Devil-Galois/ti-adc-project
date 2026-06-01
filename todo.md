## To Do List (critical)

- ./dsp/verilog/rtl 中针对时序需要插入流水线
- SRAM 控制器
- ADC 工作执行状态机
- **ping-pang 寄存器写 SRAM 数据**
- **sub-buffer 需要替换 1G 电阻为长 NMOS 电阻后仿真工作区**
- **sub-buffer 偏置方案**
- **理想电容替换为 MOM/MOS 电容**
- 寄存器地址设置（手工调试使用）
- **reference-buffer 面积待优化，建议直接慢慢减小，仿真子 ADC 动态性能不退化太多，或者可以稍微增加功耗换取面积**
- 需要优化 SAR 逻辑中基本单元的延迟控制部分和异步回路的延迟控制部分（或者可以删掉但不确定能否鲁棒）
- T coil 电感需要完成 EMX 仿真以及大小取值需要根据 ESD 和 PAD 电容优化



## To Do List (optional)

- adc_model.m 中需要加入对校准后的 ADC 模型的扫频动态测试方法
- adc_model.m 中需要加入模拟 CDAC 建立过程的方法，用以权衡冗余的插入位置与大小
- adc_model.m 中没有把 AFE 和 子 ADC 的增益失配贡献分开
- 需要添加每一个模块的仿真目标
