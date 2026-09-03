#!/bin/bash
set -e

PROJECT_ROOT="/ubc/ece/home/ugrads/r/rkaisaan/thesis"
cd "$PROJECT_ROOT"

mkdir -p outputs reports chkpts logs

run_one () {
    local freq="$1"
    local period="$2"
    local run_name="${freq}MHz"

    echo
    echo "Running Genus synthesis at ${freq} MHz (${period} ns)"
    echo

    RUN_NAME="$run_name" \
    CLK_PERIOD_NS="$period" \
    genus -files ./genus_frequency_sweep/synth_sweep.tcl \
          -log "./logs/genus_tp_lvl_${run_name}.log"
}

run_one 100 10.0
run_one 200 5.0
run_one 300 3.333
run_one 400 2.5

echo
echo "All synthesis runs complete."
echo "Reports are in ./reports/"
