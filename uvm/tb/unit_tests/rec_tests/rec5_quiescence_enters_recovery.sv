/*
 * REC-05 verifies the transition from containment into recovery.
 *
 * Three reads are admitted before the head response is delayed beyond
 * TIMEOUT_COUNTER. The resulting timeout forces containment while follower
 * obligations remain outstanding. Containment then resolves all three upstream
 * read obligations with SLVERR responses.
 *
 * Once all_upstream_empty becomes true, the top-level controller must advance
 * from GUARD_CONTAINING into GUARD_RECOVERY.
 */


class rec5_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(rec5_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "rec5_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : rec5_manager_read_seq



class rec5_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(rec5_subordinate_read_seq)

  int unsigned fixed_rvalid_delay;

  function new(string name = "rec5_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = fixed_rvalid_delay;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : rec5_subordinate_read_seq



class rec5_quiescence_enters_recovery_test extends base_test;

  `uvm_component_utils(rec5_quiescence_enters_recovery_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  rec5_manager_read_seq manager_read_seq0;
  rec5_manager_read_seq manager_read_seq1;
  rec5_manager_read_seq manager_read_seq2;

  rec5_subordinate_read_seq subordinate_read_seq0;
  rec5_subordinate_read_seq subordinate_read_seq1;
  rec5_subordinate_read_seq subordinate_read_seq2;


  function new(string name = "rec5_quiescence_enters_recovery_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    super.build_phase(phase);

    manager_read_seq0 = rec5_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = rec5_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = rec5_manager_read_seq::type_id::create("manager_read_seq2");

    subordinate_read_seq0 = rec5_subordinate_read_seq::type_id::create("subordinate_read_seq0");
    subordinate_read_seq1 = rec5_subordinate_read_seq::type_id::create("subordinate_read_seq1");
    subordinate_read_seq2 = rec5_subordinate_read_seq::type_id::create("subordinate_read_seq2");

    manager_read_seq0.fixed_addr = 32'h4000_0880;
    manager_read_seq1.fixed_addr = 32'h4000_0890;
    manager_read_seq2.fixed_addr = 32'h4000_08A0;

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

    ctrl_vif.cb.enable_reg <= '0;
    ctrl_vif.cb.enable_reg[READ_TIMEOUT] <= 1'b1;
    ctrl_vif.cb.clear_reg <= '0;

    env.sb.set_expected_read_error_responses(3);
    env.sb.set_expected_late_read_responses(3);

    `uvm_info("REC_05", "Starting containment-to-recovery transition test", UVM_LOW)

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
    * Pipelined sequences complete after request admission, not after the
    * resulting responses. Wait explicitly for the injected timeout fault so
    * that the containment/recovery episode has actually begun.
    */
    do begin
        @(ctrl_vif.cb);
    end while (ctrl_vif.cb.status_reg[READ_TIMEOUT] !== 1'b1);

    /*
    * Allow containment to retire all upstream obligations. The dedicated SVA
    * independently proves that upstream quiescence causes the state transition
    * from GUARD_CONTAINING to GUARD_RECOVERY.
    */
    do begin
        @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("REC_05", "Containment reached quiescence and the guard entered recovery", UVM_LOW)

    phase.drop_objection(this);

    endtask : run_phase

endclass : rec5_quiescence_enters_recovery_test