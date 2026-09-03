#!/bin/bash
set -e

cd /ubc/ece/home/ugrads/r/rkaisaan/thesis

mkdir -p outputs reports chkpts logs

genus -files ./genus_synthesis/synth.tcl \
      -log ./logs/genus_tp_lvl_v1.log
