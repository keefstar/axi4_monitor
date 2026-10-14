# AXI4-Lite Stall-Containment Controller

**SystemVerilog RTL · UVM verification · SVA and functional coverage · IEEE 1801 / UPF · Cadence Genus synthesis**

Undergraduate thesis | University of British Columbia, 2026  
**Author:** Kaisaan (Keefee) Rahman  
**Supervisor:** Dr. Bradley Quinton  
**[Published thesis on UBC cIRcle](https://open.library.ubc.ca/soa/cIRcle/collections/undergraduateresearch/52966/items/1.0456567)**

## Overview

This repository contains the RTL, verification environment, power intent, regression evidence, and synthesis studies for an **AXI4-Lite Stall-Containment Controller (SCC)** developed as an undergraduate thesis project.

The SCC is a parameterizable, always-on hardware intermediary between an AXI4-Lite manager and subordinate. It tracks outstanding transactions, detects supported loss-of-progress conditions, issues upstream `SLVERR` responses, handles stale downstream responses, and coordinates fault reporting and recovery.

**This README is a guide to the implementation and evidence.** The [published thesis](https://open.library.ubc.ca/soa/cIRcle/collections/undergraduateresearch/52966/items/1.0456567) provides the detailed specification, architecture, design rationale, and analysis.

## Results at a glance

| Evaluation | Result |
| --- | ---: |
| Conventional UVM regression | **62 / 62 tests passed** |
| Scored functional coverage | **283 / 283 bins observed** |
| Temporal cover properties | **63 / 64 observed** |
| UPF power-aware simulations | **8 runs** |
| Nominal Genus synthesis target | **200 MHz** |
| Nominal synthesized cell area (GPDK45) | **1,471.6 µm²** |
| Nominal reported power (GPDK45) | **111.8 µW** |

Coverage figures describe the specified and scored verification model, not exhaustive correctness. Temporal cover observations are separate from assertion pass/fail results. Synthesis figures are flow- and library-dependent estimates, not silicon measurements.

## Verification methodology

The verification strategy focused on independently demonstrating correct behavior during **normal operation, fault containment, and recovery**.

- **Requirements-traced testing:** A test plan mapped expected behavior and supported fault scenarios to directed and randomized tests.
- **Deterministic fault injection:** Controlled downstream behavior made timeout, late-response, and recovery scenarios repeatable.
- **End-to-end UVM scoreboard:** Observed interconnect transactions were checked against pending-transaction state and an **independent memory model**, rather than relying on the DUT's internal state.
- **SystemVerilog Assertions:** Temporal properties checked protocol and controller behavior alongside simulation-based checking.
- **Coverage-driven closure:** Functional coverage and temporal cover properties were reviewed against the test plan; exclusions were assessed individually.

**Final conventional regression:** 62/62 tests passed; all 283 scored functional coverage bins were observed; 63/64 temporal cover properties were observed. The thesis documents the coverage definitions, exclusions, and interpretation of the remaining temporal cover item.

Relevant material: [`uvm/`](uvm/), [`sim/`](sim/), [`final_evidence/`](final_evidence/), [`regression_logs_ieee/`](regression_logs_ieee/), and [`regression_coverage_summary.txt`](regression_coverage_summary.txt).

## IEEE 1801 / UPF power-aware verification

Power-aware verification evaluated behavior when the **downstream subordinate domain is switchable** while the SCC remains in an always-on domain.

The IEEE 1801 power intent models the relevant power domains and isolation behavior, including a clamp-to-zero isolation strategy. Eight low-power simulation runs exercised shutdown and recovery scenarios in the modeled environment.

Relevant material: [`upf/`](upf/), [`run_upf_regression_ieee.sh`](run_upf_regression_ieee.sh), and [`regression_logs_upf_ieee/`](regression_logs_upf_ieee/).

## Synthesis and design-space characterization

The RTL was synthesized using **Cadence Genus** with the **GPDK45 45-nm standard-cell library**. The nominal 200 MHz configuration reported **1,471.6 µm²** of cell area and **111.8 µW** of power. Additional studies examined how implementation results changed with design parameters and timing constraints.

| Study | What was varied | Artifacts |
| --- | --- | --- |
| Nominal synthesis | Reference configuration | [`genus_synthesis/`](genus_synthesis/) |
| Frequency sweep | Target clock frequency | [`genus_frequency_sweep/`](genus_frequency_sweep/) |
| Timer-width sweep | Timeout-counter width | [`genus_timer_width_sweep/`](genus_timer_width_sweep/) |
| Depth sweep | Outstanding-transaction tracking depth | [`genus_depth_sweep/`](genus_depth_sweep/) |

Collected reports and generated outputs are under [`reports/`](reports/) and [`outputs/`](outputs/). See the thesis for methodology, constraints, comparisons, and interpretation of results.

## Repository guide

| Path | Contents |
| --- | --- |
| [`rtl2/`](rtl2/) | SCC RTL and shared AXI4-Lite package/interface |
| [`uvm/`](uvm/) | UVM testbench, tests, checking infrastructure, assertions, coverage |
| [`sim/`](sim/) | Simulation support and temporal properties |
| [`upf/`](upf/) | IEEE 1801 power intent and power-aware simulation support |
| [`run.f`](run.f) | Simulation source file list |
| [`run_regression_ieee.sh`](run_regression_ieee.sh) | Conventional regression script |
| [`run_upf_regression_ieee.sh`](run_upf_regression_ieee.sh) | Power-aware regression script |
| [`aggregate_coverage.py`](aggregate_coverage.py) | Coverage aggregation utility |
| [`regression_tests.txt`](regression_tests.txt) | Regression test listing |
| [`regression_coverage_summary.txt`](regression_coverage_summary.txt), [`regression_coverage_hits.txt`](regression_coverage_hits.txt) | Coverage summaries and observations |
| [`observed_covers.txt`](observed_covers.txt) | Temporal cover observations |
| [`final_evidence/`](final_evidence/) | Final verification results and evidence |
| [`regression_logs_ieee/`](regression_logs_ieee/), [`regression_logs_upf_ieee/`](regression_logs_upf_ieee/) | Conventional and power-aware regression logs |
| [`genus_synthesis/`](genus_synthesis/), [`genus_frequency_sweep/`](genus_frequency_sweep/), [`genus_timer_width_sweep/`](genus_timer_width_sweep/), [`genus_depth_sweep/`](genus_depth_sweep/) | Synthesis and characterization flows |
| [`reports/`](reports/), [`outputs/`](outputs/) | Collected and generated synthesis artifacts |
| [`docs/`](docs/) | Protocol reference material |

## Scope and limitations

- **Educational research implementation:** The SCC is not presented as fabricated, silicon-validated, or production-qualified IP.
- **Verification scope:** Results apply to the documented requirements, supported fault model, configurations, and coverage definitions. Regression success does not constitute exhaustive or formal proof.
- **Power-aware scope:** UPF results come from modeled power-domain shutdown and recovery simulations, not physical power measurements.
- **Synthesis scope:** Area, power, and timing results depend on the GPDK45 library, synthesis constraints, and tool flow; they are not post-layout or measured silicon figures.
- **Reproducibility:** Scripts and outputs document the thesis environment. Running the flows may require licensed EDA software, compatible libraries, and local configuration that are not bundled here.

## Publication

Kaisaan (Keefee) Rahman, *Design, Verification, and Evaluation of an AXI4-Lite Stall-Containment Controller: RTL Design, Coverage-Driven UVM Verification, UPF Power-Aware Verification, and Synthesis-Grade Design-Space Characterization*. University of British Columbia, 2026. Supervised by Dr. Bradley Quinton.

**[Read the thesis on UBC cIRcle](https://open.library.ubc.ca/soa/cIRcle/collections/undergraduateresearch/52966/items/1.0456567)** · **[Permanent handle](https://hdl.handle.net/2429/95680)**
