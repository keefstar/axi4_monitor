
# XM-Sim Command File
# TOOL:	xmsim(64)	25.09-s001
#

set tcl_prompt1 {puts -nonewline "xcelium> "}
set tcl_prompt2 {puts -nonewline "> "}
set vlog_format %h
set vhdl_format %v
set real_precision 6
set display_unit auto
set time_unit module
set heap_garbage_size -200
set heap_garbage_time 0
set assert_report_level note
set assert_stop_level error
set autoscope yes
set assert_1164_warnings yes
set pack_assert_off {}
set severity_pack_assert_off {note warning}
set assert_output_stop_level failed
set tcl_debug_level 0
set relax_path_name 1
set vhdl_vcdmap XX01ZX01X
set intovf_severity_level ERROR
set probe_screen_format 0
set rangecnst_severity_level ERROR
set textio_severity_level ERROR
set vital_timing_checks_on 1
set vlog_code_show_force 0
set assert_count_attempts 1
set tcl_all64 false
set tcl_runerror_exit false
set assert_report_incompletes 0
set show_force 1
set force_reset_by_reinvoke 0
set tcl_relaxed_literal 0
set probe_exclude_patterns {}
set probe_packed_limit 4k
set probe_unpacked_limit 16k
set assert_internal_msg no
set svseed 1
set assert_reporting_mode 0
set vcd_compact_mode 0
set vhdl_forgen_loopindex_enum_pos 0
set xmreplay_dc_debug 0
set tcl_runcmd_interrupt next_command
set tcl_sigval_prefix {#}
set gate_loop_warn_size 1
alias . run
alias get value
alias indago verisium
alias quit exit
stop -create -name Randomize -randomize
database -open -shm -into xcelium.shm xcelium.shm -default
probe -create -database xcelium.shm tb_top.sub_power_en tb_top.sub_iso_en -power
probe -create -database xcelium.shm -pwr_mode
probe -create -database xcelium.shm tb_top.clk tb_top.dut.mode tb_top.upstream_if.arvalid tb_top.upstream_if.arready tb_top.upstream_if.rvalid tb_top.upstream_if.rready tb_top.upstream_if.r tb_top.downstream_if.arvalid tb_top.downstream_if.arready tb_top.downstream_if.rvalid tb_top.dut.rd_timeout_pulse tb_top.dut.irq tb_top.dut.status_reg

simvision -input /ubc/ece/home/ugrads/r/rkaisaan/thesis/.simvision/1104421_rkaisaan_ssh-soc.ece.ubc.ca_autosave.tcl.svcf
