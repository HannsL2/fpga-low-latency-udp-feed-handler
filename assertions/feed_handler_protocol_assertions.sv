module payload_stream_assertions (
    input logic       clk,
    input logic       reset,
    input logic [7:0] s_data,
    input logic       s_valid,
    input logic       s_ready,
    input logic       s_last,
    input logic [7:0] m_payload_data,
    input logic       m_payload_valid,
    input logic       m_payload_ready,
    input logic       m_payload_last
);

    property input_stable_while_stalled;
        @(posedge clk) disable iff (reset)
            s_valid && !s_ready |=>
                s_valid && $stable(s_data) && $stable(s_last);
    endproperty

    property output_stable_while_stalled;
        @(posedge clk) disable iff (reset)
            m_payload_valid && !m_payload_ready |=>
                m_payload_valid && $stable(m_payload_data) &&
                $stable(m_payload_last);
    endproperty

    property payload_last_requires_valid;
        @(posedge clk) disable iff (reset)
            m_payload_last |-> m_payload_valid;
    endproperty

    assert property (input_stable_while_stalled)
        else $fatal(1, "Input stream changed while stalled.");
    assert property (output_stable_while_stalled)
        else $fatal(1, "Payload output changed while stalled.");
    assert property (payload_last_requires_valid)
        else $fatal(1, "Payload last was asserted without payload valid.");

endmodule

module sequence_event_assertions (
    input logic        clk,
    input logic        reset,
    input logic        message_valid,
    input logic        sequence_event_valid,
    input logic        sequence_gap,
    input logic        sequence_duplicate,
    input logic        sequence_out_of_order,
    input logic [31:0] missing_message_count
);

    property event_follows_message;
        @(posedge clk) disable iff (reset)
            sequence_event_valid |-> $past(message_valid);
    endproperty

    property classifications_require_event;
        @(posedge clk) disable iff (reset)
            sequence_gap || sequence_duplicate || sequence_out_of_order |->
                sequence_event_valid;
    endproperty

    property classification_is_exclusive;
        @(posedge clk) disable iff (reset)
            sequence_event_valid |->
                $onehot0({sequence_gap, sequence_duplicate,
                          sequence_out_of_order});
    endproperty

    property gap_has_missing_messages;
        @(posedge clk) disable iff (reset)
            sequence_gap |-> missing_message_count != 32'd0;
    endproperty

    property non_gap_has_no_missing_messages;
        @(posedge clk) disable iff (reset)
            sequence_event_valid && !sequence_gap |->
                missing_message_count == 32'd0;
    endproperty

    assert property (event_follows_message)
        else $fatal(1, "Sequence event was not caused by a decoded message.");
    assert property (classifications_require_event)
        else $fatal(1, "Sequence classification was asserted without an event.");
    assert property (classification_is_exclusive)
        else $fatal(1, "Multiple sequence classifications were asserted together.");
    assert property (gap_has_missing_messages)
        else $fatal(1, "Sequence gap reported zero missing messages.");
    assert property (non_gap_has_no_missing_messages)
        else $fatal(1, "Non-gap sequence event reported missing messages.");

endmodule

module feed_handler_event_assertions (
    input logic                              clk,
    input logic                              reset,
    input logic                              message_valid,
    input logic [7:0]                        protocol_version,
    input logic [7:0]                        message_type,
    input logic                              reject_valid,
    input feed_handler_pkg::reject_reason_t  reject_reason
);

    property accepted_and_rejected_are_exclusive;
        @(posedge clk) disable iff (reset)
            !(message_valid && reject_valid);
    endproperty

    property rejection_has_reason;
        @(posedge clk) disable iff (reset)
            reject_valid |-> reject_reason != feed_handler_pkg::REJECT_NONE;
    endproperty

    property idle_rejection_has_no_reason;
        @(posedge clk) disable iff (reset)
            !reject_valid |-> reject_reason == feed_handler_pkg::REJECT_NONE;
    endproperty

    property decoded_message_is_supported;
        @(posedge clk) disable iff (reset)
            message_valid |->
                protocol_version == feed_handler_pkg::MARKET_PROTOCOL_VERSION &&
                message_type inside {
                    feed_handler_pkg::MESSAGE_ADD_ORDER,
                    feed_handler_pkg::MESSAGE_CANCEL_ORDER,
                    feed_handler_pkg::MESSAGE_TRADE,
                    feed_handler_pkg::MESSAGE_SYSTEM_EVENT
                };
    endproperty

    assert property (accepted_and_rejected_are_exclusive)
        else $fatal(1, "Message acceptance and rejection occurred together.");
    assert property (rejection_has_reason)
        else $fatal(1, "Packet rejection did not include a reason.");
    assert property (idle_rejection_has_no_reason)
        else $fatal(1, "Reject reason remained active without reject valid.");
    assert property (decoded_message_is_supported)
        else $fatal(1, "Decoded message used an unsupported protocol or type.");

endmodule

bind udp_payload_router payload_stream_assertions payload_stream_checks (
    .clk,
    .reset,
    .s_data,
    .s_valid,
    .s_ready,
    .s_last,
    .m_payload_data,
    .m_payload_valid,
    .m_payload_ready,
    .m_payload_last
);

bind sequence_checker sequence_event_assertions sequence_event_checks (
    .clk,
    .reset,
    .message_valid,
    .sequence_event_valid,
    .sequence_gap,
    .sequence_duplicate,
    .sequence_out_of_order,
    .missing_message_count
);

bind udp_feed_handler_top feed_handler_event_assertions feed_handler_event_checks (
    .clk,
    .reset,
    .message_valid,
    .protocol_version,
    .message_type,
    .reject_valid,
    .reject_reason
);
