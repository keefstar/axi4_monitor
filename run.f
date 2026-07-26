    // ------------------------------------------------------------
    // Xcelium file list for the AXI4-Lite SCC UVM testbench
    // Run from the project root with: xrun -f run.f
    // ------------------------------------------------------------

    // Compile all source files as SystemVerilog.
    -sv

    // Enable Cadence's built-in UVM library.
    -uvm

    // ------------------------------------------------------------
    // Include search directories
    // These directories are searched when a package uses `include.
    // They do not compile every file in the directory automatically.
    // ------------------------------------------------------------
    +incdir+./rtl2
    +incdir+./uvm/axi4l_uvc
    +incdir+./uvm/axi4l_uvc/sequences
    +incdir+./uvm/tb
    +incdir+./uvm/tb/test_env
    +incdir+./uvm/tb/unit_tests

    // ------------------------------------------------------------
    // Source files in compilation dependency order
    // ------------------------------------------------------------

    // 1. Shared AXI4-Lite protocol definitions and packed types.
    ./rtl2/a4lite_pkg.sv

    // 2. AXI4-Lite interface used by the DUT and UVM components.
    ./rtl2/axi4l_if.sv

    // 3. DUT leaf modules.
    ./rtl2/rd_queue.sv
    ./rtl2/wr_queue.sv
    ./rtl2/interrupt_ctrl.sv

    // 4. DUT top-level module.
    // Compile after the leaf modules it instantiates.
    ./rtl2/tp_lvl.sv

    // 5. Reusable AXI4-Lite UVC package.
    // This package includes the items, sequencers, sequences,
    // drivers, monitor, and agent.
    // Do not list those individual class files again here.
    ./uvm/axi4l_uvc/axi4l_uvm_pkg.sv

    // 6. Testbench package.
    // This package includes the scoreboard, coverage collector,
    // and environment.
    ./uvm/tb/axi4l_test_pkg.sv

    // 7. Testbench top module.
    // Compile this last.
    ./uvm/tb/tb_top.sv