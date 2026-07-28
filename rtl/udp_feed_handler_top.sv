module udp_feed_handler_top #(
    parameter logic [47:0] EXPECTED_DESTINATION_MAC = 48'h02_00_00_00_00_01,
    parameter logic [31:0] EXPECTED_DESTINATION_IP  = 32'hC0_A8_01_64,
    parameter logic [15:0] EXPECTED_DESTINATION_PORT = 16'd18000
) (
    input  logic        clk,
    input  logic        reset,

    input  logic [7:0]  s_data,
    input  logic        s_valid,
    output logic        s_ready,
    input  logic        s_last,

    output logic [7:0]  m_payload_data,
    output logic        m_payload_valid,
    input  logic        m_payload_ready,
    output logic        m_payload_last,

    output logic        message_valid,
    output logic [7:0]  protocol_version,
    output logic [7:0]  message_type,
    output logic [31:0] sequence_number,
    output logic [15:0] instrument_id,
    output logic [31:0] price,
    output logic [31:0] quantity,

    output logic                         reject_valid,
    output feed_handler_pkg::reject_reason_t reject_reason,
    output logic                         sequence_event_valid,
    output logic                         sequence_gap,
    output logic                         sequence_duplicate,
    output logic                         sequence_out_of_order,
    output logic [31:0]                  expected_sequence,
    output logic [31:0]                  received_sequence,
    output logic [31:0]                  missing_message_count,

    output logic [31:0] total_packet_count,
    output logic [31:0] accepted_packet_count,
    output logic [31:0] rejected_packet_count
);

    logic        input_transfer;
    logic        packet_start;
    logic        packet_end;
    logic        packet_active;
    logic [15:0] packet_byte_index;

    logic        ethernet_header_valid;
    logic        short_ethernet_frame;
    logic [47:0] destination_mac;
    logic [47:0] source_mac;
    logic [15:0] ether_type;

    logic        ipv4_header_valid;
    logic        ipv4_reject_valid;
    feed_handler_pkg::reject_reason_t ipv4_reject_reason;
    logic [3:0]  ipv4_version;
    logic [3:0]  ipv4_header_length;
    logic [15:0] ipv4_total_length;
    logic [15:0] ipv4_fragment_field;
    logic [7:0]  ipv4_protocol;
    logic [31:0] source_ip;
    logic [31:0] destination_ip;

    logic        udp_header_valid;
    logic        udp_reject_valid;
    feed_handler_pkg::reject_reason_t udp_reject_reason;
    logic [15:0] source_port;
    logic [15:0] destination_port;
    logic [15:0] udp_length;
    logic [15:0] udp_checksum;

    logic        filter_decision_valid;
    logic        filter_packet_accepted;
    logic        filter_reject_valid;
    feed_handler_pkg::reject_reason_t filter_reject_reason;

    stream_packet_controller packet_controller (
        .clk,
        .reset,
        .s_valid,
        .s_ready,
        .s_last,
        .transfer(input_transfer),
        .packet_start,
        .packet_end,
        .packet_active,
        .byte_index(packet_byte_index)
    );

    ethernet_parser ethernet_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer(input_transfer),
        .packet_start,
        .packet_end,
        .byte_index(packet_byte_index),
        .header_valid(ethernet_header_valid),
        .short_frame(short_ethernet_frame),
        .destination_mac,
        .source_mac,
        .ether_type
    );

    ipv4_parser ipv4_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer(input_transfer),
        .packet_end,
        .packet_active,
        .byte_index(packet_byte_index),
        .ethernet_header_valid,
        .ether_type,
        .header_valid(ipv4_header_valid),
        .reject_valid(ipv4_reject_valid),
        .reject_reason(ipv4_reject_reason),
        .version(ipv4_version),
        .header_length(ipv4_header_length),
        .total_length(ipv4_total_length),
        .fragment_field(ipv4_fragment_field),
        .protocol(ipv4_protocol),
        .source_ip,
        .destination_ip
    );

    udp_parser udp_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer(input_transfer),
        .packet_end,
        .packet_active,
        .byte_index(packet_byte_index),
        .ipv4_header_valid,
        .ipv4_total_length,
        .header_valid(udp_header_valid),
        .reject_valid(udp_reject_valid),
        .reject_reason(udp_reject_reason),
        .source_port,
        .destination_port,
        .udp_length,
        .checksum(udp_checksum)
    );

    packet_filter #(
        .EXPECTED_DESTINATION_MAC(EXPECTED_DESTINATION_MAC),
        .EXPECTED_DESTINATION_IP(EXPECTED_DESTINATION_IP),
        .EXPECTED_DESTINATION_PORT(EXPECTED_DESTINATION_PORT)
    ) packet_filter_inst (
        .udp_header_valid,
        .destination_mac,
        .destination_ip,
        .destination_port,
        .decision_valid(filter_decision_valid),
        .packet_accepted(filter_packet_accepted),
        .reject_valid(filter_reject_valid),
        .reject_reason(filter_reject_reason)
    );

    // Payload decoding and sequence tracking are connected after the packet
    // has passed the header checks and destination filter.
    always_comb begin
        s_ready = !reset;

        m_payload_data = 8'h00;
        m_payload_valid = 1'b0;
        m_payload_last = 1'b0;

        message_valid = 1'b0;
        protocol_version = 8'h00;
        message_type = 8'h00;
        sequence_number = 32'h0000_0000;
        instrument_id = 16'h0000;
        price = 32'h0000_0000;
        quantity = 32'h0000_0000;

        reject_valid = short_ethernet_frame || ipv4_reject_valid ||
                       udp_reject_valid || filter_reject_valid;
        if (short_ethernet_frame) begin
            reject_reason = feed_handler_pkg::REJECT_SHORT_ETHERNET;
        end else if (ipv4_reject_valid) begin
            reject_reason = ipv4_reject_reason;
        end else if (udp_reject_valid) begin
            reject_reason = udp_reject_reason;
        end else if (filter_reject_valid) begin
            reject_reason = filter_reject_reason;
        end else begin
            reject_reason = feed_handler_pkg::REJECT_NONE;
        end
        sequence_event_valid = 1'b0;
        sequence_gap = 1'b0;
        sequence_duplicate = 1'b0;
        sequence_out_of_order = 1'b0;
        expected_sequence = 32'h0000_0000;
        received_sequence = 32'h0000_0000;
        missing_message_count = 32'h0000_0000;

        total_packet_count = 32'h0000_0000;
        accepted_packet_count = 32'h0000_0000;
        rejected_packet_count = 32'h0000_0000;
    end

endmodule
