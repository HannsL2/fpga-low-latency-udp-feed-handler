package feed_handler_uvm_pkg;
    import uvm_pkg::*;
    import feed_handler_pkg::*;
    `include "uvm_macros.svh"

    typedef enum bit [1:0] {
        RESULT_PAYLOAD,
        RESULT_MESSAGE,
        RESULT_REJECT,
        RESULT_SEQUENCE
    } feed_result_kind_t;

    typedef enum bit [1:0] {
        DESTINATION_ACCEPT,
        DESTINATION_MAC_REJECT,
        DESTINATION_IP_REJECT,
        DESTINATION_PORT_REJECT
    } destination_case_t;

    typedef enum bit [1:0] {
        SEQUENCE_NORMAL,
        SEQUENCE_GAP_CASE,
        SEQUENCE_DUPLICATE_CASE,
        SEQUENCE_OLDER_CASE
    } sequence_case_t;

    localparam int unsigned RANDOM_PACKET_COUNT = 40;

    `include "03_feed_packet_item.svh"
    `include "04_feed_result_item.svh"
    `include "05_feed_handler_sequencer.svh"
    `include "06_feed_handler_driver.svh"
    `include "07_feed_input_monitor.svh"
    `include "08_feed_input_agent.svh"
    `include "09_feed_output_monitor.svh"
    `include "10_feed_handler_scoreboard.svh"
    `include "11_feed_handler_coverage.svh"
    `include "12_feed_handler_env.svh"
    `include "13_feed_handler_base_sequence.svh"
    `include "14_feed_handler_smoke_sequence.svh"
    `include "15_feed_handler_random_sequence.svh"
    `include "16_feed_handler_base_test.svh"
    `include "17_feed_handler_smoke_test.svh"
    `include "18_feed_handler_random_test.svh"
endpackage
