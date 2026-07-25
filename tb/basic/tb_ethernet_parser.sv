`timescale 1ns/1ps

module tb_ethernet_parser;

    localparam time CLOCK_PERIOD = 8ns;
    localparam int unsigned ETHERNET_BYTES = 14;

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

    logic header_valid;
    logic short_frame;
    logic [47:0] destination_mac;
    logic [47:0] source_mac;
    logic [15:0] ether_type;

    logic [7:0] header [0:ETHERNET_BYTES-1];
    int unsigned header_valid_count;
    int unsigned short_frame_count;
    int unsigned packet_start_count;
    int unsigned packet_end_count;

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

    ethernet_parser dut (
        .clk,
        .reset,
        .s_data,
        .transfer,
        .packet_start,
        .packet_end,
        .byte_index,
        .header_valid,
        .short_frame,
        .destination_mac,
        .source_mac,
        .ether_type
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            header_valid_count <= 0;
            short_frame_count <= 0;
            packet_start_count <= 0;
            packet_end_count <= 0;
        end else begin
            if (header_valid) begin
                header_valid_count <= header_valid_count + 1;
            end
            if (short_frame) begin
                short_frame_count <= short_frame_count + 1;
            end
            if (packet_start) begin
                packet_start_count <= packet_start_count + 1;
            end
            if (packet_end) begin
                packet_end_count <= packet_end_count + 1;
            end
        end
    end

    task automatic drive_byte(input logic [7:0] value, input logic last);
        begin
            @(negedge clk);
            s_data = value;
            s_valid = 1'b1;
            s_last = last;
            do begin
                @(posedge clk);
            end while (!s_ready);
        end
    endtask

    task automatic stop_source;
        begin
            @(negedge clk);
            s_data = 8'h00;
            s_valid = 1'b0;
            s_last = 1'b0;
        end
    endtask

    task automatic drive_stalled_byte(
        input logic [7:0] value,
        input logic [15:0] expected_index
    );
        int unsigned stall_cycle;
        begin
            @(negedge clk);
            s_data = value;
            s_valid = 1'b1;
            s_last = 1'b0;
            s_ready = 1'b0;

            for (stall_cycle = 0; stall_cycle < 3; stall_cycle++) begin
                @(posedge clk);
                #1ps;
                if (transfer || !packet_active || byte_index != expected_index) begin
                    $fatal(1, "Packet state changed while the input was stalled.");
                end
            end

            @(negedge clk);
            s_ready = 1'b1;
            @(posedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        s_data = 8'h00;
        s_valid = 1'b0;
        s_ready = 1'b1;
        s_last = 1'b0;

        header[0]  = 8'h02;
        header[1]  = 8'h11;
        header[2]  = 8'h22;
        header[3]  = 8'h33;
        header[4]  = 8'h44;
        header[5]  = 8'h55;
        header[6]  = 8'h0A;
        header[7]  = 8'hBB;
        header[8]  = 8'hCC;
        header[9]  = 8'hDD;
        header[10] = 8'hEE;
        header[11] = 8'hFF;
        header[12] = 8'h08;
        header[13] = 8'h00;

        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        drive_byte(header[0], 1'b0);
        drive_byte(header[1], 1'b0);
        drive_byte(header[2], 1'b0);
        drive_stalled_byte(header[3], 16'd3);
        drive_byte(header[4], 1'b0);
        drive_byte(header[5], 1'b0);
        drive_byte(header[6], 1'b0);
        drive_byte(header[7], 1'b0);
        drive_byte(header[8], 1'b0);
        drive_byte(header[9], 1'b0);
        drive_byte(header[10], 1'b0);
        drive_byte(header[11], 1'b0);
        drive_byte(header[12], 1'b0);
        drive_byte(header[13], 1'b1);
        stop_source();
        repeat (2) @(posedge clk);

        if (destination_mac != 48'h02_11_22_33_44_55) begin
            $fatal(1, "Destination MAC extraction failed: %012h", destination_mac);
        end
        if (source_mac != 48'h0A_BB_CC_DD_EE_FF) begin
            $fatal(1, "Source MAC extraction failed: %012h", source_mac);
        end
        if (ether_type != 16'h0800) begin
            $fatal(1, "EtherType extraction failed: %04h", ether_type);
        end
        if (header_valid_count != 1 || packet_start_count != 1 || packet_end_count != 1) begin
            $fatal(1, "Unexpected event counts after the complete header.");
        end
        if (short_frame_count != 0) begin
            $fatal(1, "A complete Ethernet header was reported as truncated.");
        end
        if (packet_active || byte_index != 16'd0) begin
            $fatal(1, "Packet controller did not reset its state at s_last.");
        end

        drive_byte(header[0], 1'b0);
        drive_byte(header[1], 1'b0);
        drive_byte(header[2], 1'b0);
        drive_byte(header[3], 1'b0);
        drive_byte(header[4], 1'b0);
        drive_byte(header[5], 1'b0);
        drive_byte(header[6], 1'b0);
        drive_byte(header[7], 1'b0);
        drive_byte(header[8], 1'b0);
        drive_byte(header[9], 1'b1);
        stop_source();
        repeat (2) @(posedge clk);

        if (short_frame_count != 1) begin
            $fatal(1, "A truncated Ethernet header was not reported.");
        end
        if (header_valid_count != 1 || packet_start_count != 2 || packet_end_count != 2) begin
            $fatal(1, "Unexpected event counts after the truncated header.");
        end

        $display("PASS: Ethernet fields, stalls, packet boundaries and short frames verified.");
        $finish;
    end

endmodule
