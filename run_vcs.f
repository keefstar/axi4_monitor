// ------------------------------------------------------------
// VCS file list for the AXI4-Lite SCC UVM testbench
//
// Compile from the project root using:
//
// vcs -full64 \
//     -sverilog \
//     -ntb_opts uvm-1.2 \
//     -f run_vcs.f \
//     -debug_access+all \
//     -cm line+cond+fsm+tgl+branch \
//     -cm_dir ./vcs_cov.vdb \
//     -o simv
// ------------------------------------------------------------


// ------------------------------------------------------------
// Include search directories
//
// These directories are searched by `include directives.
// They do not automatically compile every file.
// ------------------------------------------------------------

+incdir+./rtl2
+incdir+./uvm/axi4l_uvc
+incdir+./uvm/axi4l_uvc/sequences
+incdir+./uvm/tb
+incdir+./uvm/tb/test_env
+incdir+./uvm/tb/unit_tests
+incdir+./uvm/tb/unit_tests/upf_tests


// ------------------------------------------------------------
// Source files in compilation dependency order
// ------------------------------------------------------------

// 1. Shared AXI4-Lite protocol definitions and packed types.
./rtl2/a4lite_pkg.sv


// 2. Interfaces used by the DUT and testbench.
./rtl2/axi4l_if.sv
./rtl2/guard_ctrl_if.sv


// 3. DUT leaf modules.
./rtl2/rd_queue.sv
./rtl2/wr_queue.sv
./rtl2/interrupt_ctrl.sv


// 4. DUT top-level module.
./rtl2/tp_lvl.sv


// 5. Reusable AXI4-Lite UVC package.
//
// This package contains/includes the transaction items,
// sequencers, sequences, drivers, monitors, and agents.
// Do not list those class files individually here.
./uvm/axi4l_uvc/axi4l_uvm_pkg.sv


// 6. Power-control interface used by the power-aware testbench.
./uvm/tb/interfaces/power_ctrl_if.sv


// 7. Switchable subordinate model used for power-aware tests.
./uvm/tb/power_modules/axi4l_subordinate_model.sv


// 8. Testbench package.
//
// This contains/includes the scoreboard, coverage collectors,
// environment, and tests.
./uvm/tb/axi4l_test_pkg.sv


// 9. Testbench top.
//
// Compile this last because it imports/instantiates the
// previously compiled DUT and UVM testbench components.
./uvm/tb/tb_top.sv