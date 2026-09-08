module statistics_counters (
    input  logic        clk,
    input  logic        reset,
    input  logic        packet_end,
    input  logic        reject_valid,
    input  feed_handler_pkg::reject_reason_t reject_reason,
    input  logic        message_valid,
    input  logic        sequence_event_valid,
    input  logic        sequence_gap,
    input  logic        sequence_duplicate,
    input  logic        sequence_out_of_order,
    input  logic [31:0] missing_message_count,

    output logic [31:0] total_packet_count,
    output logic [31:0] accepted_packet_count,
    output logic [31:0] rejected_packet_count,
    output logic [31:0] malformed_packet_count,
    output logic [31:0] unsupported_ethertype_count,
    output logic [31:0] non_udp_packet_count,
    output logic [31:0] destination_mac_mismatch_count,
    output logic [31:0] destination_ip_mismatch_count,
    output logic [31:0] destination_port_mismatch_count,
    output logic [31:0] valid_message_count,
    output logic [31:0] sequence_gap_count,
    output logic [31:0] missing_message_total,
    output logic [31:0] duplicate_message_count,
    output logic [31:0] out_of_order_message_count
);

    always_ff @(posedge clk) begin
        if (reset) begin
            total_packet_count <= 32'h0000_0000;
            accepted_packet_count <= 32'h0000_0000;
            rejected_packet_count <= 32'h0000_0000;
            malformed_packet_count <= 32'h0000_0000;
            unsupported_ethertype_count <= 32'h0000_0000;
            non_udp_packet_count <= 32'h0000_0000;
            destination_mac_mismatch_count <= 32'h0000_0000;
            destination_ip_mismatch_count <= 32'h0000_0000;
            destination_port_mismatch_count <= 32'h0000_0000;
            valid_message_count <= 32'h0000_0000;
            sequence_gap_count <= 32'h0000_0000;
            missing_message_total <= 32'h0000_0000;
            duplicate_message_count <= 32'h0000_0000;
            out_of_order_message_count <= 32'h0000_0000;
        end else begin
            if (packet_end) begin
                total_packet_count <= total_packet_count + 32'd1;
            end

            if (message_valid) begin
                accepted_packet_count <= accepted_packet_count + 32'd1;
                valid_message_count <= valid_message_count + 32'd1;
            end

            if (reject_valid) begin
                rejected_packet_count <= rejected_packet_count + 32'd1;

                case (reject_reason)
                    feed_handler_pkg::REJECT_NONE: begin
                    end
                    feed_handler_pkg::REJECT_ETHERTYPE:
                        unsupported_ethertype_count <= unsupported_ethertype_count + 32'd1;
                    feed_handler_pkg::REJECT_NON_UDP:
                        non_udp_packet_count <= non_udp_packet_count + 32'd1;
                    feed_handler_pkg::REJECT_DESTINATION_MAC:
                        destination_mac_mismatch_count <= destination_mac_mismatch_count + 32'd1;
                    feed_handler_pkg::REJECT_DESTINATION_IP:
                        destination_ip_mismatch_count <= destination_ip_mismatch_count + 32'd1;
                    feed_handler_pkg::REJECT_DESTINATION_PORT:
                        destination_port_mismatch_count <= destination_port_mismatch_count + 32'd1;
                    default:
                        malformed_packet_count <= malformed_packet_count + 32'd1;
                endcase
            end

            if (sequence_event_valid) begin
                if (sequence_gap) begin
                    sequence_gap_count <= sequence_gap_count + 32'd1;
                    missing_message_total <= missing_message_total + missing_message_count;
                end
                if (sequence_duplicate) begin
                    duplicate_message_count <= duplicate_message_count + 32'd1;
                end
                if (sequence_out_of_order) begin
                    out_of_order_message_count <= out_of_order_message_count + 32'd1;
                end
            end
        end
    end

endmodule
