module packet_filter #(
    parameter logic [47:0] EXPECTED_DESTINATION_MAC = 48'h02_00_00_00_00_01,
    parameter logic [31:0] EXPECTED_DESTINATION_IP = 32'hC0_A8_01_64,
    parameter logic [15:0] EXPECTED_DESTINATION_PORT = 16'd18000
) (
    input  logic        udp_header_valid,
    input  logic [47:0] destination_mac,
    input  logic [31:0] destination_ip,
    input  logic [15:0] destination_port,

    output logic        decision_valid,
    output logic        packet_accepted,
    output logic        reject_valid,
    output feed_handler_pkg::reject_reason_t reject_reason
);

    always_comb begin
        decision_valid = udp_header_valid;
        packet_accepted = 1'b0;
        reject_valid = 1'b0;
        reject_reason = feed_handler_pkg::REJECT_NONE;

        if (udp_header_valid) begin
            if (destination_mac != EXPECTED_DESTINATION_MAC) begin
                reject_valid = 1'b1;
                reject_reason = feed_handler_pkg::REJECT_DESTINATION_MAC;
            end else if (destination_ip != EXPECTED_DESTINATION_IP) begin
                reject_valid = 1'b1;
                reject_reason = feed_handler_pkg::REJECT_DESTINATION_IP;
            end else if (destination_port != EXPECTED_DESTINATION_PORT) begin
                reject_valid = 1'b1;
                reject_reason = feed_handler_pkg::REJECT_DESTINATION_PORT;
            end else begin
                packet_accepted = 1'b1;
            end
        end
    end

endmodule
