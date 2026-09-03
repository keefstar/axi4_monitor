#!/bin/bash
set -e

PROJECT_ROOT="/ubc/ece/home/ugrads/r/rkaisaan/thesis"
cd "$PROJECT_ROOT"

mkdir -p outputs/depth reports/depth chkpts/depth logs/depth

run_one () {
    local depth="$1"

    echo
    echo "Running Genus: DEPTH=${depth}, TIMER_WIDTH=16, TIMEOUT_CYCLES=256, 200 MHz"
    echo

    DEPTH="$depth" \
    CLK_PERIOD_NS="5.0" \
    genus -files ./genus_depth_sweep/synth_depth.tcl \
          -log "./logs/depth/genus_d${depth}_200MHz.log"
}

run_one 1
run_one 2
run_one 4
run_one 8
run_one 16
run_one 64

echo
echo "All DEPTH synthesis runs complete."
echo "Reports are in ./reports/depth/"
