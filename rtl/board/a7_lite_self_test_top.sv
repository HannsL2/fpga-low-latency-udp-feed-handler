module a7_lite_self_test_top (
    input  logic clk_50mhz,
    input  logic reset_n,
    output logic led_pass_n,
    output logic led_fail_n
);

    localparam logic [5:0] FINAL_PACKET_INDEX = 6'd57;
    localparam logic [15:0] RESULT_TIMEOUT_CYCLES = 16'd1024;

    typedef enum logic [2:0] {
        SELF_TEST_STARTUP,
        SELF_TEST_SEND,
        SELF_TEST_WAIT_RESULT,
        SELF_TEST_CHECK_COUNTERS,
        SELF_TEST_PASS,
        SELF_TEST_FAIL
    } self_test_state_t;

    logic clk_125mhz_unbuffered;
    logic clk_125mhz;
    logic clk_feedback_unbuffered;
    logic clk_feedback;
    logic clock_locked;
    logic unused_clkfboutb;
    logic unused_clkout0b;
    logic unused_clkout1;
    logic unused_clkout1b;
    logic unused_clkout2;
    logic unused_clkout2b;
    logic unused_clkout3;
    logic unused_clkout3b;
    logic unused_clkout4;
    logic unused_clkout5;
    logic unused_clkout6;
    logic [3:0] reset_pipeline = 4'hF;
    logic reset;

    logic [7:0] s_data;
    logic       s_valid;
    logic       s_ready;
    logic       s_last;
    logic [5:0] packet_index;
    logic [15:0] timeout_counter;
    logic [5:0] startup_counter;
    self_test_state_t state;

    logic [7:0]  m_payload_data;
    logic        m_payload_valid;
    logic        m_payload_last;
    logic        message_valid;
    logic [7:0]  protocol_version;
    logic [7:0]  message_type;
    logic [31:0] sequence_number;
    logic [15:0] instrument_id;
    logic [31:0] price;
    logic [31:0] quantity;
    logic        reject_valid;
    feed_handler_pkg::reject_reason_t reject_reason;
    logic        sequence_event_valid;
    logic        sequence_gap;
    logic        sequence_duplicate;
    logic        sequence_out_of_order;
    logic [31:0] expected_sequence;
    logic [31:0] received_sequence;
    logic [31:0] missing_message_count;
    logic [31:0] total_packet_count;
    logic [31:0] accepted_packet_count;
    logic [31:0] rejected_packet_count;
    logic [31:0] malformed_packet_count;
    logic [31:0] unsupported_ethertype_count;
    logic [31:0] non_udp_packet_count;
    logic [31:0] destination_mac_mismatch_count;
    logic [31:0] destination_ip_mismatch_count;
    logic [31:0] destination_port_mismatch_count;
    logic [31:0] valid_message_count;
    logic [31:0] sequence_gap_count;
    logic [31:0] missing_message_total;
    logic [31:0] duplicate_message_count;
    logic [31:0] out_of_order_message_count;

    function automatic logic [7:0] packet_byte(input logic [5:0] index);
        case (index)
            6'd0:  packet_byte = 8'h02;
            6'd1:  packet_byte = 8'h00;
            6'd2:  packet_byte = 8'h00;
            6'd3:  packet_byte = 8'h00;
            6'd4:  packet_byte = 8'h00;
            6'd5:  packet_byte = 8'h01;
            6'd6:  packet_byte = 8'h02;
            6'd7:  packet_byte = 8'h00;
            6'd8:  packet_byte = 8'h00;
            6'd9:  packet_byte = 8'h00;
            6'd10: packet_byte = 8'h00;
            6'd11: packet_byte = 8'h02;
            6'd12: packet_byte = 8'h08;
            6'd13: packet_byte = 8'h00;
            6'd14: packet_byte = 8'h45;
            6'd15: packet_byte = 8'h00;
            6'd16: packet_byte = 8'h00;
            6'd17: packet_byte = 8'h2C;
            6'd18: packet_byte = 8'h00;
            6'd19: packet_byte = 8'h01;
            6'd20: packet_byte = 8'h00;
            6'd21: packet_byte = 8'h00;
            6'd22: packet_byte = 8'h40;
            6'd23: packet_byte = 8'h11;
            6'd24: packet_byte = 8'h00;
            6'd25: packet_byte = 8'h00;
            6'd26: packet_byte = 8'hC0;
            6'd27: packet_byte = 8'hA8;
            6'd28: packet_byte = 8'h01;
            6'd29: packet_byte = 8'h01;
            6'd30: packet_byte = 8'hC0;
            6'd31: packet_byte = 8'hA8;
            6'd32: packet_byte = 8'h01;
            6'd33: packet_byte = 8'h64;
            6'd34: packet_byte = 8'h27;
            6'd35: packet_byte = 8'h10;
            6'd36: packet_byte = 8'h46;
            6'd37: packet_byte = 8'h50;
            6'd38: packet_byte = 8'h00;
            6'd39: packet_byte = 8'h18;
            6'd40: packet_byte = 8'h00;
            6'd41: packet_byte = 8'h00;
            6'd42: packet_byte = 8'h01;
            6'd43: packet_byte = 8'h01;
            6'd44: packet_byte = 8'h00;
            6'd45: packet_byte = 8'h00;
            6'd46: packet_byte = 8'h00;
            6'd47: packet_byte = 8'h01;
            6'd48: packet_byte = 8'h12;
            6'd49: packet_byte = 8'h34;
            6'd50: packet_byte = 8'h00;
            6'd51: packet_byte = 8'h00;
            6'd52: packet_byte = 8'h30;
            6'd53: packet_byte = 8'h39;
            6'd54: packet_byte = 8'h00;
            6'd55: packet_byte = 8'h00;
            6'd56: packet_byte = 8'h00;
            6'd57: packet_byte = 8'h64;
            default: packet_byte = 8'h00;
        endcase
    endfunction

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(15.0),
        .CLKIN1_PERIOD(20.0),
        .CLKOUT0_DIVIDE_F(6.0),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) clock_manager (
        .CLKIN1(clk_50mhz),
        .CLKFBIN(clk_feedback),
        .RST(!reset_n),
        .PWRDWN(1'b0),
        .CLKOUT0(clk_125mhz_unbuffered),
        .CLKFBOUT(clk_feedback_unbuffered),
        .CLKFBOUTB(unused_clkfboutb),
        .CLKOUT0B(unused_clkout0b),
        .CLKOUT1(unused_clkout1),
        .CLKOUT1B(unused_clkout1b),
        .CLKOUT2(unused_clkout2),
        .CLKOUT2B(unused_clkout2b),
        .CLKOUT3(unused_clkout3),
        .CLKOUT3B(unused_clkout3b),
        .CLKOUT4(unused_clkout4),
        .CLKOUT5(unused_clkout5),
        .CLKOUT6(unused_clkout6),
        .LOCKED(clock_locked)
    );

    BUFG clock_buffer (
        .I(clk_125mhz_unbuffered),
        .O(clk_125mhz)
    );

    BUFG feedback_buffer (
        .I(clk_feedback_unbuffered),
        .O(clk_feedback)
    );

    always_ff @(posedge clk_125mhz or negedge reset_n) begin
        if (!reset_n) begin
            reset_pipeline <= 4'hF;
        end else if (!clock_locked) begin
            reset_pipeline <= 4'hF;
        end else begin
            reset_pipeline <= {reset_pipeline[2:0], 1'b0};
        end
    end

    assign reset = reset_pipeline[3];
    assign s_data = packet_byte(packet_index);
    assign s_valid = state == SELF_TEST_SEND;
    assign s_last = s_valid && packet_index == FINAL_PACKET_INDEX;
    assign led_pass_n = state != SELF_TEST_PASS;
    assign led_fail_n = state != SELF_TEST_FAIL;

    always_ff @(posedge clk_125mhz) begin
        if (reset) begin
            state <= SELF_TEST_STARTUP;
            startup_counter <= 6'd0;
            packet_index <= 6'd0;
            timeout_counter <= 16'd0;
        end else begin
            case (state)
                SELF_TEST_STARTUP: begin
                    if (startup_counter == 6'd31) begin
                        state <= SELF_TEST_SEND;
                    end else begin
                        startup_counter <= startup_counter + 6'd1;
                    end
                end

                SELF_TEST_SEND: begin
                    if (reject_valid) begin
                        state <= SELF_TEST_FAIL;
                    end else if (s_valid && s_ready) begin
                        if (packet_index == FINAL_PACKET_INDEX) begin
                            state <= SELF_TEST_WAIT_RESULT;
                            timeout_counter <= 16'd0;
                        end else begin
                            packet_index <= packet_index + 6'd1;
                        end
                    end
                end

                SELF_TEST_WAIT_RESULT: begin
                    if (reject_valid) begin
                        state <= SELF_TEST_FAIL;
                    end else if (message_valid) begin
                        if (protocol_version == 8'h01 &&
                            message_type == 8'h01 &&
                            sequence_number == 32'd1 &&
                            instrument_id == 16'h1234 &&
                            price == 32'd12345 &&
                            quantity == 32'd100) begin
                            state <= SELF_TEST_CHECK_COUNTERS;
                        end else begin
                            state <= SELF_TEST_FAIL;
                        end
                    end else if (timeout_counter == RESULT_TIMEOUT_CYCLES) begin
                        state <= SELF_TEST_FAIL;
                    end else begin
                        timeout_counter <= timeout_counter + 16'd1;
                    end
                end

                SELF_TEST_CHECK_COUNTERS: begin
                    if (total_packet_count == 32'd1 &&
                        accepted_packet_count == 32'd1 &&
                        rejected_packet_count == 32'd0 &&
                        valid_message_count == 32'd1 &&
                        sequence_gap_count == 32'd0 &&
                        duplicate_message_count == 32'd0 &&
                        out_of_order_message_count == 32'd0) begin
                        state <= SELF_TEST_PASS;
                    end else begin
                        state <= SELF_TEST_FAIL;
                    end
                end

                SELF_TEST_PASS: state <= SELF_TEST_PASS;
                default: state <= SELF_TEST_FAIL;
            endcase
        end
    end

    udp_feed_handler_top feed_handler (
        .clk(clk_125mhz),
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
        .quantity,
        .reject_valid,
        .reject_reason,
        .sequence_event_valid,
        .sequence_gap,
        .sequence_duplicate,
        .sequence_out_of_order,
        .expected_sequence,
        .received_sequence,
        .missing_message_count,
        .total_packet_count,
        .accepted_packet_count,
        .rejected_packet_count,
        .malformed_packet_count,
        .unsupported_ethertype_count,
        .non_udp_packet_count,
        .destination_mac_mismatch_count,
        .destination_ip_mismatch_count,
        .destination_port_mismatch_count,
        .valid_message_count,
        .sequence_gap_count,
        .missing_message_total,
        .duplicate_message_count,
        .out_of_order_message_count
    );

endmodule
