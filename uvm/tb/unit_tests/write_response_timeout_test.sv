
class write_response_timeout_test extends base_test; /* derive unit test from base test class defined */

  `uvm_component_utils(write_response_timeout_test) /* register with UVM factory*/

    /* declare sequences and sequencers handlers */
    axi4l_write_sequencer upstream_write_sqr;
    axi4l_write_sequencer downstream_write_sqr;

    write_timeout_manager_seq manager_seq;
    write_timeout_subordinate_seq subordinate_seq;

    function new( string name = "write_response_timeout_test", uvm_component parent = null
    );
      super.new(name, parent);
    endfunction : new

    /* build_phase*/
    function void build_phase (uvm_phase phase);
      super.build_phase(phase);
      /* build the sequences*/
      manager_seq = write_timeout_manager_seq::type_id::create("manager_seq");
      subordinate_seq = write_timeout_subordinate_seq::type_id::create("subordinate_seq");
    endfunction : build_phase

    /* connect_phase*/
    function void connect_phase (uvm_phase phase);
      super.connect_phase(phase);
      /* connect sequencer handle to existing ones from agent */
      upstream_write_sqr = env.upstream_agent.write_sequencer;
      downstream_write_sqr = env.downstream_agent.write_sequencer;
    endfunction : connect_phase

    virtual task run_phase (uvm_phase phase);


      int recovery_wait_cycles; /* for software interrupt emulation checking*/

      /* software enables all fault sources and begin with no clear request asserted */
     

      phase.raise_objection(this);

      @ (ctrl_vif.cb);
      ctrl_vif.cb.enable_reg <= '1;
      ctrl_vif.cb.clear_reg <= '0;

      env.sb.set_expect_write_timeout(1'b1);

    fork /* fork and join_any; start two branches simulatanerously*/
        begin
          fork /* concurrent execution*/
          manager_seq.start(upstream_write_sqr);
          subordinate_seq.start(downstream_write_sqr);
        join
    end
      begin 
        repeat (TIMEOUT_COUNTER + 50)
          @ (posedge ctrl_vif.clk);
          `uvm_fatal("TEST_TIMEOUT", $sformatf("Write-response-timeout scenario did not complete"))
      end
    join_any /* leave outer fork when either branch finishes first*/
    disable fork;

    /* Wait until the guard has completed containment and is ready for software-directed recovery*/
    /* UVM emulates the software*/
    do begin
      @ (ctrl_vif.cb);
    end while (ctrl_vif.cb.irq !== 1'b1);
    `uvm_info("SW_EMU", "Software observed guard IRQ signal", UVM_LOW)

    if (ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b1 ) begin
    `uvm_error("SW_STATUS", "WRITE_RESP_TIMEOUT status was not set")
    end else begin
    `uvm_info("SW_STATUS_PASS", "Software observed WRITE_RESP_TIMEOUT status",UVM_LOW)
    end

    /* UVM EMULATION OF SOFTWARE; EXTERNAL SOFTWARE RESET/REINITIALIZATION WOULD HAPPEN HERE*/
    `uvm_info("SW_EMU", "Emulating completion of subordinate recovery", UVM_LOW)

    /* software acknowledges recovery by wiriting 1 to the WRITE_RESP_TIMEOUT clear bit (for one clock cycle)*/
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= 3'b100;
    /* return software clear register to zero */
    @(ctrl_vif.cb);
    ctrl_vif.cb.clear_reg <= 3'b000;

    recovery_wait_cycles = 0;
    do begin
      @(ctrl_vif.cb);
      recovery_wait_cycles++;
      if (recovery_wait_cycles > 10) begin
        `uvm_fatal( "RECOVERY_TIMEOUT", "Status/IRQ did not clear after software acknowledgement")
      end

    end while (
      ctrl_vif.cb.status_reg[WRITE_RESP_TIMEOUT] !== 1'b0 ||
      ctrl_vif.cb.irq !== 1'b0
    );

    `uvm_info( "RECOVERY_PASS", "Fault status cleared and IRQ deasserted after software acknowledgement", UVM_LOW )

      phase.drop_objection(this);

    endtask : run_phase

endclass : write_response_timeout_test

