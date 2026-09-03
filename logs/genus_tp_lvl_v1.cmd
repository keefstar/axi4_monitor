# Cadence Genus(TM) Synthesis Solution, Version 19.14-s108_1, built Jul  7 2020 16:22:44

# Date: Fri Aug 28 22:09:30 2026
# Host: ssh-soc.ece.ubc.ca (x86_64 w/Linux 4.18.0-553.154.1.el8_10.x86_64) (1core*16cpus*16physical cpus*Intel Xeon Processor (Cascadelake) 16384KB)
# OS:   Red Hat Enterprise Linux 8.10 (Source)

source ./genus_synthesis/synth.tcl
chmod +x ./genus_frequency_sweep/run_sweep.sh
./genus_frequency_sweep/run_sweep.sh
