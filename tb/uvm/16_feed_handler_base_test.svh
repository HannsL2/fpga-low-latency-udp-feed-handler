class feed_handler_base_test extends uvm_test;
    `uvm_component_utils(feed_handler_base_test)

    feed_handler_env env;
    virtual feed_handler_if vif;

    function new(string name = "feed_handler_base_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = feed_handler_env::type_id::create("env", this);
        if (!uvm_config_db#(virtual feed_handler_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "feed_handler_if was not supplied to the test")
        end
    endfunction
endclass
