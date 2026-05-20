`timescale 1ns/1ps
module tb_calib_fore();

    // 参数需与 RTL 一致
    parameter N_CH      = 32;
    parameter DATA_INT  = 8;
    parameter DATA_FRAC = 8;
    parameter DOUT_W    = 16; // 8+8
    parameter N_SRAM    = 65536;
    parameter N_ITER    = 32;
    parameter N_DELAY   = 171;
    parameter TOTAL_MEM = 2097152; // 32 * 65536

    reg clk;
    reg rst_n;
    reg cal_en;
    reg [N_CH*DATA_INT-1:0] din_bus;
    reg [1:0]           alpha_sel;
    reg [1:0]           mu_os_sel;
    reg [1:0]           mu_gain_sel;
    
    wire [N_CH*DOUT_W-1:0] dout_bus;

    reg  [7:0] bit_pool [0:TOTAL_MEM-1];
    reg  [7:0] tst_pool [0:N_SRAM-1];
    calib_fore #(
        .N_CH(N_CH),
        .DATA_INT(DATA_INT),
        .DATA_FRAC(DATA_FRAC)
    ) dut(
        .clk(clk),
        .rst_n(rst_n),
        .cal_en(cal_en),
        .din_bus(din_bus),
        .alpha_sel(alpha_sel),
        .mu_os_sel(mu_os_sel),
        .mu_gain_sel(mu_gain_sel),
        .dout_bus(dout_bus)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer iter,i,ch;
    integer pool_ptr = 0;
    integer file_id;

    reg signed [DOUT_W-1:0] raw_dout;
    reg signed [DATA_INT-1:0] rounded_dout; 

    initial begin
        $dumpfile("build/tb_calib_fore.vcd");
        
        #500;
        $dumpvars(1, tb_calib_fore.clk);
        $dumpvars(1, tb_calib_fore.rst_n);
        $dumpvars(1, tb_calib_fore.cal_en);
        
        // 通道 1
        $dumpvars(0, dut.calib_fore[1].ch_calib.lms_chn.reg_os_cal);
        $dumpvars(0, dut.calib_fore[1].ch_calib.lms_chn.reg_gain_cal);
        // 通道 2
        $dumpvars(0, dut.calib_fore[2].ch_calib.lms_chn.reg_os_cal);
        $dumpvars(0, dut.calib_fore[2].ch_calib.lms_chn.reg_gain_cal);
        
        // 通道 3
        $dumpvars(0, dut.calib_fore[3].ch_calib.lms_chn.reg_os_cal);
        $dumpvars(0, dut.calib_fore[3].ch_calib.lms_chn.reg_gain_cal);

        $dumpvars(0, dut.calib_fore[4].ch_calib.lms_chn.reg_os_cal);
        $dumpvars(0, dut.calib_fore[4].ch_calib.lms_chn.reg_gain_cal);
        $dumpvars(0, dut.calib_fore[5].ch_calib.lms_chn.reg_os_cal);
        $dumpvars(0, dut.calib_fore[5].ch_calib.lms_chn.reg_gain_cal);
    end

    initial begin
        rst_n = 0;
        cal_en = 0;
        din_bus = 0;
        alpha_sel = 2'b10;
        mu_os_sel = 2'b01;
        mu_gain_sel = 2'b10;

        // read in 
        $display("Loading Calibration Data...");
        $readmemb("bin/origin_data_8bits.txt",bit_pool);
        $display("Loading Test Data...");
        $readmemb("bin/origin_test_data_8bits.txt", tst_pool);

        file_id = $fopen("bin/calib_test_data_dec.txt", "w");
        if (file_id == 0) begin
            $display("Error: Cannot open bin/calib_test_data_dec.txt. Ensure 'bin' directory exists.");
            $finish;
        end

        #100;
        rst_n = 1;
        #100;
        // inter
        for(iter = 0; iter < N_ITER; iter = iter + 1)begin
            $display("Calib-Iteration [%0d/%0d] Start",iter + 1,N_ITER);
            @(posedge clk);   // set cal_en = 1 when iter starts
            cal_en = 1;
            // send data to din_bus
            for (i = 0; i < N_SRAM / N_CH; i = i + 1)begin
                @(posedge clk);
                for (ch = 0; ch < N_CH; ch = ch + 1)begin
                    din_bus[ch*DATA_INT +:DATA_INT] = bit_pool[pool_ptr + ch];
                end
                pool_ptr = pool_ptr + N_CH;
            end
            @(posedge clk);
            cal_en = 0;
            din_bus = 0;
            $display("Calib-Interation [%0d] done. Waiting %0d cycles...", iter+1,N_DELAY);
            repeat(N_DELAY) @(posedge clk);
        end
        // calibration is done and test is going to running
        $display("Calibration Finished. Starting Test Phase with fixed parameters... ");
        cal_en = 0;
        pool_ptr = 0;

        for (i = 0; i < N_SRAM / N_CH; i = i + 1)begin
            @(posedge clk);
            for (ch = 0; ch < N_CH; ch = ch + 1) begin
                din_bus[ch*DATA_INT +: DATA_INT] = tst_pool[pool_ptr + ch];
            end
            pool_ptr = pool_ptr + N_CH;
            #1;
            for (ch = 0; ch < N_CH; ch = ch + 1)begin
                raw_dout = dout_bus[ch*DOUT_W +: DOUT_W];
                // rounded_dout = $signed(raw_dout + 16'sd128) >>>8;

                // $fdisplay(file_id, "%d", rounded_dout);
                $fdisplay(file_id, "%0.4f", $itor(raw_dout) / 256.0);
            end
        end
        $fclose(file_id);
        $display("Test Phase Complete. Results saved to bin/calib_test_data_dec.txt");
        $finish;
    end

endmodule