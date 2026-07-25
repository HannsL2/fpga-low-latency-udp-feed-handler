`timescale 1ns/1ps

module tb_feed_handler_basic;

    import feed_handler_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;
    localparam int unsigned PACKET_BYTES = 58;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] s_data;
    logic s_valid;
    logic s_ready;
    logic s_last;

    logic [7:0] m_payload_data;
    logic m_payload_valid;
    logic m_payload_ready;
    logic m_payload_last;

    logic message_valid;
    logic [7:0] protocol_version;
    logic [7:0] message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;

    reject_reason_t reject_reason;
    logic reject_valid;
    logic sequence_event_valid;
    logic sequence_gap;
    logic sequence_duplicate;
    logic sequence_out_of_order;
    logic [31:0] expected_sequence;
    logic [31:0] received_sequence;
    logic [31:0] missing_message_count;
    logic [31:0] total_packet_count;
    logic [31:0] accepted_packet_count;
    logic [31:0] rejected_packet_count;

    logic [7:0] packet [0:PACKET_BYTES-1];
    logic saw_add_order;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    udp_feed_handler_top dut (
        .clk,
        .reset,
        .s_data,
        .s_valid,
        .s_ready,
        .s_last,
        .m_payload_data,
        .m_payload_valid,
        .m_payload_ready,
        .m_payload_last,
        .message_valid,
        .protocol_version,
        .message_type,
        .sequence_number,
        .instrument_id,
        .price,
        .quantity,
        .reject_valid,
        .reject_reason,
        .sequence_event_valid,
        .sequence_gap,
        .sequence_duplicate,
        .sequence_out_of_order,
        .expected_sequence,
        .received_sequence,
        .missing_message_count,
        .total_packet_count,
        .accepted_packet_count,
        .rejected_packet_count
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            saw_add_order <= 1'b0;
        end else if (message_valid &&
                     protocol_version == MARKET_PROTOCOL_VERSION &&
                     message_type == MESSAGE_ADD_ORDER) begin
            saw_add_order <= 1'b1;
        end
    end

    task automatic build_add_order_packet;
        int unsigned index;
        begin
            for (index = 0; index < PACKET_BYTES; index++) begin
                packet[index] = 8'h00;
            end

            // Ethernet II header: destination, source, and IPv4 EtherType.
            packet[0]  = 8'h02;
            packet[1]  = 8'h00;
            packet[2]  = 8'h00;
            packet[3]  = 8'h00;
            packet[4]  = 8'h00;
            packet[5]  = 8'h01;
            packet[6]  = 8'h02;
            packet[7]  = 8'h00;
            packet[8]  = 8'h00;
            packet[9]  = 8'h00;
            packet[10] = 8'h00;
            packet[11] = 8'h02;
            packet[12] = 8'h08;
            packet[13] = 8'h00;

            // Fixed 20-byte IPv4 header. Header checksum validation is not
            // part of the supported receive path.
            packet[14] = 8'h45;
            packet[15] = 8'h00;
            packet[16] = 8'h00;
            packet[17] = 8'h2C;
            packet[18] = 8'h00;
            packet[19] = 8'h01;
            packet[20] = 8'h00;
            packet[21] = 8'h00;
            packet[22] = 8'h40;
            packet[23] = 8'h11;
            packet[24] = 8'h00;
            packet[25] = 8'h00;
            packet[26] = 8'hC0;
            packet[27] = 8'hA8;
            packet[28] = 8'h01;
            packet[29] = 8'h01;
            packet[30] = 8'hC0;
            packet[31] = 8'hA8;
            packet[32] = 8'h01;
            packet[33] = 8'h64;

            // UDP header: source port 10000, destination port 18000.
            packet[34] = 8'h27;
            packet[35] = 8'h10;
            packet[36] = 8'h46;
            packet[37] = 8'h50;
            packet[38] = 8'h00;
            packet[39] = 8'h18;
            packet[40] = 8'h00;
            packet[41] = 8'h00;

            // Project Add Order: version, type, sequence, instrument,
            // price, and quantity, all multi-byte fields big-endian.
            packet[42] = 8'h01;
            packet[43] = 8'h01;
            packet[44] = 8'h00;
            packet[45] = 8'h00;
            packet[46] = 8'h00;
            packet[47] = 8'h01;
            packet[48] = 8'h12;
            packet[49] = 8'h34;
            packet[50] = 8'h00;
            packet[51] = 8'h00;
            packet[52] = 8'h30;
            packet[53] = 8'h39;
            packet[54] = 8'h00;
            packet[55] = 8'h00;
            packet[56] = 8'h00;
            packet[57] = 8'h64;
        end
    endtask

    task automatic send_packet;
        int unsigned index;
        begin
            for (index = 0; index < PACKET_BYTES; index++) begin
                @(negedge clk);
                s_data = packet[index];
                s_valid = 1'b1;
                s_last = (index == PACKET_BYTES - 1);
                do begin
                    @(posedge clk);
                end while (!s_ready);
            end
            @(negedge clk);
            s_data = 8'h00;
            s_valid = 1'b0;
            s_last = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b1;
        s_data = 8'h00;
        s_valid = 1'b0;
        s_last = 1'b0;
        m_payload_ready = 1'b1;

        build_add_order_packet();

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        send_packet();
        repeat (4) @(posedge clk);

        if (!saw_add_order) begin
            $fatal(1, "Decoder output was not observed for the directed Add Order packet.");
        end

        $display("PASS: accepted Add Order message was decoded.");
        $finish;
    end

endmodule
