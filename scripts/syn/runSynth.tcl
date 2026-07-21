
set OUT_FOLDER /ubc/ece/home/ugrads/r/rkaisaan/thesis/outputs
set SOURCE_FOLDER /ubc/ece/home/ugrads/r/rkaisaan/thesis/rtl2
set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing
set TOP_LEVEL tp_lvl
set RUN_NAME v1

# 1) Setting the library search path
set_db lib_search_path [concat [get_db lib_search_path] $SOURCE_FOLDER $LIB_FOLDER ]
set_db library "slow_vdd1v0_basicCells.lib"

#ensure correct ordering
read_hdl -sv ${SOURCE_FOLDER}/a4lite_pkg.sv
read_hdl -sv ${SOURCE_FOLDER}/axi4l_if.sv
read_hdl -sv ${SOURCE_FOLDER}/interrupt_ctrl.sv
read_hdl -sv ${SOURCE_FOLDER}/rd_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/wr_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/tp_lvl.sv

elaborate $TOP_LEVEL
check_design -unresolved
# Here: get_db current_design -> should show :$TOP_LEVEL

# 3) Read timing constraints
source constraints.tcl

set clk_pin clk
create_clock [get_ports $clk_pin] \
        -name core_clk \
        -period 2.0 \
        -waveform {0 1}

create_clock -name io_virtual_clk -period 2.0
#Set clock back before priting.

# 4) synthesis of the design
synthesize -to_generic -effort high
synthesize -to_mapped -effort high -no_incr
synthesize -to_mapped -effort high -incr

insert_tiehilo_cells
# 5) Report specs and save 
report_area > ./reports/${TOP_LEVEL}_${RUN_NAME}_area.rpt 
report_gates > ./reports/${TOP_LEVEL}_${RUN_NAME}_gates.rpt   
report_timing > ./reports/${TOP_LEVEL}_${RUN_NAME}_timing.rpt 
report_power > ./reports/${TOP_LEVEL}_${RUN_NAME}_power.rpt
report_qor > ./reports/${TOP_LEVEL}_${RUN_NAME}_qor.rpt

write_hdl -mapped > ./outputs/${TOP_LEVEL}_${RUN_NAME}_map.sv 
write_sdc  > ./outputs/${TOP_LEVEL}_${RUN_NAME}_map.sdc 
write_sdf > ./outputs/${TOP_LEVEL}_${RUN_NAME}_map.sdf

write_db -to ./chkpts/${TOP_LEVEL}_synth_${RUN_NAME}.dat
# Here: report_qor -> would show summarized results for the synthesis
# Here: gui_show -> Right-click the top design on the left column to see the schematic on gui
