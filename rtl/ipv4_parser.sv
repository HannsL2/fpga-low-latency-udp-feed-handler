module ipv4_parser (
    input  logic        clk,
    input  logic        reset,

    input  logic [7:0]  s_data,
    input  logic        transfer,
    input  logic        packet_end,
    input  logic        packet_active,
    input  logic [15:0] byte_index,

    input  logic        ethernet_header_valid,
    input  logic [15:0] ether_type,

    output logic        header_valid,
    output logic        reject_valid,
    output feed_handler_pkg::reject_reason_t reject_reason,
    output logic [3:0]  version,
    output logic [3:0]  header_length,
    output logic [15:0] total_length,
    output logic [15:0] fragment_field,
    output logic [7:0]  protocol,
    output logic [31:0] source_ip,
    output logic [31:0] destination_ip
);

    localparam logic [15:0] IPV4_FIRST_BYTE_INDEX = 16'd14;
    localparam logic [15:0] TOTAL_LENGTH_MSB_INDEX = 16'd16;
    localparam logic [15:0] TOTAL_LENGTH_LSB_INDEX = 16'd17;
    localparam logic [15:0] FRAGMENT_MSB_INDEX = 16'd20;
    localparam logic [15:0] FRAGMENT_LSB_INDEX = 16'd21;
    localparam logic [15:0] PROTOCOL_INDEX = 16'd23;
    localparam logic [15:0] SOURCE_IP_MSB_INDEX = 16'd26;
    localparam logic [15:0] DESTINATION_IP_MSB_INDEX = 16'd30;
    localparam logic [15:0] IPV4_FINAL_BYTE_INDEX = 16'd33;

    localparam logic [15:0] MINIMUM_IPV4_TOTAL_LENGTH = 16'd20;
    localparam logic [15:0] UNSUPPORTED_FRAGMENT_MASK = 16'hBFFF;

    logic parsing_ipv4;
    logic capture_ipv4_byte;

    always_comb begin
        capture_ipv4_byte = parsing_ipv4 ||
                            (ethernet_header_valid &&
                             ether_type == feed_handler_pkg::ETHERTYPE_IPV4 &&
                             packet_active);
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            parsing_ipv4 <= 1'b0;
            header_valid <= 1'b0;
            reject_valid <= 1'b0;
            reject_reason <= feed_handler_pkg::REJECT_NONE;
            version <= 4'h0;
            header_length <= 4'h0;
            total_length <= 16'h0000;
            fragment_field <= 16'h0000;
            protocol <= 8'h00;
            source_ip <= 32'h0000_0000;
            destination_ip <= 32'h0000_0000;
        end else begin
            header_valid <= 1'b0;
            reject_valid <= 1'b0;

            if (ethernet_header_valid) begin
                version <= 4'h0;
                header_length <= 4'h0;
                total_length <= 16'h0000;
                fragment_field <= 16'h0000;
                protocol <= 8'h00;
                source_ip <= 32'h0000_0000;
                destination_ip <= 32'h0000_0000;
                reject_reason <= feed_handler_pkg::REJECT_NONE;

                if (ether_type != feed_handler_pkg::ETHERTYPE_IPV4) begin
                    parsing_ipv4 <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_ETHERTYPE;
                end else if (!packet_active) begin
                    parsing_ipv4 <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_SHORT_IPV4;
                end else begin
                    parsing_ipv4 <= 1'b1;
                end
            end

            if (transfer && capture_ipv4_byte) begin
                if (packet_end && byte_index < IPV4_FINAL_BYTE_INDEX) begin
                    parsing_ipv4 <= 1'b0;
                    reject_valid <= 1'b1;
                    reject_reason <= feed_handler_pkg::REJECT_SHORT_IPV4;
                end else begin
                    case (byte_index)
                        IPV4_FIRST_BYTE_INDEX: begin
                            version <= s_data[7:4];
                            header_length <= s_data[3:0];

                            if (s_data[7:4] != 4'd4) begin
                                parsing_ipv4 <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_IPV4_VERSION;
                            end else if (s_data[3:0] != 4'd5) begin
                                parsing_ipv4 <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_IPV4_HEADER_LENGTH;
                            end
                        end
                        TOTAL_LENGTH_MSB_INDEX: total_length[15:8] <= s_data;
                        TOTAL_LENGTH_LSB_INDEX: begin
                            total_length[7:0] <= s_data;
                            if ({total_length[15:8], s_data} < MINIMUM_IPV4_TOTAL_LENGTH) begin
                                parsing_ipv4 <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_SHORT_IPV4;
                            end
                        end
                        FRAGMENT_MSB_INDEX: fragment_field[15:8] <= s_data;
                        FRAGMENT_LSB_INDEX: begin
                            fragment_field[7:0] <= s_data;
                            if (({fragment_field[15:8], s_data} & UNSUPPORTED_FRAGMENT_MASK) != 16'h0000) begin
                                parsing_ipv4 <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_FRAGMENTED;
                            end
                        end
                        PROTOCOL_INDEX: begin
                            protocol <= s_data;
                            if (s_data != feed_handler_pkg::IPV4_PROTOCOL_UDP) begin
                                parsing_ipv4 <= 1'b0;
                                reject_valid <= 1'b1;
                                reject_reason <= feed_handler_pkg::REJECT_NON_UDP;
                            end
                        end
                        SOURCE_IP_MSB_INDEX: source_ip[31:24] <= s_data;
                        SOURCE_IP_MSB_INDEX + 16'd1: source_ip[23:16] <= s_data;
                        SOURCE_IP_MSB_INDEX + 16'd2: source_ip[15:8] <= s_data;
                        SOURCE_IP_MSB_INDEX + 16'd3: source_ip[7:0] <= s_data;
                        DESTINATION_IP_MSB_INDEX: destination_ip[31:24] <= s_data;
                        DESTINATION_IP_MSB_INDEX + 16'd1: destination_ip[23:16] <= s_data;
                        DESTINATION_IP_MSB_INDEX + 16'd2: destination_ip[15:8] <= s_data;
                        IPV4_FINAL_BYTE_INDEX: begin
                            destination_ip[7:0] <= s_data;
                            parsing_ipv4 <= 1'b0;
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
