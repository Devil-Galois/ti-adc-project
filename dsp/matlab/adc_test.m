clear;
clc;
close all;

try
    adc = adc_model();
    fprintf('======== Create ADC Successfully! ========\n');
catch ME
    error('ADC Initial Failed\nMessage: %s', ME.message);
end

% ADC 参数配置
adc.cof_gain        = 0.05; % 5% gain mismatch
adc.cof_offset      = 0.007; % sigma = 7 mV offset mismatch 
adc.cof_skew        = 3.4e-12; % -3.4-3.4 ps

% ========================================================================
% ADC calibration test based on adc_model.m
%
% N_delay_os_gain : 61
% mu_os           : 2^-8
% mu_gain         : 2^-14
% f_cal_os_gain   : 9*(28e9)/1024
% amp_cal_os_gain : 0.260
% N_iter_os_gain  : 32
% N_sram          : 2^16
% Nexp_os_gain    : 2^12
% N_delay_skew    : 131
% dcdl_step_set   : 50e-15
% fin_cal_skew    : 409*(28e9)/1024
% amp_cal_skew    : 0.260
% N_iter_skew     : 128
% f_test          : 409*(28e9)/1024
% N_mc            : 100
% ========================================================================

N_delay_os_gain     = 61;
mu_os               = 2^-8;
mu_gain             = 2^-14;
f_cal_os_gain       = 9 * adc.fs / 1024;
amp_cal_os_gain     = 0.260;
N_iter_os_gain      = 32;
N_sram              = 2^16;
Nexp_os_gain        = 2^12;

N_delay_skew        = 131;
dcdl_step_set       = 50e-15;
fin_cal_skew        = 409 * adc.fs / 1024;
amp_cal_skew        = 0.260;
N_iter_skew         = 128;

f_test = 409 * adc.fs / 1024;
N_mc = 1;

assert(mod(N_sram, adc.N_ch) == 0, 'N_sram must be divisible by N_ch.');
assert(mod(N_sram, adc.N_phase) == 0, 'N_sram must be divisible by N_phase.');

% 运行全部校准仿真
adc.calib_run( ...
    N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain, ...
    amp_cal_os_gain, N_iter_os_gain, N_sram, Nexp_os_gain, ...
    N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew, ...
    f_test, N_mc);


% Optional: 测试后台 Skew 校准跟踪能力
% adc.calib_skew_track( ...
%     N_delay_os_gain, mu_os, mu_gain, f_cal_os_gain, ...
%     amp_cal_os_gain, N_iter_os_gain, N_sram, Nexp_os_gain, ...
%     N_delay_skew, dcdl_step_set, fin_cal_skew, amp_cal_skew, N_iter_skew, ...
%     f_test);

fprintf('======== All end! ========\n');
