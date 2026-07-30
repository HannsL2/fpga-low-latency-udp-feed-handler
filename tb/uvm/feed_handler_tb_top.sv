`timescale 1ns/1ps

module feed_handler_tb_top;
    import uvm_pkg::*;
    import feed_handler_uvm_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;

    logic clk = 1'b0;
    always #(CLOCK_PERIOD / 2) clk = ~clk;

    feed_handler_if feed_handler_if(clk);

    udp_feed_handler_top DUT (
        .clk,
        .reset(feed_handler_if.reset),
        .s_data(feed_handler_if.s_data),
        .s_valid(feed_handler_if.s_valid),
        .s_ready(feed_handler_if.s_ready),
        .s_last(feed_handler_if.s_last),
        .m_payload_data(feed_handler_if.m_payload_data),
        .m_payload_valid(feed_handler_if.m_payload_valid),
        .m_payload_ready(feed_handler_if.m_payload_ready),
        .m_payload_last(feed_handler_if.m_payload_last),
        .message_valid(feed_handler_if.message_valid),
        .protocol_version(feed_handler_if.protocol_version),
        .message_type(feed_handler_if.message_type),
        .sequence_number(feed_handler_if.sequence_number),
        .instrument_id(feed_handler_if.instrument_id),
        .price(feed_handler_if.price),
        .quantity(feed_handler_if.quantity),
        .reject_valid(feed_handler_if.reject_valid),
        .reject_reason(feed_handler_if.reject_reason),
        .sequence_event_valid(feed_handler_if.sequence_event_valid),
        .sequence_gap(feed_handler_if.sequence_gap),
        .sequence_duplicate(feed_handler_if.sequence_duplicate),
        .sequence_out_of_order(feed_handler_if.sequence_out_of_order),
        .expected_sequence(feed_handler_if.expected_sequence),
        .received_sequence(feed_handler_if.received_sequence),
        .missing_message_count(feed_handler_if.missing_message_count),
        .total_packet_count(feed_handler_if.total_packet_count),
        .accepted_packet_count(feed_handler_if.accepted_packet_count),
        .rejected_packet_count(feed_handler_if.rejected_packet_count),
        .malformed_packet_count(feed_handler_if.malformed_packet_count),
        .unsupported_ethertype_count(feed_handler_if.unsupported_ethertype_count),
        .non_udp_packet_count(feed_handler_if.non_udp_packet_count),
        .destination_mac_mismatch_count(feed_handler_if.destination_mac_mismatch_count),
        .destination_ip_mismatch_count(feed_handler_if.destination_ip_mismatch_count),
        .destination_port_mismatch_count(feed_handler_if.destination_port_mismatch_count),
        .valid_message_count(feed_handler_if.valid_message_count),
        .sequence_gap_count(feed_handler_if.sequence_gap_count),
        .missing_message_total(feed_handler_if.missing_message_total),
        .duplicate_message_count(feed_handler_if.duplicate_message_count),
        .out_of_order_message_count(feed_handler_if.out_of_order_message_count)
    );

    initial begin
        feed_handler_if.reset = 1'b1;
        feed_handler_if.s_data = 8'h00;
        feed_handler_if.s_valid = 1'b0;
        feed_handler_if.s_last = 1'b0;
        feed_handler_if.m_payload_ready = 1'b1;
        uvm_config_db#(virtual feed_handler_if)::set(
            null,
            "uvm_test_top*",
            "vif",
            feed_handler_if
        );

        if ($test$plusargs("FEED_RANDOM_TEST")) begin
            run_test("feed_handler_random_test");
        end else begin
            run_test("feed_handler_smoke_test");
        end
    end

    initial begin
        #100us;
        $fatal(1, "UVM test timed out.");
    end
endmodule
