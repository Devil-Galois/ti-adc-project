%% 执行全部 RTL 级算法校准的主脚本

clc; clear; close all;

% 统一路径
script_dir  = fileparts(mfilename('fullpath'));
verilog_dir = fullfile(script_dir, '..');
dsp_dir     = fullfile(verilog_dir, '..');

matlab_dir  = fullfile(dsp_dir, 'matlab');
bin_dir     = fullfile(verilog_dir, 'bin');
build_dir   = fullfile(verilog_dir, 'build');

run_sim = fullfile(verilog_dir, 'run_sim.ps1');

if ~isfile(run_sim)
    error('run_sim.ps1 not found: %s', run_sim);
end

addpath(matlab_dir);

if ~exist(bin_dir, 'dir'), mkdir(bin_dir); end
if ~exist(build_dir, 'dir'), mkdir(build_dir); end

fs              = 28e9;
N_sram          = 2^16;             % SRAM 深度
N_FFT           = 2^16;             % FFT 点数 (已设为与 N_sram 一致)
N_iter_cal1     = 32;               % OS/Gain 迭代次数
N_delay         = 1718;             % 迭代间隔
SKEW_INTER      = 128;              % Skew 闭环迭代次数

f_calib1_target = 9 * fs / 1024; 
f_skew_target   = 409 * fs / 1024;
f_test_target   = 409 * fs / 1024; 
amp_cal         = 0.26;

% 初始化 ADC
adc = adc_model();
adc.adc_init();

[f_cal1, M_cal1] = get_coherent_freq(f_calib1_target, fs, N_FFT);
[f_skew, M_skew] = get_coherent_freq(f_skew_target, fs, N_FFT);
[f_test, M_test] = get_coherent_freq(f_test_target, fs, N_FFT);

fprintf('前台校准信号频率: %.4f MHz\n', f_cal1 / 1e6);
fprintf('后台校准信号频率: %.4f MHz\n', f_skew / 1e6);
fprintf('测试信号频率: %.4f MHz\n', f_test / 1e6);

% 生成 OS/Gain 校准的训练数据
fprintf('生成 OS/Gain 训练数据...\n');

fid1 = fopen(fullfile(bin_dir, 'tran_data_calib1.txt'), 'w');

for idx = 1 : N_iter_cal1
    t_start_idx = (N_sram + N_delay) * (idx - 1);
    t_ideal = (t_start_idx : t_start_idx + N_sram - 1) / fs;
    
    signal_in = @(t) amp_cal * sin(2 * pi * f_cal1 * t);    
    [~, decisions] = adc.quantification(t_ideal, signal_in);
    
    char_mat = char(decisions + '0');
    for r = 1 : N_sram
        fprintf(fid1, '%s\n', char_mat(r,:)); 
    end
end
fclose(fid1);


% FFT 测试数据产生
fprintf('生成 FFT 测试数据...\n');
t_test = (0 : N_sram - 1) / fs;
sig_test = @(t) amp_cal * sin(2 * pi * f_test * t);
sig_skew = @(t) amp_cal * sin(2 * pi * f_skew * t);
[d_raw_none, dec_test] = adc.quantification(t_test, sig_test);

fid_t = fopen(fullfile(bin_dir, 'test_data.txt'), 'w');   % 原始测试数据写入
char_mat_t = char(dec_test + '0');
for r = 1:N_sram
    fprintf(fid_t, '%s\n', char_mat_t(r,:));
end
fclose(fid_t);

%  向量 d_raw_none 包含原始采集、量化数据的十进制数值表示可以直接用于FFT 无任何校准
d_raw_none = d_raw_none - adc.code_center;   % 去中心化转换为有符号数


% 运行 Verilog OS/Gain 校准 (tb_calib1)
fprintf('正在运行 tb_calib1.v:OS/Gain 校准仿真(32 Iterations)...\n');

% 调用现有的 powershell 脚本
cmd = sprintf('powershell -NoProfile -ExecutionPolicy Bypass -File "%s" calib1', run_sim);
[status, cmdout] = system(cmd);

if status ~= 0
    disp('报错详细信息如下');
    disp(cmdout);
    error('Verilog tb_calib1 仿真失败');
end

% 注意：Verilog 中已输出带小数的十进制数值   
d_raw_cal1 = readmatrix(fullfile(bin_dir, 'test_calib1_dec.txt'));


% 运行 Skew 闭环校准循环 (128 次) tb_calib2 
fprintf('正在运行 tb_calib2.v:Skew 校准仿真(%d Iterations)...\n', SKEW_INTER);
reg_dcdl = [0, 0, 0];                   % Ph1, Ph2, Ph3 (Ph0是参考)
dcdl_trace = zeros(3, SKEW_INTER + 1);  % 记录轨迹

for k = 1 : SKEW_INTER
    t_offset_idx = (N_sram + N_delay) * (N_iter_cal1 + k - 1);
    t_skew_train = (t_offset_idx: t_offset_idx + N_sram - 1) / fs;
    adc.reg_dcdl = [0, reg_dcdl];      
    [~, dec_skew] = adc.quantification(t_skew_train, sig_skew);
    
    % 采样量化数据结果覆盖 tran_data_calib2.txt
    calib2_file = fullfile(bin_dir, 'tran_data_calib2.txt');
    fid_s = -1;
    msg = '';
    for retry = 1:10
        [fid_s, msg] = fopen(calib2_file, 'wt');
        if fid_s >= 0
            break;
        end
        pause(0.1);
    end
    if fid_s < 0
        error('Failed to open calib2_tran.txt for writing. File: %s. Current folder: %s. Reason: %s', ...
              calib2_file, pwd, msg);
    end
    char_mat_s = char(dec_skew + '0');
    for r = 1 : N_sram
        fprintf(fid_s, '%s\n', char_mat_s(r, :));
    end
    fclose(fid_s);
    
    % 调用 tb_calib2 进行 dcdl 调节符号判定
    cmd = sprintf('powershell -NoProfile -ExecutionPolicy Bypass -File "%s" calib2', run_sim);
    [status, cmdout] = system(cmd);

    if status ~= 0
        disp('报错详细信息如下');
        disp(cmdout);
        error('Verilog tb_calib2 仿真失败 (Iter %d)', k);
    end
    
    % 更新 reg_dcdl 向量数值
    dcdl_file = fullfile(bin_dir, 'dcdl_3bits.txt');
    fid_in = fopen(dcdl_file, 'r');
    
    if fid_in < 0
        error('Cannot open dcdl_3bits.txt: %s', dcdl_file);
    end
    
    sign_str = strtrim(fscanf(fid_in, '%s'));
    fclose(fid_in);
    
    if length(sign_str) ~= 3 || any(sign_str ~= '0' & sign_str ~= '1')
        error('Invalid dcdl_3bits.txt content: "%s". Expected exactly 3 binary bits.', sign_str);
    end
    
    disp(sign_str);
    
    for p = 1:3
        if sign_str(4 - p) == '1'
            reg_dcdl(p) = reg_dcdl(p) - 1;
        else
            reg_dcdl(p) = reg_dcdl(p) + 1;
        end
    end

    dcdl_trace(:, k+1) = reg_dcdl;
    
    fprintf('进度: %d/%d | 当前 DCDL: [%d %d %d]\n', k, SKEW_INTER, reg_dcdl(1), reg_dcdl(2), reg_dcdl(3));
end


adc.reg_dcdl = [0, reg_dcdl];   % 应用最终的 reg_dcdl 数据

reg_file = fullfile(bin_dir, 'reg_cal1.txt');
fid_reg = fopen(reg_file, 'r');

if fid_reg < 0
    error('Cannot open reg_cal1.txt: %s', reg_file);
end

os_coeffs   = zeros(32, 1);
gain_coeffs = zeros(32, 1);

for ch = 2:32
    line_os = fscanf(fid_reg, '%s', 1);
    line_gain = fscanf(fid_reg, '%s', 1);

    if isempty(line_os)
        fclose(fid_reg);
        error('reg_cal1.txt missing OS coefficient for ch%d.', ch);
    end

    if isempty(line_gain)
        fclose(fid_reg);
        error('reg_cal1.txt missing Gain coefficient for ch%d.', ch);
    end

    if length(line_os) ~= 17 || any(line_os ~= '0' & line_os ~= '1')
        fclose(fid_reg);
        error('Invalid OS coefficient for ch%d: "%s". Expected 17 binary bits.', ch, line_os);
    end

    if length(line_gain) ~= 12 || any(line_gain ~= '0' & line_gain ~= '1')
        fclose(fid_reg);
        error('Invalid Gain coefficient for ch%d: "%s". Expected 12 binary bits.', ch, line_gain);
    end

    os_coeffs(ch) = bin2signed_decimal(line_os, 9);
    gain_coeffs(ch) = bin2signed_decimal(line_gain, 11);
end

extra_token = fscanf(fid_reg, '%s', 1);
fclose(fid_reg);

if ~isempty(extra_token)
    warning('reg_cal1.txt contains extra data after ch32: "%s"', extra_token);
end


[d_raw_final, ~] = adc.quantification(t_test, sig_test);  % 产生最终校准的测试数据


d_mat = reshape(d_raw_final, 32, []);
d_corrected_mat = zeros(size(d_mat));
for ch = 1:32
    d_base_raw = d_mat(ch, :) - adc.code_center;
    d_corrected_mat(ch, :) = (d_base_raw - os_coeffs(ch)) .* (1 - gain_coeffs(ch));
end
d_raw_cal2 = d_corrected_mat(:); 

%% FFT 测试、绘制结果

full_scale_amp  = estimate_full_scale_amp(adc, N_sram, M_test, f_test);

result_non      = test_performace(adc, N_sram, f_test, d_raw_none, full_scale_amp);
result_cal1     = test_performace(adc, N_sram, f_test, d_raw_cal1, full_scale_amp);
result_cal2     = test_performace(adc, N_sram, f_test, d_raw_cal2, full_scale_amp);

plot_all(result_non, result_cal1, result_cal2, dcdl_trace');


%% 辅助函数定义

% 相干采样频率产生
function result = test_performace(obj, N_sram, f_sig, d_raw, full_scale_amp)
    M = round(f_sig / obj.fs * N_sram);
    if mod(M,2) == 0
        M = M + 1;
    end
    fin = M / N_sram * obj.fs;
    d = d_raw - mean(d_raw);
    X = fft(d, N_sram);  

    X = X(1 : N_sram / 2 + 1);

    mag = abs(X);
    mag = mag / N_sram;
    mag(2: end - 1) = 2 * mag(2 : end - 1);
    spec_db = 20 * log10(mag + eps);
    spec_db = spec_db - max(spec_db);

    P = abs(X).^2;
    idx_sig = M + 1;
    span = 0;
    idx_range = max(idx_sig - span, 1) : min(idx_sig + span, N_sram / 2 + 1);
    P_signal = sum(P(idx_range));

    P_spur = P;
    P_spur(1) = 0; 
    P_spur(idx_range) = 0;
    P_spur_max = max(P_spur);

    if P_spur_max < eps
        SFDR = 100;
    else
        SFDR = 10 * log10(P_signal / P_spur_max);
    end
    mask_signal = false(size(P));
    mask_signal(idx_range) = true;
    P_harm = 0;

    for k = 2 : 10   % calculate the 2 to 10 harmonics
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
    P_total = sum(P(2 : end));
    P_noise = P_total - P_signal - P_harm;
    if P_noise < eps
        P_noise = eps;
    end

    SNDR = 10 * log10(P_signal / (P_noise + P_harm));
    SNR = 10 * log10(P_signal / P_noise);
    THD = 10 * log10(P_harm / P_signal);
    ENOB = (SNDR-1.76) / 6.02;

    actual_amp = 2 * sqrt(P_signal) / N_sram;
    full_scale = full_scale_amp;

    if actual_amp > 0 && full_scale > 0
        backoff = 20 * log10(full_scale / actual_amp);
    else
        backoff = 0;
    end


    SNDR_FS = SNDR + backoff;
    ENOB_FS = (SNDR_FS - 1.76) / 6.02;

    result.freq = linspace(0, obj.fs / 2, N_sram / 2 + 1);   % x 
    result.spec_db = spec_db;   % y
    result.SNDR = SNDR;
    result.SNDR_FS = SNDR_FS;
    result.SNR = SNR;
    result.THD = THD;
    result.SFDR = SFDR;
    result.ENOB = ENOB;
    result.ENOB_FS = ENOB_FS;
    result.backoff = backoff;
    result.fin = fin;
end

function full_scale_amp = estimate_full_scale_amp(adc, N_sram, M, fin)
    t = (0: N_sram - 1) / adc.fs;

    cap_pt = adc.cap_arr_pt(1, :);
    cap_pb = adc.cap_arr_pb(1, :);
    cap_nt = adc.cap_arr_nt(1, :);
    cap_nb = adc.cap_arr_nb(1, :);

    c_tot_p = sum(cap_pt) + sum(cap_pb) + 2 * adc.cp_top;
    c_tot_n = sum(cap_nt) + sum(cap_nb) + 2 * adc.cp_top;

    amp_fs = adc.Vref * (sum(cap_pt) / c_tot_p + sum(cap_nt) / c_tot_n);

    signal_fs = @(t) amp_fs * sin(2 * pi * fin * t);
    [d_fs, ~] = adc.quantification(t, signal_fs);
    d_fs = d_fs - adc.code_center;

    d = d_fs - mean(d_fs);
    X = fft(d, N_sram);
    X = X(1: N_sram / 2 + 1);

    idx_sig = M + 1;
    P_signal = abs(X(idx_sig)).^2;

    full_scale_amp = 2 * sqrt(P_signal) / N_sram;
end


function [f_coh, M] = get_coherent_freq(f_target, fs, N)
    M = round(f_target / fs * N);
    if mod(M, 2) == 0
        M = M + 1; 
    end
    f_coh = M / N * fs;
end



function val = bin2signed_decimal(bin_str, frac_bits)
    
    total_bits = length(bin_str);
    v = bin2dec(bin_str);
    if bin_str(1) == '1'
        v = v - 2^total_bits;
    end
    val = v / (2^frac_bits);
end

function plot_all(result_none, result_cal1, result_cal2, dcdl_matric)
    figure('Name', 'FFT Spectrum', 'NumberTitle', 'off', ...
        'Position', [200 100 1000 900], 'Color', 'w');
    % plot the spectrum without calibration
    ax1 = subplot(3,1,1);
    plot_spectrum(ax1, result_none, 'FFT Spectrum Without Calib.');
    % plot the spectrum with os/gain calibration
    ax2 = subplot(3,1,2);
    plot_spectrum(ax2, result_cal1, 'FFT Spectrum With OS/Gain Calib.');
    % plot the spectrum with os/gain/skew calibration
    ax3 = subplot(3,1,3);
    plot_spectrum(ax3, result_cal2, 'FFT Spectrum With OS/Gain/Skew Calib.');

    figure('Name', 'Convergence Process of Skew Calibration', ...
        'NumberTitle', 'off', 'Position', [200 100 1000 420], 'Color', 'w');
    ax_trace = subplot(1,1,1);
    plot_skew_trace(ax_trace, dcdl_matric, ...
        'Skew Calibration Register Convergence Trace', 'Skew Register Value');
end


function plot_spectrum(ax, result, string_title)
    axes(ax);   
    plot(result.freq / 1e9, result.spec_db, '-*', ...
        'Color', [0.2000 0.4500 0.8000], ...
        'LineWidth', 0.75, ...
        'MarkerSize', 2, ...
        'MarkerEdgeColor', [0.2000 0.4500 0.8000]);
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
        'SFDR = %.2f dBc @ %.2f dBFS'],...
        result.fin / 1e9,...
        -1*result.backoff,...
        result.ENOB,...
        result.ENOB_FS,...
        result.SNDR,...
        -1*result.backoff,...
        result.SNDR_FS,...
        result.SFDR,...
        -1*result.backoff);
    text(0.02, 0.97, info_str, ...
        'Units', 'normalized', ...
        'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', ...
        'FontName', 'Arial', ...
        'FontSize', 6, ...
        'Color', 'k', ...
        'BackgroundColor', 'none', ...
        'Clipping', 'on');
    apply_axes_style(ax, 'fft');
end


function plot_skew_trace(ax, M_trace, string_title, string_y)
    axes(ax);
    colors = thesis_palette(5);
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
    lgd = legend(labels, 'Location', 'northoutside', ...
        'Orientation', 'horizontal');
    apply_legend_style(lgd);
    apply_axes_style(ax, 'trace');
end

function apply_axes_style(ax, style_name)
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
            set(ax, 'GridAlpha', 0.25);
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

function apply_legend_style(lgd)
    set(lgd, ...
        'Color', 'none', ...
        'TextColor', 'k', ...
        'FontName', 'Arial', ...
        'FontSize', 13, ...
        'Box', 'off');
end

function colors = thesis_palette(n)
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
