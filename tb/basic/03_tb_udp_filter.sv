`timescale 1ns/1ps

module tb_udp_filter;

    import feed_handler_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;
    localparam int unsigned FRAME_BYTES = 58;

    localparam logic [47:0] EXPECTED_MAC = 48'h02_00_00_00_00_01;
    localparam logic [31:0] EXPECTED_IP = 32'hC0_A8_01_64;
    localparam logic [15:0] EXPECTED_PORT = 16'd18000;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] s_data;
    logic s_valid;
    logic s_ready;
    logic s_last;

    logic transfer;
    logic packet_start;
    logic packet_end;
    logic packet_active;
    logic [15:0] byte_index;

    logic ethernet_header_valid;
    logic short_ethernet_frame;
    logic [47:0] destination_mac;
    logic [47:0] source_mac;
    logic [15:0] ether_type;

    logic ipv4_header_valid;
    logic ipv4_reject_valid;
    reject_reason_t ipv4_reject_reason;
    logic [3:0] ipv4_version;
    logic [3:0] ipv4_header_length;
    logic [15:0] ipv4_total_length;
    logic [15:0] ipv4_fragment_field;
    logic [7:0] ipv4_protocol;
    logic [31:0] source_ip;
    logic [31:0] destination_ip;

    logic udp_header_valid;
    logic udp_reject_valid;
    reject_reason_t udp_reject_reason;
    logic [15:0] source_port;
    logic [15:0] destination_port;
    logic [15:0] udp_length;
    logic [15:0] udp_checksum;

    logic filter_decision_valid;
    logic packet_accepted;
    logic filter_reject_valid;
    reject_reason_t filter_reject_reason;

    logic [7:0] frame [0:FRAME_BYTES-1];
    int unsigned udp_header_count;
    int unsigned udp_reject_count;
    int unsigned filter_decision_count;
    int unsigned accepted_count;
    int unsigned filter_reject_count;
    reject_reason_t last_udp_reject_reason;
    reject_reason_t last_filter_reject_reason;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    stream_packet_controller packet_controller (
        .clk,
        .reset,
        .s_valid,
        .s_ready,
        .s_last,
        .transfer,
        .packet_start,
        .packet_end,
        .packet_active,
        .byte_index
    );

    ethernet_parser ethernet_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer,
        .packet_start,
        .packet_end,
        .byte_index,
        .header_valid(ethernet_header_valid),
        .short_frame(short_ethernet_frame),
        .destination_mac,
        .source_mac,
        .ether_type
    );

    ipv4_parser ipv4_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer,
        .packet_end,
        .packet_active,
        .byte_index,
        .ethernet_header_valid,
        .ether_type,
        .header_valid(ipv4_header_valid),
        .reject_valid(ipv4_reject_valid),
        .reject_reason(ipv4_reject_reason),
        .version(ipv4_version),
        .header_length(ipv4_header_length),
        .total_length(ipv4_total_length),
        .fragment_field(ipv4_fragment_field),
        .protocol(ipv4_protocol),
        .source_ip,
        .destination_ip
    );

    udp_parser udp_parser_inst (
        .clk,
        .reset,
        .s_data,
        .transfer,
        .packet_end,
        .packet_active,
        .byte_index,
        .ipv4_header_valid,
        .ipv4_total_length,
        .header_valid(udp_header_valid),
        .reject_valid(udp_reject_valid),
        .reject_reason(udp_reject_reason),
        .source_port,
        .destination_port,
        .udp_length,
        .checksum(udp_checksum)
    );

    packet_filter #(
        .EXPECTED_DESTINATION_MAC(EXPECTED_MAC),
        .EXPECTED_DESTINATION_IP(EXPECTED_IP),
        .EXPECTED_DESTINATION_PORT(EXPECTED_PORT)
    ) packet_filter_inst (
        .udp_header_valid,
        .destination_mac,
        .destination_ip,
        .destination_port,
        .decision_valid(filter_decision_valid),
        .packet_accepted,
        .reject_valid(filter_reject_valid),
        .reject_reason(filter_reject_reason)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            udp_header_count <= 0;
            udp_reject_count <= 0;
            filter_decision_count <= 0;
            accepted_count <= 0;
            filter_reject_count <= 0;
            last_udp_reject_reason <= REJECT_NONE;
            last_filter_reject_reason <= REJECT_NONE;
        end else begin
            if (udp_header_valid) begin
                udp_header_count <= udp_header_count + 1;
            end
            if (udp_reject_valid) begin
                udp_reject_count <= udp_reject_count + 1;
                last_udp_reject_reason <= udp_reject_reason;
            end
            if (filter_decision_valid) begin
                filter_decision_count <= filter_decision_count + 1;
            end
            if (packet_accepted) begin
                accepted_count <= accepted_count + 1;
            end
            if (filter_reject_valid) begin
                filter_reject_count <= filter_reject_count + 1;
                last_filter_reject_reason <= filter_reject_reason;
            end
        end
    end

    task automatic build_valid_frame;
        int unsigned index;
        begin
            for (index = 0; index < FRAME_BYTES; index++) begin
                frame[index] = 8'h00;
            end

            frame[0] = 8'h02;
            frame[1] = 8'h00;
            frame[2] = 8'h00;
            frame[3] = 8'h00;
            frame[4] = 8'h00;
            frame[5] = 8'h01;
            frame[6] = 8'h0A;
            frame[7] = 8'hBB;
            frame[8] = 8'hCC;
            frame[9] = 8'hDD;
            frame[10] = 8'hEE;
            frame[11] = 8'hFF;
            frame[12] = 8'h08;
            frame[13] = 8'h00;

            frame[14] = 8'h45;
            frame[15] = 8'h00;
            frame[16] = 8'h00;
            frame[17] = 8'h2C;
            frame[18] = 8'h00;
            frame[19] = 8'h01;
            frame[20] = 8'h00;
            frame[21] = 8'h00;
            frame[22] = 8'h40;
            frame[23] = 8'h11;
            frame[24] = 8'h00;
            frame[25] = 8'h00;
            frame[26] = 8'hC0;
            frame[27] = 8'hA8;
            frame[28] = 8'h01;
            frame[29] = 8'h01;
            frame[30] = 8'hC0;
            frame[31] = 8'hA8;
            frame[32] = 8'h01;
            frame[33] = 8'h64;

            frame[34] = 8'h13;
            frame[35] = 8'h88;
            frame[36] = 8'h46;
            frame[37] = 8'h50;
            frame[38] = 8'h00;
            frame[39] = 8'h18;
            frame[40] = 8'hBE;
            frame[41] = 8'hEF;

            for (index = 42; index < FRAME_BYTES; index++) begin
                frame[index] = index - 42;
            end
        end
    endtask

    task automatic send_frame(
        input int unsigned length,
        input logic insert_udp_gap
    );
        int unsigned index;
        begin
            for (index = 0; index < length; index++) begin
                if (insert_udp_gap && index == 38) begin
                    @(negedge clk);
                    s_valid = 1'b0;
                    s_last = 1'b0;
                    repeat (2) @(posedge clk);
                end

                @(negedge clk);
                s_data = frame[index];
                s_valid = 1'b1;
                s_last = (index == length - 1);
                @(posedge clk);
            end

            @(negedge clk);
            s_data = 8'h00;
            s_valid = 1'b0;
            s_last = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    task automatic expect_filter_reject(
        input int unsigned expected_count,
        input reject_reason_t expected_reason
    );
        begin
            if (filter_reject_count != expected_count ||
                last_filter_reject_reason != expected_reason) begin
                $fatal(1, "Unexpected filter rejection: count=%0d reason=%0d",
                       filter_reject_count, last_filter_reject_reason);
            end
        end
    endtask

    task automatic expect_udp_reject(input int unsigned expected_count);
        begin
            if (udp_reject_count != expected_count ||
                last_udp_reject_reason != REJECT_SHORT_UDP) begin
                $fatal(1, "Unexpected UDP rejection: count=%0d reason=%0d",
                       udp_reject_count, last_udp_reject_reason);
            end
        end
    endtask

    initial begin
        reset = 1'b1;
        s_data = 8'h00;
        s_valid = 1'b0;
        s_ready = 1'b1;
        s_last = 1'b0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        build_valid_frame();
        send_frame(FRAME_BYTES, 1'b1);
        if (udp_header_count != 1 || filter_decision_count != 1 ||
            accepted_count != 1 || filter_reject_count != 0 || udp_reject_count != 0) begin
            $fatal(1, "The supported UDP packet was not accepted exactly once.");
        end
        if (source_port != 16'h1388 || destination_port != EXPECTED_PORT ||
            udp_length != 16'd24 || udp_checksum != 16'hBEEF) begin
            $fatal(1, "UDP field extraction failed.");
        end

        build_valid_frame();
        frame[5] = 8'h02;
        send_frame(FRAME_BYTES, 1'b0);
        expect_filter_reject(1, REJECT_DESTINATION_MAC);

        build_valid_frame();
        frame[33] = 8'h65;
        send_frame(FRAME_BYTES, 1'b0);
        expect_filter_reject(2, REJECT_DESTINATION_IP);

        build_valid_frame();
        frame[37] = 8'h51;
        send_frame(FRAME_BYTES, 1'b0);
        expect_filter_reject(3, REJECT_DESTINATION_PORT);

        build_valid_frame();
        frame[16] = 8'h00;
        frame[17] = 8'h1B;
        frame[38] = 8'h00;
        frame[39] = 8'h07;
        send_frame(FRAME_BYTES, 1'b0);
        expect_udp_reject(1);

        build_valid_frame();
        frame[39] = 8'h17;
        send_frame(FRAME_BYTES, 1'b0);
        expect_udp_reject(2);

        build_valid_frame();
        send_frame(40, 1'b0);
        expect_udp_reject(3);

        if (udp_header_count != 4 || filter_decision_count != 4 ||
            accepted_count != 1 || filter_reject_count != 3) begin
            $fatal(1, "UDP/filter event totals are incorrect.");
        end

        $display("PASS: UDP extraction, length validation and destination filtering verified.");
        $finish;
    end

endmodule
