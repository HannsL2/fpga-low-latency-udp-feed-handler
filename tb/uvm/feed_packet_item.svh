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
