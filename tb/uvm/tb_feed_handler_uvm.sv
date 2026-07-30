`timescale 1ns/1ps

module tb_feed_handler_uvm;
    import uvm_pkg::*;
    import feed_handler_uvm_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;

    logic clk = 1'b0;
    always #(CLOCK_PERIOD / 2) clk = ~clk;

    feed_handler_if vif(clk);

    udp_feed_handler_top dut (
        .clk,
        .reset(vif.reset),
        .s_data(vif.s_data),
        .s_valid(vif.s_valid),
        .s_ready(vif.s_ready),
        .s_last(vif.s_last),
        .m_payload_data(vif.m_payload_data),
        .m_payload_valid(vif.m_payload_valid),
        .m_payload_ready(vif.m_payload_ready),
        .m_payload_last(vif.m_payload_last),
        .message_valid(vif.message_valid),
        .protocol_version(vif.protocol_version),
        .message_type(vif.message_type),
        .sequence_number(vif.sequence_number),
        .instrument_id(vif.instrument_id),
        .price(vif.price),
        .quantity(vif.quantity),
        .reject_valid(vif.reject_valid),
        .reject_reason(vif.reject_reason),
        .sequence_event_valid(vif.sequence_event_valid),
        .sequence_gap(vif.sequence_gap),
        .sequence_duplicate(vif.sequence_duplicate),
        .sequence_out_of_order(vif.sequence_out_of_order),
        .expected_sequence(vif.expected_sequence),
        .received_sequence(vif.received_sequence),
        .missing_message_count(vif.missing_message_count),
        .total_packet_count(vif.total_packet_count),
        .accepted_packet_count(vif.accepted_packet_count),
        .rejected_packet_count(vif.rejected_packet_count),
        .malformed_packet_count(vif.malformed_packet_count),
        .unsupported_ethertype_count(vif.unsupported_ethertype_count),
        .non_udp_packet_count(vif.non_udp_packet_count),
        .destination_mac_mismatch_count(vif.destination_mac_mismatch_count),
        .destination_ip_mismatch_count(vif.destination_ip_mismatch_count),
        .destination_port_mismatch_count(vif.destination_port_mismatch_count),
        .valid_message_count(vif.valid_message_count),
        .sequence_gap_count(vif.sequence_gap_count),
        .missing_message_total(vif.missing_message_total),
        .duplicate_message_count(vif.duplicate_message_count),
        .out_of_order_message_count(vif.out_of_order_message_count)
    );

    initial begin
        vif.reset = 1'b1;
        vif.s_data = 8'h00;
        vif.s_valid = 1'b0;
        vif.s_last = 1'b0;
        vif.m_payload_ready = 1'b1;
        uvm_config_db#(virtual feed_handler_if)::set(null, "uvm_test_top*", "vif", vif);
        run_test("feed_handler_smoke_test");
    end

    initial begin
        #100us;
        $fatal(1, "UVM test timed out.");
    end

endmodule
