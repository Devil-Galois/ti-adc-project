%% FFT 测试 RTL 级前台校准

clc; clear;

% 路径导入
script_dir = fileparts(mfilename('fullpath'));
verilog_dir = fullfile(script_dir, '..');
bin_dir = fullfile(verilog_dir, 'bin');
build_dir = fullfile(verilog_dir, 'build');

% 基本参数，与 calib_fore_bin_gen.m 保持一致
N_sram = 2^16;          
fs = 28e9;
f_test = 509 * fs / 1024;
M = round(f_test / fs * N_sram);
if mod(M, 2) == 0, M = M + 1; end


%% 原始数据 FFT

fin_coherent = (M / N_sram) * fs;
weights = [64, 32, 16, 8, 8, 4, 2, 1]; 
code_center = sum(weights) / 2;

% 原始测试数据
filename = fullfile(bin_dir, 'origin_test_data_8bits.txt');

% 读取 ADC 满摆幅
full_scale_amp = load(fullfile(bin_dir, 'fullscale_reference.txt'));

fprintf('正在读取原始测试数据前 %d 行...\n', N_sram);
fid = fopen(filename, 'r');
if fid == -1, error('找不到文件，请检查路径！'); end

data_cell = textscan(fid, '%s', N_sram);
fclose(fid);
char_mat = char(data_cell{1}); 

numeric_mat = char_mat - '0'; 

d_raw = double(numeric_mat) * weights';

fprintf('正在进行FFT分析...\n');
d_raw = d_raw - code_center;

d = d_raw - mean(d_raw);

X = fft(d, N_sram);
X = X(1 : N_sram / 2 + 1);
mag = abs(X);
mag = mag / N_sram;
mag(2 : end - 1) = 2 * mag(2 : end - 1);
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
for k = 2 : 10 
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


SNDR = 10* log10(P_signal/(P_noise+P_harm));
SNR = 10*log10(P_signal/P_noise);
THD = 10*log10(P_harm/P_signal);
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


result.freq = linspace(0, fs / 2, N_sram / 2 + 1);   % x 
result.spec_db = spec_db;   % y
result.SNDR_FS = SNDR_FS;
result.SNR = SNR;
result.THD = THD;
result.SFDR = SFDR;
result.ENOB = ENOB;
result.ENOB_FS = ENOB_FS;
result.backoff = backoff;
result.fin = fin_coherent;

figure('Position',[200 100 900 700]);
subplot(2,1,1);

plot(result.freq / 1e9, result.spec_db, '-*', 'MarkerSize', 2);
xlabel('Frequency (GHz)');
ylabel('Magnitude (dB)');
title('FFT Spectrum');

ylim([-100, 0]);
grid on;

info_str = sprintf([...
    'Input signal frequency is %.4f GHz\n'...
    'Input signal amplitude is %.2f dBFS\n'...
    'ENOB = %.2f bits\n'...
    'ENOB@FS = %.2f bits\n'...
    'SNDR@FS = %.2f dB\n'...
    'SNR = %.2f dB @ %.2f dBFS\n'...
    'SFDR = %.2f dBc @ %.2f dBFS'],...
    result.fin/1e9,...
    -1*result.backoff,...
    result.ENOB,...
    result.ENOB_FS,...
    result.SNDR_FS,...
    result.SNR,...
    -1*result.backoff,...
    result.SFDR,...
    -1*result.backoff);
text(0.02, 0.97, info_str, ...
    'Units','normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 6, 'BackgroundColor', 'none');


%% 校准数据 FFT

data_vector = load(fullfile(bin_dir, 'calib_test_data_dec.txt'));
d = data_vector - mean(data_vector);

X = fft(d, N_sram);  
X = X(1 : N_sram / 2 + 1);
mag = abs(X);
mag = mag / N_sram;
mag(2 : end - 1) = 2 * mag(2 : end - 1);
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
for k = 2:10
    h = mod(k * M, N_sram);
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

ENOB = (SNDR - 1.76) / 6.02;

actual_amp = 2 * sqrt(P_signal) / N_sram;
full_scale = full_scale_amp;

if actual_amp > 0 && full_scale > 0
    backoff = 20 * log10(full_scale / actual_amp);
else
    backoff = 0;
end

SNDR_FS = SNDR + backoff;
ENOB_FS = (SNDR_FS - 1.76) / 6.02;
result.freq = linspace(0, fs / 2, N_sram / 2 + 1);   
result.spec_db = spec_db;   % y
result.SNDR_FS = SNDR_FS;
result.SNR = SNR;
result.THD = THD;
result.SFDR = SFDR;
result.ENOB = ENOB;
result.ENOB_FS = ENOB_FS;
result.backoff = backoff;
result.fin = fin_coherent;

subplot(2,1,2);

plot(result.freq / 1e9, result.spec_db, '-*', 'MarkerSize', 2);
xlabel('Frequency (GHz)');
ylabel('Magnitude (dB)');
title('ADC Data Spectrum');

ylim([-100, 0]);
grid on;
info_str = sprintf([...
    'Input signal frequency is %.4f GHz\n'...
    'Input signal amplitude is %.2f dBFS\n'...
    'ENOB = %.2f bits\n'...
    'ENOB@FS = %.2f bits\n'...
    'SNDR@FS = %.2f dB\n'...
    'SNR = %.2f dB @ %.2f dBFS\n'...
    'SFDR = %.2f dBc @ %.2f dBFS'],...
    result.fin/1e9,...
    -1*result.backoff,...
    result.ENOB,...
    result.ENOB_FS,...
    result.SNDR_FS,...
    result.SNR,...
    -1*result.backoff,...
    result.SFDR,...
    -1*result.backoff);
text(0.02, 0.97, info_str, ...
    'Units','normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 6, 'BackgroundColor', 'none');