`uvm_analysis_imp_decl(_packet)
`uvm_analysis_imp_decl(_result)

class feed_handler_scoreboard extends uvm_component;
    `uvm_component_utils(feed_handler_scoreboard)

    uvm_analysis_imp_packet #(feed_packet_item, feed_handler_scoreboard) packet_imp;
    uvm_analysis_imp_result #(feed_result_item, feed_handler_scoreboard) result_imp;
    feed_result_item expected_results[$];
    feed_result_item actual_results[$];
    bit sequence_initialized;
    bit [31:0] last_sequence;
    int unsigned checked_results;
    int unsigned error_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        packet_imp = new("packet_imp", this);
        result_imp = new("result_imp", this);
    endfunction

    function automatic bit [15:0] read_u16(feed_packet_item packet, int unsigned offset);
        return {packet.packet_bytes[offset], packet.packet_bytes[offset + 1]};
    endfunction

    function automatic bit [31:0] read_u32(feed_packet_item packet, int unsigned offset);
        return {packet.packet_bytes[offset], packet.packet_bytes[offset + 1],
                packet.packet_bytes[offset + 2], packet.packet_bytes[offset + 3]};
    endfunction

    function automatic bit [47:0] read_u48(feed_packet_item packet, int unsigned offset);
        return {packet.packet_bytes[offset], packet.packet_bytes[offset + 1],
                packet.packet_bytes[offset + 2], packet.packet_bytes[offset + 3],
                packet.packet_bytes[offset + 4], packet.packet_bytes[offset + 5]};
    endfunction

    function automatic bit supported_message_type(bit [7:0] selected_type);
        return selected_type inside {MESSAGE_ADD_ORDER, MESSAGE_CANCEL_ORDER,
                                     MESSAGE_TRADE, MESSAGE_SYSTEM_EVENT};
    endfunction

    function void queue_reject(reject_reason_t reason);
        feed_result_item expected;
        expected = feed_result_item::type_id::create("expected_reject");
        expected.kind = RESULT_REJECT;
        expected.reject_reason = reason;
        expected_results.push_back(expected);
    endfunction

    function void queue_accepted_results(feed_packet_item packet);
        feed_result_item expected;
        bit [31:0] selected_sequence;
        bit [31:0] expected_next;
        bit [31:0] forward_distance;

        expected = feed_result_item::type_id::create("expected_payload");
        expected.kind = RESULT_PAYLOAD;
        for (int unsigned index = 42; index < packet.packet_bytes.size(); index++) begin
            expected.payload.push_back(packet.packet_bytes[index]);
        end
        expected_results.push_back(expected);

        selected_sequence = read_u32(packet, 44);
        expected = feed_result_item::type_id::create("expected_message");
        expected.kind = RESULT_MESSAGE;
        expected.protocol_version = packet.packet_bytes[42];
        expected.message_type = packet.packet_bytes[43];
        expected.sequence_number = selected_sequence;
        expected.instrument_id = read_u16(packet, 48);
        expected.price = read_u32(packet, 50);
        expected.quantity = read_u32(packet, 54);
        expected_results.push_back(expected);

        expected = feed_result_item::type_id::create("expected_sequence");
        expected.kind = RESULT_SEQUENCE;
        expected.received_sequence = selected_sequence;
        if (!sequence_initialized) begin
            sequence_initialized = 1'b1;
            last_sequence = selected_sequence;
            expected.expected_sequence = selected_sequence;
        end else begin
            expected_next = last_sequence + 32'd1;
            forward_distance = selected_sequence - expected_next;
            expected.expected_sequence = expected_next;
            if (selected_sequence == expected_next) begin
                last_sequence = selected_sequence;
            end else if (selected_sequence == last_sequence) begin
                expected.sequence_duplicate = 1'b1;
            end else if (!forward_distance[31]) begin
                expected.sequence_gap = 1'b1;
                expected.missing_message_count = forward_distance;
                last_sequence = selected_sequence;
            end else begin
                expected.sequence_out_of_order = 1'b1;
            end
        end
        expected_results.push_back(expected);
    endfunction

    function void write_packet(feed_packet_item packet);
        reject_reason_t reason;
        reason = REJECT_NONE;

        if (packet.packet_bytes.size() < 14) begin
            reason = REJECT_SHORT_ETHERNET;
        end else if (read_u16(packet, 12) != ETHERTYPE_IPV4) begin
            reason = REJECT_ETHERTYPE;
        end else if (packet.packet_bytes.size() < 34) begin
            reason = REJECT_SHORT_IPV4;
        end else if (packet.packet_bytes[14][7:4] != 4) begin
            reason = REJECT_IPV4_VERSION;
        end else if (packet.packet_bytes[14][3:0] != 5) begin
            reason = REJECT_IPV4_HEADER_LENGTH;
        end else if ((read_u16(packet, 20) & 16'h3FFF) != 0) begin
            reason = REJECT_FRAGMENTED;
        end else if (packet.packet_bytes[23] != IPV4_PROTOCOL_UDP) begin
            reason = REJECT_NON_UDP;
        end else if (packet.packet_bytes.size() < 42) begin
            reason = REJECT_SHORT_UDP;
        end else if (read_u48(packet, 0) != 48'h02_00_00_00_00_01) begin
            reason = REJECT_DESTINATION_MAC;
        end else if (read_u32(packet, 30) != 32'hC0_A8_01_64) begin
            reason = REJECT_DESTINATION_IP;
        end else if (read_u16(packet, 36) != 16'd18000) begin
            reason = REJECT_DESTINATION_PORT;
        end else if (packet.packet_bytes.size() < 58) begin
            reason = REJECT_SHORT_PAYLOAD;
        end else if (packet.packet_bytes[42] != MARKET_PROTOCOL_VERSION) begin
            reason = REJECT_PROTOCOL_VERSION;
        end else if (!supported_message_type(packet.packet_bytes[43])) begin
            reason = REJECT_MESSAGE_TYPE;
        end else if (packet.packet_bytes.size() != 58) begin
            reason = REJECT_PAYLOAD_LENGTH;
        end

        if (reason == REJECT_NONE) begin
            queue_accepted_results(packet);
        end else begin
            queue_reject(reason);
        end
        compare_available();
    endfunction

    function void write_result(feed_result_item result);
        actual_results.push_back(result);
        compare_available();
    endfunction

    function automatic bit same_result(feed_result_item expected,
                                       feed_result_item actual);
        if (expected.kind != actual.kind) return 1'b0;
        case (expected.kind)
            RESULT_PAYLOAD: begin
                if (expected.payload.size() != actual.payload.size()) return 1'b0;
                foreach (expected.payload[index]) begin
                    if (expected.payload[index] != actual.payload[index]) return 1'b0;
                end
                return 1'b1;
            end
            RESULT_MESSAGE:
                return expected.protocol_version == actual.protocol_version &&
                       expected.message_type == actual.message_type &&
                       expected.sequence_number == actual.sequence_number &&
                       expected.instrument_id == actual.instrument_id &&
                       expected.price == actual.price &&
                       expected.quantity == actual.quantity;
            RESULT_REJECT:
                return expected.reject_reason == actual.reject_reason;
            RESULT_SEQUENCE:
                return expected.sequence_gap == actual.sequence_gap &&
                       expected.sequence_duplicate == actual.sequence_duplicate &&
                       expected.sequence_out_of_order == actual.sequence_out_of_order &&
                       expected.expected_sequence == actual.expected_sequence &&
                       expected.received_sequence == actual.received_sequence &&
                       expected.missing_message_count == actual.missing_message_count;
            default:
                return 1'b0;
        endcase
    endfunction

    function void compare_available();
        feed_result_item expected;
        feed_result_item actual;
        while (expected_results.size() != 0 && actual_results.size() != 0) begin
            expected = expected_results.pop_front();
            actual = actual_results.pop_front();
            checked_results++;
            if (!same_result(expected, actual)) begin
                error_count++;
                `uvm_error("MISMATCH", $sformatf("Expected %s; observed %s",
                                                 expected.convert2string(),
                                                 actual.convert2string()))
            end
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        compare_available();
        if (expected_results.size() != 0 || actual_results.size() != 0) begin
            `uvm_error("UNMATCHED", $sformatf("Unmatched results: expected=%0d actual=%0d",
                                              expected_results.size(),
                                              actual_results.size()))
        end
        if (error_count == 0 && checked_results != 0) begin
            `uvm_info("SCOREBOARD", $sformatf("Matched %0d payload, message, rejection and sequence results",
                                              checked_results), UVM_LOW)
        end
    endfunction
endclass
