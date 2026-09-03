package axi4l_test_pkg;
  
  import uvm_pkg::*;
  import a4lite_pkg::*;
  import axi4l_uvm_pkg::*;
  `include "uvm_macros.svh"
  
  `include "axi4l_sb.sv"

  /* Coverage must come before the environment */

  /* read/write coverage is transaction-level UVM coverage. It samples transactions that your monitors already publish */
  /* other coverage files (queue/fault/recovery) are not included  since they cover internal RTL state/signals and not monitor transactions */
  `include "coverage/axi4l_read_protocol_coverage.sv"
  `include "coverage/axi4l_write_protocol_coverage.sv"
  
  `include "axi4l_env.sv"
  
  `include "base_test.sv"
  `include "upf_base_test.sv"


 // `include "basic_read_test.sv"
 // `include "write_readback_test.sv"
 // `include "unit_tests/read_timeout_test.sv"
  //`include "write_response_timeout_test.sv"

  /* NORM CATEGORY */
  `include "normal_read_test_norm1.sv" //NORM-01
  `include "normal_write_test_norm2.sv" //NORM-02
  `include "normal_backpressure_test_norm3.sv" //NORM-03
  `include "aw_before_w_test_norm4.sv" //NORM-04
  `include "supported_fields_test_norm5.sv" //NORM-05
  `include "concurrent_read_write_test_norm6.sv" //NORM-06
  `include "pre_timeout_boundary_test_norm7.sv" //NORM-07

  /* RTO (READ TIMEOUT) CATEGORY */
  `include "rto1_read_response_timeout.sv" //RTO-01
  `include "rto2_legal_delayed_response.sv" //RTO-02
  `include "rto3_upstream_slverr.sv" //RTO-03
  `include "rto4_slverr_stability.sv" //RTO-04
  `include "rto5_late_response_drain.sv" //RTO-05

  /* WDT (WRITE DATA TIMEOUT) CATEGORY */
  `include "wdt1_write_data_timeout.sv" //WDT-01
  `include "wdt2_fault_handling.sv" //WDT-02
  `include "wdt3_delayed_write_data.sv" //WDT-03
  `include "wdt4_final_boundary.sv" //WDT-04
  `include "wdt5_late_write_data.sv" //WDT-05
  `include "wdt6_no_downstream_launch.sv" //WDT-06

  /* WRT (WRITE RESPONSE TIMEOUT) CATEGORY */
  `include "wrt1_write_response_timeout.sv" //WRT-01
  `include "wrt2_slverr_injection.sv" //WRT-02
  `include "wrt3_slverr_backpressure.sv" //WRT-03
  `include "wrt4_late_write_response.sv" //WRT-04
  `include "wrt5_delayed_write_response.sv" //WRT-05
  `include "wrt6_write_response_boundary.sv" //WRT-06

  /* FLT (FAULT REPORTING) CATEGORY */
  `include "flt1_read_timeout_source.sv" //FLT-01
  `include "flt2_write_data_timeout_source.sv" //FLT-02
  `include "flt3_write_response_timeout_source.sv" //FLT-03
  `include "flt4_sticky_fault_status.sv" //FLT-04
  `include "flt5_masked_fault_no_irq.sv" //FLT-05
  `include "flt6_enabled_fault_irq.sv" //FLT-06
  `include "flt7_multiple_fault_sources_test.sv" //FLT-07
  
  /* QUEUE CATEGORY */
  `include "queue1_multiple_outstanding_reads.sv" //QUEUE-01
  `include "queue2_read_ordering.sv" // QUEUE-02
  `include "queue3_read_queue_full.sv" // QUEUE-03
  `include "queue4_multiple_outstanding_writes.sv" // QUEUE-04
  `include "queue5_write_queue_full.sv" // QUEUE-05
  `include "queue6_independent_read_write_occupancy.sv" // QUEUE-06
  `include "queue7_read_capacity_reuse.sv" // QUEUE-07
  `include "queue8_head_timeout_with_followers.sv" // QUEUE-08

  /* RECOVERY AND EPOCH MANAGEMENT TESTS */
  `include "rec1_fault_enters_containment.sv" // REC-01
  `include "rec2_recovery_waits_for_quiescence.sv" // REC-02
  `include "rec3_status_irq_persist_until_ack.sv" // REC-03
  `include "rec4_early_clear_blocked_until_quiescence.sv"  // REC-04
  `include "rec5_quiescence_enters_recovery.sv" // REC-05
  `include "rec6_authorized_epoch_clear.sv" // REC-06
  `include "rec7_epoch_clear_returns_normal.sv" // REC-07
  `include "rec8_post_recovery_transaction.sv" // REC-08

  /* PROTOCOL TESTS */
  `include "prot1_read_address_backpressure.sv" // PROT-01
  `include "prot2_read_response_backpressure.sv" // PROT-02
  `include "prot3_write_address_backpressure.sv"  // PROT-03
  `include "prot4_write_data_backpressure.sv" // PROT-04
  `include "prot5_wready_waits_for_aw.sv"  // PROT-05
  `include "prot6_downstream_waits_for_write_pair.sv" // PROT-06
  `include "prot7_write_response_backpressure.sv" // PROT-07

   /* Power-aware tests */
  `include "power_ctrl_smoke_test.sv"
  `include "upf_normal_test.sv"
  `include "upf_power_down_test.sv" //PWR-02
  `include "unit_tests/upf_tests/upf_read_power_loss_test.sv" //PWR-03
  `include "unit_tests/upf_tests/upf_write_power_loss_test.sv" //PWR-04
  `include "unit_tests/upf_tests/upf_power_restore_test.sv" //PWR-05
  `include "unit_tests/upf_tests/upf_unexpected_power_loss_test.sv" //PWR-06

  /* COVERAGE TESTS TO FILL HOLES */
  `include "recovery_after_wdt_test_cc1.sv"
  `include "recovery_after_wrt_test_cc2.sv"
  `include "masked_wrt_test_cc3.sv"
  `include "simultaneous_enqueue_retire_test_cc4.sv"
  `include "zero_wstrb_test_cc5.sv"
  `include "downstream_slverr_test_cc6.sv"
  `include "downstream_decerr_test_cc7.sv"
  `include "multiple_write_ghost_test_cc9.sv"
  
endpackage : axi4l_test_pkg