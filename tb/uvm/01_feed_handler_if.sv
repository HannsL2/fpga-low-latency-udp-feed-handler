interface feed_handler_if(input logic clk);
    logic reset;

    logic [7:0] s_data;
    logic       s_valid;
    logic       s_ready;
    logic       s_last;

    logic [7:0] m_payload_data;
    logic       m_payload_valid;
    logic       m_payload_ready;
    logic       m_payload_last;

    logic        message_valid;
    logic [7:0]  protocol_version;
    logic [7:0]  message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;

    logic                             reject_valid;
    logic [3:0]                       reject_reason;
    logic                             sequence_event_valid;
    logic                             sequence_gap;
    logic                             sequence_duplicate;
    logic                             sequence_out_of_order;
    logic [31:0]                      expected_sequence;
    logic [31:0]                      received_sequence;
    logic [31:0]                      missing_message_count;

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

endinterface
