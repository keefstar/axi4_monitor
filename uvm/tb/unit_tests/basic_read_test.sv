/* very basic test to verify UVM architecture*/
class basic_read_test extends base_test;
  
  `uvm_component_utils(basic_read_test)
  
  axi4l_read_sequencer read_sqr;
  axi4l_read_sequence read_seq;
  
  function void build_phase(uvm_phase phase);
    /*A sequence is a temporary scenario object created by the test when needed.*/
    /* hence create here and connect sequencer handle to UVC sequencer instance in connect_phase*/
    read_seq = axi4l_read_seq::type_id::create("read_seq", this);
    super.build_phase(phase);
  endfunction : build_phase
  
  function void connect_phase(uvm_phase phase);
    /* assign sequencer handle to UVC sequencer instance*/
    /* agent already contains real sequencer; connect via test environment*/
    read_sqr = env.upstream_agent.read_sequencer;
  endfunction : connect_phase
  
  /* Generate AXI4L traffic */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    read_seq.start(read_sqr); /* run this sequence on this sequencer*/
    phase.drop_objection(this);
  endtask : run_phase
  
endclass : basic_read_test



/*

1) inherit common testbench from base_test
2) configure the scenario
3) start one (or more) sequences
4) Keep simulation alive until the scenario finishes (use objections)

*/