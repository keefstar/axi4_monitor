
/*

A UVM testbench contains many components—tests, environments, agents, drivers, monitors, sequencers, scoreboards—and they cannot all do everything at once. 
UVM therefore divides the simulation into an ordered set of phases.

Create components
        ↓
Connect components
        ↓
Finish configuration
        ↓
Run stimulus and observe the DUT
        ↓
Check results
        ↓
Report pass/fail information

Eg: a driver hsoudl not begin requestings equence items before: 1) the driver has beenc reated, 2) its sequencer has beenc reatde, 3. the driver and sequencer have been connected, 4. the irtual interface hsa been configired

Verification into generla activities:
Testbench creation
Configuration
Connection
Execution
Checking
Reporting


Video example:
DUT is built during elaboration


/*

1) build_phase: creates the testbench component hierarchy.
work includes: creating agents, drivers, monitors, sequencers, scoreboards, retrieiving configuraiton value + virtual interfaces, deciding wheher an agent is active or passive

2) connect_phase: connects components that were already created during build phase
work inckudes: driver sequenceitem port to sequencer export;
mointor analysis to port to an anvironemental-level analysis port
predictor output to scoreboard input

3) end_of_elaboratin_phase:
by now, complete UVM hierarchy has been built; components connected; confirguration should be settled
this phase is often used to 1) inspect final toploogy, 2) verify configuration, 3) print component hierharcy, 4) perform final strcutreal checks

4) start_of_simulation_phase: final zero-time phase before time-consuming simulation actvity begins
used for: startup msgs, printinging configs, setting report verbsoity, final intialization that does not consume time

5) run_phase: where testbench interacts with DUT over simulation time
activities include: waiting fro reset;s tarting sequences; drivingr equests; monitoring interfaces; collecting coverager; checking transactions contivnously; injecting errors; responsding to DUT requests

6) extract_phase: ater run has ended, components may extract final info from collected data
work includes: calcuatingtotals, copying internal counetrs into summary vairbales, computing final coverage/stats; gathering info needed by check_phasse

7) check_phase: determines whetehr verifcation reuslts are correct
work inckldes: confriming scoreboard queues are empty, comforming all expected responses arrived; detecting unmatched transatcions; checking final counters; ensure no protocol operations remain oiutstanding

8) report_phase: summarize the result
work includes: printing pass/fail; report transactionc ounts; reporting error totals

9) final_phase: final uvm phase before simualtion exists
used for: last cleanup/final msgs

How phases execute across the hierarchy:
A) top down phases: parent executes before its children
test.build_phase
↓
env.build_phase
↓
agent.build_phase
↓
driver.build_phase
This makes sense because the parent generally creates its children.
For example:
1. the test creates the environment;
2. the environment creates the agent;
3. the agent creates the driver, sequencer, and monitor.

B) bottom up phases: children execute before their parents


Moral: UVM phases answer the queestion: at what point in the testbench lifecycle should this code execute.

*/