module fp8_e3m4_mul (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] result,
    output logic [3:0] status
);

    // status = {invalid, overflow, underflow, inexact}
    integer magnitude_a;
    integer magnitude_b;
    integer product;
    integer exponent_field;
    integer shift_amount;
    integer quotient;
    integer remainder;
    integer half;
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
        result_sign = a[7] ^ b[7];

        result = 8'b0;
        status = 4'b0;
        magnitude_a = decode_magnitude64(a);
        magnitude_b = decode_magnitude64(b);
        product = 0;
        exponent_field = 0;
        shift_amount = 0;
        quotient = 0;
        remainder = 0;
        half = 0;

        if (a_nan || b_nan || ((a_inf || b_inf) && (a_zero || b_zero))) begin
            result = 8'h78;
            status[3] = 1'b1;
        end else if (a_inf || b_inf) begin
            result = {result_sign, 3'b111, 4'b0000};
        end else if (a_zero || b_zero) begin
            result = {result_sign, 7'b0};
        end else begin
            // Decoded operands use units of 2^-6. The product therefore uses
            // units of 2^-12; the right shift includes the 2^6 scale
            // conversion and the selected output ULP.
            product = magnitude_a * magnitude_b;

            if (product < 1024) begin exponent_field = 0; shift_amount = 6;  end
            else if (product < 2048) begin exponent_field = 1; shift_amount = 6;  end
            else if (product < 4096) begin exponent_field = 2; shift_amount = 7;  end
            else if (product < 8192) begin exponent_field = 3; shift_amount = 8;  end
            else if (product < 16384) begin exponent_field = 4; shift_amount = 9;  end
            else if (product < 32768) begin exponent_field = 5; shift_amount = 10; end
            else begin exponent_field = 6; shift_amount = 11; end

            quotient = product >> shift_amount;
            remainder = product & ((1 << shift_amount) - 1);
            half = 1 << (shift_amount - 1);
            if ((remainder > half) || ((remainder == half) && quotient[0]))
                quotient = quotient + 1;

            status[0] = (remainder != 0);

            if (exponent_field == 0) begin
                if (quotient == 0) begin
                    result = {result_sign, 7'b0};
                    status[1] = 1'b1;
                end else if (quotient >= 16) begin
                    result = {result_sign, 3'b001, 4'b0000};
                end else begin
                    result = {result_sign, 3'b000, quotient[3:0]};
                end
            end else begin
                if (quotient >= 32) begin
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
    end

endmodule
