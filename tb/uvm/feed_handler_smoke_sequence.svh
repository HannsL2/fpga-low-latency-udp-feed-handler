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
