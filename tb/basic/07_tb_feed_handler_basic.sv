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
    logic [31:0] malformed_packet_count;
    logic [31:0] unsupported_ethertype_count;
    logic [31:0] non_udp_packet_count;
    logic [31:0] destination_mac_mismatch_count;
    logic [31:0] destination_ip_mismatch_count;
    logic [31:0] destination_port_mismatch_count;
    logic [31:0] valid_message_count;
    logic [31:0] sequence_gap_count;
    logic [31:0] missing_message_total;
    logic [31:0] duplicate_message_count;
    logic [31:0] out_of_order_message_count;

    logic [7:0] packet [0:PACKET_BYTES-1];
    logic [7:0] expected_payload [0:47];
    logic saw_add_order;
    int unsigned payload_count;
    int unsigned payload_last_count;
    int unsigned expected_payload_size;
    int unsigned message_count;
    int unsigned reject_event_count;
    int unsigned gap_event_count;
    reject_reason_t last_reject_reason;
    logic [31:0] last_gap_expected;
    logic [31:0] last_gap_received;
    logic [31:0] last_gap_missing;
    logic output_stalled;
    logic [7:0] stalled_data;
    logic stalled_last;

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
        .rejected_packet_count,
        .malformed_packet_count,
        .unsupported_ethertype_count,
        .non_udp_packet_count,
        .destination_mac_mismatch_count,
        .destination_ip_mismatch_count,
        .destination_port_mismatch_count,
        .valid_message_count,
        .sequence_gap_count,
        .missing_message_total,
        .duplicate_message_count,
        .out_of_order_message_count
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            saw_add_order <= 1'b0;
            payload_count <= 0;
            payload_last_count <= 0;
            message_count <= 0;
            reject_event_count <= 0;
            gap_event_count <= 0;
            last_reject_reason <= REJECT_NONE;
            last_gap_expected <= 32'h0000_0000;
            last_gap_received <= 32'h0000_0000;
            last_gap_missing <= 32'h0000_0000;
            output_stalled <= 1'b0;
        end else if (message_valid &&
                     protocol_version == MARKET_PROTOCOL_VERSION &&
                     message_type == MESSAGE_ADD_ORDER) begin
            saw_add_order <= 1'b1;
        end

        if (!reset) begin
            if (m_payload_valid && m_payload_ready) begin
                if (m_payload_data != expected_payload[payload_count]) begin
                    $fatal(1, "Payload byte %0d was corrupted.", payload_count);
                end
                payload_count <= payload_count + 1;
                if (m_payload_last) payload_last_count <= payload_last_count + 1;
            end

            if (message_valid) message_count <= message_count + 1;
            if (reject_valid) begin
                reject_event_count <= reject_event_count + 1;
                last_reject_reason <= reject_reason;
            end
            if (sequence_event_valid && sequence_gap) begin
                gap_event_count <= gap_event_count + 1;
                last_gap_expected <= expected_sequence;
                last_gap_received <= received_sequence;
                last_gap_missing <= missing_message_count;
            end

            if (m_payload_valid && !m_payload_ready) begin
                if (output_stalled &&
                    (m_payload_data != stalled_data || m_payload_last != stalled_last)) begin
                    $fatal(1, "Payload output changed while backpressured.");
                end
                output_stalled <= 1'b1;
                stalled_data <= m_payload_data;
                stalled_last <= m_payload_last;
            end else begin
                output_stalled <= 1'b0;
            end
        end
    end

    task automatic build_add_order_packet(
        input logic [31:0] selected_sequence,
        input logic [15:0] selected_destination_port
    );
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
            packet[36] = selected_destination_port[15:8];
            packet[37] = selected_destination_port[7:0];
            packet[38] = 8'h00;
            packet[39] = 8'h18;
            packet[40] = 8'h00;
            packet[41] = 8'h00;

            // Project Add Order: version, type, sequence, instrument,
            // price, and quantity, all multi-byte fields big-endian.
            packet[42] = 8'h01;
            packet[43] = 8'h01;
            packet[44] = selected_sequence[31:24];
            packet[45] = selected_sequence[23:16];
            packet[46] = selected_sequence[15:8];
            packet[47] = selected_sequence[7:0];
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

    task automatic record_expected_payload;
        int unsigned index;
        begin
            for (index = 0; index < 16; index++) begin
                expected_payload[expected_payload_size + index] = packet[42 + index];
            end
            expected_payload_size = expected_payload_size + 16;
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
        expected_payload_size = 0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        build_add_order_packet(32'd1, 16'd18000);
        record_expected_payload();
        fork
            send_packet();
            begin
                wait (payload_count == 4);
                @(negedge clk);
                m_payload_ready = 1'b0;
                repeat (3) @(posedge clk);
                @(negedge clk);
                m_payload_ready = 1'b1;
            end
        join

        build_add_order_packet(32'd2, 16'd18000);
        record_expected_payload();
        send_packet();

        build_add_order_packet(32'd3, 16'd18001);
        send_packet();

        build_add_order_packet(32'd5, 16'd18000);
        record_expected_payload();
        send_packet();

        repeat (8) @(posedge clk);

        if (!saw_add_order) begin
            $fatal(1, "Decoder output was not observed for the directed Add Order packet.");
        end
        if (message_count != 3 || reject_event_count != 1 ||
            last_reject_reason != REJECT_DESTINATION_PORT) begin
            $fatal(1, "Accepted and rejected message events were incorrect.");
        end
        if (payload_count != 48 || payload_last_count != 3) begin
            $fatal(1, "Accepted payload output totals were incorrect.");
        end
        if (sequence_number != 32'h0000_0005 || instrument_id != 16'h1234 ||
            price != 32'h0000_3039 || quantity != 32'h0000_0064) begin
            $fatal(1, "Decoded Add Order fields were incorrect.");
        end
        if (gap_event_count != 1 || last_gap_expected != 32'd3 ||
            last_gap_received != 32'd5 || last_gap_missing != 32'd2) begin
            $fatal(1, "Integrated sequence-gap result was incorrect.");
        end
        if (total_packet_count != 4 || accepted_packet_count != 3 ||
            rejected_packet_count != 1 || valid_message_count != 3) begin
            $fatal(1, "Integrated packet statistics were incorrect.");
        end
        if (malformed_packet_count != 0 || unsupported_ethertype_count != 0 ||
            non_udp_packet_count != 0 || destination_mac_mismatch_count != 0 ||
            destination_ip_mismatch_count != 0 || destination_port_mismatch_count != 1 ||
            sequence_gap_count != 1 || missing_message_total != 2 ||
            duplicate_message_count != 0 || out_of_order_message_count != 0) begin
            $fatal(1, "Unexpected error statistics were recorded.");
        end

        $display("PASS: integrated acceptance, rejection, backpressure, sequencing and statistics verified.");
        $finish;
    end

endmodule
