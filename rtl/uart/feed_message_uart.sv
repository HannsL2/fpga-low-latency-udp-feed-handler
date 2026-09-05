module feed_message_uart #(
    parameter int unsigned CLOCK_FREQUENCY_HZ = 50_000_000,
    parameter int unsigned BAUD_RATE = 115_200
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        message_valid,
    input  logic [7:0]  message_type,
    input  logic [31:0] sequence_number,
    input  logic [15:0] instrument_id,
    input  logic [31:0] price,
    input  logic [31:0] quantity,
    output logic        message_ready,
    output logic        uart_tx_pin
);

    localparam logic [6:0] LAST_CHARACTER = 7'd63;

    logic [7:0]  latched_message_type;
    logic [31:0] latched_sequence_number;
    logic [15:0] latched_instrument_id;
    logic [31:0] latched_price;
    logic [31:0] latched_quantity;
    logic [6:0]  character_index;
    logic        formatting;
    logic [7:0]  uart_data;
    logic        uart_valid;
    logic        uart_ready;

    function automatic logic [7:0] hexadecimal_character(input logic [3:0] nibble);
        if (nibble < 10) begin
            hexadecimal_character = "0" + nibble;
        end else begin
            hexadecimal_character = "A" + (nibble - 10);
        end
    endfunction

    function automatic logic [7:0] text_character(input logic [6:0] index);
        case (index)
            7'd0: text_character = "M";
            7'd1: text_character = "S";
            7'd2: text_character = "G";
            7'd3: text_character = " ";
            7'd4: text_character = "t";
            7'd5: text_character = "y";
            7'd6: text_character = "p";
            7'd7: text_character = "e";
            7'd8: text_character = "=";
            7'd11: text_character = " ";
            7'd12: text_character = "s";
            7'd13: text_character = "e";
            7'd14: text_character = "q";
            7'd15: text_character = "=";
            7'd24: text_character = " ";
            7'd25: text_character = "i";
            7'd26: text_character = "n";
            7'd27: text_character = "s";
            7'd28: text_character = "t";
            7'd29: text_character = "=";
            7'd34: text_character = " ";
            7'd35: text_character = "p";
            7'd36: text_character = "r";
            7'd37: text_character = "i";
            7'd38: text_character = "c";
            7'd39: text_character = "e";
            7'd40: text_character = "=";
            7'd49: text_character = " ";
            7'd50: text_character = "q";
            7'd51: text_character = "t";
            7'd52: text_character = "y";
            7'd53: text_character = "=";
            7'd62: text_character = 8'h0D;
            7'd63: text_character = 8'h0A;
            default: text_character = "?";
        endcase
    endfunction

    always_comb begin
        uart_data = text_character(character_index);
        if (character_index >= 7'd9 && character_index <= 7'd10) begin
            uart_data = hexadecimal_character(
                latched_message_type[(7'd10 - character_index) * 4 +: 4]);
        end else if (character_index >= 7'd16 && character_index <= 7'd23) begin
            uart_data = hexadecimal_character(
                latched_sequence_number[(7'd23 - character_index) * 4 +: 4]);
        end else if (character_index >= 7'd30 && character_index <= 7'd33) begin
            uart_data = hexadecimal_character(
                latched_instrument_id[(7'd33 - character_index) * 4 +: 4]);
        end else if (character_index >= 7'd41 && character_index <= 7'd48) begin
            uart_data = hexadecimal_character(
                latched_price[(7'd48 - character_index) * 4 +: 4]);
        end else if (character_index >= 7'd54 && character_index <= 7'd61) begin
            uart_data = hexadecimal_character(
                latched_quantity[(7'd61 - character_index) * 4 +: 4]);
        end
    end

    assign message_ready = !formatting;
    assign uart_valid = formatting;

    always_ff @(posedge clk) begin
        if (reset) begin
            latched_message_type <= 8'h00;
            latched_sequence_number <= 32'h0000_0000;
            latched_instrument_id <= 16'h0000;
            latched_price <= 32'h0000_0000;
            latched_quantity <= 32'h0000_0000;
            character_index <= 7'd0;
            formatting <= 1'b0;
        end else begin
            if (!formatting && message_valid) begin
                latched_message_type <= message_type;
                latched_sequence_number <= sequence_number;
                latched_instrument_id <= instrument_id;
                latched_price <= price;
                latched_quantity <= quantity;
                character_index <= 7'd0;
                formatting <= 1'b1;
            end else if (formatting && uart_ready) begin
                if (character_index == LAST_CHARACTER) begin
                    formatting <= 1'b0;
                end else begin
                    character_index <= character_index + 1'b1;
                end
            end
        end
    end

    uart_tx #(
        .CLOCK_FREQUENCY_HZ(CLOCK_FREQUENCY_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) transmitter (
        .clk,
        .reset,
        .data(uart_data),
        .valid(uart_valid),
        .ready(uart_ready),
        .tx(uart_tx_pin)
    );

endmodule
