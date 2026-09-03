/*
 * REC-06 verifies authorization of epoch_clr.
 *
 * A read timeout first drives the guard through containment and into
 * GUARD_RECOVERY. Only after upstream quiescence and recovery entry are
 * established does software issue clear_reg[READ_TIMEOUT].
 *
 * The resulting recovery acknowledgment must combine with GUARD_RECOVERY and
 * all_upstream_empty to produce epoch_clr.
 */


class rec6_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec6_manager_read_seq)

  function new(string name = "rec6_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_08B0;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec6_manager_read_seq



class rec6_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec6_subordinate_read_seq)

  function new(string name = "rec6_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = TIMEOUT_COUNTER + 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec6_subordinate_read_seq



class rec6_authorized_epoch_clear_test extends base_test;

  `uvm_component_utils(rec6_authorized_epoch_clear_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec6_manager_read_seq manager_read_seq;
  rec6_subordinate_read_seq subordinate_read_seq;


  function new(string name = "rec6_authorized_epoch_clear_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq = rec6_manager_read_seq::type_id::create("manager_read_seq");
    subordinate_read_seq = rec6_subordinate_read_seq::type_id::create("subordinate_read_seq");

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[READ_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expect_read_timeout(1'b1);
    env.sb.set_expect_late_read_response(1'b1);

    `uvm_info("REC_06", "Starting authorized epoch-clear test", UVM_LOW)

    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join

    /*
     * Wait for the fault to be recorded.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1);

    /*
     * Wait until containment has resolved the upstream obligation and the
     * controller has had time to enter GUARD_RECOVERY.
     *
     * We intentionally wait for guard_busy to fall before acknowledging the
     * fault so that REC-06 exercises the legal recovery path rather than the
     * premature-clear case already covered by REC-04.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    /*
     * Software-style acknowledgment of READ_TIMEOUT.
     */
    ctrl_vif.cb.clear_reg <= '0;
    ctrl_vif.cb.clear_reg[READ_TIMEOUT] <= 1'b1;
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= '0;

    /*
     * Allow interrupt_ctrl to register the acknowledgment and the top-level
     * logic to generate epoch_clr. Dedicated SVA checks the exact condition.
     */
    repeat (3) @(ctrl_vif.cb);

    `uvm_info("REC_06", "Recovery acknowledgment generated an authorized epoch clear", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec6_authorized_epoch_clear_test