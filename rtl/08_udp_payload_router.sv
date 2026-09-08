module udp_payload_router (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  s_data,
    input  logic        s_valid,
    input  logic        s_last,
    input  logic [15:0] byte_index,
    input  logic        packet_active,
    input  logic        decision_valid,
    input  logic        destination_match,
    input  logic [15:0] udp_length,

    output logic        s_ready,
    output logic [7:0]  m_payload_data,
    output logic        m_payload_valid,
    input  logic        m_payload_ready,
    output logic        m_payload_last,

    output logic [7:0]  payload_byte_data,
    output logic        payload_byte_valid,
    output logic        payload_byte_last,
    output logic [15:0] payload_byte_index
);

    localparam logic [15:0] UDP_HEADER_FINAL_INDEX = 16'd41;
    localparam logic [15:0] PAYLOAD_FIRST_INDEX = 16'd42;
    localparam logic [15:0] UDP_HEADER_BYTES = 16'd8;

    logic route_active;
    logic route_start;
    logic route_selected;
    logic [15:0] payload_final_index;
    logic [15:0] active_final_index;
    logic current_byte_is_payload;
    logic output_slot_ready;

    always_comb begin
        route_start = decision_valid && destination_match && packet_active &&
                      udp_length > UDP_HEADER_BYTES;
        route_selected = route_active || route_start;
        active_final_index = route_active ? payload_final_index :
                             (UDP_HEADER_FINAL_INDEX + udp_length);
        current_byte_is_payload = route_selected &&
                                  byte_index >= PAYLOAD_FIRST_INDEX &&
                                  byte_index <= active_final_index;
        output_slot_ready = !m_payload_valid || m_payload_ready;

        s_ready = !reset && (!current_byte_is_payload || output_slot_ready);

        payload_byte_data = s_data;
        payload_byte_valid = s_valid && s_ready && current_byte_is_payload;
        payload_byte_last = payload_byte_valid &&
                            (s_last || byte_index == active_final_index);
        payload_byte_index = byte_index - PAYLOAD_FIRST_INDEX;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            route_active <= 1'b0;
            payload_final_index <= 16'h0000;
            m_payload_data <= 8'h00;
            m_payload_valid <= 1'b0;
            m_payload_last <= 1'b0;
        end else begin
            if (route_start) begin
                route_active <= 1'b1;
                payload_final_index <= UDP_HEADER_FINAL_INDEX + udp_length;
            end

            if (payload_byte_valid && payload_byte_last) begin
                route_active <= 1'b0;
            end

            if (output_slot_ready) begin
                if (payload_byte_valid) begin
                    m_payload_data <= payload_byte_data;
                    m_payload_valid <= 1'b1;
                    m_payload_last <= payload_byte_last;
                end else begin
                    m_payload_valid <= 1'b0;
                    m_payload_last <= 1'b0;
                end
            end
        end
    end

endmodule
