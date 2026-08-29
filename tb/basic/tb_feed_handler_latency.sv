`timescale 1ns/1ps

module tb_feed_handler_latency;

    localparam int unsigned PACKET_BYTES = 58;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [7:0] s_data = 8'h00;
    logic s_valid = 1'b0;
    logic s_ready;
    logic s_last = 1'b0;
    logic [7:0] m_payload_data;
    logic m_payload_valid;
    logic m_payload_last;
    logic message_valid;
    logic [7:0] protocol_version;
    logic [7:0] message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;
    logic [7:0] packet [0:PACKET_BYTES-1];

    int unsigned cycle_count = 0;
    int unsigned first_input_cycle = 0;
    int unsigned first_payload_input_cycle = 0;
    int unsigned first_payload_output_cycle = 0;
    int unsigned last_input_cycle = 0;
    int unsigned message_cycle = 0;
    int unsigned input_index = 0;
    logic saw_payload_output = 1'b0;

    always #4 clk = ~clk;

    udp_feed_handler_top dut (
        .clk,
        .reset,
        .s_data,
        .s_valid,
        .s_ready,
        .s_last,
        .m_payload_data,
        .m_payload_valid,
        .m_payload_ready(1'b1),
        .m_payload_last,
        .message_valid,
        .protocol_version,
        .message_type,
        .sequence_number,
        .instrument_id,
        .price,
        .quantity
    );

    always_ff @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (s_valid && s_ready) begin
            if (input_index == 0) begin
                first_input_cycle <= cycle_count;
            end
            if (input_index == 42) begin
                first_payload_input_cycle <= cycle_count;
            end
            if (s_last) begin
                last_input_cycle <= cycle_count;
            end
            input_index <= input_index + 1;
        end

        if (m_payload_valid && !saw_payload_output) begin
            saw_payload_output <= 1'b1;
            first_payload_output_cycle <= cycle_count;
        end

        if (message_valid) begin
            message_cycle <= cycle_count;
        end
    end

    task automatic build_packet;
        int unsigned index;
        begin
            for (index = 0; index < PACKET_BYTES; index++) begin
                packet[index] = 8'h00;
            end

            packet[0] = 8'h02;   packet[5] = 8'h01;
            packet[6] = 8'h02;   packet[11] = 8'h02;
            packet[12] = 8'h08;  packet[13] = 8'h00;
            packet[14] = 8'h45;  packet[17] = 8'h2C;
            packet[19] = 8'h01;  packet[22] = 8'h40;
            packet[23] = 8'h11;
            packet[26] = 8'hC0;  packet[27] = 8'hA8;
            packet[28] = 8'h01;  packet[29] = 8'h01;
            packet[30] = 8'hC0;  packet[31] = 8'hA8;
            packet[32] = 8'h01;  packet[33] = 8'h64;
            packet[34] = 8'h27;  packet[35] = 8'h10;
            packet[36] = 8'h46;  packet[37] = 8'h50;
            packet[39] = 8'h18;
            packet[42] = 8'h01;  packet[43] = 8'h01;
            packet[47] = 8'h01;
            packet[48] = 8'h12;  packet[49] = 8'h34;
            packet[52] = 8'h30;  packet[53] = 8'h39;
            packet[57] = 8'h64;
        end
    endtask

    task automatic send_packet;
        int unsigned index;
        begin
            for (index = 0; index < PACKET_BYTES; index++) begin
                @(negedge clk);
                s_data = packet[index];
                s_valid = 1'b1;
                s_last = index == PACKET_BYTES - 1;
                do begin
                    @(posedge clk);
                end while (!s_ready);
            end
            @(negedge clk);
            s_data = 8'h00;
            s_valid = 1'b0;
            s_last = 1'b0;
        end
    endtask

    initial begin
        build_packet();
        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        send_packet();
        wait (message_valid);
        repeat (2) @(posedge clk);

        if (!saw_payload_output) begin
            $fatal(1, "The accepted payload was not observed.");
        end
        if (first_payload_output_cycle - first_payload_input_cycle != 1) begin
            $fatal(1, "Payload cut-through latency changed from one cycle.");
        end
        if (message_cycle - last_input_cycle != 1) begin
            $fatal(1, "Final payload byte to decoded message latency changed from one cycle.");
        end
        if (first_payload_output_cycle - first_input_cycle != 43 ||
            message_cycle - first_input_cycle != 58) begin
            $fatal(1, "End-to-end packet latency changed unexpectedly.");
        end

        $display("PASS: latency at 125 MHz: payload cut-through=1 cycle (8 ns), final byte to message=1 cycle (8 ns), packet start to message=58 cycles (464 ns).");
        $finish;
    end

endmodule
