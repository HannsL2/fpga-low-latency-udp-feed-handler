`timescale 1ns/1ps

module tb_feed_message_uart;

    localparam int unsigned CLOCK_FREQUENCY_HZ = 100;
    localparam int unsigned BAUD_RATE = 10;
    localparam int unsigned CYCLES_PER_BIT = CLOCK_FREQUENCY_HZ / BAUD_RATE;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic message_valid = 1'b0;
    logic message_ready;
    logic uart_tx_pin;
    string expected_text =
        "MSG type=01 seq=0000002A inst=1234 price=0001E240 qty=000003E8";

    always #5 clk = !clk;

    feed_message_uart #(
        .CLOCK_FREQUENCY_HZ(CLOCK_FREQUENCY_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk,
        .reset,
        .message_valid,
        .message_type(8'h01),
        .sequence_number(32'd42),
        .instrument_id(16'h1234),
        .price(32'd123456),
        .quantity(32'd1000),
        .message_ready,
        .uart_tx_pin
    );

    task automatic receive_uart_byte(output logic [7:0] received_byte);
        @(negedge uart_tx_pin);
        repeat (CYCLES_PER_BIT / 2) @(posedge clk);
        if (uart_tx_pin !== 1'b0) begin
            $fatal(1, "UART start bit was not low at its midpoint.");
        end
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            repeat (CYCLES_PER_BIT) @(posedge clk);
            received_byte[bit_index] = uart_tx_pin;
        end
        repeat (CYCLES_PER_BIT) @(posedge clk);
        if (uart_tx_pin !== 1'b1) begin
            $fatal(1, "UART stop bit was not high at its midpoint.");
        end
    endtask

    initial begin
        logic [7:0] received_byte;

        repeat (4) @(posedge clk);
        reset <= 1'b0;
        @(posedge clk);
        if (!message_ready) begin
            $fatal(1, "UART formatter was not ready after reset.");
        end

        message_valid <= 1'b1;
        @(posedge clk);
        message_valid <= 1'b0;

        for (int character_index = 0;
             character_index < expected_text.len();
             character_index++) begin
            receive_uart_byte(received_byte);
            if (received_byte !== expected_text[character_index]) begin
                $fatal(1,
                    "UART character %0d mismatch: expected 0x%02h, received 0x%02h.",
                    character_index, expected_text[character_index], received_byte);
            end
        end

        receive_uart_byte(received_byte);
        if (received_byte !== 8'h0D) begin
            $fatal(1, "UART line did not end with carriage return.");
        end
        receive_uart_byte(received_byte);
        if (received_byte !== 8'h0A) begin
            $fatal(1, "UART line did not end with line feed.");
        end

        wait (message_ready);
        $display("PASS: decoded message formatted as a complete 115200-8-N-1 UART line.");
        $finish;
    end

endmodule
