module ethernet_parser (
    input  logic        clk,
    input  logic        reset,

    input  logic [7:0]  s_data,
    input  logic        transfer,
    input  logic        packet_start,
    input  logic        packet_end,
    input  logic [15:0] byte_index,

    output logic        header_valid,
    output logic        short_frame,
    output logic [47:0] destination_mac,
    output logic [47:0] source_mac,
    output logic [15:0] ether_type
);

    always_ff @(posedge clk) begin
        if (reset) begin
            header_valid <= 1'b0;
            short_frame <= 1'b0;
            destination_mac <= 48'h0000_0000_0000;
            source_mac <= 48'h0000_0000_0000;
            ether_type <= 16'h0000;
        end else begin
            header_valid <= 1'b0;
            short_frame <= 1'b0;

            if (transfer) begin
                if (packet_start) begin
                    destination_mac <= {s_data, 40'h0000_0000_00};
                    source_mac <= 48'h0000_0000_0000;
                    ether_type <= 16'h0000;
                end else begin
                    case (byte_index)
                        16'd1:  destination_mac[39:32] <= s_data;
                        16'd2:  destination_mac[31:24] <= s_data;
                        16'd3:  destination_mac[23:16] <= s_data;
                        16'd4:  destination_mac[15:8]  <= s_data;
                        16'd5:  destination_mac[7:0]   <= s_data;
                        16'd6:  source_mac[47:40]      <= s_data;
                        16'd7:  source_mac[39:32]      <= s_data;
                        16'd8:  source_mac[31:24]      <= s_data;
                        16'd9:  source_mac[23:16]      <= s_data;
                        16'd10: source_mac[15:8]       <= s_data;
                        16'd11: source_mac[7:0]        <= s_data;
                        16'd12: ether_type[15:8]       <= s_data;
                        16'd13: begin
                            ether_type[7:0] <= s_data;
                            header_valid <= 1'b1;
                        end
                        default: begin
                        end
                    endcase
                end

                if (packet_end && byte_index < 16'd13) begin
                    short_frame <= 1'b1;
                end
            end
        end
    end

endmodule
