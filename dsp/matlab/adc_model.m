%%  TI-SAR ADC 行为级模型
% version       :  1.0
% author        :  lijiahui
% description   :  时间交织 ADC 行为级模型涵盖基本的误差参数建模、基本的 SAR ADC 建模、校准算法行为级实现、FFT 测试实现、绘图代码等
% details       :


%%  Definition 对象
classdef adc_model < handle

    % 参数
    properties

        % 基本参数
        fs          = 28e9;                                         % 采样率
        N_ch        = 32;                                           % 通道数
        N_phase     = 4;                                            % 待校准的第一级采样相位数
        Vref        = 0.6;                                          % SAR ADC 参考基准电压
        Vcm         = 0.5;                                          % SAR ADC 共模电压                                  
        rng_seed    = 42;                                           % 初始化随机数种子
        
        % 随机失配参数
        cof_gain    = 0.06;                                         % 增益失配标准差 σ*N(0,1)
        cof_offset  = 0.010;                                        % 失调失配标准差 σ*N(0,1)
        cof_skew    = 3.4e-12;                                      % 时钟偏移范围  [-a,a] 均匀分布
        cof_jitter  = 100e-15;                                      % 采样时钟 jitter 标准差 σ*N(0,1)
        cof_cap     = 0;                                            % 电容失配标准差 σ*N(0,1)
        cof_com     = 0.0012;                                       % 比较器噪声标准差 σ*N(0,1)

        % SAR ADC 参数
        cap_weights_single  = [32, 16, 8, 4, 4, 2, 1];              % 真实物理电容权重
        dig_weights_diff    = [64, 32, 16, 8, 8, 4, 2, 1];          % DEC 数字纠错权重
        code_center;                                                % 中心码字                                                 
        cap_arr_pt;                                                 % 正端顶部实际电容阵列，含失配
        cap_arr_pb;                                                 % 正端底部实际电容阵列，含失配
        cap_arr_nt;                                                 % 负端顶部实际电容阵列，含失配
        cap_arr_nb;                                                 % 负端底部实际电容阵列，含失配
        os_comparator;                                              % 比较器失调参数（认为失调失配全部来自比较器）
        
        % AFE 参数
        gain_ch;                                                    % 32 路实际增益（由 AFE 贡献的增益失配）
        skew_ch;                                                    % 第一级采样实际时钟偏移

        % 校准寄存器
        reg_os_cal;                                                 % 失调校准寄存器 
        reg_gain_cal;                                               % 增益教主寄存器
        reg_dcdl;                                                   % 时钟偏移校准 DCDL 寄存器

        % 电路基本参数
        cunit               = 5e-16;                                % 单位电容大小
        cp_top;                                                     % 顶板寄生电容大小
        dcdl_step           = 80e-15;                               % DCDL 步长 
    end

    % 函数
    methods
        
        % ADC 初始化函数
        function obj = adc_init(obj)
            % rng(obj.rng_seed);                                        % 可选，用于固化 ADC 失配参数 
            obj.code_center= sum(obj.dig_weights_diff) / 2;             % ADC 理想中间码字输出
            obj.cp_top     = sum(obj.cap_weights_single) * obj.cunit;   % 设置 CDAC 正/负 单侧上极板寄生电容（实际 CDAC 包含 top/bottom 因此总上极板寄生应 x2）
            obj.init_hardware();                                            
            fprintf("======== ADC Initialization Successfully! ========\n\n");
        end

        % ADC 参数初始化函数
        function init_hardware(obj)
            % CDAC 参数
            obj.cap_arr_pt = zeros(obj.N_ch, 7);
            obj.cap_arr_pb = zeros(obj.N_ch, 7);
            obj.cap_arr_nt = zeros(obj.N_ch, 7);
            obj.cap_arr_nb = zeros(obj.N_ch, 7);
            
            % 理想 CDAC 容值
            ideal_caps = obj.cap_weights_single * obj.cunit;

            % 带失配电容容值
            for ch = 1:obj.N_ch
                obj.cap_arr_nt(ch, :) = ideal_caps .* (1 + obj.cof_cap*randn(1, 7));   
                obj.cap_arr_nb(ch, :) = ideal_caps .* (1 + obj.cof_cap*randn(1, 7));   
                obj.cap_arr_pt(ch, :) = ideal_caps .* (1 + obj.cof_cap*randn(1, 7));   
                obj.cap_arr_pb(ch, :) = ideal_caps .* (1 + obj.cof_cap*randn(1, 7));   
            end
            
            % 比较器失调失配参数
            obj.os_comparator   = obj.cof_offset * randn(1, obj.N_ch);      % 高斯分布
            % AFE 贡献的增益失配
            obj.gain_ch         = 1 + obj.cof_gain * randn(1, obj.N_ch);    % 高斯分布
            % 第一级采样时钟偏移
            obj.skew_ch = -1 * obj.cof_skew + 2 * obj.cof_skew * rand(1, obj.N_phase);  % 均匀分布

            % 人为设置第一级采样时钟偏移失配（可选）
            % obj.skew_ch(1) = ;
            % obj.skew_ch(2) = ;
            % obj.skew_ch(3) = ;
            % obj.skew_ch(4) = ;

            % 校准寄存器初始化为 0
            obj.reg_os_cal      = zeros(1, obj.N_ch);
            obj.reg_gain_cal    = zeros(1, obj.N_ch);
            obj.reg_dcdl        = zeros(1, obj.N_phase);
        end

        % SAR ADC 量化行为级模型
        function [d_raw, decisions_all] = quantification(obj, t_ideal, waveform)    % d_raw：全部量化十进制 DEC 后输出；decisions_all：全部量化原始 8-bit 码输出    
            
            N_data          = length(t_ideal);                          % 待量化数据长度
            d_raw           = zeros(1, N_data); 
            decisions_all   = uint8(zeros(N_data, 8)); 

            % 为所有数据点分配通道和第一级相位，例如 ch_list(a) 表示第 a 个数据点对应的量化通道；ph_list(a) 表示第 a 个数据点对应的第一级采样通道
            ch_list         = mod(0 : N_data - 1, obj.N_ch) + 1;        % channel-index 1-32
            ph_list         = mod(ch_list - 1 , obj.N_phase) + 1;       % phase-index 1-4

            % 数据点量化
            for i = 1: N_data
                ch = ch_list(i);    % 选取通道
                ph = ph_list(i);    % 选取采样相位

                % 计算此时的随机时钟 jitter 
                random_jitter = obj.cof_jitter * randn();

                % 计算实际采样时刻
                t_sample= t_ideal(i) + obj.skew_ch(ph) + obj.reg_dcdl(ph) * obj.dcdl_step + random_jitter; 

                % 计算实际采样点经 AFE 增益后到达相应子 SAR ADC 时的差分电压值
                vin_diff = waveform(t_sample) * obj.gain_ch(ch); 
                
                % 得到相应通道的电容阵列
                cap_pt = obj.cap_arr_pt(ch, :);
                cap_pb = obj.cap_arr_pb(ch, :);
                cap_nt = obj.cap_arr_nt(ch, :);
                cap_nb = obj.cap_arr_nb(ch, :);

                % 计算包含上极板寄生的总电容阵列，CDAC 上极板寄生引起增益失配
                c_tot_p = sum(cap_pt) + sum(cap_pb) + 2 * obj.cp_top;   % 正端上极板总电容，假设上极板寄生约等于理想权重电容，因此 1/2 增益衰减
                c_tot_n = sum(cap_nt) + sum(cap_nb) + 2 * obj.cp_top;   % 负端上极板总电容，假设上极板寄生约等于理想权重电容，因此 1/2 增益衰减
                
                % 计算实际正、负极板采样电压
                v_sample_p  = vin_diff / 2  + obj.Vcm;
                v_sample_n  = -vin_diff / 2 + obj.Vcm;
                
                decisions   = zeros(1,8);     
                v_node_p    = v_sample_p;      
                v_node_n    = v_sample_n;

                for bit = 1 : 7  % decide MSB to LSB+1
                    if (v_node_p + obj.os_comparator(ch) + obj.cof_com * randn(1, 1) >= v_node_n)   % 带比较器失调、比较器噪声
                        decisions(bit)  = 1;
                        v_node_p        = v_node_p - obj.Vref * cap_pt(bit) / c_tot_p;              % 更新正节点电压
                        v_node_n        = v_node_n + obj.Vref * cap_nt(bit) / c_tot_n;              % 更新负节点电压
                    else 
                        decisions(bit)  = 0;
                        v_node_p        = v_node_p + obj.Vref * cap_pb(bit) / c_tot_p;
                        v_node_n        = v_node_n - obj.Vref * cap_nb(bit) / c_tot_n;
                    end
                end
                % decide LSB
                decisions(8) = (v_node_p + obj.os_comparator(ch) >= v_node_n);
                
                decisions_all(i, :) = uint8(decisions);

                % DEC 数字纠错转为十进制无冗余结果
                d_raw(i) = sum(decisions .* obj.dig_weights_diff);
            end
        end

        % 分析所建模原始ADC 的性能（单次测试与蒙特卡洛测试与扫频测试）函数
        function analysis_adc_origin(obj, fin_single, fin_start, fin_step, fin_end)

            fprintf("======== Running Original ADC Analysis...... ========\n");
            % SRAM 容量
            N_sram  = 2 ^ 14;
            % 蒙特卡洛测试点数
            N_mc    = 100;
            
            obj.adc_init();                         % 初始化 ADC

            % FFT test
            % One case test
            fprintf("======== One Case Test ========\n");
            result_single = fft_test(obj, N_sram, fin_single);      % FFT 测试完成
            % 绘制单次测试结果
            figure('Name','ADC Spectrum','Color','w','Position',[200 100 1100 420]);
            ax = axes('Position',[0.12 0.18 0.84 0.70]);
            obj.spectrum_plot(ax, result_single, 'FFT Spectrum of ADC Model');
            % 蒙特卡洛测试
            fprintf("======== Monte Carlo Test ========\n");
            ENOB_arr        = zeros(1, N_mc);
            ENOB_FS_arr     = zeros(1, N_mc);
            SFDR_arr        = zeros(1, N_mc);
            SNDR_FS_arr     = zeros(1, N_mc);
            for k = 1:N_mc
                fprintf("MC [%d] Is Testing......\n",k);
                obj.adc_init(); 
                result_mc_k         = fft_test(obj, N_sram, fin_single); % MC(k) FFT 测试完成

                ENOB_arr(k)         = result_mc_k.ENOB;
                ENOB_FS_arr(k)      = result_mc_k.ENOB_FS;
                SFDR_arr(k)         = result_mc_k.SFDR;
                SNDR_FS_arr(k)      = result_mc_k.SNDR_FS;
            end
            results_mc.ENOB     = ENOB_arr;
            results_mc.ENOB_FS  = ENOB_FS_arr;
            results_mc.SFDR     = SFDR_arr;
            results_mc.SNDR_FS  = SNDR_FS_arr;

            % 绘制蒙特卡洛测试直方图
            figure('Name','Monte Carlo Testing', ...
                'NumberTitle','off', ...
                'Color','w', ...
                'Units','centimeters', ...
                'Position',[2 2 24 8]);

            ax1 = subplot(1,3,1);
            obj.mc_histogram_plot(ax1, results_mc.SFDR, ...
                'SFDR [dBc]', 'SFDR');

            ax2 = subplot(1,3,2);
            obj.mc_histogram_plot(ax2, results_mc.SNDR_FS, ...
                'SNDR [dB]', 'SNDR');

            ax3 = subplot(1,3,3);
            obj.mc_histogram_plot(ax3, results_mc.ENOB_FS, ...
                'ENOB [bit]', 'ENOB');
            % 扫频测试
            fprintf("======== Frequency Sweeping Test ========\n");
            fin_sweep = fin_start : fin_step : fin_end;   % 产生测试频率
            n_fin   = length(fin_sweep);                  % 测试点数量
            ENOB_FS_sweep     = zeros(1, n_fin);
            SFDR_sweep        = zeros(1, n_fin);
            SNDR_FS_sweep     = zeros(1, n_fin);
            for idx_sweep = 1 : n_fin
                    result_sweep_idx = fft_test(obj, N_sram, fin_sweep(idx_sweep));    % 频率点测试
                    ENOB_FS_sweep(idx_sweep)    = result_sweep_idx.ENOB_FS;
                    SFDR_sweep(idx_sweep)       = result_sweep_idx.SFDR;
                    SNDR_FS_sweep(idx_sweep)    = result_sweep_idx.SNDR_FS;
            end
            
            results_sweep.ENOB_FS   = ENOB_FS_sweep;
            results_sweep.SFDR      = SFDR_sweep;
            results_sweep.SNDR_FS   = SNDR_FS_sweep;
            results_sweep.fin       = fin_sweep;

            % 绘制扫频测试折线图
            obj.dynamic_sweep_plot(results_sweep);
        end

        % 失调、增益失配全数字前台自适应盲校准算法实现
        % trace:返回校准过程中的寄存器轨迹 N_delay:每次迭代校准间隔 mu_os/mu_gain:LMS 参数 fin_cal:前台校准测试频率 
        % amp_cal:前台校准测试幅度 N_iter:前台校准迭代次数 N_sram:前台校准 SRAM 数据量 N_exp:EMA 指数平滑单元低通滤波参数（平滑个数）
        function  trace = calib_fore_lms(obj, N_delay, mu_os, mu_gain, fin_cal, amp_cal, N_iter, N_sram, N_exp)
            % 计算实际前台校准信号频率
            M = round(fin_cal / obj.fs * N_sram); 
            if mod(M , 2) == 0
                M = M + 1;
            end
            fin             = M / N_sram * obj.fs;
            alpha           = 1 / N_exp;
            signal          = @(t) amp_cal * sin(2 * pi * fin * t);     % 前台校准输入信号
            average_os      = zeros(1 , obj.N_ch);                      % 32 通道 EMA 计算失调
            average_gain    = zeros(1 , obj.N_ch);                      % 32 通道 EMA 计算增益
            trace_reg_os    = zeros(N_iter * N_sram / obj.N_ch , obj.N_ch - 1); % 存放 31 通道失调校准寄存器足迹
            trace_reg_gain  = zeros(N_iter * N_sram / obj.N_ch , obj.N_ch - 1); % 存放 31 通道增益校准寄存器足迹
            row_matric      = 1;
            for idx_iter = 1 : N_iter
                t_ideal         = ((N_sram + N_delay) * (idx_iter - 1)  : N_sram * idx_iter - 1 + N_delay * (idx_iter - 1)) / obj.fs;
                [d_origin, ~]   = obj.quantification(t_ideal, signal);
                d_origin        = d_origin - obj.code_center;
                n_loop          = N_sram/obj.N_ch;
                for idx_loop    = 1 : n_loop
                    d_cal       = (d_origin((idx_loop - 1) * obj.N_ch + 1 : idx_loop * obj.N_ch) - obj.reg_os_cal) .* (1 - obj.reg_gain_cal);
                    average_os  = alpha * d_cal + (1 - alpha) * average_os;
                    average_gain= alpha * abs(d_cal) + (1 - alpha) * average_gain;
                    % LMS 迭代
                    obj.reg_os_cal(2 : 32)    = obj.reg_os_cal(2 : 32) + mu_os * (average_os(2 : 32) - average_os(1));
                    obj.reg_gain_cal(2 : 32)  = obj.reg_gain_cal(2 : 32) + mu_gain * (average_gain(2 : 32) - average_gain(1));
                    % 存放足迹
                    trace_reg_os(row_matric, :)     = obj.reg_os_cal(2 : 32);
                    trace_reg_gain(row_matric, :)   = obj.reg_gain_cal(2 : 32);
                    row_matric                      = row_matric + 1;
                end
            end
            trace.os    = trace_reg_os;
            trace.gain  = trace_reg_gain;
        end

        % 采样时钟偏移校准算法，基于 MAD 相关性运算的改进算法 by Gu Mingyang
        % N_delay:相邻两次迭代之间间隔的采样点数目，模拟真实闭环环境
        % dcdl_step_set:设置 DCDL 调节步长 fin_cal:用于后台 skew 校准的输入信号频率 amp_cal:用于后台 skew 校准的输入信号的幅度
        % N_iter:后台校准迭代可观测迭代次数 N_sram:后台校准单次迭代样本数目
        function trace = calib_skew_mad(obj, N_delay, dcdl_step_set, fin_cal, amp_cal, N_iter, N_sram)
            % 设置 ADC 后台校准参数
            obj.dcdl_step = dcdl_step_set;  
            M = round(fin_cal / obj.fs * N_sram);
            if  mod(M,2) == 0 
                M = M + 1;
            end
            fin     = M / N_sram * obj.fs;
            signal  = @ (t) amp_cal * sin(2 * pi * fin * t);
            trace   = zeros(N_iter + 1, obj.N_phase - 1);
            trace(1, :) = obj.reg_dcdl(2:end);  % 去除不连续
            % 后台闭环迭代校准
            for idx_iter = 1 : N_iter
                sum_rr      = zeros(1, obj.N_phase);
                delta_rr    = zeros(1, obj.N_phase);
                t_ideal     = ((N_sram + N_delay) * (idx_iter - 1)  : N_sram * idx_iter - 1 + N_delay * (idx_iter - 1)) / obj.fs;
                [d_origin, ~] = obj.quantification(t_ideal, signal);
                d_raw   = d_origin - obj.code_center;
                n_loop  = N_sram / obj.N_ch;
                for idx_loop = 1 : n_loop   % 数字域增益失调失配校准
                    d_raw((idx_loop - 1) * obj.N_ch + 1 : idx_loop * obj.N_ch) = ...
                    (d_raw((idx_loop - 1) * obj.N_ch + 1 : idx_loop * obj.N_ch) - obj.reg_os_cal) .* (1 - obj.reg_gain_cal);
                end
                
                % 数据重分配： 32 路转 4 相
                M_data      = reshape(d_raw, 4, []);
                data_len    = size(M_data, 2);
                % MAD 计算
                for idx_data = 1: data_len-1
                    sum_rr(1 : end - 1) = sum_rr(1 : end - 1) + abs(M_data(1 : end - 1, idx_data) - M_data(2 : end, idx_data))';
                    sum_rr(end) = sum_rr(end) + abs(M_data(end, idx_data) - M_data(1, idx_data + 1));
                end
                % 相关性计算
                average_rr  = sum_rr / (data_len - 1);
                r_ts        = mean(average_rr);
                for idx_phase = 2 : obj.N_phase   % 计算相关性差异，符号表示时钟偏移方向
                    delta_rr(idx_phase) = sum(average_rr(1 : idx_phase - 1)) - (idx_phase - 1) * r_ts;
                end
                % 更新 DCDL 数值
                obj.reg_dcdl(2 : end) = obj.reg_dcdl(2 : end) - sign(delta_rr(2 : end));
                trace(idx_iter + 1, :) = obj.reg_dcdl(2 : end);
            end
        end

        % 全局校准测试函数，包含单次仿真和蒙特卡洛仿真
        % 未校准->测试 ADC->校准 os/gain 失配-> 测试 ADC->后台校准迭代 128 周期->测试 ADC
        % N_delay_os_gain:前台校准每次迭代延迟时间所覆盖的采样点数 mu_os/gain: LMS 参数 f_cal_os_gain:前台校准输入信号频率
        % amp_cal_os_gain:前台校准输入信号幅度 N_iter_os_gain:前台校准迭代次数 N_sram:单次迭代数据点个数
        % Nexp_os_gain:EMA 指数平滑单元平滑个数 N_delay_skew:后台校准每次迭代延迟时间所覆盖的采样点数 
        % dcdl_step_set:DCDL 步长 fin_cal_skew:skew 校准输入信号频率 amp_cal_skew:skew 校准输入信号幅度
        % N_iter_skew:skew 校准后台迭代可观测次数 f_test:用于测试 ADC 校准前后动态性能信号频率 N_mc:蒙特卡洛测试点数
        % 一般设置 fft 测试信号频率等于后台 Timing Skew 校准信号频率，因为是后台校准 
        function run_analysis_calib(obj,N_delay_os_gain, mu_os, mu_gain,f_cal_os_gain,...
                                    amp_cal_os_gain,N_iter_os_gain, N_sram, Nexp_os_gain,...
                                     N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew,...
                                     f_test, N_mc)
            % 初始化 ADC
            obj.adc_init();
            
            % 无校准动态性能测试
            fprintf('======== Testing Without Calib. ========\n');
            result_without_calib = obj.fft_test(N_sram, f_test); 
            
            % 施加失调、增益失配校准
            fprintf('======== Running OS/Gain Calib. ========\n');
            trace_os_gain   = obj.calib_fore_lms(N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain, amp_cal_os_gain,N_iter_os_gain,N_sram, Nexp_os_gain);
            fprintf('======== Testing With OS/Gain Calib. ========\n');
            result_os_gain  = obj.fft_test(N_sram, f_test);
            
            % 施加 Timing Skew 校准
            fprintf('======== Running Timing Skew Calib. ========\n');
            trace_skew      = obj.calib_skew_mad(N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew, N_sram);
            fprintf('======== Testing With Timing Skew Calib. ========\n');
            result_skew     = obj.fft_test(N_sram, f_test);
            
            % 蒙特卡洛测试 仅 SFDR + ENOB
            fprintf('======== Running Monte Carlo Testing ========\n')
            ENOB_FS_none    = zeros(1,N_mc);
            SFDR_none       = zeros(1,N_mc);
            ENOB_FS_os_gain = zeros(1,N_mc);
            SFDR_os_gain    = zeros(1,N_mc);
            ENOB_FS_skew    = zeros(1,N_mc);
            SFDR_skew       = zeros(1,N_mc);
            rng(obj.rng_seed);  % 重置随机数种子
            for idx_mc = 1 : N_mc
                fprintf('MC [%d] Is Testing......\n', idx_mc);
                % 初始化 ADC
                obj.adc_init();
                % 无校准测试
                rb                      = obj.fft_test(N_sram, f_test);
                ENOB_FS_none(idx_mc)    = rb.ENOB_FS;
                SFDR_none(idx_mc)       = rb.SFDR;

                % 施加失调/增益失配校准
                obj.calib_fore_lms(N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain, amp_cal_os_gain, N_iter_os_gain,N_sram, Nexp_os_gain);  %calibration
                % 测试失调/增益校准后性能
                ra_os_gain              = obj.fft_test(N_sram, f_test);
                ENOB_FS_os_gain(idx_mc) = ra_os_gain.ENOB_FS;
                SFDR_os_gain(idx_mc)    = ra_os_gain.SFDR;
                
                % 施加后台 Timing Skew 校准
                obj.calib_skew_mad(N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew, N_sram );
                % 后台 Timing Skew 校准后测试性能
                ra_skew                 = obj.fft_test(N_sram, f_test);
                ENOB_FS_skew(idx_mc)    = ra_skew.ENOB_FS;
                SFDR_skew(idx_mc)       = ra_skew.SFDR;
            end
            % 保存蒙特卡洛仿真结果
            results_mc_none.ENOB_FS     = ENOB_FS_none;
            results_mc_none.SFDR        = SFDR_none;
            results_mc_os_gain.ENOB_FS  = ENOB_FS_os_gain;
            results_mc_os_gain.SFDR     = SFDR_os_gain;
            results_mc_skew.ENOB_FS     = ENOB_FS_skew;
            results_mc_skew.SFDR        = SFDR_skew;
            
            % 绘制结果
            % 绘制三次校准的 FFT 频谱
            figure('Name','FFT Spectrum','NumberTitle', 'off', 'Position', [200 100 900 700] );
            ax1_one = subplot(3, 1, 1);
            ax2_one = subplot(3, 1, 2);
            ax3_one = subplot(3, 1, 3);
            obj.spectrum_plot(ax1_one, result_without_calib, 'FFT Spectrum Without Calib.');
            obj.spectrum_plot(ax2_one, result_os_gain, 'FFT Spectrum With OS/Gain Calib.');
            obj.spectrum_plot(ax3_one, result_skew, 'FFT Spectrum With OS/Gain and Timing Skew Calib.');

            % 绘制校准过程的迭代收敛图
            % OS 校准寄存器收敛
            figure('Name', 'Convergence Process of Calibration', 'NumberTitle', 'off', 'Position', [200 100 900 700]);
            ax1_trace = subplot(3, 1, 1);
            ax2_trace = subplot(3, 1, 2);
            ax3_trace = subplot(3, 1, 3);
            obj.trace_plot(ax1_trace, trace_os_gain.os / 135 * 0.6, 'OS Calib. Register Convergence Trace', 'OS Register Value');
            obj.trace_plot(ax2_trace, trace_os_gain.gain, 'Gain Calib. Register Convergence Trace', 'Gain Register Value');
            obj.trace_skew_plot(ax3_trace, trace_skew, 'Skew Calib. Register Convergence Trace', 'Skew Register Value');

            % 绘制蒙特卡洛测试直方图
            figure('Name', 'Monte Carlo Result', 'NumberTitle','off','Position', [200 100 900 700]);
            ax1_mc = subplot(3, 2, 1);
            ax2_mc = subplot(3, 2, 2);
            ax3_mc = subplot(3, 2, 3);
            ax4_mc = subplot(3, 2, 4);
            ax5_mc = subplot(3, 2, 5);
            ax6_mc = subplot(3, 2, 6);
            obj.mc_histogram_plot(ax1_mc, results_mc_none.ENOB_FS, 'bits', 'Histogram of ENOB@FS Without Calib.');
            obj.mc_histogram_plot(ax2_mc, results_mc_none.SFDR, 'dBc', 'Histogram of SFDR Without Calib.');
            obj.mc_histogram_plot(ax3_mc, results_mc_os_gain.ENOB_FS, 'bits', 'Histogram of ENOB@FS With OS/Gain Calib.');
            obj.mc_histogram_plot(ax4_mc, results_mc_os_gain.SFDR, 'dBc', 'Histogram of SFDR With OS/Gain Calib.');
            obj.mc_histogram_plot(ax5_mc, results_mc_skew.ENOB_FS, 'bits', 'Histogram of ENOB@FS With OS/Gain and Timing Skew Calib.');
            obj.mc_histogram_plot(ax6_mc, results_mc_skew.SFDR, 'dBc', 'Histogram of SFDR With OS/Gain and Timing Skew Calib.');
        end

        % 测试后台 Timing Skew 校准的跟踪特性
        % ADC 初始化->完成首次后台校准->改变 ADC Skew 参数->观测后台校准能否跟踪
        function calib_skew_track(obj, N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain,...
                                    amp_cal_os_gain, N_iter_os_gain, N_sram, Nexp_os_gain,...
                                    N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew, f_test)
            % 初始化 ADC
            obj.adc_init();
            % 无校准测试
            fprintf('======== Testing Without Calib. ========\n');
            result_without_calib = obj.fft_test(N_sram, f_test);
            % 执行 OS/Gain 失配校准
            fprintf('======== Running OS/Gain Calib. ========\n');
            trace_os_gain = obj.calib_fore_lms(N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain, ...
                                                amp_cal_os_gain, N_iter_os_gain, N_sram, Nexp_os_gain);
            % OS/Gain 校准后测试
            fprintf('======== Testing With OS/Gain Calib. ========\n');
            result_calib_os_gain = obj.fft_test(N_sram, f_test);
            % 执行 Timing Skew 校准
            fprintf('======== Running Skew Calib. ========\n');
            trace_skew1 = obj.calib_skew_mad(N_delay_skew, dcdl_step_set, fin_cal_skew,...
                                            amp_cal_skew, N_iter_skew, N_sram);
            % Timing Skew 校准后测试
            fprintf('======== Testing With Timing Skew Calib. ========\n');
            result_calib_skew1 = obj.fft_test(N_sram, f_test);

            % 更新失配参数模拟实际芯片环境变化引起失配变化
            obj.skew_ch = -1 * obj.cof_skew + 2 * obj.cof_skew * rand(1, obj.N_phase);
            fprintf('======== Testing after Changing the Mismatch Parameters ========\n');
            result_change = obj.fft_test(N_sram, f_test);
            
            % 执行新一轮后台校准
            fprintf('======== Performing New Skew Calib. ========\n');
            trace_skew2 = obj.calib_skew_mad(N_delay_skew, dcdl_step_set, fin_cal_skew,...
                                            amp_cal_skew, N_iter_skew, N_sram);
            % 新一轮校准收敛后测试
            fprintf('======== Testing after New Skew Calib. ========\n');
            result_calib_skew2 = obj.fft_test(N_sram, f_test);
            
            % 绘制测试结果
            fprintf('======== Plot the Result ========\n');
            figure('Name','FFT Test before Change','NumberTitle','off','Position',[200 100 900 700]);
            ax11 = subplot(3,1,1);
            obj.spectrum_plot(ax11, result_without_calib, 'FFT Spectrum Without OS/Gain Calib.');
            ax12 = subplot(3,1,2);
            obj.spectrum_plot(ax12, result_calib_os_gain, 'FFT Spectrum With OS/Gain Calib.');
            ax13 = subplot(3,1,3);
            obj.spectrum_plot(ax13, result_calib_skew1, 'FFT Spectrum With OS/Gain and Timing Skew Calib.)');
            figure('Name','FFT Test after Change','NumberTitle','off','Position',[200 100 900 700]);
            ax21 = subplot(2,1,1);
            obj.spectrum_plot(ax21, result_change, 'FFT Spectrum Without Newest Skew Calib.');
            ax22 = subplot(2,1,2);
            obj.spectrum_plot(ax22, result_calib_skew2, 'FFT Spectrum With Newest Skew Calib.');
            figure('Name', 'Convergence Process of Calib.', 'NumberTitle', 'off', 'Position', [200 100 900 700]);
            ax31 = subplot(3,1,1);
            obj.trace_plot(ax31, trace_os_gain.os /135 *0.6 , 'OS Calibration Register Convergence Trace', 'OS Register Value');
            ax32 = subplot(3,1,2);
            obj.trace_plot(ax32, trace_os_gain.gain , 'Gain Calibration Register Convergence Trace', 'Gain Register Value');
            ax33 = subplot(3,1,3);
            obj.trace_skew_plot(ax33, [trace_skew1;trace_skew2], 'Skew Calibration Register Convergence Trace', 'Skew Register Value');
        end

    end

    % 私有函数
    methods(Access = private)
        % FFT 测试性能函数，全部基于相干采样测试
        % obj:待测试 ADC 模型; N_sram: 测试 FFT 点数; f_test: 测试信号频率
        function result = fft_test(obj, N_sram, f_test) 

            % 计算最接近的相干采样频率
            M = round(f_test / obj.fs * N_sram);
            if mod(M,2) == 0
                M = M + 1;
            end
            fin         = M / N_sram * obj.fs;                      % 实际测试信号频率
            amp         = 0.26;                                     % 测试信号幅度
            waveform    = @(t) amp * sin(2 * pi * fin * t);         % 测试信号
            t           = (0 : N_sram-1) / obj.fs;

            [d_raw, ~]  = obj.quantification(t, waveform);          % 测试量化输出

            % 数字域校准
            d_raw       = d_raw - obj.code_center;                  % 转化为有符号数
            n_loop      = N_sram / obj.N_ch;                   
            for idx_loop = 1 : n_loop
                d_raw((idx_loop-1) * obj.N_ch + 1 : idx_loop * obj.N_ch) =...
                 (d_raw((idx_loop-1) * obj.N_ch + 1 : idx_loop * obj.N_ch) - obj.reg_os_cal) .* (1 - obj.reg_gain_cal);
            end
            % 数字域校准结束

            % 得到最终用于 FFT 测试数据

            % 开始 FFT 测试
            d = d_raw - mean(d_raw);            % 归一化
            X = fft(d, N_sram);                 % 矩形窗相干采样
            
            X = X(1 : N_sram / 2 + 1);          % 单边谱

            % 计算频谱
            mag             = abs(X);                       
            mag             = mag / N_sram;                 
            mag(2 : end-1)  = 2 * mag(2 : end-1);
            spec_db         = 20*log10(mag + eps);
            spec_db         = spec_db - max(spec_db);   % 归一化
            P               = abs(X).^ 2;               % 功率计算
            idx_sig         = M + 1;                    % 主信号下标
            span            = 0;                        % 最小化频谱泄露，相干采样取为 0；非相干采样加入窗函数后需要合理取值 1-3                       
            idx_range       = max(idx_sig - span, 1) : min(idx_sig + span, N_sram / 2 + 1);  % 信号功率分量范围
            P_signal        = sum(P(idx_range));

            % 计算 SFDR
            P_spur                  = P;
            P_spur(1)               = 0;                % 去除 dc 分量     
            P_spur(idx_range)       = 0;                % 去除 信号分量
            P_spur_max              = max(P_spur);      % 计算最大杂散
            if P_spur_max < eps
                SFDR = 100;
            else
                SFDR = 10 * log10(P_signal / P_spur_max); % 计算 SFDR
            end

            % 计算谐波失真功率
            mask_signal             = false(size(P));
            mask_signal(idx_range)  = true;
            P_harm                  = 0;
            for k = 2:10                                   % 2-10 次谐波
                h = mod( k * M, N_sram );
                if h > N_sram / 2
                    h = N_sram - h;
                end
                idx_h = h + 1;
                if idx_h > 1 && idx_h <= N_sram / 2
                    idx_h_range = max(idx_h - span, 1) : min(idx_h + span, N_sram / 2 + 1);
                    if any(mask_signal(idx_h_range))
                        continue;
                    end
                    P_harm = P_harm + sum(P(idx_h_range));
                end 
            end
            P_total     = sum(P(2 : end));
            % 计算噪声功率
            P_noise     = P_total - P_signal - P_harm;
            if P_noise < eps
                P_noise = eps;
            end

            % 计算 SNDR
            SNDR    = 10 * log10(P_signal / (P_noise + P_harm));
            SNR     = 10 * log10(P_signal / P_noise);
            THD     = 10 * log10(P_harm / P_signal);

            % 计算 ENOB
            ENOB = (SNDR - 1.76) / 6.02;

            % 计算满摆幅等效性能

            % 计算实际输入信号幅度
            actual_amp  = 2 * sqrt(P_signal) / N_sram;
            % 估算 ADC 摆幅
            cap_pt_ref  = obj.cap_arr_pt(1, :);
            cap_nt_ref  = obj.cap_arr_nt(1, :);
            c_tot_p_ref = sum(obj.cap_arr_pt(1, :)) + sum(obj.cap_arr_pb(1, :)) + 2 * obj.cp_top;
            c_tot_n_ref = sum(obj.cap_arr_nt(1, :)) + sum(obj.cap_arr_nb(1, :)) + 2 * obj.cp_top;
            amp_fs = obj.Vref * (sum(cap_pt_ref) / c_tot_p_ref + sum(cap_nt_ref) / c_tot_n_ref);

            waveform_fs = @(t) amp_fs * sin(2 * pi * fin * t);
            [d_fs, ~] = obj.quantification(t, waveform_fs);   % 满摆幅测试数据输出
            d_fs = d_fs - obj.code_center;
            for idx_loop = 1:n_loop
                d_fs((idx_loop-1) * obj.N_ch + 1 : idx_loop * obj.N_ch) = ...
                    (d_fs((idx_loop-1) * obj.N_ch + 1 : idx_loop * obj.N_ch) - obj.reg_os_cal) .* ...
                    (1 - obj.reg_gain_cal);
            end
            d_fs_fft = d_fs - mean(d_fs);
            X_fs = fft(d_fs_fft, N_sram);
            X_fs = X_fs(1 : N_sram / 2 + 1);
            full_scale = 2 * abs(X_fs(idx_sig)) / N_sram;

            % 计算 backoff
            if actual_amp > 0 && full_scale > 0
                backoff = 20*log10(full_scale / actual_amp);
            else
                backoff = 0;
            end
            
            % 计算等效满摆幅动态性能（SFDR 无影响）
            SNDR_FS = SNDR + backoff;
            ENOB_FS = (SNDR_FS - 1.76) / 6.02;

            % 导出测试结果
            result.freq     = linspace(0, obj.fs / 2, N_sram / 2 + 1);      % FFT x 坐标
            result.spec_db  = spec_db;                                      % FFT y 坐标
            result.SNDR     = SNDR;                                         % 原始 SNDR
            result.SNR      = SNR;                                          % 原始 SNR
            result.THD      = THD;                                          % 总谐波失真
            result.SFDR     = SFDR;                                         % SFDR
            result.ENOB     = ENOB;                                         % ENOB
            result.SNDR_FS  = SNDR_FS;                                      % 等效满摆幅 SNDR
            result.ENOB_FS  = ENOB_FS;                                      % 等效满摆幅 ENOB
            result.backoff  = backoff;                                      % backoff
            result.fin      = fin;                                          % 测试信号频率
        end

        % 绘图函数

        % 绘制单次频谱
        function spectrum_plot(obj, ax, result, string_title)
            axes(ax);       % 切换坐标轴

            % 绘制频谱
            plot(result.freq/1e9, result.spec_db, '-*', ...
                'Color', [0.2000 0.4500 0.8000], ...
                'LineWidth', 0.75, ...
                'MarkerSize', 2, ...
                'MarkerEdgeColor', [0.2000 0.4500 0.8000]);   

            % 标签
            xlabel('Frequency (GHz)');
            ylabel('Magnitude (dB)');
            title(string_title);
            ylim([-100, 0]);
            grid on;
            info_str = sprintf([...
                'Input signal frequency is %.4f GHz\n'...
                'Input signal amplitude is %.2f dBFS\n'...
                'ENOB = %.2f bits\n'...
                'ENOB@FS = %.2f bits\n'...
                'SNDR = %.2f dB @ %.2f dBFS\n'...
                'SNDR@FS = %.2f dB\n'...
                'SFDR = %.2f dBc @ %.2f dBFS'], ...
                result.fin / 1e9, ...
                -1 * result.backoff, ...
                result.ENOB, ...
                result.ENOB_FS, ...
                result.SNDR, ...
                -1 * result.backoff, ...
                result.SNDR_FS, ...
                result.SFDR, ...
                -1 * result.backoff);

            text(0.02, 0.97, info_str, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'left', ...
                'FontName', 'Arial', ...
                'FontSize', 6, ...
                'Color', 'k', ...
                'BackgroundColor', 'none', ...
                'Clipping', 'on');

            obj.adc_apply_axes_style(ax, 'fft');
        end

        % 绘制蒙特卡洛直方图统计
        function mc_histogram_plot(obj, ax, results_mc, string_xlabel, string_title)
            axes(ax);

            histogram(results_mc, 60, ...
                'FaceColor', [0.8500 0.3250 0.0980], ...
                'EdgeColor', 'w', ...
                'FaceAlpha', 0.88, ...
                'LineWidth', 0.8);

            mu = mean(results_mc);
            sigma = std(results_mc);
            info2 = sprintf('Mean = %.4f\nStd = %.4f', mu, sigma);
            text(0.03, 0.96, info2, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'left', ...
                'FontName', 'Arial', ...
                'FontSize', 11, ...
                'Color', 'k', ...
                'BackgroundColor', 'w', ...
                'EdgeColor', 'none', ...
                'Margin', 3);

            title(string_title);
            xlabel(string_xlabel);
            ylabel('Counts');
            grid on;

            obj.adc_apply_axes_style(ax, 'hist');
        end
        
        % 绘制迭代收敛足迹
        function trace_plot(obj, ax, M_trace, string_title, string_y)
            axes(ax);
            [~, n_ch] = size(M_trace);
            colors = obj.adc_thesis_palette(max(n_ch, 5));

            hold on;
            for k = 1:n_ch
                plot(M_trace(:, k), ...
                    'LineWidth', 1.5, ...
                    'Color', colors(k, :));
            end
            hold off;
        
            grid on;
            xlabel('Iteration');
            ylabel(string_y);
            title(string_title);
        
            colormap(ax, colors);
            cb = colorbar(ax);
            cb.Label.String = 'Channel Index';
            obj.adc_apply_colorbar_style(cb);
            clim(ax, [2 32]);
        
            obj.adc_apply_axes_style(ax, 'trace');
        end

        % 绘制 DCDL 迭代足迹
        function trace_skew_plot(obj, ax, M_trace, string_title, string_y)
            axes(ax);
            colors = obj.adc_thesis_palette(5);
            n_line = size(M_trace, 2);
            if n_line == 1
                n_line = 3;
            end     

            hold on;
            if size(M_trace, 2) == 1
                plot(M_trace, 'LineWidth', 2.0, 'Color', colors(1, :));
            else
                marker_list = {'o', 's', 'v', '^', 'd'};
                for k = 1:size(M_trace, 2)
                    plot(M_trace(:, k), ...
                        'LineWidth', 2.0, ...
                        'Color', colors(k, :), ...
                        'Marker', marker_list{mod(k-1, numel(marker_list)) + 1}, ...
                        'MarkerIndices', 1:max(1, floor(size(M_trace, 1)/18)):size(M_trace, 1), ...
                        'MarkerSize', 5, ...
                        'MarkerFaceColor', 'none', ...
                        'MarkerEdgeColor', colors(k, :));
                end
            end
            hold off;       

            grid on;
            xlabel('Iteration');
            ylabel(string_y);
            title(string_title);        

            labels = arrayfun(@(x) sprintf('Ch%d', x), 2:(n_line+1), ...
                'UniformOutput', false);
            lgd = legend(labels, ...
                'Location', 'northoutside', ...
                'Orientation', 'horizontal');
            obj.adc_apply_legend_style(lgd);        

            obj.adc_apply_axes_style(ax, 'trace');
        end


        % 绘制扫频测试折线
        % 返回图窗句柄
        function figHandles = dynamic_sweep_plot(obj, results_sweep)
            fin_GHz = results_sweep.fin(:).' / 1e9;
            sfdr = results_sweep.SFDR(:).';
            sndr = results_sweep.SNDR_FS(:).';
            enob = results_sweep.ENOB_FS(:).';

            figHandles = gobjects(1, 3);
            figHandles(1) = obj.plot_one_sweep(fin_GHz, sfdr, 'SFDR [dBc]', 'SFDR vs. Input Frequency');
            figHandles(2) = obj.plot_one_sweep(fin_GHz, sndr, 'SNDR [dB]',  'SNDR vs. Input Frequency');
            figHandles(3) = obj.plot_one_sweep(fin_GHz, enob, 'ENOB [bit]', 'ENOB vs. Input Frequency');
        end

        % 绘图风格辅助函数
        function fig = plot_one_sweep(~, fin_GHz, y, yLabelText, titleText)
            c_blue = [0.3010 0.5450 0.7650];

            fig = figure( ...
                'Name', titleText, ...
                'NumberTitle', 'off', ...
                'Units', 'centimeters', ...
                'Position', [2 2 20 11], ...
                'Color', 'w');
            set(fig, 'InvertHardcopy', 'off');

            ax = axes(fig);
            set(ax, 'Units', 'normalized', 'Position', [0.125 0.165 0.835 0.700]);
            hold(ax, 'on');

            plot(ax, fin_GHz, y, '-o', ...
                'Color', c_blue, ...
                'LineWidth', 2.2, ...
                'MarkerSize', 7.5, ...
                'MarkerFaceColor', 'w', ...
                'MarkerEdgeColor', c_blue);

            xlabel(ax, 'Frequency [GHz]', ...
                'FontName', 'Arial', ...
                'FontSize', 18, ...
                'FontWeight', 'normal');

            ylabel(ax, yLabelText, ...
                'FontName', 'Arial', ...
                'FontSize', 18, ...
                'FontWeight', 'normal');

            title(ax, titleText, ...
                'FontName', 'Arial', ...
                'FontSize', 16, ...
                'FontWeight', 'normal', ...
                'Color', 'k');

            box(ax, 'on');
            grid(ax, 'on');
            set(ax, ...
                'Color', 'w', ...
                'FontName', 'Arial', ...
                'FontSize', 15, ...
                'FontWeight', 'normal', ...
                'LineWidth', 1.5, ...
                'TickDir', 'in', ...
                'TickLength', [0.012 0.012], ...
                'GridLineStyle', '-', ...
                'GridAlpha', 0.28, ...
                'XColor', 'k', ...
                'YColor', 'k', ...
                'Layer', 'top');

            xlim(ax, [0 14]);
            xticks(ax, 0:2:14);

            yMin = min(y);
            yMax = max(y);
            if yMin == yMax
                pad = max(abs(yMin) * 0.05, 1);
            else
                pad = 0.10 * (yMax - yMin);
            end
            ylim(ax, [yMin - pad, yMax + pad]);
        
            if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
                ax.Toolbar.Visible = 'off';
            end
        end
        
        function adc_apply_axes_style(~, ax, style_name)
            if nargin < 2
                style_name = 'paper';
            end
        
            set(gcf, 'Color', 'w', 'InvertHardcopy', 'off');
            set(ax, ...
                'Color', 'w', ...
                'XColor', 'k', ...
                'YColor', 'k', ...
                'ZColor', 'k', ...
                'FontName', 'Arial', ...
                'FontSize', 15, ...
                'LineWidth', 1.4, ...
                'Box', 'on', ...
                'TickDir', 'in', ...
                'TickLength', [0.012 0.012], ...
                'Layer', 'top', ...
                'GridColor', [0.45 0.45 0.45], ...
                'MinorGridColor', [0.65 0.65 0.65], ...
                'MinorGridAlpha', 0.12);
        
            switch lower(style_name)
                case 'fft'
                    set(ax, 'GridAlpha', 0.22);
                case 'trace'
                    set(ax, 'GridAlpha', 0.28);
                case 'hist'
                    set(ax, 'GridAlpha', 0.18);
                otherwise
                    set(ax, 'GridAlpha', 0.24);
            end
        
            set(get(ax, 'XLabel'), ...
                'FontName', 'Arial', 'FontSize', 18, 'Color', 'k', ...
                'FontWeight', 'normal');
            set(get(ax, 'YLabel'), ...
                'FontName', 'Arial', 'FontSize', 18, 'Color', 'k', ...
                'FontWeight', 'normal');
            set(get(ax, 'ZLabel'), ...
                'FontName', 'Arial', 'FontSize', 18, 'Color', 'k', ...
                'FontWeight', 'normal');
            set(get(ax, 'Title'), ...
                'FontName', 'Arial', 'FontSize', 16, 'Color', 'k', ...
                'FontWeight', 'normal');
        
            txt = findall(ax, 'Type', 'text');
            for k = 1:numel(txt)
                set(txt(k), 'FontName', 'Arial', 'Color', 'k');
            end
        end

        function adc_apply_legend_style(~, lgd)
            set(lgd, ...
                'Color', 'none', ...
                'TextColor', 'k', ...
                'FontName', 'Arial', ...
                'FontSize', 13, ...
                'Box', 'off');
        end

        function adc_apply_colorbar_style(~, cb)
            set(cb, ...
                'Color', 'k', ...
                'FontName', 'Arial', ...
                'FontSize', 13, ...
                'LineWidth', 1.2);
            cb.Label.Color = 'k';
            cb.Label.FontName = 'Arial';
            cb.Label.FontSize = 14;
        end

        function colors = adc_thesis_palette(~, n)
            base = [ ...
                0.8500 0.3250 0.0980; ...
                0.9290 0.6940 0.1250; ...
                0.4940 0.1840 0.5560; ...
                0.3010 0.5450 0.7650; ...
                0.4660 0.6740 0.1880; ...
                0.0000 0.4470 0.7410; ...
                0.6350 0.0780 0.1840];
        
            colors = zeros(n, 3);
            for k = 1:n
                colors(k, :) = base(mod(k-1, size(base, 1)) + 1, :);
            end
        end

    end
end