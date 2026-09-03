Genus TIMER_WIDTH sweep

Sweep:
- TIMER_WIDTH = 9, 12, 16, 24
- DEPTH = 8
- TIMEOUT_CYCLES = 256
- Clock = 200 MHz (5.0 ns)

9 bits is the minimum width that can represent 256. Do not use 8 bits.

The sweep uses synthesis-only wrappers, so the verified tp_lvl RTL is not edited.

Run from ~/thesis after sourcing Genus:
chmod +x genus_timer_width_sweep/run_timer_width_sweep.sh
./genus_timer_width_sweep/run_timer_width_sweep.sh

The launcher is Bash, so this single command works even when your interactive shell is tcsh.

Reports:
reports/timer_width/

Compare the four sweep points only against each other. tw16 is the default/reference configuration.
