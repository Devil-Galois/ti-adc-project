module lms_core #( 
    parameter MEAN_INT          = 8,
    parameter MEAN_FRAC         = 9,    // 9bits
    parameter MU_SEL_W          = 2,
    parameter REG_OS_INT        = 8,
    parameter REG_OS_FRAC       = 12,
    parameter REG_GAIN_INT      = 1,
    parameter REG_GAIN_FRAC     = 16,
    parameter LMS_OS_INT        = 8,
    parameter LMS_OS_FRAC       = 9,
    parameter LMS_GAIN_INT      = 1,
    parameter LMS_GAIN_FRAC     = 11
)(
    input   wire                                            clk,
    input   wire                                            rst_n,
    // !======new signal======!
    input   wire                                            cal_en,

    // !======================!
    input   wire    signed  [MEAN_INT+MEAN_FRAC-1:0]        mean_os_chn,
    input   wire    signed  [MEAN_INT+MEAN_FRAC-1:0]        mean_os_ch0,
    input   wire    signed  [MEAN_INT+MEAN_FRAC-1:0]        mean_gain_chn,
    input   wire    signed  [MEAN_INT+MEAN_FRAC-1:0]        mean_gain_ch0,
    input   wire            [MU_SEL_W-1:0]                  mu_os_sel,
    input   wire            [MU_SEL_W-1:0]                  mu_gain_sel,
    
    output  reg     signed  [LMS_OS_INT+LMS_OS_FRAC-1:0]    lms_os,
    output  reg     signed  [LMS_GAIN_INT+LMS_GAIN_FRAC-1:0]lms_gain
);

    localparam  MEAN_W      =   MEAN_INT    +   MEAN_FRAC;      // 8+9
    localparam  REG_OS_W    =   REG_OS_INT  +   REG_OS_FRAC;    // 8+12
    localparam  REG_GAIN_W  =   REG_GAIN_INT+   REG_GAIN_FRAC;  // 1+16
    localparam  LMS_OS_W    =   LMS_OS_INT  +   LMS_OS_FRAC;    // 8+9
    localparam  LMS_GAIN_W  =   LMS_GAIN_INT+   LMS_GAIN_FRAC;  // 1+11

    wire        signed  [MEAN_W-1:0]    delta_os;   // 8+9
    wire        signed  [MEAN_W-1:0]    delta_gain; // 8+9

    assign  delta_os    =   mean_os_chn     -   mean_os_ch0;
    assign  delta_gain  =   mean_gain_chn   -   mean_gain_ch0;
    

    function    signed  [REG_OS_W-1:0]  mu_os_shift;   // 20bits
        input   signed  [REG_OS_W-1:0]  delta_os_in; 
        input           [MU_SEL_W-1:0]  sel_os_in;
        begin
            case (sel_os_in)
                2'b00:      mu_os_shift = delta_os_in >>> 7;
                2'b01:      mu_os_shift = delta_os_in >>> 8;
                2'b10:      mu_os_shift = delta_os_in >>> 9;
                2'b11:      mu_os_shift = delta_os_in >>> 10;
                default:    mu_os_shift = delta_os_in >>> 8;
            endcase
        end
    endfunction

    function    signed  [MEAN_INT+REG_GAIN_FRAC-1:0]    mu_gain_shift; // 8+16bits = 24bits
        input   signed  [MEAN_INT+REG_GAIN_FRAC-1:0]    delta_gain_in;
        input           [MU_SEL_W-1:0]                  sel_gain_in;
        begin
            case (sel_gain_in)
                2'b00:      mu_gain_shift = delta_gain_in >>> 12;
                2'b01:      mu_gain_shift = delta_gain_in >>> 13;
                2'b10:      mu_gain_shift = delta_gain_in >>> 14;
                2'b11:      mu_gain_shift = delta_gain_in >>> 15;
                default:    mu_gain_shift = delta_gain_in >>> 14;
            endcase
        end
    endfunction

    wire    signed [REG_OS_W-1:0]   mu_x_delta_os   = mu_os_shift({delta_os,{3'b0}},   mu_os_sel);  // 17---8+12bits
    wire    signed [MEAN_INT+REG_GAIN_FRAC-1:0] temp = mu_gain_shift({delta_gain,{7'b0}},    mu_gain_sel);// 17----8+16bits
    wire    signed [REG_GAIN_W-1:0] mu_x_delta_gain = temp[REG_GAIN_W-1:0];         // 1+16bits  截断低位


    reg     signed [REG_OS_W-1:0]   reg_os_cal;                 // 8+12bits
    reg     signed [REG_GAIN_W-1:0] reg_gain_cal;               // 1+16bits

    wire    signed [REG_OS_W-1:0]       next_os_cal     = mu_x_delta_os + reg_os_cal;
    wire    signed [REG_GAIN_W-1:0]     next_gain_cal   = mu_x_delta_gain + reg_gain_cal;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            reg_os_cal      <= {REG_OS_W{1'b0}};
            reg_gain_cal    <= {REG_GAIN_W{1'b0}};
            lms_os          <= {LMS_OS_W{1'b0}};
            lms_gain        <= {LMS_GAIN_W{1'b0}};
        end
        else if(cal_en) begin
            reg_os_cal      <= next_os_cal;
            reg_gain_cal    <= next_gain_cal;
            lms_os          <= next_os_cal[REG_OS_W-1:REG_OS_FRAC-LMS_OS_FRAC]; //
            lms_gain        <= next_gain_cal[REG_GAIN_W-1:REG_GAIN_FRAC-LMS_GAIN_FRAC];
        end
    end

endmodule