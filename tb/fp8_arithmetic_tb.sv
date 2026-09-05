`timescale 1ns/1ps

module fp8_arithmetic_tb;

    logic [7:0] a;
    logic [7:0] b;
    logic subtract;
    logic [7:0] multiply_result;
    logic [7:0] add_result;
    logic [3:0] multiply_status;
    logic [3:0] add_status;
    integer checks;

    fp8_e3m4_mul multiplier (
        .a(a), .b(b), .result(multiply_result), .status(multiply_status)
    );

    fp8_e3m4_add adder (
        .a(a), .b(b), .subtract(subtract),
        .result(add_result), .status(add_status)
    );

    task automatic check_multiply(
        input logic [7:0] operand_a,
        input logic [7:0] operand_b,
        input logic [7:0] expected_result,
        input logic [3:0] expected_status
    );
        begin
            a = operand_a;
            b = operand_b;
            subtract = 1'b0;
            #1;
            if ((multiply_result !== expected_result) ||
                (multiply_status !== expected_status))
                $fatal(1, "MUL a=%02h b=%02h got=%02h/%01h expected=%02h/%01h",
                       a, b, multiply_result, multiply_status,
                       expected_result, expected_status);
            checks = checks + 1;
        end
    endtask

    task automatic check_add(
        input logic [7:0] operand_a,
        input logic [7:0] operand_b,
        input logic       operation,
        input logic [7:0] expected_result,
        input logic [3:0] expected_status
    );
        begin
            a = operand_a;
            b = operand_b;
            subtract = operation;
            #1;
            if ((add_result !== expected_result) || (add_status !== expected_status))
                $fatal(1, "ADD/SUB a=%02h b=%02h op=%0d got=%02h/%01h expected=%02h/%01h",
                       a, b, operation, add_result, add_status,
                       expected_result, expected_status);
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;

        check_multiply(8'h38, 8'h40, 8'h48, 4'b0000); // 1.5 * 2.0 = 3.0
        check_multiply(8'h10, 8'h10, 8'h04, 4'b0000); // 0.25 * 0.25 = 0.0625
        check_multiply(8'h01, 8'h20, 8'h00, 4'b0011); // halfway to min subnormal -> even zero
        check_multiply(8'h03, 8'h20, 8'h02, 4'b0001); // halfway -> even subnormal 0x02
        check_multiply(8'h70, 8'h00, 8'h78, 4'b1000); // infinity * zero = NaN
        check_multiply(8'h6F, 8'h40, 8'h70, 4'b0101); // overflow to infinity

        check_add(8'h38, 8'h30, 1'b0, 8'h44, 4'b0000); // 1.5 + 1.0 = 2.5
        check_add(8'h30, 8'h30, 1'b1, 8'h00, 4'b0000); // 1.0 - 1.0 = 0
        check_add(8'h01, 8'h01, 1'b0, 8'h02, 4'b0000); // subnormal addition
        check_add(8'h40, 8'h20, 1'b1, 8'h38, 4'b0000); // 2.0 - 0.5 = 1.5
        check_add(8'h6F, 8'h6F, 1'b0, 8'h70, 4'b0101); // overflow to infinity
        check_add(8'h70, 8'hF0, 1'b0, 8'h78, 4'b1000); // +inf + -inf = NaN

        $display("PASS: %0d directed FP8 E3M4 arithmetic checks", checks);
        $finish;
    end

endmodule
