module stream_packet_controller (
    input  logic        clk,
    input  logic        reset,

    input  logic        s_valid,
    input  logic        s_ready,
    input  logic        s_last,

    output logic        transfer,
    output logic        packet_start,
    output logic        packet_end,
    output logic        packet_active,
    output logic [15:0] byte_index
);

    always_comb begin
        transfer = s_valid && s_ready && !reset;
        packet_start = transfer && !packet_active;
        packet_end = transfer && s_last;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            packet_active <= 1'b0;
            byte_index <= 16'd0;
        end else if (transfer) begin
            if (s_last) begin
                packet_active <= 1'b0;
                byte_index <= 16'd0;
            end else begin
                packet_active <= 1'b1;
                byte_index <= byte_index + 16'd1;
            end
        end
    end

endmodule
