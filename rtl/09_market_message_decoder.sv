module market_message_decoder (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  payload_data,
    input  logic        payload_valid,
    input  logic        payload_last,
    input  logic [15:0] payload_index,

    output logic        message_valid,
    output logic        reject_valid,
    output feed_handler_pkg::reject_reason_t reject_reason,
    output logic [7:0]  protocol_version,
    output logic [7:0]  message_type,
    output logic [31:0] sequence_number,
    output logic [15:0] instrument_id,
    output logic [31:0] price,
    output logic [31:0] quantity
);

    localparam logic [15:0] FINAL_MESSAGE_BYTE_INDEX = 16'd15;

    logic decoding_message;

    function automatic logic supported_message_type(input logic [7:0] value);
        supported_message_type = value == feed_handler_pkg::MESSAGE_ADD_ORDER ||
                                 value == feed_handler_pkg::MESSAGE_CANCEL_ORDER ||
                                 value == feed_handler_pkg::MESSAGE_TRADE ||
                                 value == feed_handler_pkg::MESSAGE_SYSTEM_EVENT;
    endfunction

    always_ff @(posedge clk) begin
        if (reset) begin
            decoding_message <= 1'b0;
            message_valid <= 1'b0;
            reject_valid <= 1'b0;
            reject_reason <= feed_handler_pkg::REJECT_NONE;
            protocol_version <= 8'h00;
            message_type <= 8'h00;
            sequence_number <= 32'h0000_0000;
            instrument_id <= 16'h0000;
            price <= 32'h0000_0000;
            quantity <= 32'h0000_0000;
        end else begin
            message_valid <= 1'b0;
            reject_valid <= 1'b0;

            if (payload_valid) begin
                if (payload_index == 16'd0) begin
                    decoding_message <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_NONE;
                    protocol_version <= payload_data;
                    message_type <= 8'h00;
                    sequence_number <= 32'h0000_0000;
                    instrument_id <= 16'h0000;
                    price <= 32'h0000_0000;
                    quantity <= 32'h0000_0000;
                end

                if (payload_last && payload_index < FINAL_MESSAGE_BYTE_INDEX) begin
                    decoding_message <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_SHORT_PAYLOAD;
                end else if (payload_index == 16'd0) begin
                    if (payload_data != feed_handler_pkg::MARKET_PROTOCOL_VERSION) begin
                        decoding_message <= 1'b0;
                        reject_valid <= 1'b1;
                        reject_reason <= feed_handler_pkg::REJECT_PROTOCOL_VERSION;
                    end
                end else if (decoding_message) begin
                    case (payload_index)
                        16'd1: begin
                            message_type <= payload_data;
                            if (!supported_message_type(payload_data)) begin
                                decoding_message <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_MESSAGE_TYPE;
                            end
                        end
                        16'd2: sequence_number[31:24] <= payload_data;
                        16'd3: sequence_number[23:16] <= payload_data;
                        16'd4: sequence_number[15:8] <= payload_data;
                        16'd5: sequence_number[7:0] <= payload_data;
                        16'd6: instrument_id[15:8] <= payload_data;
                        16'd7: instrument_id[7:0] <= payload_data;
                        16'd8: price[31:24] <= payload_data;
                        16'd9: price[23:16] <= payload_data;
                        16'd10: price[15:8] <= payload_data;
                        16'd11: price[7:0] <= payload_data;
                        16'd12: quantity[31:24] <= payload_data;
                        16'd13: quantity[23:16] <= payload_data;
                        16'd14: quantity[15:8] <= payload_data;
                        FINAL_MESSAGE_BYTE_INDEX: begin
                            quantity[7:0] <= payload_data;
                            decoding_message <= 1'b0;
                            if (payload_last) begin
                                message_valid <= 1'b1;
                            end else begin
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_PAYLOAD_LENGTH;
                            end
                        end
                        default: begin
                        end
                    endcase
                end
            end
        end
    end

endmodule
