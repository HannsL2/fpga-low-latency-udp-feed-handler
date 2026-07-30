class feed_output_monitor extends uvm_component;
    `uvm_component_utils(feed_output_monitor)

    virtual feed_handler_if vif;
    uvm_analysis_port #(feed_result_item) result_ap;
    bit [7:0] payload_bytes[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        result_ap = new("result_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the output monitor")
        end
    endfunction

    task run_phase(uvm_phase phase);
        feed_result_item result;

        forever begin
            @(posedge vif.clk);
            if (vif.reset) begin
                payload_bytes.delete();
            end else begin
                if (vif.m_payload_valid && vif.m_payload_ready) begin
                    payload_bytes.push_back(vif.m_payload_data);
                    if (vif.m_payload_last) begin
                        result = feed_result_item::type_id::create("payload_result");
                        result.kind = RESULT_PAYLOAD;
                        result.payload = payload_bytes;
                        result_ap.write(result);
                        payload_bytes.delete();
                    end
                end

                if (vif.message_valid) begin
                    result = feed_result_item::type_id::create("message_result");
                    result.kind = RESULT_MESSAGE;
                    result.protocol_version = vif.protocol_version;
                    result.message_type = vif.message_type;
                    result.sequence_number = vif.sequence_number;
                    result.instrument_id = vif.instrument_id;
                    result.price = vif.price;
                    result.quantity = vif.quantity;
                    result_ap.write(result);
                end

                if (vif.reject_valid) begin
                    result = feed_result_item::type_id::create("reject_result");
                    result.kind = RESULT_REJECT;
                    result.reject_reason = reject_reason_t'(vif.reject_reason);
                    result_ap.write(result);
                end

                if (vif.sequence_event_valid) begin
                    result = feed_result_item::type_id::create("sequence_result");
                    result.kind = RESULT_SEQUENCE;
                    result.sequence_gap = vif.sequence_gap;
                    result.sequence_duplicate = vif.sequence_duplicate;
                    result.sequence_out_of_order = vif.sequence_out_of_order;
                    result.expected_sequence = vif.expected_sequence;
                    result.received_sequence = vif.received_sequence;
                    result.missing_message_count = vif.missing_message_count;
                    result_ap.write(result);
                end
            end
        end
    endtask
endclass
