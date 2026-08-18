class upf_normal_test extends upf_base_test;

  `uvm_component_utils(upf_normal_test)

  function new(string name = "upf_normal_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    axi4l_manager_read_seq read_seq;
    phase.raise_objection(this);

    `uvm_info(
      "PWR01",
      $sformatf(
        "Starting normal-power test: power=%0b iso=%0b reset_n=%0b",
        pwr_vif.sub_power_en,
        pwr_vif.sub_iso_en,
        pwr_vif.sub_reset_n
      ),
      UVM_LOW
    )

    read_seq = axi4l_manager_read_seq::type_id::create("read_seq");
    read_seq.start(env.upstream_agent.read_sequencer);

    phase.drop_objection(this);

  endtask

endclass