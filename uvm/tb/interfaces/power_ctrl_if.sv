interface power_ctrl_if (input logic clk);

  /*
   * Power-control signals start directly in the RUN state.
   * Declaration initialization gives deterministic time-zero values without
   * requiring clock synchronization. Clocking-block drives are reserved for
   * runtime power transitions.
   */

  /* Controls UPF power switch supplying PD_SUB */
  logic sub_power_en = 1'b1;

  /* Controls UPF isolation on PD_SUB -> PD_AON crossings */
  logic sub_iso_en   = 1'b0;

  /* Used to reinitialize PD_SUB after power restoration */
  logic sub_reset_n  = 1'b1;

  localparam int POWER_SETTLE_CYCLES = 2;
  localparam int RESET_HOLD_CYCLES = 2;
  localparam int WAKEUP_CYCLES = 2;

  /* clocking block */

  /* syncrhnoize to posedge clk*/
  clocking cb @ (posedge clk);
    /* sample signal 1 sim time step before posedge clk*/
    /* for output, drive signal at posedge clk*/
    default input #1step output #0;
    output sub_power_en;
    output sub_iso_en; 
    output sub_reset_n;
  endclocking 


  /*
  task automatic init_power();
    @(cb);
    cb.sub_power_en <= 1'b1;
    cb.sub_reset_n <= 1'b1;
    cb.sub_iso_en <= 1'b0;
  endtask : init_power
   */

  /* MANAGED SHUTDOWN */
  /* RUN -> SUB_SLEEP*/
  /* correct low power sequencing:
  1) Assert isolation
  2) Remove PD_SUB power
  */
  task automatic sub_power_down();
    @(cb);
    cb.sub_iso_en <= 1'b1;
    @(cb);
    cb.sub_power_en <= 1'b0;

  endtask : sub_power_down

  /* Use for PR-06 fault-injection path*/
  task automatic sub_power_fail();
    /* sudden/uncontrolled loss of PD_SUB supply*/
    /* sub_iso_en is intentionally NOT changed here */
    @(cb);
    cb.sub_power_en <= 1'b0;
  endtask : sub_power_fail

  /* Assert isolation after unexpexted failure*/
  /* useful for PR-06 if want to observe a period of unisolated corruption first, and then establish a safe clamp*/
  task automatic isolate_sub();
    @(cb);
    cb.sub_iso_en <= 1'b1;
  endtask : isolate_sub

   task automatic power_sub_on();
    /* Protect PD_AON throughout restoration */
    @(cb);
    cb.sub_iso_en <= 1'b1;
    /*Restore subordinate supply*/
    @(cb);
    cb.sub_power_en <= 1'b1;
    repeat (POWER_SETTLE_CYCLES) @(cb);
    /*Reinitialize subordinate state.*/
    cb.sub_reset_n <= 1'b0;
    repeat (RESET_HOLD_CYCLES) @ (cb);
    cb.sub_reset_n <= 1'b1;
    /* Allow subordinate logic to return to operational state. */
     repeat (WAKEUP_CYCLES) @(cb);
    /*  Safe to reconnect PD_SUB outputs to PD_AON. */
    cb.sub_iso_en <= 1'b0;

  endtask : power_sub_on


endinterface : power_ctrl_if