/* very basic test to verify UVM architecture*/
class basic_read_test extends base_test;
  
  `uvm_component_utils(basic_read_test)
  
  /* env has two agent instantiations*/
  axi4l_read_sequencer upstream_read_sqr;
  axi4l_read_sequencer downstream_read_sqr;

  axi4l_manager_read_seq manager_read_seq;
  axi4l_subordinate_read_seq subordinate_read_seq;
  
  function new(string name = "basic_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    /*A sequence is a temporary scenario object created by the test when needed.*/
    /* hence create here and connect sequencer handle to UVC sequencer instance in connect_phase*/
    //read_seq = axi4l_read_seq::type_id::create("read_seq", this);
    manager_read_seq = axi4l_manager_read_seq::type_id::create("manager_read_seq", this);
    subordinate_read_seq = axi4l_subordinate_read_seq::type_id::create("subordinate_read_seq", this);
    super.build_phase(phase);
  endfunction : build_phase
  
  function void connect_phase(uvm_phase phase);
    /* assign sequencer handle to UVC sequencer instance*/
    /* agent already contains real sequencer; connect via test environment*/
    upstream_read_sqr = env.upstream_agent.read_sequencer;
    downstream_read_sqr = env.downstream_agent.read_sequencer;

  endfunction : connect_phase
  
  /* Generate AXI4L traffic */
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 50ns);
   // read_seq.start(read_sqr); /* run this sequence on this sequencer*/
    fork
      manager_read_seq.start(upstream_read_sqr);
      subordinate_read_seq.start(downstream_read_sqr);
    join
    phase.drop_objection(this);
  endtask : run_phase
  
endclass : basic_read_test

/*

using fork join:
The upstream manager sequence and downstream subordinate sequence must run

at the same time.

The manager sequence sends a read request into the DUT.

The subordinate sequence prepares the downstream driver to accept that

forwarded request and return a read response.

If we started them one after another like this:

  manager_read_seq.start(...);

  subordinate_read_seq.start(...);

the first start() call is blocking.

That means the test waits until the manager sequence completely finishes

before starting the subordinate sequence.

But the manager sequence may not finish until it receives a read response.

That response can only come after the subordinate sequence starts.

So sequential execution can cause a deadlock:

  manager waits for response

  subordinate has not started yet

  test is waiting for manager to finish

fork allows both start() calls to execute concurrently.

join waits until BOTH sequences have completed before the test continues

and drops its objection.
*/


/*

1) inherit common testbench from base_test
2) configure the scenario
3) start one (or more) sequences
4) Keep simulation alive until the scenario finishes (use objections)

*/