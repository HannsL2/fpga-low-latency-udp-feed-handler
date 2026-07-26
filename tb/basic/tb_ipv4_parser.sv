`timescale 1ns/1ps

module tb_ipv4_parser;

    import feed_handler_pkg::*;

    localparam time CLOCK_PERIOD = 8ns;
    localparam int unsigned FRAME_BYTES = 34;

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
    logic [3:0] version;
    logic [3:0] header_length;
    logic [15:0] total_length;
    logic [15:0] fragment_field;
    logic [7:0] protocol;
    logic [31:0] source_ip;
    logic [31:0] destination_ip;

    logic [7:0] frame [0:FRAME_BYTES-1];
    int unsigned valid_count;
    int unsigned reject_count;
    reject_reason_t last_reject_reason;

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

    ipv4_parser dut (
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
        .version,
        .header_length,
        .total_length,
        .fragment_field,
        .protocol,
        .source_ip,
        .destination_ip
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            valid_count <= 0;
            reject_count <= 0;
            last_reject_reason <= REJECT_NONE;
        end else begin
            if (ipv4_header_valid) begin
                valid_count <= valid_count + 1;
            end
            if (ipv4_reject_valid) begin
                reject_count <= reject_count + 1;
                last_reject_reason <= ipv4_reject_reason;
            end
        end
    end

    task automatic build_valid_frame;
        int unsigned index;
        begin
            for (index = 0; index < FRAME_BYTES; index++) begin
                frame[index] = 8'h00;
            end

            frame[0]  = 8'h02;
            frame[1]  = 8'h11;
            frame[2]  = 8'h22;
            frame[3]  = 8'h33;
            frame[4]  = 8'h44;
            frame[5]  = 8'h55;
            frame[6]  = 8'h0A;
            frame[7]  = 8'hBB;
            frame[8]  = 8'hCC;
            frame[9]  = 8'hDD;
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
        end
    endtask

    task automatic send_frame(input int unsigned length);
        int unsigned index;
        begin
            for (index = 0; index < length; index++) begin
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

    task automatic expect_reject(
        input int unsigned expected_count,
        input reject_reason_t expected_reason
    );
        begin
            if (reject_count != expected_count || last_reject_reason != expected_reason) begin
                $fatal(1, "Unexpected IPv4 rejection: count=%0d reason=%0d", reject_count, last_reject_reason);
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
        send_frame(FRAME_BYTES);
        if (valid_count != 1 || reject_count != 0) begin
            $fatal(1, "The supported IPv4 header was not accepted.");
        end
        if (version != 4'd4 || header_length != 4'd5 || total_length != 16'h002C) begin
            $fatal(1, "IPv4 control fields were decoded incorrectly.");
        end
        if (fragment_field != 16'h0000 || protocol != IPV4_PROTOCOL_UDP) begin
            $fatal(1, "IPv4 fragment or protocol fields were decoded incorrectly.");
        end
        if (source_ip != 32'hC0_A8_01_01 || destination_ip != 32'hC0_A8_01_64) begin
            $fatal(1, "IPv4 address extraction failed.");
        end

        build_valid_frame();
        frame[12] = 8'h86;
        frame[13] = 8'hDD;
        send_frame(14);
        expect_reject(1, REJECT_ETHERTYPE);

        build_valid_frame();
        frame[14] = 8'h65;
        send_frame(FRAME_BYTES);
        expect_reject(2, REJECT_IPV4_VERSION);

        build_valid_frame();
        frame[14] = 8'h46;
        send_frame(FRAME_BYTES);
        expect_reject(3, REJECT_IPV4_HEADER_LENGTH);

        build_valid_frame();
        frame[16] = 8'h00;
        frame[17] = 8'h13;
        send_frame(FRAME_BYTES);
        expect_reject(4, REJECT_SHORT_IPV4);

        build_valid_frame();
        frame[20] = 8'h20;
        send_frame(FRAME_BYTES);
        expect_reject(5, REJECT_FRAGMENTED);

        build_valid_frame();
        frame[20] = 8'h80;
        send_frame(FRAME_BYTES);
        expect_reject(6, REJECT_FRAGMENTED);

        build_valid_frame();
        frame[23] = 8'h06;
        send_frame(FRAME_BYTES);
        expect_reject(7, REJECT_NON_UDP);

        build_valid_frame();
        send_frame(21);
        expect_reject(8, REJECT_SHORT_IPV4);

        build_valid_frame();
        frame[20] = 8'h40;
        send_frame(FRAME_BYTES);
        if (valid_count != 2 || reject_count != 8 || fragment_field != 16'h4000) begin
            $fatal(1, "The IPv4 Don't Fragment flag was not accepted correctly.");
        end

        $display("PASS: IPv4 extraction and supported-format validation verified.");
        $finish;
    end

endmodule
