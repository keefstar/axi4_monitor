/*
 * REC-03 verifies persistence of fault status and interrupt indication through
 * containment until explicit software acknowledgment.
 *
 * A read timeout is generated and allowed to complete containment. The test
 * then deliberately withholds clear_reg for several cycles after quiescence.
 * READ_TIMEOUT status and IRQ must remain asserted throughout that interval.
 * Only after software asserts the READ_TIMEOUT clear bit may the pending fault
 * indication be acknowledged and cleared.
 */


class rec3_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec3_manager_read_seq)

  function new(string name = "rec3_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0840;
    req.prot = 3'b000;
    req.ar_delay  = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec3_manager_read_seq



class rec3_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec3_subordinate_read_seq)

  function new(string name = "rec3_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = TIMEOUT_COUNTER + 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec3_subordinate_read_seq



class rec3_status_irq_persist_until_ack_test extends base_test;

  `uvm_component_utils(rec3_status_irq_persist_until_ack_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec3_manager_read_seq manager_read_seq;
  rec3_subordinate_read_seq subordinate_read_seq;


  function new(string name = "rec3_status_irq_persist_until_ack_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = rec3_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = rec3_subordinate_read_seq::type_id::create("subordinate_read_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * Enable READ_TIMEOUT so that once the failed epoch becomes upstream
     * quiescent, the pending sticky fault is reflected on irq.
     */
    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[READ_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("REC_03", "Starting status/IRQ persistence test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    /*
     * Wait until the fault has been recorded and the guard has become
     * upstream-quiescent. IRQ should now be asserted for the enabled fault.
     */
    do begin
      @(ctrl_vif.cb);
    end while (
      ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1 ||
      ctrl_vif.cb.irq !== 1'b1
    );

    /*
     * Deliberately withhold acknowledgment. Sticky status and IRQ must remain
     * asserted throughout this interval.
     */
    repeat (5) begin
      @(ctrl_vif.cb);

      if (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1)
        `uvm_error("REC_03_STATUS", "READ_TIMEOUT status did not remain asserted before acknowledgment")

      if (ctrl_vif.cb.irq !== 1'b1)
        `uvm_error("REC_03_IRQ", "IRQ did not remain asserted before acknowledgment")
    end

    `uvm_info("REC_03", "Status and IRQ remained asserted while acknowledgment was withheld", UVM_LOW)

    /*
     * Explicit software-style W1C acknowledgment.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[READ_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Give interrupt_ctrl sufficient time to register the acknowledgment and
     * update its sticky status.
     */
    repeat (2) @(ctrl_vif.cb);

    if (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b0)
      `uvm_error("REC_03_STATUS_CLEAR", "READ_TIMEOUT status did not clear after acknowledgment")

    if (ctrl_vif.cb.irq !== 1'b0)
      `uvm_error("REC_03_IRQ_CLEAR", "IRQ did not deassert after acknowledgment")

    /*
     * The deliberately delayed real subordinate response may still need to
     * drain before guard_busy falls.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("REC_03", "Persistent fault indication was explicitly acknowledged and cleared", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec3_status_irq_persist_until_ack_test