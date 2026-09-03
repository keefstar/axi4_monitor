/*
 * QUEUE-04 verifies multiple outstanding writes.
 *
 * Three complete upstream AW/W transaction pairs are admitted before the first
 * B response retires. This forces the SCC write queue to track several
 * outstanding write-response obligations simultaneously.
 *
 * The pipelined write-driver mode is required because the original blocking
 * driver waits for B before completing each sequence item, which would prevent
 * more than one write from becoming outstanding at a time.
 */


class queue4_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(queue4_manager_write_seq)
  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;

  function new(string name = "queue4_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();
    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.data = fixed_data;
    req.strb = '1;
    req.aw_delay = 0;
    req.w_delay = 0;
    req.bready_delay = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : queue4_manager_write_seq



class queue4_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(queue4_subordinate_write_seq)

  function new(string name = "queue4_subordinate_write_seq");
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

endclass : queue4_subordinate_write_seq



class queue4_multiple_outstanding_writes_test extends base_test;

  `uvm_component_utils(queue4_multiple_outstanding_writes_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  queue4_manager_write_seq manager_write_seq0;
  queue4_manager_write_seq manager_write_seq1;
  queue4_manager_write_seq manager_write_seq2;

  queue4_subordinate_write_seq subordinate_write_seq0;
  queue4_subordinate_write_seq subordinate_write_seq1;
  queue4_subordinate_write_seq subordinate_write_seq2;


  function new(string name = "queue4_multiple_outstanding_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Enable the optional pipelined write-driver paths only for this test.
     * Existing tests retain the original blocking write-driver behavior.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

    manager_write_seq0 = queue4_manager_write_seq::type_id::create("manager_write_seq0");
    manager_write_seq1 = queue4_manager_write_seq::type_id::create("manager_write_seq1");
    manager_write_seq2 = queue4_manager_write_seq::type_id::create("manager_write_seq2");

    subordinate_write_seq0 = queue4_subordinate_write_seq::type_id::create("subordinate_write_seq0");
    subordinate_write_seq1 = queue4_subordinate_write_seq::type_id::create("subordinate_write_seq1");
    subordinate_write_seq2 = queue4_subordinate_write_seq::type_id::create("subordinate_write_seq2");

    manager_write_seq0.fixed_addr = 32'h4000_0200;
    manager_write_seq1.fixed_addr = 32'h4000_0210;
    manager_write_seq2.fixed_addr = 32'h4000_0220;

    manager_write_seq0.fixed_data = 32'h1111_1111;
    manager_write_seq1.fixed_data = 32'h2222_2222;
    manager_write_seq2.fixed_data = 32'h3333_3333;

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr   = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info("QUEUE_04", "Starting multiple-outstanding-write test", UVM_LOW)

    /*
     * The manager sequence stream and subordinate sequence stream run
     * concurrently. Within each stream, sequence order is deterministic.
     *
     * Because the pipelined drivers release each sequence item immediately
     * after AW/W completion, write 2 and write 3 may begin before B1 returns.
     */
    fork

      begin
        manager_write_seq0.start(upstream_write_sqr);
        manager_write_seq1.start(upstream_write_sqr);
        manager_write_seq2.start(upstream_write_sqr);
      end

      begin
        subordinate_write_seq0.start(downstream_write_sqr);
        subordinate_write_seq1.start(downstream_write_sqr);
        subordinate_write_seq2.start(downstream_write_sqr);
      end

    join

    /*
     * In pipelined mode, sequence completion means the AW/W pair has completed,
     * not that the B response has retired. Wait until the SCC has no remaining
     * outstanding write obligations.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_04", "Multiple outstanding writes completed and retired", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue4_multiple_outstanding_writes_test