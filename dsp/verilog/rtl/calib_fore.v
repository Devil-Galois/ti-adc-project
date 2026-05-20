`timescale 1ns/1ps
module calib_fore #(
    // parameter for global
    parameter DATA_INT          = 8,
    parameter DATA_FRAC         = 8,
    // parameter for iir
    parameter MEAN_INT          = 8,
    parameter MEAN_FRAC         = 9,
    // parameter for select signal
    parameter MU_SEL_W          = 2,
    // parameter for lms core
    parameter REG_OS_INT        = 8,
    parameter REG_OS_FRAC       = 12,
    parameter REG_GAIN_INT      = 1,
    parameter REG_GAIN_FRAC     = 16,
    parameter LMS_OS_INT        = 8,
    parameter LMS_OS_FRAC       = 9,
    parameter LMS_GAIN_INT      = 1,
    parameter LMS_GAIN_FRAC     = 11,
    // parameter for iir 
    parameter ACC_INT           = 8,    // the width of integer part of acc
    parameter ACC_FRAC          = 16,   // the width of fractional part of acc
    parameter ALPHA_W           = 2,
    // global parameter
    parameter N_CH              = 32,
    parameter DOUT_INT          = 8,
    parameter DOUT_FRAC         = 8
)(  
    input   wire                        clk,
    input   wire                        rst_n,
    // new signal to enable the calibration
    input   wire                        cal_en,   

    input   wire    [N_CH*DATA_INT-1:0] din_bus,     // unsigned input from sram controller
    input   wire    [ALPHA_W-1:0]       alpha_sel,   // select iir speed tau = 1/alpha
    input   wire    [MU_SEL_W-1:0]      mu_os_sel,   // select lms step of os calib.
    input   wire    [MU_SEL_W-1:0]      mu_gain_sel, // select lms step of gain calib.

    output  wire    [N_CH*(DOUT_INT+DOUT_FRAC)-1:0] dout_bus    // unsigned format output but with sign bits  
);

    wire    signed  [DATA_INT+DATA_FRAC-1:0]    ch_signed_data  [0:N_CH-1];   // data  signed
    wire    signed  [DOUT_INT+DOUT_FRAC-1:0]    ch_cal_data     [0:N_CH-1];   // data after calibration 8+8bits

    // average data from iir filter
    wire    signed  [MEAN_INT+MEAN_FRAC-1:0]    ch_mean_os     [0:N_CH-1];
    wire    signed  [MEAN_INT+MEAN_FRAC-1:0]    ch_mean_gain   [0:N_CH-1];

    // unpacking and calib.
    genvar i;
    generate
        for (i = 0; i < N_CH; i = i + 1)begin: calib_fore  // for all channels
            // decoder and encoder
            // original to signed
            d2signed #(
                .INT_W(DATA_INT),
                .FRAC_W(DATA_FRAC)
            ) u_d2signed(
                .d_in(din_bus[i*DATA_INT +: DATA_INT]),   // unsigned input data   ch0:0-7 ch1:8-15....etc
                .d_signed(ch_signed_data[i])                // signed output data 8+8bits fixed points
            );      

            if (i == 0) begin: ch0_refer
                // no calib for ch0
                assign ch_cal_data[0] = ch_signed_data[0];
                // iir for ch0 as reference
                iir_core #(
                    .DATA_INT(DATA_INT),   // int8
                    .DATA_FRAC(DATA_FRAC), // frac8
                    .ACC_INT(ACC_INT),      // int 8
                    .ACC_FRAC(ACC_FRAC),  // frac 16   (shift = 10 11 12 13)
                    .MEAN_INT(MEAN_INT),    // int8
                    .MEAN_FRAC(MEAN_FRAC),  // frac9
                    .ALPHA_W(ALPHA_W)
                ) iir_ch0(
                    .clk(clk),
                    .rst_n(rst_n),
                    .d_cal(ch_cal_data[0]),     // 8+8  signed
                    .alpha_sel(alpha_sel),  // 2bits
                    .average_os(ch_mean_os[0]), // 8+9      signed
                    .average_gain(ch_mean_gain[0]),  // 8+9 signed
                    .cal_en(cal_en)
                );
                // no lms for ch0
            end
            else begin: ch_calib   // ch1 to ch31 aligen to ch0 
                wire    [LMS_OS_INT+LMS_OS_FRAC-1:0]        lms_os_val;  // lms data for calib   8+9
                wire    [LMS_GAIN_INT+LMS_GAIN_FRAC-1:0]    lms_gain_val;// lms data for calib   1+11
                // calib for ch1 to ch31
                correct #(
                    .DATA_INT(DATA_INT),// int8
                    .DATA_FRAC(DATA_FRAC),// frac8
                    .LMS_OS_INT(LMS_OS_INT),// int8
                    .LMS_OS_FRAC(LMS_OS_FRAC),// frac9
                    .LMS_GAIN_INT(LMS_GAIN_INT),// int1
                    .LMS_GAIN_FRAC(LMS_GAIN_FRAC)// frac11
                ) correct_chn(
                    .d_signed(ch_signed_data[i]),  // 8+8 signed data
                    .lms_os(lms_os_val),        // 8+9 lms for calib
                    .lms_gain(lms_gain_val),    // 1+11 lms for calib
                    .d_cal(ch_cal_data[i])      // data after calibration
                );
                // iir for ch1 to ch31
                iir_core #(
                    .DATA_INT(DATA_INT),  // int8
                    .DATA_FRAC(DATA_FRAC),// frac8
                    .ACC_INT(ACC_INT),      // int8
                    .ACC_FRAC(ACC_FRAC),    // frac16
                    .MEAN_INT(MEAN_INT),    // int8
                    .MEAN_FRAC(MEAN_FRAC), // frac9
                    .ALPHA_W(ALPHA_W)       // sel int 2
                ) iir_chn(
                    .clk(clk),          
                    .rst_n(rst_n),
                    .d_cal(ch_cal_data[i]), // 8+8 signed 
                    .alpha_sel(alpha_sel),
                    .average_os(ch_mean_os[i]), // 8+9 signed 
                    .average_gain(ch_mean_gain[i]),  // 8+9 signed
                    .cal_en(cal_en) 
                );
                // lms core to calculate lms_os and lms_gain
                lms_core #(
                    .MEAN_INT(MEAN_INT),  // int8
                    .MEAN_FRAC(MEAN_FRAC),// frac9
                    .MU_SEL_W(MU_SEL_W), // sel int2
                    .REG_OS_INT(REG_OS_INT),  // int8
                    .REG_OS_FRAC(REG_OS_FRAC), // frac12
                    .REG_GAIN_INT(REG_GAIN_INT), // int1
                    .REG_GAIN_FRAC(REG_GAIN_FRAC), // frac16
                    .LMS_OS_INT(LMS_OS_INT),   // int8
                    .LMS_OS_FRAC(LMS_OS_FRAC), // frac9
                    .LMS_GAIN_INT(LMS_GAIN_INT),  // int1
                    .LMS_GAIN_FRAC(LMS_GAIN_FRAC) // frac11
                ) lms_chn(
                    .clk(clk),
                    .rst_n(rst_n),
                    .mean_os_chn(ch_mean_os[i]),  // 8+9
                    .mean_os_ch0(ch_mean_os[0]), // 8+9
                    .mean_gain_chn(ch_mean_gain[i]), // 8+9
                    .mean_gain_ch0(ch_mean_gain[0]), // 8+9
                    .mu_os_sel(mu_os_sel), // 2
                    .mu_gain_sel(mu_gain_sel),// 2
                    .lms_os(lms_os_val),   // 8+9 
                    .lms_gain(lms_gain_val), // 1+11
                    .cal_en(cal_en)
                );
            end

            // packed  to output
            assign dout_bus[i*(DOUT_INT+DOUT_FRAC) +: DOUT_INT+DOUT_FRAC] = ch_cal_data[i];

        end
    endgenerate

endmodule