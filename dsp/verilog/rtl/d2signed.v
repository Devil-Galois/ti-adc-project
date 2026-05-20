/*
* module name: dcal_to_signed
* function   : sram controller的8bits数字码d_cal，权重为64，32，16，8，8，4，2，1.
* 先计算总值d_weighted，由于d_weighted范围就在0~135.所以8bits够用 然后扩充为16bits定点无符号数，
* 接着这个16bits定点无符号数转换为有符号数，然后减去一个67.5中间值，这个值也要是有符号数，
* 然后两个有符号数相减得到最终的输出数据。

* 验证可行
*/
module d2signed #(
    parameter   INT_W  = 8, 
    parameter   FRAC_W = 8     
)(
    input  wire [INT_W-1:0]          d_in,        // 8bits unsigned input data(non-binary weights)
    output wire signed [INT_W+FRAC_W-1:0] d_signed // 8+8 signed fixed point data
);

    wire [INT_W-1:0] d_weighted;                   // 8bits unsigned data binary weights(0-135)
    
    assign d_weighted = ({{4'b0},d_in[7:4]} << 3) + {{4'b0},d_in[3:0]};   // 0-135    8bits unsigned

    wire [INT_W+FRAC_W-1:0] d_weighted_fp;         // 16bits unsigned
    
    assign d_weighted_fp = {d_weighted, {FRAC_W{1'b0}}}; // fixed point number    16bits unsigned

    
    localparam [16:0] OFFSET = 16'd17280; // 67.5       // 17bits 0_01000011_10000000
    
    wire signed [INT_W+FRAC_W:0] sub_result;        // 17bits signed
    
    assign sub_result = $signed({1'b0, d_weighted_fp}) - $signed(OFFSET);// 16bits expand to 17bits always unsigned    2-c

    assign d_signed = sub_result[INT_W+FRAC_W-1:0];

endmodule