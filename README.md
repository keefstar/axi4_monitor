# AXI4-Lite Stall-Containment Controller

This repository contains the RTL design, UVM verification environment, IEEE 1801 power-aware verification setup, regression artifacts, and Cadence Genus synthesis results associated with my CPEN 499 undergraduate thesis:

**Design, Verification, and Evaluation of an AXI4-Lite Stall-Containment Controller**

The project implements an always-on AXI4-Lite intermediary that detects loss of forward progress, contains supported timeout conditions, reports faults, and supports controlled recovery.

## Repository Structure

- `rtl2/` — SCC RTL and shared AXI4-Lite package/interface
- `uvm/` — UVM verification environment, tests, scoreboard, assertions, and coverage collectors
- `upf/` — IEEE 1801 power intent and power-aware verification support
- `sim/` — simulation support files
- `regression_logs_ieee/` — conventional regression logs
- `regression_logs_upf_ieee/` — power-aware regression logs
- `final_evidence/` — final verification evidence and summaries
- `genus_synthesis/` — nominal synthesis flow and reports
- `genus_frequency_sweep/` — target-frequency sweep
- `genus_timer_width_sweep/` — timeout-counter-width sweep
- `genus_depth_sweep/` — outstanding-transaction-depth sweep
- `reports/` — collected reports from synthesis
- `outputs/` — generated outputs from synthesis  
- `docs/` — contains AXI4-Lite specification documentation

## Final Verification Results

- **62 / 62 tests passed**
- **283 / 283 scored functional-coverage bins observed**
- **63 / 64 temporal cover properties observed**

## Synthesis
