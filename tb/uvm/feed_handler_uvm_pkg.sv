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

    `include "feed_packet_item.svh"
    `include "feed_result_item.svh"
    `include "feed_handler_sequencer.svh"
    `include "feed_handler_driver.svh"
    `include "feed_input_monitor.svh"
    `include "feed_input_agent.svh"
    `include "feed_output_monitor.svh"
    `include "feed_handler_scoreboard.svh"
    `include "feed_handler_coverage.svh"
    `include "feed_handler_env.svh"
    `include "feed_handler_base_sequence.svh"
    `include "feed_handler_smoke_sequence.svh"
    `include "feed_handler_random_sequence.svh"
    `include "feed_handler_base_test.svh"
    `include "feed_handler_smoke_test.svh"
    `include "feed_handler_random_test.svh"
endpackage
