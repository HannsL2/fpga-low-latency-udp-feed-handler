package feed_handler_uvm_pkg;
    import uvm_pkg::*;
    import feed_handler_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        RESULT_PAYLOAD,
        RESULT_MESSAGE,
        RESULT_REJECT,
        RESULT_SEQUENCE
    } feed_result_kind_t;

    typedef enum bit [1:0] {
        DESTINATION_ACCEPT,
        DESTINATION_MAC_REJECT,
        DESTINATION_IP_REJECT,
        DESTINATION_PORT_REJECT
    } destination_case_t;

    typedef enum bit [1:0] {
        SEQUENCE_NORMAL,
        SEQUENCE_GAP_CASE,
        SEQUENCE_DUPLICATE_CASE,
        SEQUENCE_OLDER_CASE
    } sequence_case_t;

    localparam int unsigned RANDOM_PACKET_COUNT = 40;

    class feed_packet_item extends uvm_sequence_item;
        bit [7:0] packet_bytes[$];
        rand int unsigned input_gap_cycles;
        rand int unsigned idle_cycles;
        rand int unsigned payload_stall_cycles;

        constraint timing_limits {
            input_gap_cycles inside {[0:3]};
            idle_cycles inside {[2:8]};
            payload_stall_cycles inside {[0:8]};
        }

        `uvm_object_utils(feed_packet_item)

        function new(string name = "feed_packet_item");
            super.new(name);
            input_gap_cycles = 0;
            idle_cycles = 3;
            payload_stall_cycles = 0;
        endfunction

        virtual function void do_copy(uvm_object rhs);
            feed_packet_item source;
            super.do_copy(rhs);
            if (!$cast(source, rhs)) begin
                `uvm_fatal("COPY", "feed_packet_item copy used with the wrong type")
            end
            packet_bytes = source.packet_bytes;
            input_gap_cycles = source.input_gap_cycles;
            idle_cycles = source.idle_cycles;
            payload_stall_cycles = source.payload_stall_cycles;
        endfunction

        virtual function string convert2string();
            return $sformatf("bytes=%0d gap=%0d idle=%0d payload_stall=%0d",
                             packet_bytes.size(), input_gap_cycles, idle_cycles,
                             payload_stall_cycles);
        endfunction
    endclass

    class feed_result_item extends uvm_sequence_item;
        feed_result_kind_t kind;
        bit [7:0] payload[$];
        reject_reason_t reject_reason;
        bit [7:0] protocol_version;
        bit [7:0] message_type;
        bit [31:0] sequence_number;
        bit [15:0] instrument_id;
        bit [31:0] price;
        bit [31:0] quantity;
        bit sequence_gap;
        bit sequence_duplicate;
        bit sequence_out_of_order;
        bit [31:0] expected_sequence;
        bit [31:0] received_sequence;
        bit [31:0] missing_message_count;

        `uvm_object_utils(feed_result_item)

        function new(string name = "feed_result_item");
            super.new(name);
            reject_reason = REJECT_NONE;
        endfunction

        virtual function string convert2string();
            case (kind)
                RESULT_PAYLOAD:
                    return $sformatf("payload bytes=%0d", payload.size());
                RESULT_MESSAGE:
                    return $sformatf("message type=%02h sequence=%0d instrument=%04h price=%0d quantity=%0d",
                                     message_type, sequence_number, instrument_id,
                                     price, quantity);
                RESULT_REJECT:
                    return $sformatf("reject reason=%0d", reject_reason);
                RESULT_SEQUENCE:
                    return $sformatf("sequence expected=%0d received=%0d gap=%0b duplicate=%0b older=%0b missing=%0d",
                                     expected_sequence, received_sequence, sequence_gap,
                                     sequence_duplicate, sequence_out_of_order,
                                     missing_message_count);
                default:
                    return "unknown result";
            endcase
        endfunction
    endclass

    class feed_handler_driver extends uvm_driver #(feed_packet_item);
        `uvm_component_utils(feed_handler_driver)

        virtual feed_handler_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the driver")
            end
        endfunction

        task apply_reset();
            vif.reset <= 1'b1;
            vif.s_data <= 8'h00;
            vif.s_valid <= 1'b0;
            vif.s_last <= 1'b0;
            vif.m_payload_ready <= 1'b1;
            repeat (4) @(posedge vif.clk);
            @(negedge vif.clk);
            vif.reset <= 1'b0;
            repeat (2) @(posedge vif.clk);
        endtask

        task drive_payload_stall(int unsigned stall_cycles);
            if (stall_cycles == 0) return;
            do @(posedge vif.clk); while (!vif.m_payload_valid);
            @(negedge vif.clk);
            vif.m_payload_ready <= 1'b0;
            repeat (stall_cycles) @(posedge vif.clk);
            @(negedge vif.clk);
            vif.m_payload_ready <= 1'b1;
        endtask

        task drive_packet(feed_packet_item item);
            foreach (item.packet_bytes[index]) begin
                repeat (item.input_gap_cycles) begin
                    @(negedge vif.clk);
                    vif.s_valid <= 1'b0;
                    vif.s_last <= 1'b0;
                end

                @(negedge vif.clk);
                vif.s_data <= item.packet_bytes[index];
                vif.s_valid <= 1'b1;
                vif.s_last <= (index == item.packet_bytes.size() - 1);

                do @(posedge vif.clk); while (!vif.s_ready);
            end

            @(negedge vif.clk);
            vif.s_valid <= 1'b0;
            vif.s_last <= 1'b0;
            repeat (item.idle_cycles) @(posedge vif.clk);
        endtask

        task run_phase(uvm_phase phase);
            feed_packet_item request;
            apply_reset();

            forever begin
                seq_item_port.get_next_item(request);
                fork
                    drive_packet(request);
                    drive_payload_stall(request.payload_stall_cycles);
                join
                vif.m_payload_ready <= 1'b1;
                seq_item_port.item_done();
            end
        endtask
    endclass

    class feed_input_monitor extends uvm_component;
        `uvm_component_utils(feed_input_monitor)

        virtual feed_handler_if vif;
        uvm_analysis_port #(feed_packet_item) packet_ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            packet_ap = new("packet_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the input monitor")
            end
        endfunction

        task run_phase(uvm_phase phase);
            feed_packet_item observed_packet;
            observed_packet = feed_packet_item::type_id::create("observed_packet");

            forever begin
                @(posedge vif.clk);
                if (vif.reset) begin
                    observed_packet.packet_bytes.delete();
                end else if (vif.s_valid && vif.s_ready) begin
                    observed_packet.packet_bytes.push_back(vif.s_data);
                    if (vif.s_last) begin
                        packet_ap.write(observed_packet);
                        observed_packet = feed_packet_item::type_id::create("observed_packet");
                    end
                end
            end
        endtask
    endclass

    class feed_output_monitor extends uvm_component;
        `uvm_component_utils(feed_output_monitor)

        virtual feed_handler_if vif;
        uvm_analysis_port #(feed_result_item) result_ap;
        bit [7:0] payload_bytes[$];

        function new(string name, uvm_component parent);
            super.new(name, parent);
            result_ap = new("result_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the output monitor")
            end
        endfunction

        task run_phase(uvm_phase phase);
            feed_result_item result;

            forever begin
                @(posedge vif.clk);
                if (vif.reset) begin
                    payload_bytes.delete();
                end else begin
                    if (vif.m_payload_valid && vif.m_payload_ready) begin
                        payload_bytes.push_back(vif.m_payload_data);
                        if (vif.m_payload_last) begin
                            result = feed_result_item::type_id::create("payload_result");
                            result.kind = RESULT_PAYLOAD;
                            result.payload = payload_bytes;
                            result_ap.write(result);
                            payload_bytes.delete();
                        end
                    end

                    if (vif.message_valid) begin
                        result = feed_result_item::type_id::create("message_result");
                        result.kind = RESULT_MESSAGE;
                        result.protocol_version = vif.protocol_version;
                        result.message_type = vif.message_type;
                        result.sequence_number = vif.sequence_number;
                        result.instrument_id = vif.instrument_id;
                        result.price = vif.price;
                        result.quantity = vif.quantity;
                        result_ap.write(result);
                    end

                    if (vif.reject_valid) begin
                        result = feed_result_item::type_id::create("reject_result");
                        result.kind = RESULT_REJECT;
                        result.reject_reason = reject_reason_t'(vif.reject_reason);
                        result_ap.write(result);
                    end

                    if (vif.sequence_event_valid) begin
                        result = feed_result_item::type_id::create("sequence_result");
                        result.kind = RESULT_SEQUENCE;
                        result.sequence_gap = vif.sequence_gap;
                        result.sequence_duplicate = vif.sequence_duplicate;
                        result.sequence_out_of_order = vif.sequence_out_of_order;
                        result.expected_sequence = vif.expected_sequence;
                        result.received_sequence = vif.received_sequence;
                        result.missing_message_count = vif.missing_message_count;
                        result_ap.write(result);
                    end
                end
            end
        endtask
    endclass

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

    class feed_handler_coverage extends uvm_subscriber #(feed_result_item);
        `uvm_component_utils(feed_handler_coverage)

        feed_result_kind_t sampled_kind;
        bit [7:0] sampled_message_type;
        reject_reason_t sampled_reject_reason;
        bit [2:0] sampled_sequence_class;

        covergroup result_coverage;
            option.per_instance = 1;
            result_kind: coverpoint sampled_kind;
            message_type: coverpoint sampled_message_type
                iff (sampled_kind == RESULT_MESSAGE) {
                bins add_order = {MESSAGE_ADD_ORDER};
                bins cancel_order = {MESSAGE_CANCEL_ORDER};
                bins trade = {MESSAGE_TRADE};
                bins system_event = {MESSAGE_SYSTEM_EVENT};
            }
            reject_reason: coverpoint sampled_reject_reason
                iff (sampled_kind == RESULT_REJECT);
            sequence_class: coverpoint sampled_sequence_class
                iff (sampled_kind == RESULT_SEQUENCE) {
                bins normal = {3'b000};
                bins gap = {3'b100};
                bins duplicate = {3'b010};
                bins out_of_order = {3'b001};
                illegal_bins multiple = default;
            }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            result_coverage = new();
        endfunction

        function void write(feed_result_item t);
            sampled_kind = t.kind;
            sampled_message_type = t.message_type;
            sampled_reject_reason = t.reject_reason;
            sampled_sequence_class = {t.sequence_gap,
                                      t.sequence_duplicate,
                                      t.sequence_out_of_order};
            result_coverage.sample();
        endfunction
    endclass

    class feed_handler_env extends uvm_env;
        `uvm_component_utils(feed_handler_env)

        uvm_sequencer #(feed_packet_item) sequencer;
        feed_handler_driver driver;
        feed_input_monitor input_monitor;
        feed_output_monitor output_monitor;
        feed_handler_scoreboard scoreboard;
        feed_handler_coverage coverage;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = uvm_sequencer#(feed_packet_item)::type_id::create("sequencer", this);
            driver = feed_handler_driver::type_id::create("driver", this);
            input_monitor = feed_input_monitor::type_id::create("input_monitor", this);
            output_monitor = feed_output_monitor::type_id::create("output_monitor", this);
            scoreboard = feed_handler_scoreboard::type_id::create("scoreboard", this);
            coverage = feed_handler_coverage::type_id::create("coverage", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            input_monitor.packet_ap.connect(scoreboard.packet_imp);
            output_monitor.result_ap.connect(scoreboard.result_imp);
            output_monitor.result_ap.connect(coverage.analysis_export);
        endfunction
    endclass

    class feed_handler_base_sequence extends uvm_sequence #(feed_packet_item);
        `uvm_object_utils(feed_handler_base_sequence)

        function new(string name = "feed_handler_base_sequence");
            super.new(name);
        endfunction

        function feed_packet_item create_packet(string item_name,
                                                bit [7:0] selected_type,
                                                bit [31:0] selected_sequence,
                                                bit [15:0] selected_port,
                                                int unsigned stall_cycles = 0);
            feed_packet_item item;
            bit [7:0] bytes[0:57];

            item = feed_packet_item::type_id::create(item_name);
            foreach (bytes[index]) bytes[index] = 8'h00;

            bytes[0] = 8'h02;
            bytes[5] = 8'h01;
            bytes[6] = 8'h10;
            bytes[7] = 8'h20;
            bytes[8] = 8'h30;
            bytes[9] = 8'h40;
            bytes[10] = 8'h50;
            bytes[11] = 8'h60;
            bytes[12] = 8'h08;
            bytes[13] = 8'h00;

            bytes[14] = 8'h45;
            bytes[16] = 8'h00;
            bytes[17] = 8'h2C;
            bytes[22] = 8'h40;
            bytes[23] = 8'h11;
            bytes[26] = 8'hC0;
            bytes[27] = 8'hA8;
            bytes[28] = 8'h01;
            bytes[29] = 8'h01;
            bytes[30] = 8'hC0;
            bytes[31] = 8'hA8;
            bytes[32] = 8'h01;
            bytes[33] = 8'h64;

            bytes[34] = 8'h27;
            bytes[35] = 8'h10;
            bytes[36] = selected_port[15:8];
            bytes[37] = selected_port[7:0];
            bytes[38] = 8'h00;
            bytes[39] = 8'h18;

            bytes[42] = MARKET_PROTOCOL_VERSION;
            bytes[43] = selected_type;
            bytes[44] = selected_sequence[31:24];
            bytes[45] = selected_sequence[23:16];
            bytes[46] = selected_sequence[15:8];
            bytes[47] = selected_sequence[7:0];
            bytes[48] = 8'h12;
            bytes[49] = 8'h34;
            bytes[50] = 8'h00;
            bytes[51] = 8'h00;
            bytes[52] = 8'h30;
            bytes[53] = 8'h39;
            bytes[54] = 8'h00;
            bytes[55] = 8'h00;
            bytes[56] = 8'h00;
            bytes[57] = 8'h64;

            foreach (bytes[index]) item.packet_bytes.push_back(bytes[index]);
            item.input_gap_cycles = 0;
            item.idle_cycles = 3;
            item.payload_stall_cycles = stall_cycles;
            return item;
        endfunction

        task send_packet(feed_packet_item item);
            start_item(item);
            finish_item(item);
        endtask
    endclass

    class feed_handler_smoke_sequence extends feed_handler_base_sequence;
        `uvm_object_utils(feed_handler_smoke_sequence)

        function new(string name = "feed_handler_smoke_sequence");
            super.new(name);
        endfunction

        task body();
            send_packet(create_packet("add_sequence_1", MESSAGE_ADD_ORDER,
                                      32'd1, 16'd18000));
            send_packet(create_packet("cancel_sequence_2", MESSAGE_CANCEL_ORDER,
                                      32'd2, 16'd18000, 3));
            send_packet(create_packet("rejected_trade_sequence_3", MESSAGE_TRADE,
                                      32'd3, 16'd18001));
            send_packet(create_packet("trade_sequence_5", MESSAGE_TRADE,
                                      32'd5, 16'd18000));
            send_packet(create_packet("system_sequence_6", MESSAGE_SYSTEM_EVENT,
                                      32'd6, 16'd18000));
        endtask
    endclass

    class feed_handler_random_sequence extends feed_handler_base_sequence;
        `uvm_object_utils(feed_handler_random_sequence)

        rand bit [1:0] message_type_index;
        rand destination_case_t destination_case;
        rand sequence_case_t sequence_case;
        rand int unsigned input_gap_cycles;
        rand int unsigned idle_cycles;
        rand int unsigned payload_stall_cycles;
        rand bit [15:0] selected_instrument;
        rand bit [31:0] selected_price;
        rand bit [31:0] selected_quantity;

        bit sequence_initialized;
        bit [31:0] last_accepted_sequence;

        constraint stimulus_distribution {
            destination_case dist {
                DESTINATION_ACCEPT := 7,
                DESTINATION_MAC_REJECT := 1,
                DESTINATION_IP_REJECT := 1,
                DESTINATION_PORT_REJECT := 1
            };
            sequence_case dist {
                SEQUENCE_NORMAL := 5,
                SEQUENCE_GAP_CASE := 2,
                SEQUENCE_DUPLICATE_CASE := 1,
                SEQUENCE_OLDER_CASE := 1
            };
            input_gap_cycles dist {0 := 5, 1 := 3, 2 := 2};
            idle_cycles inside {[3:5]};
            payload_stall_cycles inside {[0:4]};
            selected_instrument != 16'h0000;
            selected_quantity inside {[1:1_000_000]};
        }

        function new(string name = "feed_handler_random_sequence");
            super.new(name);
        endfunction

        function bit [7:0] selected_message_type();
            case (message_type_index)
                2'd0: return MESSAGE_ADD_ORDER;
                2'd1: return MESSAGE_CANCEL_ORDER;
                2'd2: return MESSAGE_TRADE;
                default: return MESSAGE_SYSTEM_EVENT;
            endcase
        endfunction

        function bit [31:0] choose_sequence_number();
            bit [31:0] selected_sequence;
            int unsigned offset;

            if (!sequence_initialized) begin
                return 32'd100;
            end

            offset = $urandom_range(4, 1);
            case (sequence_case)
                SEQUENCE_NORMAL:
                    selected_sequence = last_accepted_sequence + 32'd1;
                SEQUENCE_GAP_CASE:
                    selected_sequence = last_accepted_sequence + offset + 32'd1;
                SEQUENCE_DUPLICATE_CASE:
                    selected_sequence = last_accepted_sequence;
                default:
                    selected_sequence = last_accepted_sequence - offset;
            endcase
            return selected_sequence;
        endfunction

        function void update_sequence_model(bit [31:0] selected_sequence);
            if (!sequence_initialized) begin
                sequence_initialized = 1'b1;
                last_accepted_sequence = selected_sequence;
            end else if (sequence_case inside {SEQUENCE_NORMAL, SEQUENCE_GAP_CASE}) begin
                last_accepted_sequence = selected_sequence;
            end
        endfunction

        task body();
            feed_packet_item item;
            bit [31:0] selected_sequence;
            bit [15:0] selected_port;

            for (int unsigned packet_index = 0;
                 packet_index < RANDOM_PACKET_COUNT; packet_index++) begin
                if (!this.randomize()) begin
                    `uvm_fatal("RANDOMIZE", "Random packet controls could not be solved")
                end

                selected_sequence = choose_sequence_number();
                selected_port = destination_case == DESTINATION_PORT_REJECT ?
                                16'd18001 : 16'd18000;
                item = create_packet($sformatf("random_packet_%0d", packet_index),
                                     selected_message_type(), selected_sequence,
                                     selected_port);

                item.packet_bytes[48] = selected_instrument[15:8];
                item.packet_bytes[49] = selected_instrument[7:0];
                item.packet_bytes[50] = selected_price[31:24];
                item.packet_bytes[51] = selected_price[23:16];
                item.packet_bytes[52] = selected_price[15:8];
                item.packet_bytes[53] = selected_price[7:0];
                item.packet_bytes[54] = selected_quantity[31:24];
                item.packet_bytes[55] = selected_quantity[23:16];
                item.packet_bytes[56] = selected_quantity[15:8];
                item.packet_bytes[57] = selected_quantity[7:0];

                if (destination_case == DESTINATION_MAC_REJECT) begin
                    item.packet_bytes[5] ^= 8'h01;
                end else if (destination_case == DESTINATION_IP_REJECT) begin
                    item.packet_bytes[33] ^= 8'h01;
                end

                item.input_gap_cycles = input_gap_cycles;
                item.idle_cycles = idle_cycles;
                item.payload_stall_cycles = destination_case == DESTINATION_ACCEPT ?
                                            payload_stall_cycles : 0;
                send_packet(item);

                if (destination_case == DESTINATION_ACCEPT) begin
                    update_sequence_model(selected_sequence);
                end
            end
        endtask
    endclass

    class feed_handler_base_test extends uvm_test;
        `uvm_component_utils(feed_handler_base_test)

        feed_handler_env env;
        virtual feed_handler_if vif;

        function new(string name = "feed_handler_base_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = feed_handler_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the test")
            end
        endfunction
    endclass

    class feed_handler_smoke_test extends feed_handler_base_test;
        `uvm_component_utils(feed_handler_smoke_test)

        function new(string name = "feed_handler_smoke_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            feed_handler_smoke_sequence smoke_sequence;
            phase.raise_objection(this);
            smoke_sequence = feed_handler_smoke_sequence::type_id::create("smoke_sequence");
            smoke_sequence.start(env.sequencer);
            repeat (12) @(posedge vif.clk);

            if (vif.total_packet_count != 5 ||
                vif.accepted_packet_count != 4 ||
                vif.rejected_packet_count != 1 ||
                vif.valid_message_count != 4 ||
                vif.destination_port_mismatch_count != 1 ||
                vif.sequence_gap_count != 1 ||
                vif.missing_message_total != 2) begin
                `uvm_error("COUNTERS", "Final packet, message, rejection or sequence counters were incorrect")
            end

            `uvm_info("TEST", "UVM packet generation, monitoring, scoreboard and coverage scenario completed", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass

    class feed_handler_random_test extends feed_handler_base_test;
        `uvm_component_utils(feed_handler_random_test)

        function new(string name = "feed_handler_random_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            feed_handler_random_sequence random_sequence;
            phase.raise_objection(this);
            random_sequence = feed_handler_random_sequence::type_id::create("random_sequence");
            random_sequence.start(env.sequencer);
            repeat (12) @(posedge vif.clk);

            if (vif.total_packet_count != RANDOM_PACKET_COUNT ||
                vif.accepted_packet_count + vif.rejected_packet_count !=
                    RANDOM_PACKET_COUNT ||
                vif.accepted_packet_count != vif.valid_message_count ||
                vif.rejected_packet_count !=
                    vif.destination_mac_mismatch_count +
                    vif.destination_ip_mismatch_count +
                    vif.destination_port_mismatch_count) begin
                `uvm_error("COUNTERS", "Random-regression packet and destination counters were inconsistent")
            end

            if (vif.sequence_gap_count == 0 ||
                vif.duplicate_message_count == 0 ||
                vif.out_of_order_message_count == 0 ||
                vif.missing_message_total == 0) begin
                `uvm_error("SEQUENCE_COVERAGE", "Random regression did not exercise every sequence classification")
            end

            `uvm_info("RANDOM_TEST", $sformatf("Completed %0d constrained-random packets: accepted=%0d rejected=%0d gaps=%0d duplicates=%0d older=%0d",
                                              RANDOM_PACKET_COUNT,
                                              vif.accepted_packet_count,
                                              vif.rejected_packet_count,
                                              vif.sequence_gap_count,
                                              vif.duplicate_message_count,
                                              vif.out_of_order_message_count), UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass

endpackage
