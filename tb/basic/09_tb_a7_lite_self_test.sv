`timescale 1ns/1ps

module tb_a7_lite_self_test;

    logic clk_50mhz = 1'b0;
    logic reset_n = 1'b0;
    logic led_pass_n;
    logic led_fail_n;

    always #10 clk_50mhz = ~clk_50mhz;

    a7_lite_self_test_top dut (
        .clk_50mhz,
        .reset_n,
        .led_pass_n,
        .led_fail_n
    );

    initial begin
        repeat (10) @(posedge clk_50mhz);
        reset_n = 1'b1;

        fork
            begin
                wait (!led_pass_n || !led_fail_n);
                if (!led_fail_n) begin
                    $fatal(1, "A7-LITE self-test reached the failure state.");
                end
                $display("PASS: A7-LITE 125 MHz on-board packet replay completed successfully.");
                $finish;
            end
            begin
                #50us;
                $fatal(1, "A7-LITE self-test did not complete before the timeout.");
            end
        join_any
        disable fork;
    end

endmodule
