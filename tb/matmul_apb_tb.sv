`timescale 1ns/1ps

module matmul_apb_tb;

    localparam logic [11:0] CONTROL_ADDR = 12'h000;
    localparam logic [11:0] STATUS_ADDR  = 12'h004;
    localparam logic [11:0] MODE_ADDR    = 12'h008;
    localparam logic [11:0] INFO_ADDR    = 12'h00C;
    localparam logic [11:0] MATRIX_A_BASE = 12'h100;
    localparam logic [11:0] MATRIX_B_BASE = 12'h140;
    localparam logic [11:0] MATRIX_C_BASE = 12'h180;

    logic PCLK;
    logic PRESETn;
    logic [11:0] PADDR;
    logic PSEL;
    logic PENABLE;
    logic PWRITE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic PREADY;
    logic PSLVERR;

    logic [7:0] matrix_a_values [0:15];
    logic [7:0] matrix_b_values [0:15];
    integer expected_int [0:15];
    logic [31:0] read_data;
    integer index;
    integer polls;
    logic saw_busy;

    matmul_apb_wrapper dut (.*);

    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    task automatic apb_write(input logic [11:0] address,
                             input logic [31:0] data);
        begin
            @(negedge PCLK);
            PADDR = address;
            PWDATA = data;
            PWRITE = 1'b1;
            PSEL = 1'b1;
            PENABLE = 1'b0;
            @(negedge PCLK);
            PENABLE = 1'b1;
            @(posedge PCLK);
            #1;
            if (!PREADY || PSLVERR)
                $fatal(1, "APB write failed at address %03h", address);
            @(negedge PCLK);
            PSEL = 1'b0;
            PENABLE = 1'b0;
            PWRITE = 1'b0;
        end
    endtask

    task automatic apb_read(input logic [11:0] address,
                            output logic [31:0] data);
        begin
            @(negedge PCLK);
            PADDR = address;
            PWRITE = 1'b0;
            PSEL = 1'b1;
            PENABLE = 1'b0;
            @(negedge PCLK);
            PENABLE = 1'b1;
            @(posedge PCLK);
            #1;
            if (!PREADY || PSLVERR)
                $fatal(1, "APB read failed at address %03h", address);
            data = PRDATA;
            @(negedge PCLK);
            PSEL = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    task automatic load_operands;
        begin
            for (index = 0; index < 16; index = index + 1) begin
                apb_write(MATRIX_A_BASE + index*4, {24'b0, matrix_a_values[index]});
                apb_write(MATRIX_B_BASE + index*4, {24'b0, matrix_b_values[index]});
            end
        end
    endtask

    task automatic wait_for_completion;
        begin
            polls = 0;
            saw_busy = 1'b0;
            read_data = 32'b0;
            while (!((read_data[1] == 1'b1) && saw_busy) && (polls < 40)) begin
                apb_read(STATUS_ADDR, read_data);
                if (read_data[0])
                    saw_busy = 1'b1;
                polls = polls + 1;
            end
            if (!saw_busy || !read_data[1])
                $fatal(1, "Accelerator timeout: status=%08h polls=%0d", read_data, polls);
        end
    endtask

    initial begin
        PADDR = 12'b0;
        PSEL = 1'b0;
        PENABLE = 1'b0;
        PWRITE = 1'b0;
        PWDATA = 32'b0;
        PRESETn = 1'b0;
        repeat (4) @(posedge PCLK);
        @(negedge PCLK);
        PRESETn = 1'b1;

        apb_read(INFO_ADDR, read_data);
        if (read_data !== 32'h2008_0404)
            $fatal(1, "Unexpected accelerator information word: %08h", read_data);

        // Signed INT8 matrix A.
        matrix_a_values[0]=8'h01; matrix_a_values[1]=8'h02;
        matrix_a_values[2]=8'h03; matrix_a_values[3]=8'h04;
        matrix_a_values[4]=8'hFF; matrix_a_values[5]=8'h00;
        matrix_a_values[6]=8'h02; matrix_a_values[7]=8'h01;
        matrix_a_values[8]=8'h05; matrix_a_values[9]=8'h01;
        matrix_a_values[10]=8'hFE; matrix_a_values[11]=8'h00;
        matrix_a_values[12]=8'h02; matrix_a_values[13]=8'h02;
        matrix_a_values[14]=8'h02; matrix_a_values[15]=8'h02;

        // Signed INT8 matrix B.
        matrix_b_values[0]=8'h01; matrix_b_values[1]=8'h00;
        matrix_b_values[2]=8'h02; matrix_b_values[3]=8'hFF;
        matrix_b_values[4]=8'h03; matrix_b_values[5]=8'h01;
        matrix_b_values[6]=8'h00; matrix_b_values[7]=8'h02;
        matrix_b_values[8]=8'hFE; matrix_b_values[9]=8'h04;
        matrix_b_values[10]=8'h01; matrix_b_values[11]=8'h00;
        matrix_b_values[12]=8'h01; matrix_b_values[13]=8'hFF;
        matrix_b_values[14]=8'h03; matrix_b_values[15]=8'h02;

        expected_int[0]=5;   expected_int[1]=10;
        expected_int[2]=17;  expected_int[3]=11;
        expected_int[4]=-4;  expected_int[5]=7;
        expected_int[6]=3;   expected_int[7]=3;
        expected_int[8]=12;  expected_int[9]=-7;
        expected_int[10]=8;  expected_int[11]=-3;
        expected_int[12]=6;  expected_int[13]=8;
        expected_int[14]=12; expected_int[15]=6;

        apb_write(MODE_ADDR, 32'd0);
        load_operands();
        apb_write(CONTROL_ADDR, 32'd1);
        wait_for_completion();

        for (index = 0; index < 16; index = index + 1) begin
            apb_read(MATRIX_C_BASE + index*4, read_data);
            if ($signed(read_data) !== expected_int[index])
                $fatal(1, "INT8 C[%0d]=%0d expected=%0d",
                       index, $signed(read_data), expected_int[index]);
        end

        // FP8 run: all-ones matrices produce 4.0 (E3M4 0x50) in every cell.
        for (index = 0; index < 16; index = index + 1) begin
            matrix_a_values[index] = 8'h30;
            matrix_b_values[index] = 8'h30;
        end
        apb_write(MODE_ADDR, 32'd1);
        load_operands();
        apb_write(CONTROL_ADDR, 32'd1);
        wait_for_completion();

        if (read_data[6:3] !== 4'b0000)
            $fatal(1, "Unexpected FP8 exception status: %01h", read_data[6:3]);

        for (index = 0; index < 16; index = index + 1) begin
            apb_read(MATRIX_C_BASE + index*4, read_data);
            if (read_data !== 32'h0000_0050)
                $fatal(1, "FP8 C[%0d]=%08h expected=00000050", index, read_data);
        end

        $display("PASS: APB configuration, INT8 matrix multiply, and FP8 systolic flow verified");
        $display("      2 matrix operations, 32 result elements checked");
        $finish;
    end

    initial begin
        $dumpfile("matmul_apb.vcd");
        $dumpvars(0, matmul_apb_tb);
        #20000 $fatal(1, "Simulation timeout");
    end

endmodule
