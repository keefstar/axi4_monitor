#!/bin/bash
set -e

PROJECT_ROOT="/ubc/ece/home/ugrads/r/rkaisaan/thesis"
cd "$PROJECT_ROOT"

mkdir -p outputs/timer_width reports/timer_width chkpts/timer_width logs/timer_width

run_one () {
    local width="$1"
    echo
    echo "Running Genus: TIMER_WIDTH=${width}, TIMEOUT_CYCLES=256, 200 MHz"
    echo
    TIMER_WIDTH="$width" \
    CLK_PERIOD_NS="5.0" \
    genus -files ./genus_timer_width_sweep/synth_timer_width.tcl \
          -log "./logs/timer_width/genus_tw${width}_200MHz.log"
}

run_one 9
run_one 12
run_one 16
run_one 24

echo
echo "All timer-width synthesis runs complete."
echo "Reports are in ./reports/timer_width/"
