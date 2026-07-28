#!/usr/bin/env bash

# ------------------------------------------------------------
# Runs Xcelium using run.f
#
# The complete output is saved to:
#     xcelium.log
#
# The old xcelium.log is overwritten every time this script runs.
# ------------------------------------------------------------

set -o pipefail

LOG_FILE="xcelium.log"

# Delete the previous log and create a fresh empty one.
: > "$LOG_FILE"

echo "============================================================" | tee -a "$LOG_FILE"
echo "Starting Xcelium compilation: $(date)"                | tee -a "$LOG_FILE"
echo "Command: xrun -f run.f $*"                           | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

# Run Xcelium.
# 2>&1 combines errors and normal output.
# tee displays the output and writes it into xcelium.log.
xrun -f run.f "$@" 2>&1 | tee -a "$LOG_FILE"

# Preserve the real exit status from xrun rather than tee.
XRUN_STATUS=${PIPESTATUS[0]}

echo                                                        | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "Xcelium finished with exit status: $XRUN_STATUS"       | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE"                               | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

exit "$XRUN_STATUS"