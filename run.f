// ------------------------------------------------------------
// Xcelium file list for the AXI4-Lite SCC UVM testbench
// Run from the project root with: xrun -f run.f
// ------------------------------------------------------------

// Compile all source files as SystemVerilog.
-sv

// Enable Cadence's built-in UVM library.
-uvm

// Enable RTL code coverage and SystemVerilog functional coverage.
-coverage all

// Store Cadence coverage databases here.
-covworkdir ./cov_work

// Replace the existing coverage result when rerunning the same test.
-covoverwrite

// Permit SimVision to inspect signals and objects.
-access +rwc


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
+incdir+./uvm/tb/coverage

// Add directories for specific test groups.
+incdir+./uvm/tb/unit_tests/norm_tests
+incdir+./uvm/tb/unit_tests/rto_tests
+incdir+./uvm/tb/unit_tests/wdt_tests
+incdir+./uvm/tb/unit_tests/wrt_tests
+incdir+./uvm/tb/unit_tests/flt_tests
+incdir+./uvm/tb/unit_tests/queue_tests
+incdir+./uvm/tb/unit_tests/rec_tests
+incdir+./uvm/tb/unit_tests/prot_tests
+incdir+./uvm/tb/unit_tests/coverage_tests
+incdir+./uvm/tb/unit_tests/upf_tests


// ------------------------------------------------------------
// Source files in compilation dependency order
// ------------------------------------------------------------

// 1. Shared AXI4-Lite protocol definitions and packed types.
./rtl2/a4lite_pkg.sv

// 2. Interfaces used by the DUT and UVM components.
./rtl2/axi4l_if.sv
./rtl2/guard_ctrl_if.sv

// 3. DUT leaf modules.
./rtl2/rd_queue.sv
./rtl2/wr_queue.sv
./rtl2/interrupt_ctrl.sv

// 4. DUT top-level module.
// Compile after the leaf modules it instantiates.
./rtl2/tp_lvl.sv


// ------------------------------------------------------------
// Assertions
// These bind into the already-compiled DUT modules.
// ------------------------------------------------------------

./sim/rd_queue_sva.sv
./sim/wr_queue_sva.sv
./sim/interrupt_ctrl_sva.sv
./sim/tp_lvl_queue_sva.sv
./sim/tp_lvl_recovery_sva.sv


// ------------------------------------------------------------
// Bind-based functional coverage
// These sample internal RTL fault, recovery, and queue state.
// Read/write protocol coverage is included through axi4l_test_pkg.sv.
// ------------------------------------------------------------

./uvm/tb/coverage/axi4l_fault_coverage.sv
./uvm/tb/coverage/axi4l_recovery_coverage.sv
./uvm/tb/coverage/axi4l_queue_coverage.sv


// 5. Reusable AXI4-Lite UVC package.
// This package includes the items, sequencers, sequences,
// drivers, monitor, and agents.
./uvm/axi4l_uvc/axi4l_uvm_pkg.sv

// Power-control interface.
./uvm/tb/interfaces/power_ctrl_if.sv

// Subordinate model used for UPF verification.
./uvm/tb/power_modules/axi4l_subordinate_model.sv
./uvm/tb/power_modules/axi4l_subordinate_wrapper.sv

// 6. Testbench package.
// This package includes the scoreboard, UVM coverage classes,
// environment, and tests.
./uvm/tb/axi4l_test_pkg.sv

// 7. Testbench top module.
// Compile this last.
./uvm/tb/tb_top.sv