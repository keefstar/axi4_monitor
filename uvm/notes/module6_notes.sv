


components are things that actually make up the testbench
axi4l_driver
axi4l_monitor
axi4l_sequencer
axi4l_agent
axi4l_scoreboard
axi4l_env
axi4l_test
^^^^all inheirt from some form of uvm_comopnent
so mentally seperate them like this
objects = info components = machines that do things with that info Driver: "Okay, I received that transaction. I'll wiggle AWVALID/AWADDR/WVALID/WDATA accordingly." axi4l_write_item OBJECT ↓ sequencer COMPONENT ↓ driver COMPONENT ↓ AXI signals ↓ DUT ↓ monitor COMPONENT ↓ scoreboard COMPONENT rn at th estart of that chain: COMPONENT TEMPLATE: the boilerplate that nearly every compennt we write will have class axi4l_manager_driver extends uvm_driver#(axi4l_write_item);
`uvm_component_utils(axi4l_manager_driver)
function new(string name, uvm_component parent);
  super.new(name, parent);
endfunction
endclass

KEY DIFFERENCE WHEN COMAPRED WITH OUR TRANSACTION IS THE CONSTRUCTOR:
transaction has:
function new(string name = "axi4l_write_item");
  super.new(name);
endfunction

because an object doensnt lvie in the UVM component hierarchy

A comopnent uses:
function new(string name, uvm_component parent);
  super.new(name, parent);
endfunction

the PARENT is what creates the hierarchy.


What is a TB IN UVM: the UVM env omtaining ALL THE VERIFIATION MACHINERY FOR default
UVM TESTBENCH / ENVIRONMENT

upstream AXI agent
|
v
[AXI4 - Lite Guard]
|
v
downstream AXI agent


monitors-------------------- +
|
v
scoreboard
|
v
coverage

TESTBENCH NEEDS TO EMULATE BOTH THINGS SURROUNDING OUT GUARD.UVM WORLD WOULD NEED TO ACT LIKE THE EXTERNAL DEVICES OF UPSTREAM MANAGER AND DOWNSTREAM SUBORDINATE

thesis: we are not veryfing like CPU -> reg block, we are veryfiyning something in the middle.
our env needs control of both sides.need to be able o say:
upstread: send a read to addr 0 x1000 and odwnstream needs to say'respond normally'

TESTBENCH SHELLS:


class axi4l_guard_env extends uvm_env;
  
  `uvm_component_utils(axi4l_guard_env)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // create agents, scoreboard, etc.
    
  endfunction
endclass

eventally my env may contain:
class axi4l_guard_env extends uvm_env;
  
  `uvm_component_utils(axi4l_guard_env)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // create agents, scoreboard, etc.
    
  endfunction
endclass

axi4l_guard_env
│
├ ─ ─ upstream_agent
│
├ ─ ─ downstream_agent
│
└ ─ ─ scoreboard

TEST REQUIREMENTS:
distincigon between env and test
ENV DESCRIBES: what verification machinery exists ?
TEST DESCRIVES: what are we doing in this partiuclar start_of_simulation_phase
ENV: LABORATRY
TEST: EXPERIMENT

SIMPLE TEST EXAMPLE:
creat ea base test
class axi4l_base_test extends uvm_test;
  
  `uvm_component_utils(axi4l_base_test)
  
  axi4l_guard_env env;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    env = axi4l_guard_env::type_id::create("env", this);
    
  endfunction
endclass

supposed archietcture:
uvm_test_top
│
└ ─ ─ axi4l_base_test / specific test
│
└ ─ ─ axi4l_guard_env
│
├ ─ ─ upstream_agent
│ │
│ ├ ─ ─ read sequencer
│ ├ ─ ─ write sequencer
│ ├ ─ ─ driver
│ └ ─ ─ monitor
│
├ ─ ─ downstream_agent
│ │
│ ├ ─ ─ response sequencer / responder
│ ├ ─ ─ driver
│ └ ─ ─ monitor
│
└ ─ ─ scoreboard