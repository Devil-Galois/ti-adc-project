%% 生成前台校准迭代 ADC 原始数据流

clc; clear;
% 添加 ADC 模型目录
script_dir  = fileparts(mfilename('fullpath'));
verilog_dir = fullfile(script_dir, '..');
dsp_dir     = fullfile(verilog_dir, '..');
addpath(fullfile(dsp_dir, 'matlab'));

bin_dir     = fullfile(verilog_dir, 'bin');
if ~exist(bin_dir, 'dir')
    mkdir(bin_dir);
end

% ADC 初始化
adc = adc_model();
% 配置 ADC 参数
% 由于仅前台校准测试，因此将所有 Skew 非理想因素置零
adc.cof_skew = 0;

adc.adc_init();

% 设置 ADC 原始数据流参数
N_sram          = 2^16;             % 每一轮产生的点数 (65536) 即 SARM 容量
N_iter          = 32;               % 总迭代次数
N_delay         = 7281;             % 每一轮之间的采样点间隔
amp_cal         = 0.26;             % 信号幅度
fs              = 28e9;             % 采样率
target_fin      = 9 * fs / 1024;    % 校准信号目标频率

% 计算校准信号真实频率
M = round(target_fin / fs * N_sram);
if mod(M, 2) == 0, M = M + 1; end
fin_coherent = (M / N_sram) * fs;
signal = @(t) amp_cal * sin(2 * pi * fin_coherent * t);

fprintf('前台校准信号频率: %.6f GHz\n', fin_coherent / 1e9);

% 原始数据存放文件
fid = fopen(fullfile(bin_dir, 'origin_data_8bits.txt'), 'w');

% 循环产生迭代数据并存入文件
for idx_iter = 1 : N_iter
    fprintf('正在生成并保存第 %d/%d 轮数据...\n', idx_iter, N_iter);
    
    t_start_idx = (N_sram + N_delay) * (idx_iter - 1);
    t_end_idx   = t_start_idx + N_sram - 1;
    t_ideal     = (t_start_idx : t_end_idx) / fs;
    
    [~, decisions_all] = adc.quantification(t_ideal, signal);
    
    char_matrix = char(decisions_all + '0'); 
    for r = 1 : N_sram
        fprintf(fid, '%s\n', char_matrix(r, :));
    end
end

fclose(fid);
fprintf('原始数据已生成: origin_data_8bits.txt (总行数: %d)\n', N_iter * N_sram);


%%  生成 ADC 校准前后所需测试数据流

f_test = 509 * fs / 1024;
amp_test = amp_cal; 
M = round(f_test / fs * N_sram);
if mod(M, 2) == 0, M = M + 1; end
fin_test = (M / N_sram) * fs;
signal = @(t) amp_test * sin(2 * pi * fin_test * t);

fprintf('测试信号频率: %.6f GHz\n', fin_test / 1e9);

% 测试数据流存放位置
fid_test        = fopen(fullfile(bin_dir, 'origin_test_data_8bits.txt'), 'w');
t_start_idx     = 0;
t_end_idx       = t_start_idx + N_sram - 1;
t_ideal         = (t_start_idx : t_end_idx) / fs;
[~, test_all]   = adc.quantification(t_ideal, signal);
char_matrix     = char(test_all + '0'); 
for r = 1 : N_sram
    fprintf(fid_test, '%s\n', char_matrix(r, :));
end
fclose(fid_test);
fprintf('测试数据已生成: origin_test_data_8bits.txt (总行数: %d)\n', N_sram);

%% 计算满摆幅基波幅度用于 FFT 测试
cap_pt = adc.cap_arr_pt(1, :);
cap_pb = adc.cap_arr_pb(1, :);
cap_nt = adc.cap_arr_nt(1, :);
cap_nb = adc.cap_arr_nb(1, :);

c_tot_p = sum(cap_pt) + sum(cap_pb) + 2 * adc.cp_top;
c_tot_n = sum(cap_nt) + sum(cap_nb) + 2 * adc.cp_top;

amp_fs = adc.Vref * (sum(cap_pt) / c_tot_p + sum(cap_nt) / c_tot_n);

signal_fs       = @(t) 0.999 * amp_fs * sin(2 * pi * fin_test * t);
[d_fs, ~]       = adc.quantification(t_ideal, signal_fs);
d_fs            = d_fs - adc.code_center;

d               = d_fs - mean(d_fs);
X               = fft(d, N_sram);
X               = X(1: N_sram / 2 + 1);

idx_sig         = M + 1;
span            = 0;
idx_range       = max(idx_sig - span, 1) : min(idx_sig + span, N_sram / 2 + 1);

P               = abs(X).^2;
P_signal        = sum(P(idx_range));

full_scale_amp  = 2 * sqrt(P_signal) / N_sram;

fid_fs          = fopen(fullfile(bin_dir, 'fullscale_reference.txt'), 'w');

fprintf(fid_fs, '%.16e\n', full_scale_amp);
fclose(fid_fs);

fprintf('满摆幅参考: %.8f code\n', full_scale_amp);

