/*
 * CC-04: exercise simultaneous queue enqueue and retirement.
 *
 * Pipelined read and write traffic is staggered around the return of an earlier
 * response so that a new transaction may be admitted on the same cycle that an
 * existing transaction retires. The test targets the OP_ENQUEUE_AND_RETIRE
 * coverage bin for both the read and write queues.
 */


class cc4_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(cc4_manager_read_seq)

  int unsigned fixed_ar_delay;

  function new(string name = "cc4_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_0A00;
    req.prot  = 3'b000;
    req.ar_delay = fixed_ar_delay;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : cc4_manager_read_seq


class cc4_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(cc4_subordinate_read_seq)

  function new(string name = "cc4_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : cc4_subordinate_read_seq


class cc4_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc4_manager_write_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;
  int unsigned fixed_delay;

  function new(string name = "cc4_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.data  = fixed_data;
    req.strb = '1;
    req.aw_delay = fixed_delay;
    req.w_delay  = fixed_delay;
    req.bready_delay = 0;
    req.suppress_wvalid  = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc4_manager_write_seq


class cc4_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc4_subordinate_write_seq)

  function new(string name = "cc4_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = 20;
    req.suppress_bvalid = 0;
    req.late_bvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc4_subordinate_write_seq


class simultaneous_enqueue_retire_test_cc4 extends base_test;

  `uvm_component_utils(simultaneous_enqueue_retire_test_cc4)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  cc4_manager_read_seq manager_read_seq0;
  cc4_manager_read_seq manager_read_seq1;
  cc4_manager_read_seq manager_read_seq2;
  cc4_manager_read_seq manager_read_seq3;

  cc4_subordinate_read_seq subordinate_read_seq0;
  cc4_subordinate_read_seq subordinate_read_seq1;
  cc4_subordinate_read_seq subordinate_read_seq2;
  cc4_subordinate_read_seq subordinate_read_seq3;

  cc4_manager_write_seq manager_write_seq0;
  cc4_manager_write_seq manager_write_seq1;
  cc4_manager_write_seq manager_write_seq2;
  cc4_manager_write_seq manager_write_seq3;

  cc4_subordinate_write_seq subordinate_write_seq0;
  cc4_subordinate_write_seq subordinate_write_seq1;
  cc4_subordinate_write_seq subordinate_write_seq2;
  cc4_subordinate_write_seq subordinate_write_seq3;


  function new(string name = "simultaneous_enqueue_retire_test_cc4", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Allow later transactions to begin before earlier responses have retired.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

    manager_read_seq0 = cc4_manager_read_seq::type_id::create("manager_read_seq0");
    manager_read_seq1 = cc4_manager_read_seq::type_id::create("manager_read_seq1");
    manager_read_seq2 = cc4_manager_read_seq::type_id::create("manager_read_seq2");
    manager_read_seq3 = cc4_manager_read_seq::type_id::create("manager_read_seq3");

    subordinate_read_seq0 = cc4_subordinate_read_seq::type_id::create("subordinate_read_seq0");
    subordinate_read_seq1 = cc4_subordinate_read_seq::type_id::create("subordinate_read_seq1");
    subordinate_read_seq2 = cc4_subordinate_read_seq::type_id::create("subordinate_read_seq2");
    subordinate_read_seq3 = cc4_subordinate_read_seq::type_id::create("subordinate_read_seq3");

    manager_write_seq0 = cc4_manager_write_seq::type_id::create("manager_write_seq0");
    manager_write_seq1 = cc4_manager_write_seq::type_id::create("manager_write_seq1");
    manager_write_seq2 = cc4_manager_write_seq::type_id::create("manager_write_seq2");
    manager_write_seq3 = cc4_manager_write_seq::type_id::create("manager_write_seq3");

    subordinate_write_seq0 = cc4_subordinate_write_seq::type_id::create("subordinate_write_seq0");
    subordinate_write_seq1 = cc4_subordinate_write_seq::type_id::create("subordinate_write_seq1");
    subordinate_write_seq2 = cc4_subordinate_write_seq::type_id::create("subordinate_write_seq2");
    subordinate_write_seq3 = cc4_subordinate_write_seq::type_id::create("subordinate_write_seq3");

    /*
     * Sweep admission timing around the 20-cycle response delay so one new
     * request coincides with retirement of an earlier transaction.
     */
    manager_read_seq0.fixed_ar_delay = 0;
    manager_read_seq1.fixed_ar_delay = 18;
    manager_read_seq2.fixed_ar_delay = 19;
    manager_read_seq3.fixed_ar_delay = 20;

    manager_write_seq0.fixed_delay = 0;
    manager_write_seq1.fixed_delay = 18;
    manager_write_seq2.fixed_delay = 19;
    manager_write_seq3.fixed_delay = 20;

    manager_write_seq0.fixed_addr = 32'h4000_0B00;
    manager_write_seq1.fixed_addr = 32'h4000_0B10;
    manager_write_seq2.fixed_addr = 32'h4000_0B20;
    manager_write_seq3.fixed_addr = 32'h4000_0B30;

    manager_write_seq0.fixed_data = 32'h1111_1111;
    manager_write_seq1.fixed_data = 32'h2222_2222;
    manager_write_seq2.fixed_data = 32'h3333_3333;
    manager_write_seq3.fixed_data = 32'h4444_4444;

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr    = env.upstream_agent.read_sequencer;
    downstream_read_sqr  = env.downstream_agent.read_sequencer;
    upstream_write_sqr   = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info("CC_04", "Starting simultaneous read-queue enqueue/retire coverage closure", UVM_LOW)

    /*
     * Run the read timing sweep first.
     */
    fork

      begin
        manager_read_seq0.start(upstream_read_sqr);
        manager_read_seq1.start(upstream_read_sqr);
        manager_read_seq2.start(upstream_read_sqr);
        manager_read_seq3.start(upstream_read_sqr);
      end

      begin
        subordinate_read_seq0.start(downstream_read_sqr);
        subordinate_read_seq1.start(downstream_read_sqr);
        subordinate_read_seq2.start(downstream_read_sqr);
        subordinate_read_seq3.start(downstream_read_sqr);
      end

    join

    /*
     * Allow all read obligations to retire before beginning the write sweep.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("CC_04", "Starting simultaneous write-queue enqueue/retire coverage closure", UVM_LOW)

    /*
     * Repeat the timing sweep on the write queue.
     */
    fork

      begin
        manager_write_seq0.start(upstream_write_sqr);
        manager_write_seq1.start(upstream_write_sqr);
        manager_write_seq2.start(upstream_write_sqr);
        manager_write_seq3.start(upstream_write_sqr);
      end

      begin
        subordinate_write_seq0.start(downstream_write_sqr);
        subordinate_write_seq1.start(downstream_write_sqr);
        subordinate_write_seq2.start(downstream_write_sqr);
        subordinate_write_seq3.start(downstream_write_sqr);
      end

    join

    /*
     * Wait for the final write-response obligations to retire.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2) @(ctrl_vif.cb);

    `uvm_info("CC_04", "Simultaneous enqueue/retire coverage-closure stimulus completed", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : simultaneous_enqueue_retire_test_cc4