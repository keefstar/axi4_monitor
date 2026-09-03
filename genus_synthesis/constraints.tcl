# 200 MHz primary clock.
create_clock -name core_clk -period 5.0 -waveform {0 2.5} [get_ports clk]

# Virtual clock for external I/O timing assumptions.
create_clock -name io_virtual_clk -period 5.0

# The active-low reset is asynchronous and is not timed as synchronous data.
set_false_path -from [get_ports rst_n]

# Use 1.0 ns input and output delays for a reproducible comparison.
set DATA_INPUTS [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]

set_input_delay 1.0 -clock io_virtual_clk $DATA_INPUTS
set_output_delay 1.0 -clock io_virtual_clk [all_outputs]

# Apply a modest output load for comparative synthesis.
set_load 0.05 [all_outputs]
