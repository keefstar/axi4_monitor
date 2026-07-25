test
└ ─ ─ env
├ ─ ─ upstream_axi4l_agent
│ ├ ─ ─ sequencer
│ ├ ─ ─ driver
│ └ ─ ─ monitor
│
├ ─ ─ downstream_axi4l_agent
│ ├ ─ ─ driver
│ └ ─ ─ monitor
│
└ ─ ─ scoreboard

That is essentially a multiple - UVC / multiple - agent environment.
The biggest thing to learn from this module is therefore how multiple agents / UVCs are instantiated, configured, and connected inside one environment.
You do not necessarily need two completely different UVC implementations.

I have one reusable axi4l_agent
I can instnatiate it twice:
axi4l_agent upstream_agent;
axi4l_agent downstream_agent;
and configure it differnetly.

The upstream agent behaves like the external AXI manager talking to your guard.
The downstream agent represents the subordinate side and can deliberately do things.
I can create multiple test slike:
axi4l_base_test
|
+--normal_read_test
|
+--read_timeout_test
|
+--normal_write_test
|
+--write_data_timeout_test
|
+--write_resp_timeout_test
|
+--flush_recovery_test
Each test does not rebuild the whole testbench.
What changes between tests is mainly:

*which sequences you run
*how you configure the agents
*what kind of stall / fault behavior you create
*maybe timeout / delay settings
A single reusable UVM environment defines the fixed testbench topology, while multiple tests reuse that environment with different configuration and sequences to exercise different verification scenarios.
You build / instantiate one reusable testbench environment, and then many different tests reuse that same environment.

There are exceptions to the above ^
Sometimes the DUT is complex enough that you genuinely need different testbench topologies.
If tests require fundamentally different verification topologies, multiple reusable testbench classes may be created, often using inheritance.Otherwise, multiple tests should generally reuse one common testbench environment.

REUSABLE UVC CONCEPT

A UVC should be configurable and reusable.

Agents can be:
-ACTIVE: driver / sequencer generate stimulus + monitor observes
-PASSIVE: monitor only

The same UVC can therefore be reused in different testbench contexts.

For my AXI4 - Lite thesis:
-upstream and downstream AXI agents reuse common AXI concepts / components
-agents can be configured according to their required role
-topology is fixed: one upstream and one downstream side

I do NOT need:
-dynamically configurable numbers of AXI agents
-a dedicated Clock / Reset UVC
-acceleration - specific Clock / Reset architecture

When you integrate a UVC into a testbench, there are four separate jobs: compile it, instantiate / connect the interface, configure it, then create the UVC instance.
1) Compilation: need to compile all of:
axi4l_uvc /
├ ─ ─ axi4l_pkg.sv
├ ─ ─ axi4l_if.sv
├ ─ ─ axi4l_agent.sv
├ ─ ─ axi4l_driver.sv
├ ─ ─ axi4l_monitor.sv
├ ─ ─ axi4l_sequencer.sv
...
Then your Xcelium file list needs to compile things in the correct order.
This absolutely matters because SystemVerilog compilation order can bite you.

uvm /
├ ─ ─ axi4l_uvc /
│ ├ ─ ─ axi4l_agent.sv
│ ├ ─ ─ axi4l_driver.sv
│ └ ─ ─...
├ ─ ─ sequences /
└ ─ ─ tests /

So in your Xcelium run.f, you might write:
+incdir +./ uvm / axi4l_uvc
+incdir +./ uvm / sequences
+incdir +./ uvm / tests
“ When my code says include "axi4l_agent.sv", go search these folders to find it.”
So for you, +incdir is basically just giving Xcelium the addresses of the folders where your UVM.sv files live.
You ’ ll use this when we set up your actual Xcelium run.f.

2) Import and interface:
a) import UVC package;
import axi4l_uvm_pkg::*;
b) instantiate real interfaces:
axi4l_if upstream_if(.clk(clk), .areset(aresetn));
axi4l_if downstream_if(.clk(clk), .areset(aresetn));
c) Put the interface into config_db:
uvm_config_db#(virtual axi4l_if)::set(
  null,
  "uvm_test_top.env.agent*",
  "vif",
  upstream_if
);

3) configurations and instantiations
Configuration happens before the component is created.
uvm_config_int::set(...);
Configure before creation:
Configuration must be placed in the config_db before the UVM components that need it are built.In my project, tb_top sets the upstream / downstream virtual interfaces before calling run_test().Other agent configuration, such as active / passive role, can later be set by the test / environment before the agents are created.

4) config objects:
A config object is just a normal UVM object whose job is to hold settings.
Think of it like a little settings box.

class axi4l_agent_cgf extends uvm_object:
  
  uvm_active_passive_enum is_active;
  int unsigned max_delay;
  bit allow_stalls;
  
endclass

So instead of passing three separate settings around:
axi4l_agent_cfg cfg;
cfg = axi4l_agent_cfg::type_id::create("cfg");
cfg.is_active = UVM_ACTIVE;
cfg.max_delay = 5;
cfg.allow_stalls = 1;