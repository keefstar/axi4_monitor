set PROJECT_ROOT   /ubc/ece/home/ugrads/r/rkaisaan/thesis
set SOURCE_FOLDER  ${PROJECT_ROOT}/rtl2
set SWEEP_FOLDER   ${PROJECT_ROOT}/genus_timer_width_sweep
set OUT_FOLDER     ${PROJECT_ROOT}/outputs/timer_width
set REPORT_FOLDER  ${PROJECT_ROOT}/reports/timer_width
set CHKPT_FOLDER   ${PROJECT_ROOT}/chkpts/timer_width

set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing
set LIB_FILE   slow_vdd1v0_basicCells.lib

if {[info exists ::env(TIMER_WIDTH)]} {
    set TIMER_WIDTH $::env(TIMER_WIDTH)
} else {
    set TIMER_WIDTH 16
}

if {[info exists ::env(CLK_PERIOD_NS)]} {
    set CLK_PERIOD_NS $::env(CLK_PERIOD_NS)
} else {
    set CLK_PERIOD_NS 5.0
}

set TOP_LEVEL tp_lvl_tw${TIMER_WIDTH}
set RUN_NAME tw${TIMER_WIDTH}_200MHz

file mkdir $OUT_FOLDER
file mkdir $REPORT_FOLDER
file mkdir $CHKPT_FOLDER

set_db lib_search_path [concat [get_db lib_search_path] $SOURCE_FOLDER $LIB_FOLDER $SWEEP_FOLDER]
set_db library $LIB_FILE

read_hdl -sv ${SOURCE_FOLDER}/a4lite_pkg.sv
read_hdl -sv ${SOURCE_FOLDER}/axi4l_if.sv
read_hdl -sv ${SOURCE_FOLDER}/interrupt_ctrl.sv
read_hdl -sv ${SOURCE_FOLDER}/rd_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/wr_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/tp_lvl.sv
read_hdl -sv ${SWEEP_FOLDER}/${TOP_LEVEL}.sv

elaborate $TOP_LEVEL
check_design -unresolved

source ${SWEEP_FOLDER}/constraints.tcl

synthesize -to_generic -effort high
synthesize -to_mapped -effort high -no_incr
synthesize -to_mapped -effort high -incr

insert_tiehilo_cells

report_area   > ${REPORT_FOLDER}/${RUN_NAME}_area.rpt
report_gates  > ${REPORT_FOLDER}/${RUN_NAME}_gates.rpt
report_timing > ${REPORT_FOLDER}/${RUN_NAME}_timing.rpt
report_power  > ${REPORT_FOLDER}/${RUN_NAME}_power.rpt
report_qor    > ${REPORT_FOLDER}/${RUN_NAME}_qor.rpt

write_hdl -mapped > ${OUT_FOLDER}/${RUN_NAME}_map.sv
write_sdc         > ${OUT_FOLDER}/${RUN_NAME}_map.sdc
write_sdf         > ${OUT_FOLDER}/${RUN_NAME}_map.sdf
write_db -to ${CHKPT_FOLDER}/${RUN_NAME}.dat

puts ""
puts "GENUS TIMER-WIDTH SYNTHESIS COMPLETE"
puts "Top: $TOP_LEVEL"
puts "TIMER_WIDTH: $TIMER_WIDTH"
puts "TIMEOUT_CYCLES: 256"
puts "Clock period: $CLK_PERIOD_NS ns"
puts ""

exit
