class feed_input_agent extends uvm_agent;
    `uvm_component_utils(feed_input_agent)

    feed_handler_sequencer sequencer;
    feed_handler_driver driver;
    feed_input_monitor monitor;

    function new(string name = "feed_input_agent",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = feed_handler_sequencer::type_id::create("sequencer", this);
        driver = feed_handler_driver::type_id::create("driver", this);
        monitor = feed_input_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
