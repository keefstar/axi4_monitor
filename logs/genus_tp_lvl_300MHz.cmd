# Cadence Genus(TM) Synthesis Solution, Version 19.14-s108_1, built Jul  7 2020 16:22:44

# Date: Sat Aug 29 15:08:39 2026
# Host: ssh-soc.ece.ubc.ca (x86_64 w/Linux 4.18.0-553.154.1.el8_10.x86_64) (1core*16cpus*16physical cpus*Intel Xeon Processor (Cascadelake) 16384KB)
# OS:   Red Hat Enterprise Linux 8.10 (Source)

source ./genus_frequency_sweep/synth_sweep.tcl
RUN_NAME="400MHz" \ CLK_PERIOD_NS="2.5" \ genus -files ./genus_frequency_sweep/synth_sweep.tcl \ -log "./logs/genus_tp_lvl_400MHz.log"
exit
