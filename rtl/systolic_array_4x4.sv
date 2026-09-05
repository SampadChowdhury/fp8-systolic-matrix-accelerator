module systolic_array_4x4 (
    input  logic         clk,
    input  logic         reset,
    input  logic         clear,
    input  logic         enable,
    input  logic         fp8_mode,
    input  logic [31:0]  a_edge,
    input  logic [31:0]  b_edge,
    output logic [511:0] results,
    output logic [63:0]  pe_status
);

    logic [7:0] a_link [0:3][0:3];
    logic [7:0] b_link [0:3][0:3];

    genvar row;
    genvar column;
    generate
        for (row = 0; row < 4; row = row + 1) begin : generate_rows
            for (column = 0; column < 4; column = column + 1) begin : generate_columns
                wire [7:0] pe_input_a;
                wire [7:0] pe_input_b;

                if (column == 0)
                    assign pe_input_a = a_edge[row*8 +: 8];
                else
                    assign pe_input_a = a_link[row][column-1];

                if (row == 0)
                    assign pe_input_b = b_edge[column*8 +: 8];
                else
                    assign pe_input_b = b_link[row-1][column];

                dual_mode_mac_pe pe (
                    .clk(clk),
                    .reset(reset),
                    .clear(clear),
                    .enable(enable),
                    .fp8_mode(fp8_mode),
                    .in_a(pe_input_a),
                    .in_b(pe_input_b),
                    .out_a(a_link[row][column]),
                    .out_b(b_link[row][column]),
                    .accumulator(results[(row*4+column)*32 +: 32]),
                    .status(pe_status[(row*4+column)*4 +: 4])
                );
            end
        end
    endgenerate

endmodule
