/*
 * CC-08: exercise sustained queue turnover at partial occupancies.
 *
 * For each occupancy from 2 through 7, the test first creates multiple
 * outstanding transactions, then admits another request at approximately the
 * same cycle that the oldest transaction retires.
 *
 * The objective is to exercise simultaneous enqueue/retire operation while the
 * queue is already partially occupied, for both read and write queues.
 */


class cc8_manager_read_seq extends axi4l_manager_read_seq;

  `uvm_object_utils(cc8_manager_read_seq)

  int unsigned fixed_ar_delay;

  function new(string name = "cc8_manager_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = 32'h4000_1000;
    req.prot = 3'b000;
    req.ar_delay = fixed_ar_delay;
    req.rready_delay = 0;

  endfunction : randomize_req

endclass : cc8_manager_read_seq


class cc8_subordinate_read_seq extends axi4l_subordinate_read_seq;

  `uvm_object_utils(cc8_subordinate_read_seq)

  int unsigned fixed_rvalid_delay;

  function new(string name = "cc8_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.arready_delay = 0;
    req.rvalid_delay = fixed_rvalid_delay;
    req.suppress_rvalid = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : cc8_subordinate_read_seq


class cc8_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(cc8_manager_write_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;
  int unsigned fixed_delay;

  function new(string name = "cc8_manager_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.addr = fixed_addr;
    req.prot = 3'b000;
    req.data = fixed_data;
    req.strb = 4'b1111;
    req.aw_delay = fixed_delay;
    req.w_delay  = fixed_delay;
    req.bready_delay  = 0;
    req.suppress_wvalid = 0;
    req.late_wvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : cc8_manager_write_seq


class cc8_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(cc8_subordinate_write_seq)

  int unsigned fixed_bvalid_delay;

  function new(string name = "cc8_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;
    req.bvalid_delay = fixed_bvalid_delay;
    req.suppress_bvalid = 0;
    req.late_bvalid_after_timeout = 0;
    req.resp = RESP_OKAY;

  endfunction : randomize_req

endclass : cc8_subordinate_write_seq


class queue_turnover_test_cc8 extends base_test;

  `uvm_component_utils(queue_turnover_test_cc8)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;


  function new(string name = "queue_turnover_test_cc8", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Pipelined operation is required so new requests may be admitted while
     * earlier transactions remain outstanding.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.read_driver", "pipelined_manager_reads", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.read_driver", "pipelined_subordinate_reads", 1'b1);

    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_read_sqr    = env.upstream_agent.read_sequencer;
    downstream_read_sqr  = env.downstream_agent.read_sequencer;

    upstream_write_sqr   = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_read_turnover(int unsigned occupancy);

    cc8_manager_read_seq manager_seq[0:7];
    cc8_subordinate_read_seq subordinate_seq[0:7];

    int unsigned turnover_delay;

    /*
     * CC-04 established the approximate read timing relationship. Compensate
     * for the additional immediately admitted requests when targeting a larger
     * starting occupancy.
     */
    turnover_delay = 20 - (occupancy - 1);

    for (int i = 0; i <= occupancy; i++) begin

      manager_seq[i] = cc8_manager_read_seq::type_id::create(
        $sformatf("manager_read_occ%0d_seq%0d", occupancy, i)
      );

      subordinate_seq[i] = cc8_subordinate_read_seq::type_id::create(
        $sformatf("subordinate_read_occ%0d_seq%0d", occupancy, i)
      );

      manager_seq[i].fixed_ar_delay = 0;
      subordinate_seq[i].fixed_rvalid_delay = 20;

    end

    /*
     * Delay only the turnover request. The preceding requests are admitted
     * immediately and establish the required queue occupancy.
     */
    manager_seq[occupancy].fixed_ar_delay = turnover_delay;

    `uvm_info( "CC_08_READ", $sformatf( "Targeting read occupancy %0d with simultaneous enqueue/retire", occupancy ), UVM_LOW )

    fork

      begin
        for (int i = 0; i <= occupancy; i++)
          manager_seq[i].start(upstream_read_sqr);
      end

      begin
        for (int i = 0; i <= occupancy; i++)
          subordinate_seq[i].start(downstream_read_sqr);
      end

    join

    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (3) @(ctrl_vif.cb);

  endtask : run_read_turnover


  task run_write_turnover(int unsigned occupancy);

    cc8_manager_write_seq manager_seq[0:7];
    cc8_subordinate_write_seq subordinate_seq[0:7];

    int unsigned turnover_delay;

    /*
     * CC-04 showed that an 18-cycle write-request delay aligned a new AW/W
     * admission with retirement of the preceding B response. Compensate for
     * the additional immediately admitted transactions.
     */
    turnover_delay = 18 - (occupancy - 1);

    for (int i = 0; i <= occupancy; i++) begin

      manager_seq[i] = cc8_manager_write_seq::type_id::create(
        $sformatf("manager_write_occ%0d_seq%0d", occupancy, i)
      );

      subordinate_seq[i] = cc8_subordinate_write_seq::type_id::create(
        $sformatf("subordinate_write_occ%0d_seq%0d", occupancy, i)
      );

      manager_seq[i].fixed_addr = 32'h4000_2000 + (occupancy * 32'h100) + (i * 32'h10);
      manager_seq[i].fixed_data = 32'h8000_0000 + (occupancy * 32'h100) + i;
      manager_seq[i].fixed_delay = 0;
      subordinate_seq[i].fixed_bvalid_delay = 20;

    end

    manager_seq[occupancy].fixed_delay = turnover_delay;

    `uvm_info( "CC_08_WRITE", $sformatf( "Targeting write occupancy %0d with simultaneous enqueue/retire", occupancy ), UVM_LOW )

    fork

      begin
        for (int i = 0; i <= occupancy; i++)
          manager_seq[i].start(upstream_write_sqr);
      end

      begin
        for (int i = 0; i <= occupancy; i++)
          subordinate_seq[i].start(downstream_write_sqr);
      end

    join

    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (3) @(ctrl_vif.cb);

  endtask : run_write_turnover


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info( "CC_08", "Starting partial-occupancy queue-turnover coverage-closure test", UVM_LOW )

    /*
     * Each subtest returns the SCC to an empty state before the next occupancy
     * target begins, preventing one target from contaminating the next.
     */
    for (int occupancy = 2; occupancy <= 7; occupancy++)
      run_read_turnover(occupancy);

    for (int occupancy = 2; occupancy <= 7; occupancy++)
      run_write_turnover(occupancy);

    `uvm_info( "CC_08", "Partial-occupancy queue-turnover coverage-closure stimulus completed", UVM_LOW )

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue_turnover_test_cc8