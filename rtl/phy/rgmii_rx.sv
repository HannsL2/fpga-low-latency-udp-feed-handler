module rgmii_rx (
    input  logic       rx_clk,
    input  logic [3:0] rgmii_rxd,
    input  logic       rgmii_rx_ctl,

    output logic [7:0] data,
    output logic       data_valid,
    output logic       data_error
);

    logic [3:0] rising_nibble;
    logic [3:0] falling_nibble;
    logic       rising_control;
    logic       falling_control;

    genvar bit_index;
    generate
        for (bit_index = 0; bit_index < 4; bit_index++) begin : generate_data_iddr
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) data_iddr (
                .Q1(rising_nibble[bit_index]),
                .Q2(falling_nibble[bit_index]),
                .C(rx_clk),
                .CE(1'b1),
                .D(rgmii_rxd[bit_index]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    endgenerate

    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) control_iddr (
        .Q1(rising_control),
        .Q2(falling_control),
        .C(rx_clk),
        .CE(1'b1),
        .D(rgmii_rx_ctl),
        .R(1'b0),
        .S(1'b0)
    );

    always_comb begin
        data = {falling_nibble, rising_nibble};
        data_valid = rising_control;
        data_error = rising_control ^ falling_control;
    end

endmodule
