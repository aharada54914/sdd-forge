#!/bin/sh
# Re-runnable driver for the T-001/T-002/T-003 verification-artifact backfill.
#
# The three tasks were flipped to Done without a verification contract or an
# evidence bundle, so check-task-state fails for the whole feature. Backfilling
# those six artifacts requires evidence for every check the risk tier mandates.
# Rather than point the contracts at old implementation logs and call that a
# verification, this script RE-RUNS every gate command now, at the current HEAD,
# and saves the real output. Each log records the exact command that produced it
# so the argument list is auditable rather than implied (the shape used by
# specs/epic-189-a1-project-context/verification/qg/).
#
# Usage:
#   run-checks.sh              regenerate every log except task-state.log
#   run-checks.sh task-state   regenerate only task-state.log
#
# task-state.log is separate because it is self-referential: check-task-state
# validates the very contracts and bundles this backfill produces, so it can
# only go green after they exist, and the bundles must then be regenerated to
# pick up its final bytes. See README.md for the fixed-point argument.
#
# No log embeds a timestamp: a re-run must be able to reproduce the same bytes,
# and a clock value would invalidate every bundle hash on every re-run.

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
scripts="$root/plugins/sdd-quality-loop/scripts"
cd "$root" || exit 1

mkdir -p "$here/T-001" "$here/T-002" "$here/T-003"

failures=0

# run <log-path> <note> -- <command...>
# Writes the note, "$ <command>", the command's combined output, and its exit
# status. Records a failure instead of aborting, so one red check still leaves a
# complete set of logs to read.
run() {
  log=$1
  note=$2
  shift 3  # drop log, note, and the literal "--"
  {
    printf '%s\n' "$note"
    printf '\n$ %s\n' "$*"
  } > "$log"
  "$@" >> "$log" 2>&1
  rc=$?
  printf '\nexit status: %s\n' "$rc" >> "$log"
  printf '%-62s exit=%s\n' "${log#"$root"/}" "$rc"
  [ "$rc" -eq 0 ] || failures=$((failures + 1))
}

SCOPE_NOTE='Scan scope is recorded here so the argument list is auditable rather
than implied. The files are exactly the agent-editable deliverables that
traceability.md'"'"'s "Deliverables (Per Task)" table attributes to this task.
Excluded on purpose: specs/epic-195-a7-compatibility/verification/golden-baseline/
canonical/, which is captured product output (a fixture), not authored code --
check-placeholders is scoped to changed production files per
references/deterministic-check-policy.md ("Keep the caller scoped to changed
files"), and scanning captured product bytes would flag markers this feature
never wrote.'

case "${1:-all}" in
task-state)
  run "$here/task-state.log" \
    'Whole-feature tasks.md state-machine gate. This single run is the evidence
for all three tasks: check-task-state validates every task in the file at once,
so there is one run, not three. It transitively runs check-evidence-bundle and
check-contract for each Done task, which is why its output names them.' \
    -- sh "$scripts/check-task-state.sh" \
         specs/epic-195-a7-compatibility/tasks.md \
         reports/quality-gate reports/implementation .
  [ "$failures" -eq 0 ] || exit 1
  exit 0
  ;;
all) ;;
*)
  echo "usage: run-checks.sh [task-state]" >&2
  exit 2
  ;;
esac

# ---------------------------------------------------------------- T-001
run "$here/T-001/placeholder.log" "$SCOPE_NOTE" \
  -- sh "$scripts/check-placeholders.sh" \
       tests/lib/fixture-matrix-builder.sh \
       tests/lib/fixture-matrix-builder.ps1

run "$here/T-001/acceptance.log" \
  'T-001 acceptance harness, both runtimes. The fixture-matrix builder is a
sourced library that design.md forbids registering as its own run-all suite, so
its acceptance suite lives beside the task evidence rather than under tests/.
This log is the evidence for both the unit-tests and the acceptance-tests
contract checks: the harness is the only suite that exercises the deliverable,
matching specs/epic-189-a1-project-context/verification/qg/T-001/, whose
contract points both ids at one focused-tests.log.' \
  -- sh -c '
      bash specs/epic-195-a7-compatibility/verification/T-001/acceptance.sh
      sh_rc=$?
      echo
      echo "$ pwsh -NoProfile -File specs/epic-195-a7-compatibility/verification/T-001/acceptance.ps1"
      pwsh -NoProfile -File specs/epic-195-a7-compatibility/verification/T-001/acceptance.ps1
      ps_rc=$?
      [ "$sh_rc" -eq 0 ] && [ "$ps_rc" -eq 0 ]'

# ---------------------------------------------------------------- T-002
run "$here/T-002/placeholder.log" "$SCOPE_NOTE" \
  -- sh "$scripts/check-placeholders.sh" \
       tests/capture-golden-baseline.sh tests/capture-golden-baseline.ps1 \
       tests/promote-golden-baseline.sh tests/promote-golden-baseline.ps1 \
       tests/golden-baseline-contract.tests.sh tests/golden-baseline-contract.tests.ps1 \
       tests/run-all.sh tests/run-all.ps1

run "$here/T-002/acceptance.log" \
  'T-002 acceptance suite, both runtimes. Evidence for both the unit-tests and
the acceptance-tests contract checks; the TDD Red->Green pair those two checks
also carry lives in verification/T-002/red-bash.log and green-bash.log, captured
at implementation time and unchanged since.' \
  -- sh -c '
      bash tests/golden-baseline-contract.tests.sh
      sh_rc=$?
      echo
      echo "$ pwsh -NoProfile -File tests/golden-baseline-contract.tests.ps1"
      pwsh -NoProfile -File tests/golden-baseline-contract.tests.ps1
      ps_rc=$?
      [ "$sh_rc" -eq 0 ] && [ "$ps_rc" -eq 0 ]'

# ---------------------------------------------------------------- T-003
run "$here/T-003/placeholder.log" "$SCOPE_NOTE" \
  -- sh "$scripts/check-placeholders.sh" \
       tests/compatibility-byte-identical.tests.sh tests/compatibility-byte-identical.tests.ps1 \
       tests/install.tests.sh tests/install.tests.ps1 \
       tests/uninstall.tests.sh tests/uninstall.tests.ps1 \
       tests/run-all.sh tests/run-all.ps1

run "$here/T-003/acceptance.log" \
  'T-003 acceptance suite, both runtimes. Evidence for both the unit-tests and
the acceptance-tests contract checks.' \
  -- sh -c '
      bash tests/compatibility-byte-identical.tests.sh
      sh_rc=$?
      echo
      echo "$ pwsh -NoProfile -File tests/compatibility-byte-identical.tests.ps1"
      pwsh -NoProfile -File tests/compatibility-byte-identical.tests.ps1
      ps_rc=$?
      [ "$sh_rc" -eq 0 ] && [ "$ps_rc" -eq 0 ]'

# ------------------------------------------------------------- shared
run "$here/regression.log" \
  'Targeted regression, shared by all three contracts.

Targeted rather than tests/run-all.sh because run-all is structurally red in
this repository until a human applies the staged human-copy CI patch (the
deterministic-lane self-check fails closed by design), so a full run-all log
would record a designed red and prove nothing about these three tasks. This
feature already set that precedent: verification/T-001/regression-targeted.log.

The suite list is every shipped suite these three tasks author or edit
(golden-baseline-contract, compatibility-byte-identical, install, uninstall,
per traceability.md'"'"'s Deliverables table), plus two blast-radius neighbours --
structural-compatibility, the sibling consumer of the same run-all registration
block, and loop-driver, the cross-epic shared driver -- plus gates.tests.sh,
which owns the risk-gate-matrix tier-minimum invariant that the contracts this
backfill authors are validated against.' \
  -- sh -c '
      rc=0
      for s in tests/golden-baseline-contract.tests.sh \
               tests/compatibility-byte-identical.tests.sh \
               tests/install.tests.sh \
               tests/uninstall.tests.sh \
               tests/structural-compatibility.tests.sh \
               tests/loop-driver.tests.sh \
               tests/gates.tests.sh; do
        echo "=========================================================="
        echo "[RUN] $s"
        echo "=========================================================="
        bash "$s" || rc=1
        echo
      done
      exit $rc'

run "$here/traceability.log" \
  'REQ -> AC -> TEST -> evidence chain gate, shared by all three contracts.
The first command proves traceability.json is still a faithful derivation of the
reviewed traceability.md; the second is the gate itself. Only T-002 is required
to carry a requirement-traceability check (high tier,
references/risk-gate-matrix.md), but the run covers the whole feature, so the
same log is honest evidence for any contract that names the check.' \
  -- sh -c '
      python3 specs/epic-195-a7-compatibility/verification/qg-backfill/derive-traceability-json.py --check
      derive_rc=$?
      echo
      echo "$ sh plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-195-a7-compatibility/traceability.json ."
      sh plugins/sdd-quality-loop/scripts/check-traceability.sh \
         specs/epic-195-a7-compatibility/traceability.json .
      gate_rc=$?
      [ "$derive_rc" -eq 0 ] && [ "$gate_rc" -eq 0 ]'

echo
if [ "$failures" -ne 0 ]; then
  echo "$failures backfill check(s) FAILED; read the logs above." >&2
  exit 1
fi
echo "All backfill checks passed. task-state.log is generated separately:"
echo "  sh $0 task-state"
