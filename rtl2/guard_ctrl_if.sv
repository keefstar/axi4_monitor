interface guard_ctrl_if (input logic clk);

  import a4lite_pkg::*;

  /* software controlled registers */
  logic [NUM_FAULT_SOURCES-1:0] enable_reg;
  logic [NUM_FAULT_SOURCES-1:0] clear_reg;

  /* hardware-generated status registers*/
  logic [NUM_FAULT_SOURCES-1:0] status_reg;
  logic irq;
  logic guard_busy;

  clocking cb @ (posedge clk);
    output enable_reg;
    output clear_reg;

    input status_reg;
    input irq;
    input guard_busy;
  endclocking : cb

endinterface : guard_ctrl_if