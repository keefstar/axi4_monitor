# Timing and I/O constraints for fixed-frequency timer-width sweep.
set clk_pin clk
set rstn_pin rst_n
set clk_period $CLK_PERIOD_NS
set eighth [expr {$clk_period / 8.0}]
set quarter [expr {$clk_period / 4.0}]
set half_period [expr {$clk_period / 2.0}]
set inputs_no_clk_rstn [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]
create_clock [get_ports $clk_pin] -name core_clk -period $clk_period -waveform [list 0 $half_period]
create_clock -name io_virtual_clk -period $clk_period
set_driving_cell -lib_cell DFFX1 -input_transition_rise $eighth -input_transition_fall $eighth $inputs_no_clk_rstn
set_load [expr {[load_of [get_lib_pins */NAND2X4/A]] * 4}] [all_outputs]
set_input_delay -max $quarter -clock io_virtual_clk $inputs_no_clk_rstn
set_output_delay -max $quarter -clock io_virtual_clk [all_outputs]
set_clock_uncertainty $eighth [get_clocks core_clk]
set_clock_latency $eighth [get_clocks core_clk]
set_false_path -from [get_ports $rstn_pin]
