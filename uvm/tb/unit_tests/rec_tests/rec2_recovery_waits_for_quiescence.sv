/*
 * REC-02 verifies that recovery cannot begin before upstream quiescence.
 *
 * Three reads are admitted before the first downstream response is delayed
 * beyond TIMEOUT_COUNTER. The head therefore times out while two follower
 * obligations remain outstanding.
 *
 * The guard must enter containment but cannot proceed into GUARD_RECOVERY
 * while those upstream obligations remain. Containment injects SLVERR
 * responses until the outstanding upstream read set becomes empty. Only after
 * that quiescent condition is reached may the recovery FSM advance.
 */


class rec2_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec2_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "rec2_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec2_manager_read_seq



class rec2_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec2_subordinate_read_seq)

  int unsigned fixed_rvalid_delay;

  function new(string name = "rec2_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = fixed_rvalid_delay;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec2_subordinate_read_seq



class rec2_recovery_waits_for_quiescence_test extends base_test;

  `uvm_component_utils(rec2_recovery_waits_for_quiescence_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec2_manager_read_seq manager_read_seq0;
  rec2_manager_read_seq manager_read_seq1;
  rec2_manager_read_seq manager_read_seq2;

  rec2_subordinate_read_seq subordinate_read_seq0;
  rec2_subordinate_read_seq subordinate_read_seq1;
  rec2_subordinate_read_seq subordinate_read_seq2;


  function new(string name = "rec2_recovery_waits_for_quiescence_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Multiple reads must already be outstanding when the fault occurs, so
     * reuse the pipelined read infrastructure introduced for QUEUE.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    super.build_phase(phase);

    manager_read_seq0 = rec2_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = rec2_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = rec2_manager_read_seq::type_id::create("manager_read_seq2");

    subordinate_read_seq0 = rec2_subordinate_read_seq::type_id::create("subordinate_read_seq0");
    subordinate_read_seq1 = rec2_subordinate_read_seq::type_id::create("subordinate_read_seq1");
    subordinate_read_seq2 = rec2_subordinate_read_seq::type_id::create("subordinate_read_seq2");

    manager_read_seq0.fixed_addr = 32'h4000_0810;
    manager_read_seq1.fixed_addr = 32'h4000_0820;
    manager_read_seq2.fixed_addr = 32'h4000_0830;

    /*
     * FIFO response generation means delaying the head response also keeps the
     * follower responses behind it. The head consequently expires while all
     * three upstream obligations are still outstanding.
     */
    subordinate_read_seq0.fixed_rvalid_delay = TIMEOUT_COUNTER + 20;
    subordinate_read_seq1.fixed_rvalid_delay = 0;
    subordinate_read_seq2.fixed_rvalid_delay = 0;

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr   = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    /*
     * The head timeout plus containment produces three upstream SLVERR
     * responses. Because all three requests were already forwarded downstream,
     * their eventual real R responses must all be consumed as ghosts.
     */
    env.sb.set_expected_read_error_responses(3);
    env.sb.set_expected_late_read_responses(3);

    `uvm_info("REC_02", "Starting recovery-quiescence gating test", UVM_LOW)

    fork

      begin
        manager_read_seq0.start(upstream_read_sqr);
        manager_read_seq1.start(upstream_read_sqr);
        manager_read_seq2.start(upstream_read_sqr);
      end

      begin
        subordinate_read_seq0.start(downstream_read_sqr);
        subordinate_read_seq1.start(downstream_read_sqr);
        subordinate_read_seq2.start(downstream_read_sqr);
      end

    join

    /*
     * Wait until upstream obligations and downstream ghost debt have both been
     * resolved. The SVA checker independently verifies that RECOVERY was not
     * entered before upstream quiescence.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("REC_02", "Containment remained active until upstream quiescence was reached", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : rec2_recovery_waits_for_quiescence_test