`timescale 1ns/1ps

module tb_rgmii_live_receive;

    import feed_handler_pkg::*;

    localparam int unsigned FRAME_BYTES = 58;

    logic rx_clk = 1'b0;
    logic reset;
    logic [3:0] rgmii_rxd;
    logic rgmii_rx_ctl;
    logic [7:0] phy_data;
    logic phy_data_valid;
    logic phy_data_error;
    logic [7:0] frame_data;
    logic frame_valid;
    logic frame_ready;
    logic frame_last;
    logic frame_error;

    logic message_valid;
    logic [7:0] protocol_version;
    logic [7:0] message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;
    logic reject_valid;
    reject_reason_t reject_reason;
    logic [31:0] total_packet_count;
    logic [31:0] accepted_packet_count;
    logic [31:0] rejected_packet_count;
    logic [31:0] valid_message_count;

    logic [7:0] frame [0:FRAME_BYTES-1];
    int unsigned delivered_frame_bytes;
    int unsigned delivered_last_count;
    int unsigned message_count;
    int unsigned error_count;

    always #4ns rx_clk = ~rx_clk;

    rgmii_rx rgmii_receiver (
        .rx_clk,
        .rgmii_rxd,
        .rgmii_rx_ctl,
        .data(phy_data),
        .data_valid(phy_data_valid),
        .data_error(phy_data_error)
    );

    ethernet_frame_deframer deframer (
        .clk(rx_clk),
        .reset,
        .phy_data,
        .phy_data_valid,
        .phy_data_error,
        .frame_data,
        .frame_valid,
        .frame_ready,
        .frame_last,
        .frame_error
    );

    udp_feed_handler_top dut (
        .clk(rx_clk),
        .reset,
        .s_data(frame_data),
        .s_valid(frame_valid),
        .s_ready(frame_ready),
        .s_last(frame_last),
        .m_payload_data(),
        .m_payload_valid(),
        .m_payload_ready(1'b1),
        .m_payload_last(),
        .message_valid,
        .protocol_version,
        .message_type,
        .sequence_number,
        .instrument_id,
        .price,
        .quantity,
        .reject_valid,
        .reject_reason,
        .sequence_event_valid(),
        .sequence_gap(),
        .sequence_duplicate(),
        .sequence_out_of_order(),
        .expected_sequence(),
        .received_sequence(),
        .missing_message_count(),
        .total_packet_count,
        .accepted_packet_count,
        .rejected_packet_count,
        .malformed_packet_count(),
        .unsupported_ethertype_count(),
        .non_udp_packet_count(),
        .destination_mac_mismatch_count(),
        .destination_ip_mismatch_count(),
        .destination_port_mismatch_count(),
        .valid_message_count,
        .sequence_gap_count(),
        .missing_message_total(),
        .duplicate_message_count(),
        .out_of_order_message_count()
    );

    always_ff @(posedge rx_clk) begin
        if (reset) begin
            delivered_frame_bytes <= 0;
            delivered_last_count <= 0;
            message_count <= 0;
            error_count <= 0;
        end else begin
            if (frame_valid && frame_ready) begin
                if (frame_data != frame[delivered_frame_bytes]) begin
                    $fatal(1, "Deframed byte %0d was %02x, expected %02x.",
                           delivered_frame_bytes, frame_data,
                           frame[delivered_frame_bytes]);
                end
                delivered_frame_bytes <= delivered_frame_bytes + 1;
                if (frame_last) delivered_last_count <= delivered_last_count + 1;
            end
            if (message_valid) message_count <= message_count + 1;
            if (frame_error || reject_valid) error_count <= error_count + 1;
        end
    end

    task automatic set_frame_byte(input int unsigned index, input logic [7:0] value);
        frame[index] = value;
    endtask

    task automatic build_frame;
        int unsigned index;
        begin
            for (index = 0; index < FRAME_BYTES; index++) frame[index] = 8'h00;

            set_frame_byte(0, 8'h02); set_frame_byte(1, 8'h00);
            set_frame_byte(2, 8'h00); set_frame_byte(3, 8'h00);
            set_frame_byte(4, 8'h00); set_frame_byte(5, 8'h01);
            set_frame_byte(6, 8'h02); set_frame_byte(7, 8'h00);
            set_frame_byte(8, 8'h00); set_frame_byte(9, 8'h00);
            set_frame_byte(10, 8'h00); set_frame_byte(11, 8'h02);
            set_frame_byte(12, 8'h08); set_frame_byte(13, 8'h00);

            set_frame_byte(14, 8'h45); set_frame_byte(15, 8'h00);
            set_frame_byte(16, 8'h00); set_frame_byte(17, 8'h2C);
            set_frame_byte(18, 8'h00); set_frame_byte(19, 8'h01);
            set_frame_byte(20, 8'h00); set_frame_byte(21, 8'h00);
            set_frame_byte(22, 8'h40); set_frame_byte(23, 8'h11);
            set_frame_byte(24, 8'h00); set_frame_byte(25, 8'h00);
            set_frame_byte(26, 8'hC0); set_frame_byte(27, 8'hA8);
            set_frame_byte(28, 8'h01); set_frame_byte(29, 8'h01);
            set_frame_byte(30, 8'hC0); set_frame_byte(31, 8'hA8);
            set_frame_byte(32, 8'h01); set_frame_byte(33, 8'h64);

            set_frame_byte(34, 8'h27); set_frame_byte(35, 8'h10);
            set_frame_byte(36, 8'h46); set_frame_byte(37, 8'h50);
            set_frame_byte(38, 8'h00); set_frame_byte(39, 8'h18);
            set_frame_byte(40, 8'h00); set_frame_byte(41, 8'h00);

            set_frame_byte(42, 8'h01); set_frame_byte(43, 8'h01);
            set_frame_byte(44, 8'h00); set_frame_byte(45, 8'h00);
            set_frame_byte(46, 8'h00); set_frame_byte(47, 8'h2A);
            set_frame_byte(48, 8'h12); set_frame_byte(49, 8'h34);
            set_frame_byte(50, 8'h00); set_frame_byte(51, 8'h01);
            set_frame_byte(52, 8'hE2); set_frame_byte(53, 8'h40);
            set_frame_byte(54, 8'h00); set_frame_byte(55, 8'h00);
            set_frame_byte(56, 8'h03); set_frame_byte(57, 8'hE8);
        end
    endtask

    task automatic drive_rgmii_byte(
        input logic [7:0] selected_byte,
        input logic selected_valid,
        input logic selected_error
    );
        begin
            @(negedge rx_clk);
            #1ns;
            rgmii_rxd = selected_byte[3:0];
            rgmii_rx_ctl = selected_valid;
            @(posedge rx_clk);
            #1ns;
            rgmii_rxd = selected_byte[7:4];
            rgmii_rx_ctl = selected_valid ^ selected_error;
        end
    endtask

    task automatic send_rgmii_frame;
        int unsigned index;
        begin
            for (index = 0; index < 7; index++) begin
                drive_rgmii_byte(8'h55, 1'b1, 1'b0);
            end
            drive_rgmii_byte(8'hD5, 1'b1, 1'b0);
            for (index = 0; index < FRAME_BYTES; index++) begin
                drive_rgmii_byte(frame[index], 1'b1, 1'b0);
            end
            // The deframer removes these four trailing FCS bytes. CRC checking
            // is outside the current receive-path scope, so fixed values suffice.
            drive_rgmii_byte(8'h11, 1'b1, 1'b0);
            drive_rgmii_byte(8'h22, 1'b1, 1'b0);
            drive_rgmii_byte(8'h33, 1'b1, 1'b0);
            drive_rgmii_byte(8'h44, 1'b1, 1'b0);
            drive_rgmii_byte(8'h00, 1'b0, 1'b0);
        end
    endtask

    initial begin
        reset = 1'b1;
        rgmii_rxd = 4'h0;
        rgmii_rx_ctl = 1'b0;
        build_frame();

        repeat (8) @(posedge rx_clk);
        @(negedge rx_clk);
        reset = 1'b0;
        repeat (4) @(posedge rx_clk);

        send_rgmii_frame();
        repeat (32) @(posedge rx_clk);

        if (delivered_frame_bytes != FRAME_BYTES || delivered_last_count != 1) begin
            $fatal(1, "Deframer delivered %0d bytes and %0d last markers.",
                   delivered_frame_bytes, delivered_last_count);
        end
        if (message_count != 1 || error_count != 0) begin
            $fatal(1, "Expected one decoded message and no errors.");
        end
        if (protocol_version != 8'h01 || message_type != 8'h01 ||
            sequence_number != 32'd42 || instrument_id != 16'h1234 ||
            price != 32'd123456 || quantity != 32'd1000) begin
            $fatal(1, "Decoded RGMII message fields were incorrect.");
        end
        if (total_packet_count != 1 || accepted_packet_count != 1 ||
            rejected_packet_count != 0 || valid_message_count != 1) begin
            $fatal(1, "Full-path packet counters were incorrect.");
        end

        $display("PASS: RGMII DDR receive, preamble/FCS removal and UDP decoding verified.");
        $finish;
    end

endmodule
