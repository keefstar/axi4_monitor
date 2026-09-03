#!/bin/bash

TEST_FILE="regression_tests.txt"
LOG_DIR="regression_logs"
COV_DIR="cov_work"
SUMMARY_FILE="$LOG_DIR/regression_summary.txt"

mkdir -p "$LOG_DIR"

rm -f "$SUMMARY_FILE"

echo "AXI4-Lite SCC Regression" | tee "$SUMMARY_FILE"
echo "Started: $(date)" | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"

pass_count=0
fail_count=0
total_count=0

while IFS= read -r test || [ -n "$test" ]; do

    # Ignore empty lines and comments.
    [[ -z "$test" ]] && continue
    [[ "$test" =~ ^[[:space:]]*# ]] && continue

    total_count=$((total_count + 1))

    log="$LOG_DIR/${test}.log"

    echo "------------------------------------------------------------"
    echo "Running: $test"
    echo "Log:     $log"
    echo "------------------------------------------------------------"

    xrun -f run.f \
        -covtest "$test" \
        +UVM_TESTNAME="$test" \
        2>&1 | tee "$log"

    xrun_status=${PIPESTATUS[0]}

    errors=$(grep -E "UVM_ERROR[[:space:]]*:" "$log" | tail -1 | awk '{print $3}')
    fatals=$(grep -E "UVM_FATAL[[:space:]]*:" "$log" | tail -1 | awk '{print $3}')

    if [[ "$xrun_status" -eq 0 && "$errors" == "0" && "$fatals" == "0" ]]; then

        echo "$test : PASS" | tee -a "$SUMMARY_FILE"
        pass_count=$((pass_count + 1))

    else

        echo "$test : FAIL" | tee -a "$SUMMARY_FILE"
        fail_count=$((fail_count + 1))

    fi

    echo ""

done < "$TEST_FILE"

echo "" | tee -a "$SUMMARY_FILE"
echo "Regression complete" | tee -a "$SUMMARY_FILE"
echo "Total : $total_count" | tee -a "$SUMMARY_FILE"
echo "PASS  : $pass_count" | tee -a "$SUMMARY_FILE"
echo "FAIL  : $fail_count" | tee -a "$SUMMARY_FILE"
echo "Ended : $(date)" | tee -a "$SUMMARY_FILE"

if [[ "$fail_count" -ne 0 ]]; then
    exit 1
fi

exit 0