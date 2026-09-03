#!/bin/bash

UVMHOME="CDNS-IEEE-20"
UPF_FILE="./upf/guard_power_4.0.upf"
LOGDIR="./regression_logs_upf_ieee"

mkdir -p "$LOGDIR"

TESTS=(

  # Basic power-control / infrastructure
  power_ctrl_smoke_test
  upf_base_test

  # Normal powered operation
  upf_normal_test

  # Power-state transitions
  upf_power_down_test
  upf_power_restore_test

  # Power loss during outstanding AXI4-Lite traffic
  upf_read_power_loss_test
  upf_write_power_loss_test

  # Loss of power without prior isolation
  upf_unexpected_power_loss_test
)

echo "========================================"
echo " IEEE 1800.2 + UPF 4.0 Regression"
echo " UVM home : $UVMHOME"
echo " UPF file : $UPF_FILE"
echo " Tests    : ${#TESTS[@]}"
echo "========================================"

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do

    echo
    echo "========================================"
    echo " RUNNING: $test"
    echo "========================================"

    xrun -f run.f \
        -uvmhome "$UVMHOME" \
        +define+POWER_AWARE_SIM \
        -access +rwc \
        -lps_1801 "$UPF_FILE" \
        -covtest "$test" \
        +UVM_TESTNAME="$test" \
        > "$LOGDIR/$test.log" 2>&1

    if grep -q "UVM_ERROR :    0" "$LOGDIR/$test.log" && \
       grep -q "UVM_FATAL :    0" "$LOGDIR/$test.log"; then

        echo "PASS: $test"
        ((PASS++))

    else

        echo "FAIL: $test"
        ((FAIL++))

        echo "  Check: $LOGDIR/$test.log"

    fi

done

echo
echo "========================================"
echo " POWER-AWARE REGRESSION COMPLETE"
echo " PASS: $PASS"
echo " FAIL: $FAIL"
echo " TOTAL: $((PASS + FAIL))"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "ALL ${#TESTS[@]} POWER-AWARE TESTS PASSED"
else
    echo "Some tests failed. Check $LOGDIR/"
fi