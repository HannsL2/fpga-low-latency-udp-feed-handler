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

    // Later receive-path blocks consume the parsed Ethernet fields. Their
    // interface outputs remain inactive until those blocks are connected.
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

        reject_valid = 1'b0;
        reject_reason = feed_handler_pkg::REJECT_NONE;
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
