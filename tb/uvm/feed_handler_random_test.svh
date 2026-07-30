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
        random_sequence.start(env.input_agent.sequencer);
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
