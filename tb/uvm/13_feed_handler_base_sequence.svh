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
