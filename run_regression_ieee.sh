#!/bin/bash

UVMHOME="CDNS-IEEE-20"
LOGDIR="./regression_logs_ieee"

mkdir -p "$LOGDIR"

TESTS=(

  # NORM: 7
  normal_read_test_norm1
  normal_write_test_norm2
  normal_backpressure_test_norm3
  aw_before_w_test_norm4
  supported_fields_test_norm5
  concurrent_read_write_test_norm6
  pre_timeout_boundary_test_norm7

  # RTO: 5
  rto1_read_response_timeout_test
  rto2_legal_delayed_response_test
  rto3_upstream_slverr_test
  rto4_slverr_stability_test
  rto5_late_response_drain_test

  # WDT: 6
  wdt1_write_data_timeout_test
  wdt2_fault_handling_test
  wdt3_delayed_write_data_test
  wdt4_final_boundary_test
  wdt5_late_write_data_test
  wdt6_no_downstream_launch_test

  # WRT: 6
  wrt1_write_response_timeout_test
  wrt2_slverr_injection_test
  wrt3_slverr_backpressure_test
  wrt4_late_write_response_test
  wrt5_delayed_write_response_test
  wrt6_write_response_boundary_test

  # FLT: 7
  flt1_read_timeout_source_test
  flt2_write_data_timeout_source_test
  flt3_write_response_timeout_source_test
  flt4_sticky_fault_status_test
  flt5_masked_fault_no_irq_test
  flt6_enabled_fault_irq_test
  flt7_multiple_fault_sources_test

  # QUEUE: 8
  queue1_multiple_outstanding_reads_test
  queue2_read_ordering_test
  queue3_read_queue_full_test
  queue4_multiple_outstanding_writes_test
  queue5_write_queue_full_test
  queue6_independent_read_write_occupancy_test
  queue7_read_capacity_reuse_test
  queue8_head_timeout_with_followers_test

  # REC: 8
  rec1_fault_enters_containment_test
  rec2_recovery_waits_for_quiescence_test
  rec3_status_irq_persist_until_ack_test
  rec4_early_clear_blocked_until_quiescence_test
  rec5_quiescence_enters_recovery_test
  rec6_authorized_epoch_clear_test
  rec7_epoch_clear_returns_normal_test
  rec8_post_recovery_transaction_test

  # PROT: 7
  prot1_read_address_backpressure_test
  prot2_read_response_backpressure_test
  prot3_write_address_backpressure_test
  prot4_write_data_backpressure_test
  prot5_wready_waits_for_aw_test
  prot6_downstream_waits_for_write_pair_test
  prot7_write_response_backpressure_test

  # Coverage-closing: 8
  recovery_after_wdt_test_cc1
  recovery_after_wrt_test_cc2
  masked_wrt_test_cc3
  simultaneous_enqueue_retire_test_cc4
  zero_wstrb_test_cc5
  downstream_slverr_test_cc6
  downstream_decerr_test_cc7
  multiple_write_ghost_test_cc9
)

echo "========================================"
echo " IEEE 1800.2-2020 UVM Regression"
echo " UVM home: $UVMHOME"
echo " Tests: ${#TESTS[@]}"
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

    fi

done

echo
echo "========================================"
echo " REGRESSION COMPLETE"
echo " PASS: $PASS"
echo " FAIL: $FAIL"
echo " TOTAL: $((PASS + FAIL))"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "ALL 62 TESTS PASSED"
else
    echo "Some tests failed. Check $LOGDIR/"
fi