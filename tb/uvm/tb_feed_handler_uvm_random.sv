`timescale 1ns/1ps

module tb_feed_handler_uvm_random;

    tb_feed_handler_uvm #(
        .DEFAULT_TEST_NAME("feed_handler_random_test")
    ) random_environment();

    wire        clk = random_environment.clk;
    wire        reset = random_environment.vif.reset;
    wire        s_valid = random_environment.vif.s_valid;
    wire        s_ready = random_environment.vif.s_ready;
    wire        s_last = random_environment.vif.s_last;
    wire        m_payload_valid = random_environment.vif.m_payload_valid;
    wire        m_payload_ready = random_environment.vif.m_payload_ready;
    wire        message_valid = random_environment.vif.message_valid;
    wire        reject_valid = random_environment.vif.reject_valid;
    wire        sequence_event_valid = random_environment.vif.sequence_event_valid;

endmodule
