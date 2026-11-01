#!/usr/bin/env bash
# HITL (human-in-the-loop) feedback-loop template for `diagnose` Phase 1 —
# last resort when a human must perform a manual step (e.g. click a UI) that the
# agent cannot automate. Keeps the loop STRUCTURED: the agent prints exactly what
# to do, the human does it, presses Enter, and the captured result feeds back.
#
# Copy this into the target repo, fill CHECK, and run it. Do not commit the copy.
set -u

ITER="${1:-5}"          # max iterations
if [[ ! "$ITER" =~ ^[1-9][0-9]*$ ]] || [[ ${#ITER} -gt 19 ]] ||
   { [[ ${#ITER} -eq 19 ]] && [[ "$ITER" > 9223372036854775807 ]]; }; then
  echo "iteration count must be a positive supported integer" >&2
  exit 2
fi
i=0
while [ "$i" -lt "$ITER" ]; do
  i=$((i + 1))
  echo "=============================================="
  echo "[HITL loop] iteration $i / $ITER"
  echo "MANUAL STEP: <describe the exact action the human must perform to trigger the bug>"
  printf 'Press Enter after performing the step (or type q + Enter to stop)... '
  read -r ans || { echo "manual input unavailable" >&2; exit 2; }
  [ "$ans" = "q" ] && { echo "stopped by human"; exit 2; }

  # --- CHECK: the red-capable assertion for THIS bug -------------------------
  # Replace with the command that inspects the result of the manual step and
  # returns 0 when the exact symptom is present, 1 when absent, and >1 on
  # check/tool failure (unavailable observation, not green).
  #   e.g. grep -q "EXPECTED_ERROR" ./out.log
  if CHECK; then
    echo "RED: symptom reproduced on iteration $i"
    exit 1
  else
    check_status=$?
    if [ "$check_status" -ne 1 ]; then
      echo "CHECK unavailable or failed (exit $check_status)" >&2
      exit 2
    fi
    echo "green: symptom not observed this iteration"
  fi
done

echo "loop finished without reproducing ($ITER iterations)"
exit 0
