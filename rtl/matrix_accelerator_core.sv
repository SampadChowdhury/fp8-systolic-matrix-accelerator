module matrix_accelerator_core (
    input  logic         clk,
    input  logic         reset,
    input  logic         start,
    input  logic         fp8_mode,
    input  logic [127:0] matrix_a,
    input  logic [127:0] matrix_b,
    output logic         busy,
    output logic         done,
    output logic [511:0] matrix_c,
    output logic [3:0]   status
);

    typedef enum logic [1:0] {IDLE, CLEAR, RUN, COMPLETE} state_t;
    state_t state;
    logic [3:0] cycle_count;
    logic mode_latched;
    logic [31:0] a_edge;
    logic [31:0] b_edge;
    logic [63:0] pe_status;
    integer input_row;
    integer input_column;
    integer status_index;

    always_comb begin
        a_edge = 32'b0;
        b_edge = 32'b0;

        for (input_row = 0; input_row < 4; input_row = input_row + 1) begin
            if ((cycle_count >= input_row) && (cycle_count < input_row + 4)) begin
                a_edge[input_row*8 +: 8] =
                    matrix_a[(input_row*32)+((cycle_count-input_row)*8) +: 8];
            end
        end

        for (input_column = 0; input_column < 4; input_column = input_column + 1) begin
            if ((cycle_count >= input_column) && (cycle_count < input_column + 4)) begin
                b_edge[input_column*8 +: 8] =
                    matrix_b[((cycle_count-input_column)*32)+(input_column*8) +: 8];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            cycle_count  <= 4'b0;
            mode_latched <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    cycle_count <= 4'b0;
                    if (start) begin
                        mode_latched <= fp8_mode;
                        state <= CLEAR;
                    end
                end
                CLEAR: begin
                    cycle_count <= 4'b0;
                    state <= RUN;
                end
                RUN: begin
                    if (cycle_count == 4'd9) begin
                        state <= COMPLETE;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end
                COMPLETE: begin
                    if (start) begin
                        mode_latched <= fp8_mode;
                        state <= CLEAR;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    systolic_array_4x4 array (
        .clk(clk),
        .reset(reset),
        .clear(state == CLEAR),
        .enable(state == RUN),
        .fp8_mode(mode_latched),
        .a_edge(a_edge),
        .b_edge(b_edge),
        .results(matrix_c),
        .pe_status(pe_status)
    );

    always_comb begin
        status = 4'b0;
        for (status_index = 0; status_index < 16; status_index = status_index + 1)
            status = status | pe_status[status_index*4 +: 4];
    end

    assign busy = (state == CLEAR) || (state == RUN);
    assign done = (state == COMPLETE);

endmodule
