class upf_write_power_loss_test extends upf_base_test;

  `uvm_component_utils(upf_write_power_loss_test)

  function new(string name = "upf_write_power_loss_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    axi4l_manager_write_seq write_seq;
    axi_resp_e upstream_resp;
    bit aw_done, w_done;

    phase.raise_objection(this);

    env.sb.set_expect_write_timeout(1'b1);
    write_seq = axi4l_manager_write_seq::type_id::create("write_seq");

    fork

      begin
        write_seq.start(env.upstream_agent.write_sequencer);
      end

      begin
        aw_done = 0;
        w_done = 0;

        while (!(aw_done && w_done)) begin
          @(env.downstream_agent.monitor.vif.mon_cb);

          if (
            env.downstream_agent.monitor.vif.mon_cb.awvalid === 1'b1 &&
            env.downstream_agent.monitor.vif.mon_cb.awready === 1'b1
          )
            aw_done = 1;

          if (
            env.downstream_agent.monitor.vif.mon_cb.wvalid === 1'b1 &&
            env.downstream_agent.monitor.vif.mon_cb.wready === 1'b1
          )
            w_done = 1;
        end

        `uvm_info( "PWR04", "Downstream AW/W accepted; powering off PD_SUB before B response", UVM_LOW )

        pwr_vif.sub_power_down();
      end

      begin
        do begin
          @(env.upstream_agent.monitor.vif.mon_cb);
        end while (!(
          env.upstream_agent.monitor.vif.mon_cb.bvalid === 1'b1 &&
          env.upstream_agent.monitor.vif.mon_cb.bready === 1'b1
        ));

        upstream_resp = env.upstream_agent.monitor.vif.mon_cb.b.resp;
      end

    join

    repeat (2) @(pwr_vif.cb);

    if (pwr_vif.sub_power_en !== 1'b0)
      `uvm_error("PWR04", "PD_SUB did not power off")

    if (pwr_vif.sub_iso_en !== 1'b1)
      `uvm_error("PWR04", "PD_SUB isolation was not asserted")

    if (upstream_resp !== RESP_SLVERR)
      `uvm_error(
        "PWR04",
        $sformatf("Expected upstream SLVERR, received %s", upstream_resp.name())
      )

    if (ctrl_vif.status_reg[WRITE_RESP_TIMEOUT] !== 1'b1)
      `uvm_error("PWR04", "WRITE_RESP_TIMEOUT status was not asserted")

    if (ctrl_vif.irq !== 1'b1)
      `uvm_error("PWR04", "IRQ was not asserted")

    `uvm_info( "PWR04", $sformatf( "Power-loss containment complete: resp=%s write_timeout=%b irq=%b", upstream_resp.name(), ctrl_vif.status_reg[WRITE_RESP_TIMEOUT], ctrl_vif.irq ), UVM_LOW )

    phase.drop_objection(this);

  endtask

endclass : upf_write_power_loss_test