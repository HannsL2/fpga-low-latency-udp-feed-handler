module sequence_checker (
    input  logic        clk,
    input  logic        reset,
    input  logic        message_valid,
    input  logic [31:0] sequence_number,

    output logic        sequence_event_valid,
    output logic        sequence_gap,
    output logic        sequence_duplicate,
    output logic        sequence_out_of_order,
    output logic [31:0] expected_sequence,
    output logic [31:0] received_sequence,
    output logic [31:0] missing_message_count
);

    logic        sequence_initialized;
    logic [31:0] last_sequence;
    logic [31:0] expected_next;
    logic [31:0] forward_distance;

    always_comb begin
        expected_next = last_sequence + 32'd1;
        forward_distance = sequence_number - expected_next;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sequence_initialized <= 1'b0;
            last_sequence <= 32'h0000_0000;
            sequence_event_valid <= 1'b0;
            sequence_gap <= 1'b0;
            sequence_duplicate <= 1'b0;
            sequence_out_of_order <= 1'b0;
            expected_sequence <= 32'h0000_0000;
            received_sequence <= 32'h0000_0000;
            missing_message_count <= 32'h0000_0000;
        end else begin
            sequence_event_valid <= 1'b0;
            sequence_gap <= 1'b0;
            sequence_duplicate <= 1'b0;
            sequence_out_of_order <= 1'b0;
            missing_message_count <= 32'h0000_0000;

            if (message_valid) begin
                sequence_event_valid <= 1'b1;
                received_sequence <= sequence_number;

                if (!sequence_initialized) begin
                    sequence_initialized <= 1'b1;
                    last_sequence <= sequence_number;
                    expected_sequence <= sequence_number;
                end else begin
                    expected_sequence <= expected_next;

                    if (sequence_number == expected_next) begin
                        last_sequence <= sequence_number;
                    end else if (sequence_number == last_sequence) begin
                        sequence_duplicate <= 1'b1;
                    end else if (!forward_distance[31]) begin
                        sequence_gap <= 1'b1;
                        missing_message_count <= forward_distance;
                        last_sequence <= sequence_number;
                    end else begin
                        sequence_out_of_order <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
