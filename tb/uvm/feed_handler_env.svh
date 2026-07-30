class feed_handler_env extends uvm_env;
    `uvm_component_utils(feed_handler_env)

    feed_input_agent input_agent;
    feed_output_monitor output_monitor;
    feed_handler_scoreboard scoreboard;
    feed_handler_coverage coverage;

    function new(string name = "feed_handler_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        input_agent = feed_input_agent::type_id::create("input_agent", this);
        output_monitor = feed_output_monitor::type_id::create("output_monitor", this);
        scoreboard = feed_handler_scoreboard::type_id::create("scoreboard", this);
        coverage = feed_handler_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        input_agent.monitor.packet_ap.connect(scoreboard.packet_imp);
        output_monitor.result_ap.connect(scoreboard.result_imp);
        output_monitor.result_ap.connect(coverage.analysis_export);
    endfunction
endclass
