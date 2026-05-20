`timescale 1ns/1ps

module tb_calib2();
    parameter N_CH   = 32;
    parameter N_SRAM = 65536;

    reg clk, rst_n, skew_cal_en;
    reg [N_CH*8-1:0] din_bus;

    // reg_os_lms fp8+9  reg_gain_lms fp1+11
    reg signed [16:0] os_reg_pool [1:31];  
    reg signed [11:0] gain_reg_pool [1:31];
    reg [7:0]  skew_mem [0:N_SRAM-1];   // data for training

    wire [N_CH*16-1:0] corrected_bus;    // sigend fp8+8 output to be detected
    wire [2:0] skew_sign;           // 3bits signs
    wire done;                      // one interation cycle is done

    // f_reg: point to the file saves the reg value of gain/os lms
    // f_sign: point to the file saves the 3bits sign
    integer i, ch, f_reg, f_sign;

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : cal_link
            wire [15:0] d_signed;
            d2signed u_d2s(.d_in(din_bus[g*8 +: 8]), .d_signed(d_signed));
            if (g == 0) assign corrected_bus[15:0] = d_signed;
            else begin
                correct u_cor(
                    .d_signed(d_signed),
                    .lms_os(os_reg_pool[g]),
                    .lms_gain(gain_reg_pool[g]),
                    .d_cal(corrected_bus[g*16 +: 16])
                );
            end
        end
    endgenerate

    skew_calib u_skew (
        .clk(clk), .rst_n(rst_n), .skew_cal_en(skew_cal_en),
        .din_bus(corrected_bus), .done(done), .skew_sign(skew_sign)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    reg signed [16:0] tmp_os;
    reg signed [11:0] tmp_gain;

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("build/tb_skew_step.vcd");
            $dumpvars(0, tb_calib2);
        end
    end

    integer r_count; // 用于接收 $fscanf 的返回值

    initial begin
        f_reg = $fopen("build/reg_cal1.txt", "r");
        if (f_reg == 0) begin $display("Error: reg_cal1.txt not found!"); $fatal; end
        for (i = 1; i < 32; i = i + 1) begin
            r_count = $fscanf(f_reg, "%b", tmp_os);
            if (r_count != 1) begin
                $display("Error: failed to read OS register for ch%0d", i);
                $fatal;
            end
            os_reg_pool[i] = tmp_os;
            r_count = $fscanf(f_reg, "%b", tmp_gain);
            if (r_count != 1) begin
                $display("Error: failed to read Gain register for ch%0d", i);
                $fatal;
            end
            gain_reg_pool[i] = tmp_gain;
        end
        $fclose(f_reg);

        $readmemb("data_gen/calib2_tran.txt", skew_mem);

        rst_n = 0; skew_cal_en = 0;din_bus = 0;
        #200 rst_n = 1; #100;
        
        @(posedge clk) skew_cal_en = 1;
        for (i = 0; i < N_SRAM / 32; i = i + 1) begin
            @(posedge clk);
            for (ch = 0; ch < 32; ch = ch + 1)
                din_bus[ch*8 +: 8] = skew_mem[i*32 + ch];
        end

        $display("Verilog: Data feed finished, waiting for 'done' pulse...");


        fork : wait_or_timeout
            begin
                @(posedge done); // 捕捉脉冲的上升沿，即使只有一拍也能抓到
                $display("Verilog: Skew Calibration Done detected at %t", $time);
                disable wait_or_timeout;
            end
            begin
                repeat(1000) @(posedge clk); 
                $display("Verilog Error: Simulation Timeout! 'done' pulse never arrived.");
                $fatal; 
            end
        join
        repeat(10) @(posedge clk); 

        f_sign = $fopen("build/dcdl_3bits.txt", "w");
        if (f_sign == 0) begin
            $display("Verilog Error: Could not open dcdl_3bits.txt");
            $fatal;
        end else begin
            $fdisplay(f_sign, "%b", skew_sign);
            $fclose(f_sign);
            $display("Verilog: Successfully wrote skew_sign %b", skew_sign);
        end

        #100;
        skew_cal_en = 0;
        
        #100;
        $finish; 
    end
endmodule
