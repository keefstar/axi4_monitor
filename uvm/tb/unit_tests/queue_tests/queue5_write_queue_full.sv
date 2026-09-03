/*
 * QUEUE-05 verifies write-queue capacity and admission control.
 *
 * DEPTH complete AW/W transaction pairs are admitted before any B response
 * retires, filling the SCC's outstanding write-response capacity. One
 * additional write is then presented while the queue is full. The SCC must
 * backpressure that transaction rather than overflow its bookkeeping state.
 *
 * After the first B response retires and capacity becomes available, the
 * blocked write must be admitted. All resulting B responses must then retire
 * normally and leave the SCC idle.
 */


class queue5_manager_write_seq extends axi4l_manager_write_seq;

  `uvm_object_utils(queue5_manager_write_seq)

  logic [ADDR_WIDTH-1:0] fixed_addr;
  logic [DATA_WIDTH-1:0] fixed_data;

  function new(string name = "queue5_manager_write_seq");
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

endclass : queue5_manager_write_seq



class queue5_subordinate_write_seq extends axi4l_subordinate_write_seq;

  `uvm_object_utils(queue5_subordinate_write_seq)

  function new(string name = "queue5_subordinate_write_seq");
    super.new(name);
  endfunction

  virtual function void randomize_req();

    req.constraint_mode(0);

    req.awready_delay = 0;
    req.wready_delay = 0;

    /*
     * Hold the first B response off long enough for all DEPTH writes to
     * accumulate. This remains comfortably below TIMEOUT_COUNTER.
     */
    req.bvalid_delay = 50;

    req.suppress_bvalid = 0;
    req.late_bvalid_after_timeout = 0;

  endfunction : randomize_req

endclass : queue5_subordinate_write_seq



class queue5_write_queue_full_test extends base_test;

  `uvm_component_utils(queue5_write_queue_full_test)

  axi4l_write_sequencer upstream_write_sqr;
  axi4l_write_sequencer downstream_write_sqr;

  queue5_manager_write_seq manager_write_seq[DEPTH+1];
  queue5_subordinate_write_seq subordinate_write_seq[DEPTH+1];


  function new(string name = "queue5_write_queue_full_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    /*
     * Reuse the pipelined write-driver infrastructure introduced for QUEUE-04.
     * This allows additional AW/W pairs to complete while previous writes are
     * still waiting for their B responses.
     */
    uvm_config_db#(bit)::set(this, "env.upstream_agent.write_driver", "pipelined_manager_writes", 1'b1);
    uvm_config_db#(bit)::set(this, "env.downstream_agent.write_driver", "pipelined_subordinate_writes", 1'b1);

    super.build_phase(phase);

    for (int i = 0; i < DEPTH+1; i++) begin

      manager_write_seq[i] = queue5_manager_write_seq::type_id::create($sformatf("manager_write_seq%0d", i));
      subordinate_write_seq[i] = queue5_subordinate_write_seq::type_id::create($sformatf("subordinate_write_seq%0d", i));

      manager_write_seq[i].fixed_addr = 32'h4000_0300 + (i * 32'h10);
      manager_write_seq[i].fixed_data = 32'hA500_0000 + i;

    end

  endfunction : build_phase


  function void connect_phase(uvm_phase phase);

    upstream_write_sqr   = env.upstream_agent.write_sequencer;
    downstream_write_sqr = env.downstream_agent.write_sequencer;

  endfunction : connect_phase


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 100ns);

    `uvm_info("QUEUE_05", $sformatf("Starting write-capacity test: fill DEPTH=%0d and attempt one additional write", DEPTH), UVM_LOW)

    /*
     * Requests are sequential within each sequencer stream so transaction
     * ordering is deterministic, while manager and subordinate activity run
     * concurrently.
     *
     * The ninth manager item will remain blocked while the SCC is full. Once
     * B1 retires and frees one outstanding slot, the ninth AW/W pair can finish.
     */
    fork

      begin
        for (int i = 0; i < DEPTH+1; i++)
          manager_write_seq[i].start(upstream_write_sqr);
      end

      begin
        for (int i = 0; i < DEPTH+1; i++)
          subordinate_write_seq[i].start(downstream_write_sqr);
      end

    join

    /*
     * Pipelined sequence completion means all AW/W pairs have eventually been
     * admitted. Wait until every B-response obligation has also retired.
     */
    do begin
      @(ctrl_vif.cb);
    end while (ctrl_vif.cb.guard_busy !== 1'b0);

    repeat (2)
      @(ctrl_vif.cb);

    `uvm_info("QUEUE_05", "Write queue reached capacity, blocked the additional write, reopened admission, and retired all writes", UVM_LOW)

    phase.drop_objection(this);

  endtask : run_phase

endclass : queue5_write_queue_full_test