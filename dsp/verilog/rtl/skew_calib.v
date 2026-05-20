/*
 * File: skew_calib.v
 * Description: Background Skew Calibration Module for TI-ADC.
 *              Implements MAD algorithm and DCDL update logic.
 *              Matches MATLAB function: calib_skew_lms
 *              SPI controller removed, output done + skew_sign instead.
 * Version: 1.0 by Lijiahui, 2026-3-30
 * Input: 32-channel signed data (packed as unsigned bus) from calib_fore.
 * Output: done pulse and 3-bit skew direction signs.
 */
module skew_calib #(
    parameter   DIN_INT         = 8,       // width of integerity of data after os/gain calib. 
    parameter   DIN_FRAC        = 8,       // width of fraction of data after os/gain calib.
    parameter   DATA_INT        = 8,       // int8
    parameter   DATA_FRAC       = 6,       // cut down

    parameter   POINTS_W        = 14,      // 2^14 per phase
    parameter   N_CYCLE         = 11,      // 2^16/2^5 = 2^11 = 2048 cycles

    parameter   ACC_W           = 32,      // 8(integer)+6(fraction)+14(65536/4)=28 for per phase 

    parameter   N_CH            = 32,      // number of channels
    parameter   N_PHA           = 4        // number of phases
) (
    input   wire                                        clk,
    input   wire                                        rst_n,
    input   wire                                        skew_cal_en,        // start skew calibration interaction
    input   wire    [N_CH*(DIN_INT+DIN_FRAC)-1:0]       din_bus,            // unsigned data with sign bit input from the module of gain and os calib.

    output  reg                                         done,               // skew calibrationo is done                          
    output  reg     [N_PHA-2:0]                         skew_sign           // phase1-3 skew detection  (1=lag,0=lead)
);

    localparam  DIN_W               = DIN_INT   + DIN_FRAC;     // width of input data from bus
    localparam  DATA_W              = DATA_INT  + DATA_FRAC;    // width of data used for calculation
    localparam  CLK_CNT_MAX         = 1 << N_CYCLE;             // cnt max value
    localparam  AVG_W               = ACC_W - POINTS_W + 2 + 3; // ACC_W-POINTS_W: average   +2: x4  +2: for calculate delta_rr

    wire    signed  [DIN_W-1:0]     ch_data_full    [0:N_CH-1]; // 8+8 bits signed
    wire    signed  [DATA_W-1:0]    ch_data         [0:N_CH-1]; // 8+6 bits signed

    // unpack data and cut down
    genvar i;
    generate
        for (i = 0; i<N_CH; i = i + 1) begin: extrac
            assign ch_data_full[i] = $signed(din_bus[i*DIN_W +: DIN_W]); // unpacking and sign
            assign ch_data[i]      = ch_data_full[i] >>> (DIN_FRAC - DATA_FRAC); // cut down 
        end
    endgenerate 

    // mad calculation
    reg     signed  [DATA_W-1:0]    last_ch31_r;   // 8+6 signed data
    reg             [DATA_W-1:0]    abs_diff_r  [0:N_CH-1];   // 8+6 unsigned data 

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            last_ch31_r     <= {DATA_W{1'b0}};
            for(integer j = 0; j < N_CH; j = j + 1)begin
                abs_diff_r[j] <= {DATA_W{1'b0}};
            end
        end
        else begin
            last_ch31_r     <= ch_data[N_CH-1];
            for(integer j = 0; j < N_CH - 1; j = j + 1)begin
                abs_diff_r[j] <= (ch_data[j] > ch_data[j+1]) ? (ch_data[j]-ch_data[j+1]) : (ch_data[j+1]-ch_data[j]);
            end
            abs_diff_r[N_CH-1] <= (last_ch31_r > ch_data[0]) ? (last_ch31_r - ch_data[0]) : (ch_data[0] - last_ch31_r);
        end
    end
    // plus tree stage1
    reg     [DATA_W+1-1:0]    sum_p1  [0:N_PHA-1][0:3];
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            for(integer p = 0; p < N_PHA; p = p + 1)
                for(integer m = 0; m < 4; m = m + 1) sum_p1[p][m] <= 0;
        end
        else begin
            for(integer p = 0; p < N_PHA; p = p + 1)begin
                sum_p1[p][0]  <= abs_diff_r[p]  +  abs_diff_r[p+4];
                sum_p1[p][1]  <= abs_diff_r[p+8]  +  abs_diff_r[p+12];
                sum_p1[p][2]  <= abs_diff_r[p+16]  + abs_diff_r[p+20];
                sum_p1[p][3]  <= abs_diff_r[p+24]  + abs_diff_r[p+28];
            end
        end
    end
    // plus tree stage2
    reg     [DATA_W+3-1:0]  beat_sum_r  [0:N_PHA-1];
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            for(integer p = 0; p < N_PHA; p = p + 1) beat_sum_r[p] <= 0;
        end
        else begin
            for(integer p = 0; p < N_PHA; p = p + 1)begin
                beat_sum_r[p] <= sum_p1[p][0] + sum_p1[p][1] + sum_p1[p][2] + sum_p1[p][3];
            end
        end   
    end

    reg     [2:0] en_delay;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n) en_delay <= 3'b0;
        else en_delay <= {en_delay[1:0],skew_cal_en};
    end

    wire    cal_en_aligned = en_delay[2];


    // acc
    reg     signed  [ACC_W-1:0]     sum_rr  [0:N_PHA-1];                // signed 32bits
    reg             [11:0]          acc_cnt;                            // max 2048
    reg                             sum_done;

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            acc_cnt         <= 12'd0;
            sum_done        <= 1'b0;
            for(integer k = 0; k < N_PHA; k = k + 1)
                sum_rr[k] <= {ACC_W{1'b0}};
        end
        else if(!skew_cal_en)begin
            acc_cnt         <= 12'd0;
            sum_done        <= 1'b0;
            for(integer k = 0; k < N_PHA; k = k + 1)
                sum_rr[k] <= {ACC_W{1'b0}};
        end
        else if(cal_en_aligned)begin
            if(acc_cnt < CLK_CNT_MAX)begin
                acc_cnt <= acc_cnt + 1'b1;
                for(integer k = 0; k < N_PHA; k = k + 1)
                    sum_rr[k] <= sum_rr[k] + $signed(beat_sum_r[k]);
            end
            else begin
                sum_done  <= 1'b1;
            end
        end
    end

    reg     signed  [AVG_W-1:0] avg_rr_x4_r [0:N_PHA-1];
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            for(integer k = 0; k < N_PHA; k = k + 1) avg_rr_x4_r[k] <= {AVG_W{1'b0}};
        end
        else if(sum_done)begin
            avg_rr_x4_r[0]    <=   sum_rr[0] >>> (POINTS_W - 2);
            avg_rr_x4_r[1]    <=   sum_rr[1] >>> (POINTS_W - 2);
            avg_rr_x4_r[2]    <=   sum_rr[2] >>> (POINTS_W - 2);
            avg_rr_x4_r[3]    <=   sum_rr[3] >>> (POINTS_W - 2);
        end
    end

    reg signed [AVG_W-1:0] sum_avg_rr_r;
    reg signed [AVG_W-1:0] sum_avg_x2_r;
    reg signed [AVG_W-1:0] sum_avg_x3_r;

    reg     sum_done_dl;
    reg     sum_done_dl2; 
    reg     sum_done_dl3; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_done_dl  <= 1'b0;
            sum_done_dl2 <= 1'b0;
            sum_done_dl3 <= 1'b0;
        end else begin
            sum_done_dl  <= sum_done;
            sum_done_dl2 <= sum_done_dl;
            sum_done_dl3 <= sum_done_dl2;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_avg_rr_r <= 0;
            sum_avg_x2_r <= 0;
            sum_avg_x3_r <= 0;
        end 
        else if (sum_done_dl) begin 
            sum_avg_rr_r <= (avg_rr_x4_r[0] >>> 2) + (avg_rr_x4_r[1] >>> 2) 
                          + (avg_rr_x4_r[2] >>> 2) + (avg_rr_x4_r[3] >>> 2);
            sum_avg_x2_r <= ((avg_rr_x4_r[0] >>> 2) + (avg_rr_x4_r[1] >>> 2) 
                          + (avg_rr_x4_r[2] >>> 2) + (avg_rr_x4_r[3] >>> 2)) << 1;
            sum_avg_x3_r <= ((avg_rr_x4_r[0] + avg_rr_x4_r[1] + avg_rr_x4_r[2] + avg_rr_x4_r[3]) >>> 2) * 3;
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done         <= 1'b0;
            skew_sign    <= {(N_PHA-1){1'b0}};
        end 
        else begin
            if(sum_done_dl2&(!sum_done_dl3))begin
                done <= 1'b1;
                skew_sign[0] <= (avg_rr_x4_r[0] - sum_avg_rr_r > 0);// skew_sign = 1---> DCDL minus     skew_sign = 0---> DCDL plus
                skew_sign[1] <= (avg_rr_x4_r[0] + avg_rr_x4_r[1] - sum_avg_x2_r > 0);
                skew_sign[2] <= (avg_rr_x4_r[0] + avg_rr_x4_r[1] + avg_rr_x4_r[2] - sum_avg_x3_r > 0);
            end
            else begin
                done <= 1'b0;
            end
        end
    end

endmodule