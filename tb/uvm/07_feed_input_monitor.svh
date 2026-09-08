class feed_input_monitor extends uvm_component;
    `uvm_component_utils(feed_input_monitor)

    virtual feed_handler_if vif;
    uvm_analysis_port #(feed_packet_item) packet_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        packet_ap = new("packet_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the input monitor")
        end
    endfunction

    task run_phase(uvm_phase phase);
        feed_packet_item observed_packet;
        observed_packet = feed_packet_item::type_id::create("observed_packet");

        forever begin
            @(posedge vif.clk);
            if (vif.reset) begin
                observed_packet.packet_bytes.delete();
            end else if (vif.s_valid && vif.s_ready) begin
                observed_packet.packet_bytes.push_back(vif.s_data);
                if (vif.s_last) begin
                    packet_ap.write(observed_packet);
                    observed_packet = feed_packet_item::type_id::create("observed_packet");
                end
            end
        end
    endtask
endclass
