`timescale 1ns/1ps

module tb_sequence_checker;
    localparam time CLOCK_PERIOD = 8ns;

    logic clk = 1'b0;
    logic reset;
    logic message_valid;
    logic [31:0] sequence_number;
    logic sequence_event_valid;
    logic sequence_gap;
    logic sequence_duplicate;
    logic sequence_out_of_order;
    logic [31:0] expected_sequence;
    logic [31:0] received_sequence;
    logic [31:0] missing_message_count;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    sequence_checker dut (.*);

    task automatic apply_reset;
        begin
            @(negedge clk);
            reset = 1'b1;
            message_valid = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    task automatic check_sequence(
        input logic [31:0] value,
        input logic [31:0] expected_value,
        input logic gap,
        input logic duplicate,
        input logic out_of_order,
        input logic [31:0] missing
    );
        begin
            @(negedge clk);
            sequence_number = value;
            message_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);

            if (!sequence_event_valid || expected_sequence != expected_value ||
                received_sequence != value || sequence_gap != gap ||
                sequence_duplicate != duplicate ||
                sequence_out_of_order != out_of_order ||
                missing_message_count != missing) begin
                $fatal(1, "Incorrect result for %08h: valid=%0b expected=%08h received=%08h gap=%0b duplicate=%0b older=%0b missing=%0d",
                       value, sequence_event_valid, expected_sequence, received_sequence,
                       sequence_gap, sequence_duplicate, sequence_out_of_order,
                       missing_message_count);
            end

            message_valid = 1'b0;
            @(posedge clk);
            @(negedge clk);
            if (sequence_event_valid) $fatal(1, "Sequence event did not pulse for one cycle.");
        end
    endtask

    initial begin
        reset = 1'b0;
        message_valid = 1'b0;
        sequence_number = 32'h0000_0000;

        apply_reset();
        check_sequence(32'd100, 32'd100, 1'b0, 1'b0, 1'b0, 32'd0);
        check_sequence(32'd101, 32'd101, 1'b0, 1'b0, 1'b0, 32'd0);
        check_sequence(32'd105, 32'd102, 1'b1, 1'b0, 1'b0, 32'd3);
        check_sequence(32'd105, 32'd106, 1'b0, 1'b1, 1'b0, 32'd0);
        check_sequence(32'd104, 32'd106, 1'b0, 1'b0, 1'b1, 32'd0);

        sequence_number = 32'd999;
        repeat (2) @(posedge clk);
        check_sequence(32'd106, 32'd106, 1'b0, 1'b0, 1'b0, 32'd0);

        apply_reset();
        check_sequence(32'hFFFF_FFFE, 32'hFFFF_FFFE, 1'b0, 1'b0, 1'b0, 32'd0);
        check_sequence(32'hFFFF_FFFF, 32'hFFFF_FFFF, 1'b0, 1'b0, 1'b0, 32'd0);
        check_sequence(32'h0000_0000, 32'h0000_0000, 1'b0, 1'b0, 1'b0, 32'd0);
        check_sequence(32'h0000_0002, 32'h0000_0001, 1'b1, 1'b0, 1'b0, 32'd1);
        check_sequence(32'h0000_0002, 32'h0000_0003, 1'b0, 1'b1, 1'b0, 32'd0);
        check_sequence(32'hFFFF_FFF0, 32'h0000_0003, 1'b0, 1'b0, 1'b1, 32'd0);

        $display("PASS: sequence progression, anomalies and wraparound verified.");
        $finish;
    end
endmodule
