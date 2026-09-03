/*
 * QUEUE-06 verifies independent read/write occupancy.
 *
 * Multiple reads and multiple writes are issued concurrently, with downstream
 * R and B responses delayed so both queues contain outstanding obligations at
 * the same time. The read and write paths must operate independently: activity
 * on one path must not prevent the other from accepting or retiring its own
 * transactions.
 */

class queue6_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(queue6_manager_read_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;

  function new(string name = "queue6_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.ar_delay = 0;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : queue6_manager_read_seq



class queue6_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(queue6_subordinate_read_seq)

  function new(string name = "queue6_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = 20;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : queue6_subordinate_read_seq



class queue6_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(queue6_manager_write_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;

  function new(string name = "queue6_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.data = fixed_data;
    req.strb = '1;
    req.aw_delay = 0;
    req.w_delay  = 0;
    req.bready_delay  = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : queue6_manager_write_seq



class queue6_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(queue6_subordinate_write_seq)

  function new(string name = "queue6_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = 25;
    req.suppress_bvalid = 0;
    req.late_bvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : queue6_subordinate_write_seq



class queue6_independent_read_write_occupancy_test extends base_test;

  `uvm_component_utils(queue6_independent_read_write_occupancy_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;
  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  queue6_manager_read_seq manager_read_seq[3];
  queue6_subordinate_read_seq subordinate_read_seq[3];

  queue6_manager_write_seq manager_write_seq[3];
  queue6_subordinate_write_seq subordinate_write_seq[3];


  function new(string name = "queue6_independent_read_write_occupancy_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /* Enable pipelined operation on both independent AXI transaction paths. */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

    for (int i = 0; i < 3; i++) begin

      manager_read_seq[i] = queue6_manager_read_seq::type_id::create($sformatf("manager_read_seq%0d", i));
      subordinate_read_seq[i] = queue6_subordinate_read_seq::type_id::create($sformatf("subordinate_read_seq%0d", i));

      manager_write_seq[i] = queue6_manager_write_seq::type_id::create($sformatf("manager_write_seq%0d", i));
      subordinate_write_seq[i] = queue6_subordinate_write_seq::type_id::create($sformatf("subordinate_write_seq%0d", i));

      manager_read_seq[i].fixed_addr = 32'h4000_0400 + (i * 32'h10);

      manager_write_seq[i].fixed_addr = 32'h4000_0500 + (i * 32'h10);
      manager_write_seq[i].fixed_data = 32'hB600_0000 + i;

    end

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

    `uvm_info("QUEUE_06", "Starting concurrent read/write occupancy test", UVM_LOW)

    /*
     * All four streams operate concurrently:
     *
     *   upstream AR requests
     *   downstream R responses
     *   upstream AW/W requests
     *   downstream B responses
     *
     * Delayed R/B responses allow both queues to accumulate outstanding
     * obligations simultaneously.
     */
    fork

      begin
        for (int i = 0; i < 3; i++)
          manager_read_seq[i].start(upstream_read_sqr);
      end

      begin
        for (int i = 0; i < 3; i++)
          subordinate_read_seq[i].start(downstream_read_sqr);
      end

      begin
        for (int i = 0; i < 3; i++)
          manager_write_seq[i].start(upstream_write_sqr);
      end

      begin
        for (int i = 0; i < 3; i++)
          subordinate_write_seq[i].start(downstream_write_sqr);
      end

    join

    /*
     * Sequence completion only guarantees request-side handshakes in pipelined
     * mode. Wait until both queues have retired every outstanding obligation.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_06", "Concurrent read and write obligations completed independently", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue6_independent_read_write_occupancy_test