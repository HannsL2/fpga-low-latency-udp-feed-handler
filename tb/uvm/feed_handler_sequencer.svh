class feed_handler_sequencer extends uvm_sequencer #(feed_packet_item);
    `uvm_component_utils(feed_handler_sequencer)

    function new(string name = "feed_handler_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
