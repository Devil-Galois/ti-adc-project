`timescale 1ns/1ps

module tb_calib1();
    parameter N_CH      = 32;
    parameter DATA_INT  = 8;
    parameter DATA_FRAC = 8;
    parameter DOUT_W    = 16;   // 8+8
    parameter N_SRAM    = 65536;
    parameter N_ITER    = 32;
    parameter N_DELAY   = 1718;
    parameter TOTAL_MEM = 2097152; // N_SRAM * N_ITER

    reg clk, rst_n, cal_en;
    reg [N_CH*DATA_INT-1:0] din_bus;
    reg [1:0] alpha_sel, mu_os_sel, mu_gain_sel;
    wire [N_CH*DOUT_W-1:0]  dout_bus;

    // 存储器定义
    reg [7:0] bit_pool [0:TOTAL_MEM-1];
    reg [7:0] tst_pool [0:N_SRAM-1];

    // 变量声明
    integer iter, i, ch, pool_ptr;
    integer f_reg, f_test_out; // f_reg  save the data of reg_os_lms and reg_gain_lms in 31 chs  // f_test_out save the data of data after calibration
    reg signed [DOUT_W-1:0] raw_dout;

    // 实例化 DUT
    calib_fore #(.N_CH(N_CH)) dut (
        .clk(clk), .rst_n(rst_n), .cal_en(cal_en),
        .din_bus(din_bus), .alpha_sel(alpha_sel),
        .mu_os_sel(mu_os_sel), .mu_gain_sel(mu_gain_sel),
        .dout_bus(dout_bus)
    );

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("build/tb_calib1_regs.vcd");   // save the waveform to be checked
            $dumpvars(1, tb_calib1.clk, tb_calib1.rst_n, tb_calib1.cal_en);
        end
    end

    genvar k;
    generate
        for (k = 1; k < 32; k = k + 1) begin : dump_gen
            initial begin
                if ($test$plusargs("dump")) begin
                    $dumpvars(0, dut.calib_fore[k].ch_calib.lms_chn.reg_os_cal);
                    $dumpvars(0, dut.calib_fore[k].ch_calib.lms_chn.reg_gain_cal);
                end
            end
        end
    endgenerate

    // clk generation
    initial clk = 0;
    always #5 clk = ~clk;

    wire [16:0] os_final_val [1:31];   // lms_os fp8+9
    wire [11:0] gain_final_val [1:31]; // lms_gain fp1+11

    genvar g;
    generate
        for (g = 1; g < 32; g = g + 1) begin : wire_regs
            assign os_final_val[g]   = dut.calib_fore[g].ch_calib.lms_chn.lms_os;
            assign gain_final_val[g] = dut.calib_fore[g].ch_calib.lms_chn.lms_gain;
        end
    endgenerate


    // start simulation
    initial begin
        // initial 
        rst_n = 0; cal_en = 0; din_bus = 0; pool_ptr = 0;
        alpha_sel = 2'b10; mu_os_sel = 2'b01; mu_gain_sel = 2'b10;

        // load the data for trainning and testing
        $display("Loading Calibration Data: calib1_tran.txt");
        $readmemb("data_gen/calib1_tran.txt", bit_pool);
        $display("Loading Test Data: adc_test.txt");
        $readmemb("data_gen/adc_test.txt", tst_pool);  // original test data input 8bits

        #100 rst_n = 1; #100;

        // trainning
        for(iter = 0; iter < N_ITER; iter = iter + 1) begin      // every interation N_SRAM data
            $display("---Iteration [%0d/%0d] Start---", iter+1, N_ITER);
            @(posedge clk) cal_en = 1;
            for (i = 0; i < N_SRAM / N_CH; i = i + 1) begin
                @(posedge clk);
                for (ch = 0; ch < N_CH; ch = ch + 1)
                    din_bus[ch*DATA_INT +: DATA_INT] = bit_pool[pool_ptr + ch];
                pool_ptr = pool_ptr + N_CH;
            end
            @(posedge clk) cal_en = 0; din_bus = 0;
            $display("Iteration [%0d] done. Waiting delay...", iter+1);
            repeat(N_DELAY) @(posedge clk);
        end

        // save the register of reg_os_lms and reg_gain_lms to files
        // formate: reg_os_lms:fp8+9   reg_gain_lms:fp1+11
        f_reg = $fopen("build/reg_cal1.txt", "w");
        if (f_reg == 0) begin $display("Error: Cannot open reg_cal1.txt"); $finish; end
        for (i = 1; i < 32; i = i + 1) begin
            $fdisplay(f_reg, "%b", os_final_val[i]);
            $fdisplay(f_reg, "%b", gain_final_val[i]);
        end
        $fclose(f_reg);
        $display("Registers saved to build/reg_cal1.txt");

        // test data input and calibration
        f_test_out = $fopen("build/test_calib1.txt", "w");
        if (f_test_out == 0) begin $display("Error: Cannot open test_calib1.txt"); $finish; end
        
        cal_en = 0; pool_ptr = 0; // frezee the register 
        for (i = 0; i < N_SRAM / N_CH; i = i + 1) begin
            @(posedge clk);
            for (ch = 0; ch < N_CH; ch = ch + 1)
                din_bus[ch*DATA_INT +: DATA_INT] = tst_pool[pool_ptr + ch];
            pool_ptr = pool_ptr + N_CH;
            
            #2; // waiting for the combination logic output
            for (ch = 0; ch < N_CH; ch = ch + 1) begin
                raw_dout = dout_bus[ch*DOUT_W +: DOUT_W];
                // dec output fp
                $fdisplay(f_test_out, "%0.4f", $itor(raw_dout) / 256.0);
            end
        end
        $fclose(f_test_out);
        $display("Calibration and Test complete. Calibrated test data saved to build/test_calib1.txt");
        
        $finish;
    end
endmodule
