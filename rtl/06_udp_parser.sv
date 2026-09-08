module udp_parser (
    input  logic        clk,
    input  logic        reset,

    input  logic [7:0]  s_data,
    input  logic        transfer,
    input  logic        packet_end,
    input  logic        packet_active,
    input  logic [15:0] byte_index,

    input  logic        ipv4_header_valid,
    input  logic [15:0] ipv4_total_length,

    output logic        header_valid,
    output logic        reject_valid,
    output feed_handler_pkg::reject_reason_t reject_reason,
    output logic [15:0] source_port,
    output logic [15:0] destination_port,
    output logic [15:0] udp_length,
    output logic [15:0] checksum
);

    localparam logic [15:0] UDP_FIRST_BYTE_INDEX = 16'd34;
    localparam logic [15:0] DESTINATION_PORT_MSB_INDEX = 16'd36;
    localparam logic [15:0] UDP_LENGTH_MSB_INDEX = 16'd38;
    localparam logic [15:0] CHECKSUM_MSB_INDEX = 16'd40;
    localparam logic [15:0] UDP_FINAL_BYTE_INDEX = 16'd41;

    localparam logic [15:0] IPV4_HEADER_LENGTH_BYTES = 16'd20;
    localparam logic [15:0] MINIMUM_UDP_LENGTH = 16'd8;
    localparam logic [15:0] MINIMUM_IPV4_UDP_LENGTH = 16'd28;

    logic parsing_udp;
    logic capture_udp_byte;

    always_comb begin
        capture_udp_byte = parsing_udp ||
                           (ipv4_header_valid &&
                            packet_active &&
                            ipv4_total_length >= MINIMUM_IPV4_UDP_LENGTH);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            parsing_udp <= 1'b0;
            header_valid <= 1'b0;
            reject_valid <= 1'b0;
            reject_reason <= feed_handler_pkg::REJECT_NONE;
            source_port <= 16'h0000;
            destination_port <= 16'h0000;
            udp_length <= 16'h0000;
            checksum <= 16'h0000;
        end else begin
            header_valid <= 1'b0;
            reject_valid <= 1'b0;

            if (ipv4_header_valid) begin
                source_port <= 16'h0000;
                destination_port <= 16'h0000;
                udp_length <= 16'h0000;
                checksum <= 16'h0000;
                reject_reason <= feed_handler_pkg::REJECT_NONE;

                if (ipv4_total_length < MINIMUM_IPV4_UDP_LENGTH || !packet_active) begin
                    parsing_udp <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_SHORT_UDP;
                end else begin
                    parsing_udp <= 1'b1;
                end
            end

            if (transfer && capture_udp_byte) begin
                if (packet_end && byte_index < UDP_FINAL_BYTE_INDEX) begin
                    parsing_udp <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_SHORT_UDP;
                end else begin
                    case (byte_index)
                        UDP_FIRST_BYTE_INDEX: source_port[15:8] <= s_data;
                        UDP_FIRST_BYTE_INDEX + 16'd1: source_port[7:0] <= s_data;
                        DESTINATION_PORT_MSB_INDEX: destination_port[15:8] <= s_data;
                        DESTINATION_PORT_MSB_INDEX + 16'd1: destination_port[7:0] <= s_data;
                        UDP_LENGTH_MSB_INDEX: udp_length[15:8] <= s_data;
                        UDP_LENGTH_MSB_INDEX + 16'd1: begin
                            udp_length[7:0] <= s_data;
                            if ({udp_length[15:8], s_data} < MINIMUM_UDP_LENGTH ||
                                {udp_length[15:8], s_data} !=
                                    (ipv4_total_length - IPV4_HEADER_LENGTH_BYTES)) begin
                                parsing_udp <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_SHORT_UDP;
                            end
                        end
                        CHECKSUM_MSB_INDEX: checksum[15:8] <= s_data;
                        UDP_FINAL_BYTE_INDEX: begin
                            checksum[7:0] <= s_data;
                            parsing_udp <= 1'b0;
                            header_valid <= 1'b1;
                        end
                        default: begin
                        end
                    endcase
                end
            end
        end
    end

endmodule
