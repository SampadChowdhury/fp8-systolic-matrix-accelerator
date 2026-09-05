module fp8_e3m4_add (
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic       subtract,
    output logic [7:0] result,
    output logic [3:0] status
);

    // status = {invalid, overflow, underflow, inexact}
    integer signed_a;
    integer signed_b;
    integer signed_sum;
    integer magnitude;
    integer exponent_field;
    integer shift_amount;
    integer quotient;
    integer remainder;
    integer half;
    logic   b_effective_sign;
    logic   result_sign;
    logic   a_zero, b_zero, a_inf, b_inf, a_nan, b_nan;

    function automatic integer decode_magnitude64(input logic [7:0] value);
        integer exponent;
        integer fraction;
        begin
            exponent = value[6:4];
            fraction = value[3:0];
            if (exponent == 0)
                decode_magnitude64 = fraction;
            else
                decode_magnitude64 = (16 + fraction) << (exponent - 1);
        end
    endfunction

    always @* begin
        a_zero = (a[6:0] == 7'b0);
        b_zero = (b[6:0] == 7'b0);
        a_inf  = (a[6:4] == 3'b111) && (a[3:0] == 4'b0);
        b_inf  = (b[6:4] == 3'b111) && (b[3:0] == 4'b0);
        a_nan  = (a[6:4] == 3'b111) && (a[3:0] != 4'b0);
        b_nan  = (b[6:4] == 3'b111) && (b[3:0] != 4'b0);
        b_effective_sign = b[7] ^ subtract;

        result = 8'b0;
        status = 4'b0;
        signed_a = a[7] ? -decode_magnitude64(a) : decode_magnitude64(a);
        signed_b = b_effective_sign ? -decode_magnitude64(b) : decode_magnitude64(b);
        signed_sum = signed_a + signed_b;
        result_sign = (signed_sum < 0);
        magnitude = result_sign ? -signed_sum : signed_sum;
        exponent_field = 0;
        shift_amount = 0;
        quotient = 0;
        remainder = 0;
        half = 0;

        if (a_nan || b_nan || (a_inf && b_inf && (a[7] != b_effective_sign))) begin
            result = 8'h78;
            status[3] = 1'b1;
        end else if (a_inf) begin
            result = {a[7], 3'b111, 4'b0000};
        end else if (b_inf) begin
            result = {b_effective_sign, 3'b111, 4'b0000};
        end else if (magnitude == 0) begin
            result = 8'b0;
        end else begin
            if (magnitude < 16) begin exponent_field = 0; shift_amount = 0; end
            else if (magnitude < 32) begin exponent_field = 1; shift_amount = 0; end
            else if (magnitude < 64) begin exponent_field = 2; shift_amount = 1; end
            else if (magnitude < 128) begin exponent_field = 3; shift_amount = 2; end
            else if (magnitude < 256) begin exponent_field = 4; shift_amount = 3; end
            else if (magnitude < 512) begin exponent_field = 5; shift_amount = 4; end
            else begin exponent_field = 6; shift_amount = 5; end

            quotient = magnitude >> shift_amount;
            if (shift_amount == 0) begin
                remainder = 0;
                half = 0;
            end else begin
                remainder = magnitude & ((1 << shift_amount) - 1);
                half = 1 << (shift_amount - 1);
                if ((remainder > half) || ((remainder == half) && quotient[0]))
                    quotient = quotient + 1;
            end

            status[0] = (remainder != 0);

            if (exponent_field == 0) begin
                result = {result_sign, 3'b000, quotient[3:0]};
            end else if (quotient >= 32) begin
                if (exponent_field == 6) begin
                    result = {result_sign, 3'b111, 4'b0000};
                    status[2] = 1'b1;
                    status[0] = 1'b1;
                end else begin
                    exponent_field = exponent_field + 1;
                    result = {result_sign, exponent_field[2:0], 4'b0000};
                end
            end else begin
                result = {result_sign, exponent_field[2:0], quotient[3:0]};
            end
        end
    end

endmodule
