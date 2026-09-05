module uart_tx #(
    parameter int unsigned CLOCK_FREQUENCY_HZ = 50_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] data,
    input  logic       valid,
    output logic       ready,
    output logic       tx
);

    localparam int unsigned CYCLES_PER_BIT = CLOCK_FREQUENCY_HZ / BAUD_RATE;
    localparam int unsigned COUNTER_WIDTH = $clog2(CYCLES_PER_BIT);

    logic [9:0] shift_register;
    logic [3:0] bit_count;
    logic [COUNTER_WIDTH-1:0] baud_counter;
    logic busy;

    assign ready = !busy;
    assign tx = busy ? shift_register[0] : 1'b1;

    always_ff @(posedge clk) begin
        if (reset) begin
            shift_register <= 10'h3FF;
            bit_count <= 4'd0;
            baud_counter <= '0;
            busy <= 1'b0;
        end else if (!busy) begin
            if (valid) begin
                // One start bit, eight data bits (least significant first),
                // and one stop bit: conventional 8-N-1 UART framing.
                shift_register <= {1'b1, data, 1'b0};
                bit_count <= 4'd0;
                baud_counter <= CYCLES_PER_BIT - 1;
                busy <= 1'b1;
            end
        end else if (baud_counter != 0) begin
            baud_counter <= baud_counter - 1'b1;
        end else if (bit_count == 4'd9) begin
            busy <= 1'b0;
        end else begin
            shift_register <= {1'b1, shift_register[9:1]};
            bit_count <= bit_count + 1'b1;
            baud_counter <= CYCLES_PER_BIT - 1;
        end
    end

endmodule
