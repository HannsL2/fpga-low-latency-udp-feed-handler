class feed_handler_driver extends uvm_driver #(feed_packet_item);
    `uvm_component_utils(feed_handler_driver)

    virtual feed_handler_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the driver")
        end
    endfunction

    task apply_reset();
        vif.reset <= 1'b1;
        vif.s_data <= 8'h00;
        vif.s_valid <= 1'b0;
        vif.s_last <= 1'b0;
        vif.m_payload_ready <= 1'b1;
        repeat (4) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.reset <= 1'b0;
        repeat (2) @(posedge vif.clk);
    endtask

    task drive_payload_stall(int unsigned stall_cycles);
        if (stall_cycles == 0) return;
        do @(posedge vif.clk); while (!vif.m_payload_valid);
        @(negedge vif.clk);
        vif.m_payload_ready <= 1'b0;
        repeat (stall_cycles) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.m_payload_ready <= 1'b1;
    endtask

    task drive_packet(feed_packet_item item);
        foreach (item.packet_bytes[index]) begin
            repeat (item.input_gap_cycles) begin
                @(negedge vif.clk);
                vif.s_valid <= 1'b0;
                vif.s_last <= 1'b0;
            end

            @(negedge vif.clk);
            vif.s_data <= item.packet_bytes[index];
            vif.s_valid <= 1'b1;
            vif.s_last <= (index == item.packet_bytes.size() - 1);

            do @(posedge vif.clk); while (!vif.s_ready);
        end

        @(negedge vif.clk);
        vif.s_valid <= 1'b0;
        vif.s_last <= 1'b0;
        repeat (item.idle_cycles) @(posedge vif.clk);
    endtask

    task run_phase(uvm_phase phase);
        feed_packet_item request;
        apply_reset();

        forever begin
            seq_item_port.get_next_item(request);
            fork
                drive_packet(request);
                drive_payload_stall(request.payload_stall_cycles);
            join
            vif.m_payload_ready <= 1'b1;
            seq_item_port.item_done();
        end
    endtask
endclass
