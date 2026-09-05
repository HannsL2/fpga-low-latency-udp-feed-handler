module feed_message_cdc (
    input  logic        source_clk,
    input  logic        source_reset,
    input  logic        source_valid,
    input  logic [7:0]  source_message_type,
    input  logic [31:0] source_sequence_number,
    input  logic [15:0] source_instrument_id,
    input  logic [31:0] source_price,
    input  logic [31:0] source_quantity,
    output logic        source_ready,
    output logic        source_overflow,

    input  logic        destination_clk,
    input  logic        destination_reset,
    input  logic        destination_ready,
    output logic        destination_valid,
    output logic [7:0]  destination_message_type,
    output logic [31:0] destination_sequence_number,
    output logic [15:0] destination_instrument_id,
    output logic [31:0] destination_price,
    output logic [31:0] destination_quantity
);

    logic [119:0] source_payload;
    logic source_request_toggle;
    logic destination_acknowledge_toggle;
    (* ASYNC_REG = "TRUE" *) logic acknowledge_sync_1;
    (* ASYNC_REG = "TRUE" *) logic acknowledge_sync_2;

    (* ASYNC_REG = "TRUE" *) logic [119:0] payload_sync_1;
    (* ASYNC_REG = "TRUE" *) logic [119:0] payload_sync_2;
    (* ASYNC_REG = "TRUE" *) logic request_sync_1;
    (* ASYNC_REG = "TRUE" *) logic request_sync_2;
    (* ASYNC_REG = "TRUE" *) logic request_sync_3;

    assign source_ready = source_request_toggle == acknowledge_sync_2;

    always_ff @(posedge source_clk) begin
        if (source_reset) begin
            source_payload <= '0;
            source_request_toggle <= 1'b0;
            acknowledge_sync_1 <= 1'b0;
            acknowledge_sync_2 <= 1'b0;
            source_overflow <= 1'b0;
        end else begin
            acknowledge_sync_1 <= destination_acknowledge_toggle;
            acknowledge_sync_2 <= acknowledge_sync_1;
            source_overflow <= 1'b0;

            if (source_valid) begin
                if (source_ready) begin
                    source_payload <= {
                        source_message_type,
                        source_sequence_number,
                        source_instrument_id,
                        source_price,
                        source_quantity
                    };
                    source_request_toggle <= !source_request_toggle;
                end else begin
                    source_overflow <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge destination_clk) begin
        if (destination_reset) begin
            payload_sync_1 <= '0;
            payload_sync_2 <= '0;
            request_sync_1 <= 1'b0;
            request_sync_2 <= 1'b0;
            request_sync_3 <= 1'b0;
            destination_acknowledge_toggle <= 1'b0;
            destination_valid <= 1'b0;
            destination_message_type <= 8'h00;
            destination_sequence_number <= 32'h0000_0000;
            destination_instrument_id <= 16'h0000;
            destination_price <= 32'h0000_0000;
            destination_quantity <= 32'h0000_0000;
        end else begin
            payload_sync_1 <= source_payload;
            payload_sync_2 <= payload_sync_1;
            request_sync_1 <= source_request_toggle;
            request_sync_2 <= request_sync_1;
            request_sync_3 <= request_sync_2;
            if (!destination_valid &&
                request_sync_3 != destination_acknowledge_toggle) begin
                {
                    destination_message_type,
                    destination_sequence_number,
                    destination_instrument_id,
                    destination_price,
                    destination_quantity
                } <= payload_sync_2;
                destination_valid <= 1'b1;
            end else if (destination_valid && destination_ready) begin
                destination_valid <= 1'b0;
                destination_acknowledge_toggle <= request_sync_3;
            end
        end
    end

endmodule
