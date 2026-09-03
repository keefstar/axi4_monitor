class upf_read_power_loss_test extends upf_base_test;

  `uvm_component_utils(upf_read_power_loss_test)

  function new(string name = "upf_read_power_loss_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    axi4l_manager_read_seq read_seq;
    axi_resp_e upstream_resp;

    phase.raise_objection(this);
    env.sb.set_expect_read_timeout(1'b1); //tell scoreboard 
    read_seq = axi4l_manager_read_seq::type_id::create("read_seq");

    fork
        
      /* Issue read and wait until manager eventually receives a response */
      begin
        read_seq.start(env.upstream_agent.read_sequencer);
      end

      /* Kill PD_SUB only after the read has been accepted downstream */
      begin
        do begin
          @(env.downstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.downstream_agent.monitor.vif.mon_cb.arvalid === 1'b1 &&
          env.downstream_agent.monitor.vif.mon_cb.arready === 1'b1
        ));

        `uvm_info(
          "PWR03",
          "Downstream AR accepted; powering off PD_SUB before read response",
          UVM_LOW
        )

        pwr_vif.sub_power_down();
      end

      /* Observe the response eventually returned by the SCC upstream */
      begin
        do begin
          @(env.upstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.upstream_agent.monitor.vif.mon_cb.rvalid === 1'b1 &&
          env.upstream_agent.monitor.vif.mon_cb.rready === 1'b1
        ));

        upstream_resp = env.upstream_agent.monitor.vif.mon_cb.r.resp;
      end

    join

    repeat (2) @(pwr_vif.cb);

    if (pwr_vif.sub_power_en !== 1'b0)
      `uvm_error("PWR03", "PD_SUB did not power off")

    if (pwr_vif.sub_iso_en !== 1'b1)
      `uvm_error("PWR03", "PD_SUB isolation was not asserted")

    if (upstream_resp !== RESP_SLVERR)
      `uvm_error(
        "PWR03",
        $sformatf("Expected upstream SLVERR, received %s", upstream_resp.name())
      )

    if (ctrl_vif.status_reg[READ_TIMEOUT] !== 1'b1)
      `uvm_error("PWR03", "READ_TIMEOUT status was not asserted")

    if (ctrl_vif.irq !== 1'b1)
      `uvm_error("PWR03", "IRQ was not asserted")

    `uvm_info( "PWR03", $sformatf( "Power-loss containment complete: resp=%s read_timeout=%b irq=%b", upstream_resp.name(), ctrl_vif.status_reg[READ_TIMEOUT], ctrl_vif.irq ), UVM_LOW )

    phase.drop_objection(this);

  endtask

endclass : upf_read_power_loss_test