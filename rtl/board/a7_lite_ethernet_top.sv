module a7_lite_ethernet_top (
    input  logic       clk_50mhz,
    input  logic       reset_n,

    input  logic       eth_rx_clk,
    input  logic       eth_rx_ctl,
    input  logic [3:0] eth_rxd,
    output logic       eth_tx_clk,
    output logic       eth_tx_ctl,
    output logic [3:0] eth_txd,
    output logic       eth_mdc,
    inout  wire        eth_mdio,
    output logic       eth_reset_n,

    output logic       uart_tx,
    output logic       led_link_n,
    output logic       led_activity_n
);

    localparam int unsigned PHY_RESET_CYCLES = 1_000_000;
    localparam int unsigned ACTIVITY_LED_CYCLES = 5_000_000;

    logic tx_clock_unbuffered;
    logic tx_clock_125mhz;
    logic tx_feedback_unbuffered;
    logic tx_feedback;
    logic tx_clock_locked;
    logic tx_clock_pin;

    logic rx_clock_input;
    logic rx_clock_unbuffered;
    logic rx_clock;
    logic rx_feedback_unbuffered;
    logic rx_feedback;
    logic rx_clock_locked;

    logic [19:0] phy_reset_counter = '0;
    logic [3:0] rx_reset_pipeline = 4'hF;
    logic rx_reset;

    logic [7:0] rgmii_data;
    logic rgmii_data_valid;
    logic rgmii_data_error;
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

    logic uart_message_valid;
    logic [7:0] uart_message_type;
    logic [31:0] uart_sequence_number;
    logic [15:0] uart_instrument_id;
    logic [31:0] uart_price;
    logic [31:0] uart_quantity;
    logic uart_message_ready;
    logic message_cdc_ready;
    logic message_cdc_overflow;
    logic [22:0] activity_counter;

    IBUF rx_clock_input_buffer (
        .I(eth_rx_clk),
        .O(rx_clock_input)
    );

    // The PHY is strapped for no internal RX delay. The MMCM introduces a
    // 2.5 ns sampling shift before the IDDR input registers. This centres the
    // implemented setup/hold window after accounting for the package and
    // clock-network delays reported by static timing analysis.
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(8.0),
        .CLKIN1_PERIOD(8.0),
        .CLKOUT0_DIVIDE_F(8.0),
        .CLKOUT0_PHASE(112.5),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) rx_clock_manager (
        .CLKIN1(rx_clock_input),
        .CLKFBIN(rx_feedback),
        .RST(!reset_n),
        .PWRDWN(1'b0),
        .CLKOUT0(rx_clock_unbuffered),
        .CLKFBOUT(rx_feedback_unbuffered),
        .LOCKED(rx_clock_locked)
    );

    BUFG rx_clock_buffer (
        .I(rx_clock_unbuffered),
        .O(rx_clock)
    );

    BUFG rx_feedback_buffer (
        .I(rx_feedback_unbuffered),
        .O(rx_feedback)
    );

    // A free-running 125 MHz transmit clock lets the PHY establish a gigabit
    // link even though this receive-only design never transmits frame data.
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(15.0),
        .CLKIN1_PERIOD(20.0),
        .CLKOUT0_DIVIDE_F(6.0),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) tx_clock_manager (
        .CLKIN1(clk_50mhz),
        .CLKFBIN(tx_feedback),
        .RST(!reset_n),
        .PWRDWN(1'b0),
        .CLKOUT0(tx_clock_unbuffered),
        .CLKFBOUT(tx_feedback_unbuffered),
        .LOCKED(tx_clock_locked)
    );

    BUFG tx_clock_buffer (
        .I(tx_clock_unbuffered),
        .O(tx_clock_125mhz)
    );

    BUFG tx_feedback_buffer (
        .I(tx_feedback_unbuffered),
        .O(tx_feedback)
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) tx_clock_output_register (
        .Q(tx_clock_pin),
        .C(tx_clock_125mhz),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );

    OBUF tx_clock_output_buffer (
        .I(tx_clock_pin),
        .O(eth_tx_clk)
    );

    assign eth_tx_ctl = 1'b0;
    assign eth_txd = 4'h0;
    assign eth_mdc = 1'b0;
    assign eth_mdio = 1'bz;

    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            phy_reset_counter <= '0;
            eth_reset_n <= 1'b0;
        end else if (!tx_clock_locked) begin
            phy_reset_counter <= '0;
            eth_reset_n <= 1'b0;
        end else if (phy_reset_counter != PHY_RESET_CYCLES - 1) begin
            phy_reset_counter <= phy_reset_counter + 1'b1;
            eth_reset_n <= 1'b0;
        end else begin
            eth_reset_n <= 1'b1;
        end
    end

    always_ff @(posedge rx_clock or negedge reset_n) begin
        if (!reset_n) begin
            rx_reset_pipeline <= 4'hF;
        end else if (!rx_clock_locked || !eth_reset_n) begin
            rx_reset_pipeline <= 4'hF;
        end else begin
            rx_reset_pipeline <= {rx_reset_pipeline[2:0], 1'b0};
        end
    end

    assign rx_reset = rx_reset_pipeline[3];

    rgmii_rx receiver (
        .rx_clk(rx_clock),
        .rgmii_rxd(eth_rxd),
        .rgmii_rx_ctl(eth_rx_ctl),
        .data(rgmii_data),
        .data_valid(rgmii_data_valid),
        .data_error(rgmii_data_error)
    );

    ethernet_frame_deframer deframer (
        .clk(rx_clock),
        .reset(rx_reset),
        .phy_data(rgmii_data),
        .phy_data_valid(rgmii_data_valid),
        .phy_data_error(rgmii_data_error),
        .frame_data,
        .frame_valid,
        .frame_ready,
        .frame_last,
        .frame_error
    );

    udp_feed_handler_top feed_handler (
        .clk(rx_clock),
        .reset(rx_reset),
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
        .reject_valid(),
        .reject_reason(),
        .sequence_event_valid(),
        .sequence_gap(),
        .sequence_duplicate(),
        .sequence_out_of_order(),
        .expected_sequence(),
        .received_sequence(),
        .missing_message_count(),
        .total_packet_count(),
        .accepted_packet_count(),
        .rejected_packet_count(),
        .malformed_packet_count(),
        .unsupported_ethertype_count(),
        .non_udp_packet_count(),
        .destination_mac_mismatch_count(),
        .destination_ip_mismatch_count(),
        .destination_port_mismatch_count(),
        .valid_message_count(),
        .sequence_gap_count(),
        .missing_message_total(),
        .duplicate_message_count(),
        .out_of_order_message_count()
    );

    feed_message_cdc message_clock_crossing (
        .source_clk(rx_clock),
        .source_reset(rx_reset),
        .source_valid(message_valid),
        .source_message_type(message_type),
        .source_sequence_number(sequence_number),
        .source_instrument_id(instrument_id),
        .source_price(price),
        .source_quantity(quantity),
        .source_ready(message_cdc_ready),
        .source_overflow(message_cdc_overflow),
        .destination_clk(clk_50mhz),
        .destination_reset(!reset_n),
        .destination_ready(uart_message_ready),
        .destination_valid(uart_message_valid),
        .destination_message_type(uart_message_type),
        .destination_sequence_number(uart_sequence_number),
        .destination_instrument_id(uart_instrument_id),
        .destination_price(uart_price),
        .destination_quantity(uart_quantity)
    );

    feed_message_uart uart_reporter (
        .clk(clk_50mhz),
        .reset(!reset_n),
        .message_valid(uart_message_valid),
        .message_type(uart_message_type),
        .sequence_number(uart_sequence_number),
        .instrument_id(uart_instrument_id),
        .price(uart_price),
        .quantity(uart_quantity),
        .message_ready(uart_message_ready),
        .uart_tx_pin(uart_tx)
    );

    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            activity_counter <= '0;
        end else if (uart_message_valid) begin
            activity_counter <= ACTIVITY_LED_CYCLES - 1;
        end else if (activity_counter != 0) begin
            activity_counter <= activity_counter - 1'b1;
        end
    end

    // Board LEDs are active-low. D6 indicates a recovered gigabit RX clock;
    // D5 lights briefly whenever a decoded message reaches the UART domain.
    assign led_link_n = !rx_clock_locked;
    assign led_activity_n = activity_counter == 0;

endmodule
