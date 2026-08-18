/*
 * End-to-end read timeout test.
 *
 * The subordinate accepts the read address but intentionally never
 * returns RVALID. The DUT must timeout and inject SLVERR upstream.
 */


/*==============================================================
 * MANAGER READ SEQUENCE
 *==============================================================*/

class timeout_manager_read_seq
  extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(timeout_manager_read_seq)

  function new(string name = "timeout_manager_read_seq");
    super.new(name);
  endfunction

  virtual task body();

    req = axi4l_read_item::type_id::create("req");

    start_item(req);

    req.configure_for_manager();

    assert(
      req.randomize() with {
        addr         == 32'h0000_0020;
        prot         == 3'b000;
        ar_delay     == 0;
        rready_delay == 0;
      }
    )
    else begin
      `uvm_fatal(
        get_type_name(),
        "Manager timeout-read item randomization failed"
      )
    end

    `uvm_info(
      get_type_name(),
      $sformatf(
        "Issuing read expected to timeout: addr=0x%0h",
        req.addr
      ),
      UVM_LOW
    )

    /*
     * The manager driver waits for the DUT's injected R response.
     * It should eventually receive RRESP=SLVERR.
     */
    finish_item(req);

    if (req.resp !== RESP_SLVERR) begin
      `uvm_error(
        "MANAGER_TIMEOUT_RESP",
        $sformatf(
          "Manager expected SLVERR but received resp=0x%0h",
          req.resp
        )
      )
    end

  endtask : body

endclass : timeout_manager_read_seq


/*==============================================================
 * FAULTING SUBORDINATE READ SEQUENCE
 *==============================================================*/

class timeout_subordinate_read_seq
  extends uvm_sequence#(axi4l_read_item);

  `uvm_object_utils(timeout_subordinate_read_seq)

  function new(string name = "timeout_subordinate_read_seq");
    super.new(name);
  endfunction

  virtual task body();

    req = axi4l_read_item::type_id::create("req");

    start_item(req);

    req.configure_for_subordinate();

    assert(
      req.randomize() with {
        arready_delay  == 0;
        suppress_rvalid == 1'b1;
      }
    )
    else begin
      `uvm_fatal(
        get_type_name(),
        "Subordinate timeout-read item randomization failed"
      )
    end

    finish_item(req);

  endtask : body

endclass : timeout_subordinate_read_seq


/*==============================================================
 * READ TIMEOUT TEST
 *==============================================================*/

class read_timeout_test extends base_test;

  `uvm_component_utils(read_timeout_test)

  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  timeout_manager_read_seq manager_read_seq;
  timeout_subordinate_read_seq subordinate_read_seq;

  function new(
    string name = "read_timeout_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  virtual function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    manager_read_seq =
      timeout_manager_read_seq::type_id::create(
        "manager_read_seq"
      );

    subordinate_read_seq =
      timeout_subordinate_read_seq::type_id::create(
        "subordinate_read_seq"
      );

  endfunction : build_phase


  virtual function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    upstream_read_sqr =
      env.upstream_agent.read_sequencer;

    downstream_read_sqr =
      env.downstream_agent.read_sequencer;

  endfunction : connect_phase


  virtual task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    /*
     * Tell the scoreboard that this read should receive an injected
     * upstream SLVERR without a downstream R response.
     */
    env.sb.set_expect_read_timeout(1'b1);

    fork
      manager_read_seq.start(
        upstream_read_sqr
      );

      subordinate_read_seq.start(
        downstream_read_sqr
      );
    join

    /*
     * Verify the architectural fault indications.
     *
     * These are top-level HDL signals, so the cleanest long-term
     * approach is a DUT-status interface. For a first test, access
     * them through tb_top only if your package permits it.
     */

    phase.drop_objection(this);

  endtask : run_phase

endclass : read_timeout_test