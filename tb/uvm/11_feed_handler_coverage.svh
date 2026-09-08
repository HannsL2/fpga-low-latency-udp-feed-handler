class feed_handler_coverage extends uvm_subscriber #(feed_result_item);
    `uvm_component_utils(feed_handler_coverage)

    feed_result_kind_t sampled_kind;
    bit [7:0] sampled_message_type;
    reject_reason_t sampled_reject_reason;
    bit [2:0] sampled_sequence_class;

    covergroup result_coverage;
        option.per_instance = 1;
        result_kind: coverpoint sampled_kind;
        message_type: coverpoint sampled_message_type
            iff (sampled_kind == RESULT_MESSAGE) {
            bins add_order = {MESSAGE_ADD_ORDER};
            bins cancel_order = {MESSAGE_CANCEL_ORDER};
            bins trade = {MESSAGE_TRADE};
            bins system_event = {MESSAGE_SYSTEM_EVENT};
        }
        reject_reason: coverpoint sampled_reject_reason
            iff (sampled_kind == RESULT_REJECT);
        sequence_class: coverpoint sampled_sequence_class
            iff (sampled_kind == RESULT_SEQUENCE) {
            bins normal = {3'b000};
            bins gap = {3'b100};
            bins duplicate = {3'b010};
            bins out_of_order = {3'b001};
            illegal_bins multiple = default;
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        result_coverage = new();
    endfunction

    function void write(feed_result_item t);
        sampled_kind = t.kind;
        sampled_message_type = t.message_type;
        sampled_reject_reason = t.reject_reason;
        sampled_sequence_class = {t.sequence_gap,
                                  t.sequence_duplicate,
                                  t.sequence_out_of_order};
        result_coverage.sample();
    endfunction
endclass
