module ethernet_frame_deframer (
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] phy_data,
    input  logic       phy_data_valid,
    input  logic       phy_data_error,

    output logic [7:0] frame_data,
    output logic       frame_valid,
    input  logic       frame_ready,
    output logic       frame_last,
    output logic       frame_error
);

    typedef enum logic [1:0] {
        SEARCH_PREAMBLE,
        RECEIVE_FRAME,
        DISCARD_FRAME
    } deframer_state_t;

    localparam logic [7:0] PREAMBLE_BYTE = 8'h55;
    localparam logic [7:0] START_FRAME_DELIMITER = 8'hD5;

    deframer_state_t state;
    logic [2:0] preamble_count;
    logic [7:0] tail_buffer [0:4];
    logic [2:0] tail_count;
    logic       previous_phy_valid;
    logic       output_blocked;
    integer     tail_index;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= SEARCH_PREAMBLE;
            preamble_count <= 3'd0;
            tail_count <= 3'd0;
            previous_phy_valid <= 1'b0;
            frame_data <= 8'h00;
            frame_valid <= 1'b0;
            frame_last <= 1'b0;
            frame_error <= 1'b0;
            output_blocked <= 1'b0;
            for (tail_index = 0; tail_index < 5; tail_index++) begin
                tail_buffer[tail_index] <= 8'h00;
            end
        end else begin
            frame_valid <= 1'b0;
            frame_last <= 1'b0;
            frame_error <= 1'b0;
            previous_phy_valid <= phy_data_valid;


            if (frame_valid && !frame_ready) begin
                output_blocked <= 1'b1;
            end

            case (state)
                SEARCH_PREAMBLE: begin
                    tail_count <= 3'd0;
                    output_blocked <= 1'b0;

                    if (phy_data_valid) begin
                        if (phy_data_error) begin
                            state <= DISCARD_FRAME;
                            preamble_count <= 3'd0;
                        end else if (phy_data == PREAMBLE_BYTE) begin
                            if (preamble_count != 3'd7) begin
                                preamble_count <= preamble_count + 3'd1;
                            end
                        end else if (phy_data == START_FRAME_DELIMITER &&
                                     preamble_count == 3'd7) begin
                            state <= RECEIVE_FRAME;
                            preamble_count <= 3'd0;
                        end else begin
                            preamble_count <= 3'd0;
                        end
                    end
                end

                RECEIVE_FRAME: begin
                    if (phy_data_valid) begin
                        if (phy_data_error) begin
                            state <= DISCARD_FRAME;
                            frame_error <= 1'b1;
                            tail_count <= 3'd0;
                        end else if (tail_count < 3'd5) begin
                            tail_buffer[tail_count] <= phy_data;
                            tail_count <= tail_count + 3'd1;
                        end else begin
                            frame_data <= tail_buffer[0];
                            frame_valid <= 1'b1;
                            if (!frame_ready) begin
                                output_blocked <= 1'b1;
                            end
                            tail_buffer[0] <= tail_buffer[1];
                            tail_buffer[1] <= tail_buffer[2];
                            tail_buffer[2] <= tail_buffer[3];
                            tail_buffer[3] <= tail_buffer[4];
                            tail_buffer[4] <= phy_data;
                        end
                    end else if (previous_phy_valid) begin
                        if (tail_count == 3'd5 && !output_blocked) begin
                            frame_data <= tail_buffer[0];
                            frame_valid <= 1'b1;
                            frame_last <= 1'b1;
                        end else begin
                            frame_error <= 1'b1;
                        end
                        state <= SEARCH_PREAMBLE;
                        preamble_count <= 3'd0;
                        tail_count <= 3'd0;
                    end
                end

                default: begin
                    if (!phy_data_valid && previous_phy_valid) begin
                        state <= SEARCH_PREAMBLE;
                        preamble_count <= 3'd0;
                        tail_count <= 3'd0;
                    end
                end
            endcase
        end
    end

endmodule
