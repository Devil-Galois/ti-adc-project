/*
 * File: iir_core.v
 * Description: IIR filter core module for SAR ADC calibration (OS and Gain).
 * 指数平滑操作 EMA
 * version 1.0 by Li Jiahui, 2026-3-30
*/
module iir_core #(
    parameter DATA_INT          = 8,    // the width of integerity of input data including 1bits sign
    parameter DATA_FRAC         = 8,    // the width of fraction of input data
    parameter ACC_INT           = 8,    // the width of integer part of acc
    parameter ACC_FRAC          = 16,   // the width of fractional part of acc
    parameter MEAN_INT          = 8,    // the width of integerity of output data
    parameter MEAN_FRAC         = 9,    // the width of fractional part of output data
    parameter ALPHA_W           = 2     // width of alpha_sel, determines the number of alpha values that can be selected
)(
    input   wire                                                clk,
    input   wire                                                rst_n,
    // enable signal  new   !========!
    input   wire                                                cal_en,

    input   wire    signed  [DATA_INT+DATA_FRAC-1:0]            d_cal,              // data after calib.
    input   wire            [ALPHA_W-1:0]                       alpha_sel,

    output  reg     signed  [MEAN_INT+MEAN_FRAC-1:0]            average_os,
    output  reg     signed  [MEAN_INT+MEAN_FRAC-1:0]            average_gain
);

    localparam  ACC_W   =   ACC_INT     +   ACC_FRAC;                               // 24bits
    localparam  MEAN_W  =   MEAN_INT    +   MEAN_FRAC;                              // 17bits
    localparam  DATA_W  =   DATA_INT    +   DATA_FRAC;                              // 16bits

    wire        signed [ACC_W-1:0]  d_fp;
    wire        signed [ACC_W-1:0]  d_abs_fp;

    assign      d_fp        =   {d_cal,{(ACC_W-DATA_W){1'b0}}};    // expand the input data  to 16bits
    assign      d_abs_fp    =   d_cal[DATA_W-1] ? -d_fp : d_fp;

    function    signed          [ACC_W-1:0]         do_shift;
        input   signed          [ACC_W-1:0]         din;
        input                   [ALPHA_W-1:0]       sel;
        begin
            case (sel)
                2'b00:  do_shift = din >>> 10;
                2'b01:  do_shift = din >>> 11;
                2'b10:  do_shift = din >>> 12;
                2'b11:  do_shift = din >>> 13;
                default:do_shift = din >>> 12;
            endcase
        end
    endfunction

    reg     signed [ACC_W-1:0] acc_r;
    reg     signed [ACC_W-1:0] acc_abs_r;

    wire    signed [ACC_W-1:0] alpha_x_d    = do_shift(d_fp,    alpha_sel);
    wire    signed [ACC_W-1:0] alpha_x_acc  = do_shift(acc_r,   alpha_sel);
    wire    signed [ACC_W-1:0] next_acc     = acc_r - alpha_x_acc + alpha_x_d;

    wire    signed [ACC_W-1:0] alpha_x_d_abs    = do_shift(d_abs_fp,  alpha_sel);
    wire    signed [ACC_W-1:0] alpha_x_acc_abs  = do_shift(acc_abs_r, alpha_sel);
    wire    signed [ACC_W-1:0] next_acc_abs     = acc_abs_r - alpha_x_acc_abs + alpha_x_d_abs;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            acc_r           <= {ACC_W{1'b0}};
            acc_abs_r       <= {ACC_W{1'b0}};
            average_os      <= {MEAN_W{1'b0}};
            average_gain    <= {MEAN_W{1'b0}};
        end 
        else if(cal_en)begin                // refresh only cal_en is high
            acc_r           <= next_acc;
            acc_abs_r       <= next_acc_abs;
            average_os      <= next_acc[ACC_W-1:ACC_FRAC-MEAN_FRAC];        // [23:8]
            average_gain    <= next_acc_abs[ACC_W-1:ACC_FRAC-MEAN_FRAC];    // [23:8]
        end
    end

endmodule