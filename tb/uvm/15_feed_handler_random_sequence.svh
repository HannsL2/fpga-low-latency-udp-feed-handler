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
