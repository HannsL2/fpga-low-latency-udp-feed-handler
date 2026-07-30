`timescale 1ns/1ps

module tb_statistics_counters;
    import feed_handler_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;
    logic clk = 1'b0;
    logic reset;
    logic packet_end;
    logic reject_valid;
    reject_reason_t reject_reason;
    logic message_valid;
    logic sequence_event_valid;
    logic sequence_gap;
    logic sequence_duplicate;
    logic sequence_out_of_order;
    logic [31:0] missing_message_count;
    logic [31:0] total_packet_count;
    logic [31:0] accepted_packet_count;
    logic [31:0] rejected_packet_count;
    logic [31:0] malformed_packet_count;
    logic [31:0] unsupported_ethertype_count;
    logic [31:0] non_udp_packet_count;
    logic [31:0] destination_mac_mismatch_count;
    logic [31:0] destination_ip_mismatch_count;
    logic [31:0] destination_port_mismatch_count;
    logic [31:0] valid_message_count;
    logic [31:0] sequence_gap_count;
    logic [31:0] missing_message_total;
    logic [31:0] duplicate_message_count;
    logic [31:0] out_of_order_message_count;

    always #(CLOCK_PERIOD / 2) clk = ~clk;
    statistics_counters dut (.*);

    task automatic pulse_packet_end;
        @(negedge clk); packet_end = 1'b1;
        @(posedge clk); @(negedge clk); packet_end = 1'b0;
    endtask

    task automatic pulse_message;
        @(negedge clk); message_valid = 1'b1;
        @(posedge clk); @(negedge clk); message_valid = 1'b0;
    endtask

    task automatic pulse_reject(input reject_reason_t reason);
        @(negedge clk); reject_reason = reason; reject_valid = 1'b1;
        @(posedge clk); @(negedge clk); reject_valid = 1'b0;
    endtask

    task automatic pulse_sequence(
        input logic gap,
        input logic duplicate,
        input logic older,
        input logic [31:0] missing
    );
        @(negedge clk);
        sequence_event_valid = 1'b1;
        sequence_gap = gap;
        sequence_duplicate = duplicate;
        sequence_out_of_order = older;
        missing_message_count = missing;
        @(posedge clk); @(negedge clk);
        sequence_event_valid = 1'b0;
        sequence_gap = 1'b0;
        sequence_duplicate = 1'b0;
        sequence_out_of_order = 1'b0;
        missing_message_count = 32'd0;
    endtask

    initial begin
        reset = 1'b1;
        packet_end = 1'b0;
        reject_valid = 1'b0;
        reject_reason = REJECT_NONE;
        message_valid = 1'b0;
        sequence_event_valid = 1'b0;
        sequence_gap = 1'b0;
        sequence_duplicate = 1'b0;
        sequence_out_of_order = 1'b0;
        missing_message_count = 32'd0;
        repeat (3) @(posedge clk);
        @(negedge clk); reset = 1'b0;

        repeat (8) pulse_packet_end();
        repeat (2) pulse_message();
        pulse_reject(REJECT_ETHERTYPE);
        pulse_reject(REJECT_NON_UDP);
        pulse_reject(REJECT_DESTINATION_MAC);
        pulse_reject(REJECT_DESTINATION_IP);
        pulse_reject(REJECT_DESTINATION_PORT);
        pulse_reject(REJECT_SHORT_UDP);

        pulse_sequence(1'b0, 1'b0, 1'b0, 32'd0);
        pulse_sequence(1'b1, 1'b0, 1'b0, 32'd4);
        pulse_sequence(1'b0, 1'b1, 1'b0, 32'd0);
        pulse_sequence(1'b0, 1'b0, 1'b1, 32'd0);

        if (total_packet_count != 8 || accepted_packet_count != 2 ||
            rejected_packet_count != 6 || valid_message_count != 2)
            $fatal(1, "Primary packet or message counters are incorrect.");
        if (malformed_packet_count != 1 || unsupported_ethertype_count != 1 ||
            non_udp_packet_count != 1 || destination_mac_mismatch_count != 1 ||
            destination_ip_mismatch_count != 1 || destination_port_mismatch_count != 1)
            $fatal(1, "Reject-reason counters are incorrect.");
        if (sequence_gap_count != 1 || missing_message_total != 4 ||
            duplicate_message_count != 1 || out_of_order_message_count != 1)
            $fatal(1, "Sequence statistics are incorrect.");

        $display("PASS: packet, rejection, message and sequence counters verified.");
        $finish;
    end
endmodule
