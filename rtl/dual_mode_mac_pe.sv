module dual_mode_mac_pe (
    input  logic        clk,
    input  logic        reset,
    input  logic        clear,
    input  logic        enable,
    input  logic        fp8_mode,
    input  logic [7:0]  in_a,
    input  logic [7:0]  in_b,
    output logic [7:0]  out_a,
    output logic [7:0]  out_b,
    output logic [31:0] accumulator,
    output logic [3:0]  status
);

    logic signed [31:0] int_accumulator;
    logic signed [15:0] int_product;
    logic [7:0] fp8_accumulator;
    logic [7:0] fp8_product;
    logic [7:0] fp8_sum;
    logic [3:0] multiply_status;
    logic [3:0] add_status;
    logic [3:0] sticky_status;

    assign int_product = $signed(in_a) * $signed(in_b);

    fp8_e3m4_mul multiply (
        .a(in_a),
        .b(in_b),
        .result(fp8_product),
        .status(multiply_status)
    );

    fp8_e3m4_add add (
        .a(fp8_accumulator),
        .b(fp8_product),
        .subtract(1'b0),
        .result(fp8_sum),
        .status(add_status)
    );

    always_ff @(posedge clk) begin
        if (reset || clear) begin
            out_a            <= 8'b0;
            out_b            <= 8'b0;
            int_accumulator  <= 32'sd0;
            fp8_accumulator  <= 8'b0;
            sticky_status    <= 4'b0;
        end else if (enable) begin
            out_a <= in_a;
            out_b <= in_b;
            if (fp8_mode) begin
                fp8_accumulator <= fp8_sum;
                sticky_status <= sticky_status | multiply_status | add_status;
            end else begin
                int_accumulator <= int_accumulator + int_product;
            end
        end
    end

    assign accumulator = fp8_mode
                       ? {24'b0, fp8_accumulator}
                       : int_accumulator;
    assign status = fp8_mode ? sticky_status : 4'b0;

endmodule
