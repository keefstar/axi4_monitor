set PROJECT_ROOT   /ubc/ece/home/ugrads/r/rkaisaan/thesis
set SOURCE_FOLDER  ${PROJECT_ROOT}/rtl2
set OUT_FOLDER     ${PROJECT_ROOT}/outputs
set REPORT_FOLDER  ${PROJECT_ROOT}/reports
set CHKPT_FOLDER   ${PROJECT_ROOT}/chkpts

set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing
set LIB_FILE   slow_vdd1v0_basicCells.lib

set TOP_LEVEL tp_lvl

if {[info exists ::env(RUN_NAME)]} {
    set RUN_NAME $::env(RUN_NAME)
} else {
    set RUN_NAME v1
}

if {[info exists ::env(CLK_PERIOD_NS)]} {
    set CLK_PERIOD_NS $::env(CLK_PERIOD_NS)
} else {
    set CLK_PERIOD_NS 5.0
}

file mkdir $OUT_FOLDER
file mkdir $REPORT_FOLDER
file mkdir $CHKPT_FOLDER

# Set library and RTL search paths.
set_db lib_search_path [concat [get_db lib_search_path] $SOURCE_FOLDER $LIB_FOLDER]
set_db library $LIB_FILE

# Read RTL in dependency order.
read_hdl -sv ${SOURCE_FOLDER}/a4lite_pkg.sv
read_hdl -sv ${SOURCE_FOLDER}/axi4l_if.sv
read_hdl -sv ${SOURCE_FOLDER}/interrupt_ctrl.sv
read_hdl -sv ${SOURCE_FOLDER}/rd_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/wr_queue.sv
read_hdl -sv ${SOURCE_FOLDER}/tp_lvl.sv

elaborate $TOP_LEVEL
check_design -unresolved

# Apply timing and I/O constraints.
source ${PROJECT_ROOT}/genus_frequency_sweep/constraints.tcl

# Synthesize.
synthesize -to_generic -effort high
synthesize -to_mapped -effort high -no_incr
synthesize -to_mapped -effort high -incr

insert_tiehilo_cells

# Generate reports.
report_area  > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_area.rpt
report_area -detail -show_full_names > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_area_hier.rpt
report_gates  > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_gates.rpt
report_timing  > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_timing.rpt
report_power  > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_power.rpt
report_qor > ${REPORT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_qor.rpt

# Write synthesized outputs.
write_hdl -mapped > ${OUT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_map.sv
write_sdc > ${OUT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_map.sdc
write_sdf > ${OUT_FOLDER}/${TOP_LEVEL}_${RUN_NAME}_map.sdf

write_db -to ${CHKPT_FOLDER}/${TOP_LEVEL}_synth_${RUN_NAME}.dat

puts ""
puts "GENUS SYNTHESIS COMPLETE"
puts "Top: $TOP_LEVEL"
puts "Run: $RUN_NAME"
puts "Clock period: $CLK_PERIOD_NS ns"
puts ""
