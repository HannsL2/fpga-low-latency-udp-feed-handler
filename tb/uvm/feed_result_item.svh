class feed_result_item extends uvm_sequence_item;
    feed_result_kind_t kind;
    bit [7:0] payload[$];
    reject_reason_t reject_reason;
    bit [7:0] protocol_version;
    bit [7:0] message_type;
    bit [31:0] sequence_number;
    bit [15:0] instrument_id;
    bit [31:0] price;
    bit [31:0] quantity;
    bit sequence_gap;
    bit sequence_duplicate;
    bit sequence_out_of_order;
    bit [31:0] expected_sequence;
    bit [31:0] received_sequence;
    bit [31:0] missing_message_count;

    `uvm_object_utils(feed_result_item)

    function new(string name = "feed_result_item");
        super.new(name);
        reject_reason = REJECT_NONE;
    endfunction

    virtual function string convert2string();
        case (kind)
            RESULT_PAYLOAD:
                return $sformatf("payload bytes=%0d", payload.size());
            RESULT_MESSAGE:
                return $sformatf("message type=%02h sequence=%0d instrument=%04h price=%0d quantity=%0d",
                                 message_type, sequence_number, instrument_id,
                                 price, quantity);
            RESULT_REJECT:
                return $sformatf("reject reason=%0d", reject_reason);
            RESULT_SEQUENCE:
                return $sformatf("sequence expected=%0d received=%0d gap=%0b duplicate=%0b older=%0b missing=%0d",
                                 expected_sequence, received_sequence, sequence_gap,
                                 sequence_duplicate, sequence_out_of_order,
                                 missing_message_count);
            default:
                return "unknown result";
        endcase
    endfunction
endclass
