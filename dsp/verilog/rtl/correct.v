/* 
* module name: correct.v
* function: 用于使用reg_os_cal和reg_gain_cal的数据完成原始数据的修正操作
* 由于原始数据8+8范围为-67.5 to 67.5 所以距离可以表示的满摆幅范围-128~128-2^(-8)差距很大
* 在操作 d_base = d_signed - lms_os 和操作 d_cal = d_base - temp[15:0]中均不会超出范围
* 注意在temp中bits16和bits15都是符号位
*/
module correct #(
    parameter   DATA_INT            = 8,
    parameter   DATA_FRAC           = 8,
    parameter   LMS_OS_INT          = 8,
    parameter   LMS_OS_FRAC         = 9,
    parameter   LMS_GAIN_INT        = 1,
    parameter   LMS_GAIN_FRAC       = 11
)(
    input   wire    signed [DATA_INT+DATA_FRAC-1:0]         d_signed,       // 8+8
    input   wire    signed [LMS_OS_INT+LMS_OS_FRAC-1:0]     lms_os,         // 8+9
    input   wire    signed [LMS_GAIN_INT+LMS_GAIN_FRAC-1:0] lms_gain,       // 1+11
    output  wire    signed [DATA_INT+DATA_FRAC-1:0]         d_cal           // 8+8
);

    localparam  MUL_WIDTH           = DATA_INT+DATA_FRAC+1+LMS_GAIN_INT+LMS_GAIN_FRAC;   // 29bits
    localparam  KEEP_FRAC           = DATA_FRAC + 1;                                   // 9bits fraction
    localparam  SUB_WIDTH           = DATA_INT+KEEP_FRAC;                              // 8+9bits

    // offset calibration
    wire    signed  [SUB_WIDTH-1:0]    d_base = {d_signed,1'b0} - lms_os; // 8+9 bits
    // gain error calculation
    wire    signed  [MUL_WIDTH-1:0]    d_base_x_gain_err = d_base * lms_gain;  // 17 * 12bits = 29bits

    wire    signed  [SUB_WIDTH-1:0]             gain_err_ext;   // 8+9bits
    assign  gain_err_ext  = d_base_x_gain_err[MUL_WIDTH-2:LMS_OS_FRAC+LMS_GAIN_FRAC-KEEP_FRAC];

    wire    signed  [SUB_WIDTH-1:0]     diff_ext = d_base - gain_err_ext;  // 8+9bits

    // round
    wire    signed  [SUB_WIDTH-1:0]     sign_ext = diff_ext >>> (SUB_WIDTH-1);
    wire    signed  [SUB_WIDTH-1:0]     round_os = 1'b1 + sign_ext;
    wire    signed  [SUB_WIDTH-1:0]     diff_rounded = (diff_ext + round_os) >>> 1;

    assign  d_cal = diff_rounded[DATA_INT+DATA_FRAC-1:0];
endmodule