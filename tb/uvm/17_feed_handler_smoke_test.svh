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
        smoke_sequence.start(env.input_agent.sequencer);
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
