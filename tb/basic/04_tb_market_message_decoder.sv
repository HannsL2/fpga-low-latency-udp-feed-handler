`timescale 1ns/1ps

module tb_market_message_decoder;
    import feed_handler_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;
    logic clk = 1'b0;
    logic reset;
    logic [7:0] payload_data;
    logic payload_valid;
    logic payload_last;
    logic [15:0] payload_index;
    logic message_valid;
    logic reject_valid;
    reject_reason_t reject_reason;
    logic [7:0] protocol_version;
    logic [7:0] message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;
    logic [7:0] message [0:16];
    int unsigned message_count;
    int unsigned reject_count;
    reject_reason_t last_reject_reason;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    market_message_decoder dut (.*);

    always_ff @(posedge clk) begin
        if (reset) begin
            message_count <= 0;
            reject_count <= 0;
            last_reject_reason <= REJECT_NONE;
        end else begin
            if (message_valid) message_count <= message_count + 1;
            if (reject_valid) begin
                reject_count <= reject_count + 1;
                last_reject_reason <= reject_reason;
            end
        end
    end

    task automatic build_message(input logic [7:0] selected_type);
        int unsigned index;
        begin
            for (index = 0; index < 17; index++) message[index] = 8'h00;
            message[0] = MARKET_PROTOCOL_VERSION;
            message[1] = selected_type;
            message[2] = 8'h12; message[3] = 8'h34;
            message[4] = 8'h56; message[5] = 8'h78;
            message[6] = 8'hAB; message[7] = 8'hCD;
            message[8] = 8'h01; message[9] = 8'h23;
            message[10] = 8'h45; message[11] = 8'h67;
            message[12] = 8'h89; message[13] = 8'hAB;
            message[14] = 8'hCD; message[15] = 8'hEF;
            message[16] = 8'h55;
        end
    endtask

    task automatic send_payload(input int unsigned length);
        int unsigned index;
        begin
            for (index = 0; index < length; index++) begin
                if (index == 6) begin
                    @(negedge clk); payload_valid = 1'b0;
                    repeat (2) @(posedge clk);
                end
                @(negedge clk);
                payload_data = message[index];
                payload_index = index;
                payload_valid = 1'b1;
                payload_last = (index == length - 1);
                @(posedge clk);
            end
            @(negedge clk);
            payload_valid = 1'b0;
            payload_last = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic expect_reject(input int unsigned count, input reject_reason_t reason);
        if (reject_count != count || last_reject_reason != reason)
            $fatal(1, "Unexpected decoder rejection: count=%0d reason=%0d", reject_count, last_reject_reason);
    endtask

    initial begin
        reset = 1'b1;
        payload_data = 8'h00;
        payload_valid = 1'b0;
        payload_last = 1'b0;
        payload_index = 16'd0;
        repeat (4) @(posedge clk);
        @(negedge clk); reset = 1'b0;

        build_message(MESSAGE_ADD_ORDER);
        send_payload(16);
        if (message_count != 1 || protocol_version != 8'h01 || message_type != MESSAGE_ADD_ORDER ||
            sequence_number != 32'h1234_5678 || instrument_id != 16'hABCD ||
            price != 32'h0123_4567 || quantity != 32'h89AB_CDEF)
            $fatal(1, "Add Order field extraction failed.");

        build_message(MESSAGE_CANCEL_ORDER); send_payload(16);
        build_message(MESSAGE_TRADE); send_payload(16);
        build_message(MESSAGE_SYSTEM_EVENT); send_payload(16);
        if (message_count != 4) $fatal(1, "A supported message type was rejected.");

        build_message(MESSAGE_ADD_ORDER); message[0] = 8'h02; send_payload(16);
        expect_reject(1, REJECT_PROTOCOL_VERSION);
        build_message(8'h7F); send_payload(16);
        expect_reject(2, REJECT_MESSAGE_TYPE);
        build_message(MESSAGE_ADD_ORDER); send_payload(8);
        expect_reject(3, REJECT_SHORT_PAYLOAD);
        build_message(MESSAGE_ADD_ORDER); send_payload(17);
        expect_reject(4, REJECT_PAYLOAD_LENGTH);

        if (message_count != 4) $fatal(1, "Malformed payload produced message_valid.");
        $display("PASS: market-message decoding and validation verified.");
        $finish;
    end
endmodule
