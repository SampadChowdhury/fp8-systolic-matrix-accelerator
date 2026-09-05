module matmul_apb_wrapper (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [11:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);

    localparam logic [11:0] CONTROL_ADDR = 12'h000;
    localparam logic [11:0] STATUS_ADDR  = 12'h004;
    localparam logic [11:0] MODE_ADDR    = 12'h008;
    localparam logic [11:0] INFO_ADDR    = 12'h00C;
    localparam logic [11:0] MATRIX_A_BASE = 12'h100;
    localparam logic [11:0] MATRIX_B_BASE = 12'h140;
    localparam logic [11:0] MATRIX_C_BASE = 12'h180;

    logic [127:0] matrix_a;
    logic [127:0] matrix_b;
    logic [511:0] matrix_c;
    logic fp8_mode;
    logic start_pulse;
    logic busy;
    logic done;
    logic [3:0] accelerator_status;
    logic transfer;
    logic write_transfer;
    logic address_is_aligned;
    logic address_is_a;
    logic address_is_b;
    logic address_is_c;
    integer element_index;

    assign transfer = PSEL && PENABLE;
    assign write_transfer = transfer && PWRITE;
    assign PREADY = 1'b1;
    assign address_is_aligned = (PADDR[1:0] == 2'b00);
    assign address_is_a = (PADDR >= MATRIX_A_BASE) && (PADDR < MATRIX_B_BASE);
    assign address_is_b = (PADDR >= MATRIX_B_BASE) && (PADDR < MATRIX_C_BASE);
    assign address_is_c = (PADDR >= MATRIX_C_BASE) && (PADDR < 12'h1C0);

    always @* begin
        element_index = PADDR[5:2];
        PRDATA = 32'b0;

        case (PADDR)
            CONTROL_ADDR: PRDATA = 32'b0;
            STATUS_ADDR:  PRDATA = {25'b0, accelerator_status,
                                    (|accelerator_status), done, busy};
            MODE_ADDR:    PRDATA = {31'b0, fp8_mode};
            // {result width, operand width, rows, columns}
            INFO_ADDR:    PRDATA = {8'd32, 8'd8, 8'd4, 8'd4};
            default: begin
                if (address_is_a && address_is_aligned)
                    PRDATA = {24'b0, matrix_a[element_index*8 +: 8]};
                else if (address_is_b && address_is_aligned)
                    PRDATA = {24'b0, matrix_b[element_index*8 +: 8]};
                else if (address_is_c && address_is_aligned)
                    PRDATA = matrix_c[element_index*32 +: 32];
            end
        endcase
    end

    always @* begin
        PSLVERR = 1'b0;
        if (transfer) begin
            if (!address_is_aligned)
                PSLVERR = 1'b1;
            else if (PWRITE) begin
                if (!((PADDR == CONTROL_ADDR) || (PADDR == MODE_ADDR)
                      || address_is_a || address_is_b))
                    PSLVERR = 1'b1;
                else if (busy && ((PADDR == MODE_ADDR) || address_is_a || address_is_b))
                    PSLVERR = 1'b1;
            end else if (!((PADDR == CONTROL_ADDR) || (PADDR == STATUS_ADDR)
                           || (PADDR == MODE_ADDR) || (PADDR == INFO_ADDR)
                           || address_is_a || address_is_b || address_is_c)) begin
                PSLVERR = 1'b1;
            end
        end
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            matrix_a   <= 128'b0;
            matrix_b   <= 128'b0;
            fp8_mode   <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (write_transfer && !PSLVERR) begin
                if (PADDR == CONTROL_ADDR) begin
                    if (PWDATA[0] && !busy)
                        start_pulse <= 1'b1;
                end else if (PADDR == MODE_ADDR) begin
                    fp8_mode <= PWDATA[0];
                end else if (address_is_a) begin
                    matrix_a[element_index*8 +: 8] <= PWDATA[7:0];
                end else if (address_is_b) begin
                    matrix_b[element_index*8 +: 8] <= PWDATA[7:0];
                end
            end
        end
    end

    matrix_accelerator_core accelerator (
        .clk(PCLK),
        .reset(!PRESETn),
        .start(start_pulse),
        .fp8_mode(fp8_mode),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .busy(busy),
        .done(done),
        .matrix_c(matrix_c),
        .status(accelerator_status)
    );

endmodule
