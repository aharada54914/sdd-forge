#!/bin/sh
# Re-runnable driver for the T-004 quality-gate cycle-3 host checks.
#
# Cycle 1 (ledger seq0674) returned NEEDS_WORK on one Critical and two Majors.
# Cycle 2 (seq0675) returned PASS, but commit e96cfc6f landed after its evaluator
# finished and moved three of the 49 files its manifest bound -- including the
# T-004 implementation report the manifest exists to bind. That manifest can no
# longer be re-validated, so cycle 2 cannot carry a Done flip: nobody later can
# confirm what its evaluator actually read. Cycle 3 re-runs the gate under a
# fresh manifest reserved against current bytes.
#
# The implementation report is a claim; this script RE-RUNS every gate command
# and every cycle-1 disproof method now, at the current HEAD, and saves the real
# output. Each log records the exact command that produced it so the argument
# list is auditable rather than implied (the shape used by
# specs/epic-195-a7-compatibility/verification/qg-backfill/).
#
# This is a byte-for-byte copy of the corrected cycle-2 driver except for its
# output directory and this header. Keeping the logic identical is the point:
# cycle 3's logs are comparable to cycle 2's precisely because the same commands
# produced them, so any divergence is a real change in the tree rather than a
# change in how it was measured.
#
# Usage:
#   run-checks.sh              regenerate every log except task-state.log
#   run-checks.sh task-state   regenerate only task-state.log
#   run-checks.sh only <name>  regenerate only <name>.log (e.g. `only regression`)
#
# The `only` selector exists so the byte-reproducibility this header claims can
# be re-checked for one stage without paying for the whole sweep: run a stage,
# diff its log against the committed copy, and the claim is either true or it
# is not.
#
# task-state.log is separate because it is self-referential: check-task-state
# validates the very contract and bundle this gate produces, so it can only go
# green after they exist, and the bundle must then be regenerated to pick up its
# final bytes. Same fixed point as the qg-backfill driver's README documents.
#
# No log embeds a timestamp or an absolute path: a re-run must reproduce the
# same bytes, and a clock value or a machine-specific path would invalidate the
# evidence bundle hash on every re-run.
#
# One exception is handled rather than asserted away. tests/install.tests.sh
# echoes its own mktemp scratch directory, which differs on every run, so a raw
# regression.log is not byte-reproducible and would break the bundle hash. Every
# log is therefore passed through scrub_volatile(), which rewrites only the
# random component of a mktemp path to the literal <scratch>. Nothing else is
# filtered: every ok:/PASS:/FAIL: line, count and exit status is the untouched
# output of the command named in the log.

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../../.." && pwd)
cd "$root" || exit 1
out="specs/epic-195-a7-compatibility/verification/qg-cycle3/T-004"

scrub_volatile() {
  # Rewrite ONLY the random suffix mktemp appends. See the header note.
  # Three generators produce one in this repository: a bare `mktemp -d` (tmp.
  # plus 8+ alphanumerics), this script's own `qg-t004-*.XXXXXX` templates, and
  # loop_fixture_init's `loop-fixture.XXXXXX` template in tests/lib/loop-driver.sh.
  #
  # The loop-fixture rule was missing in the cycle-2 driver, and cycle 3 caught
  # it the only way it can be caught: re-running the sweep and diffing. Exactly
  # one line of regression.log differed between the two cycles --
  # `ok: TEST-005.2: greenfield fixture root (.../loop-fixture.IW28ha) lies
  # outside the repository working tree` -- an ok: line whose assertion passed
  # both times and whose only unstable component was the scratch path. Harmless
  # to the verdict, fatal to the byte-reproducibility this header claims, and
  # therefore to any evidence-bundle hash over these logs: every re-run would
  # have reported a spurious mismatch. Fixed here rather than asserted away.
  # A wall-clock DURATION is the other non-reproducible value, and cycle 3 found
  # it the same way. Exactly one line in exactly one log carries one:
  # `loop-driver.tests.sh: 22 passed, 0 failed, Ns elapsed`, which read 2s in
  # cycle 2 and 1s here. Two consecutive cycle-3 runs happened to agree, so this
  # would have looked stable and broken the bundle later. Only the duration is
  # rewritten -- `22 passed, 0 failed` is load-bearing and is never touched.
  # The macOS TMPDIR prefix is the third and last one. Two lines of
  # regression.log print a scratch path in full, and the per-user directory
  # `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/` is stable on this
  # machine but meaningless on any other -- so the header's "no absolute path"
  # claim was true of every log except this one. Rewritten to <tmpdir> so the
  # claim holds and another machine can reproduce these bytes.
  sed -e 's#/private/var/folders/[A-Za-z0-9_+-]*/[A-Za-z0-9_+-]*/T/#<tmpdir>/#g' \
      -e 's#/var/folders/[A-Za-z0-9_+-]*/[A-Za-z0-9_+-]*/T/#<tmpdir>/#g' \
      -e 's#tmp\.[A-Za-z0-9]\{8,\}#tmp.<scratch>#g' \
      -e 's#\(qg-t004-[a-z-]*\)\.[A-Za-z0-9]\{6\}#\1.<scratch>#g' \
      -e 's#\(loop-fixture\)\.[A-Za-z0-9]\{6\}#\1.<scratch>#g' \
      -e 's#[0-9][0-9]*s elapsed#<elapsed>s elapsed#g'
}

only_stage=""
[ "${1:-}" = only ] && only_stage="${2:?run-checks.sh only <stage-name>}.log"

run_log() {
  # run_log <log-name> <preamble-or-dash> <command-string>
  if [ -n "$only_stage" ] && [ "$1" != "$only_stage" ]; then
    return 0
  fi
  log="$out/$1"
  preamble="$2"
  cmd="$3"
  # Scratch file lives outside the evidence directory on purpose: a crash must
  # never leave a stray artifact next to the logs the evidence bundle hashes.
  raw="${TMPDIR:-/tmp}/qg-t004-runlog.$$"
  : > "$log"
  if [ "$preamble" != "-" ]; then
    printf '%s\n\n' "$preamble" >> "$log"
  fi
  printf '$ sh -c %s\n' "$cmd" >> "$log"
  # Capture the COMMAND's exit status, not the scrubber's: POSIX sh has no
  # PIPESTATUS, so a pipeline here would silently report sed's status and mask
  # every failure this driver exists to surface.
  sh -c "$cmd" > "$raw" 2>&1
  rc=$?
  scrub_volatile < "$raw" >> "$log"
  rm -f "$raw"
  printf '\nexit status: %d\n' "$rc" >> "$log"
  echo "[$1] exit status: $rc"
  return $rc
}

if [ "${1:-}" = task-state ]; then
  run_log task-state.log \
"Whole-feature tasks.md state-machine gate. check-task-state validates every
task in the file at once, so there is one run, not one per task. It transitively
runs check-evidence-bundle and check-contract for each Done task, which is why
its output names them." \
'sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/epic-195-a7-compatibility/tasks.md reports/quality-gate reports/implementation .'
  exit $?
fi

overall=0

run_log acceptance.log \
"T-004 acceptance suite, both runtimes, run by the gate host rather than read
from the implementer's green-sh.log / green-ps1.log. Evidence for both the
unit-tests and the acceptance-tests contract checks: the structural-compatibility
twins ARE the acceptance surface REQ-002's AC-005/006/007/030/042/043 name, and
this repository has no separate unit layer beneath them." \
'
      bash tests/structural-compatibility.tests.sh
      sh_rc=$?
      echo
      echo "$ pwsh -NoProfile -File tests/structural-compatibility.tests.ps1"
      pwsh -NoProfile -File tests/structural-compatibility.tests.ps1
      ps_rc=$?
      echo
      echo "bash exit=$sh_rc pwsh exit=$ps_rc"
      [ "$sh_rc" -eq 0 ] && [ "$ps_rc" -eq 0 ]
' || overall=1

run_log critical-closure.log \
"Cycle 1 Critical, re-tested by the gate host using cycle 1's own disproof
method. The canonicalizer is made to FAIL to parse coherently -- the F1 corpus
requirements.md artifact AND its shipped requirements.template.md are both set
to unparseable seven-hash heading grammar -- so a twin that discards the
canonicalizer exit status compares \"\" against \"\" and reports PASS.

Three runs, all against scratch copies of the product surface under a temp root,
never the live tree:
  A. the delivered Bash twin      -- expected non-zero (it was always correct)
  B. the delivered PowerShell twin -- expected non-zero (this is the fix)
  C. the PRE-FIX PowerShell twin, under the IDENTICAL condition -- expected
     ZERO, i.e. cycle 1's false GREEN reproduced, which is what proves run B is
     testing the defect and not a vacuous condition.
A non-zero C would mean this experiment never exercised the Critical at all.

The pre-fix revision is resolved from the twin's own path history rather than
written as a relative ref. An earlier version of this script used HEAD~1, which
was correct only while HEAD was the remediation commit itself; once any further
commit landed, HEAD~1 became the FIXED twin and the control would have silently
agreed with run B instead of contradicting it. The seq0675 evaluator caught that
off-by-one independently. The lookup below takes the second-newest commit that
touched the twin, and the script aborts if that resolves to the same bytes as
the delivered twin -- a control that is byte-identical to the subject proves
nothing and must fail loudly rather than pass quietly." \
'
      set -u
      work=$(mktemp -d "${TMPDIR:-/tmp}/qg-t004-critical.XXXXXX")
      copy_surface() {
        d="$1"
        mkdir -p "$d/tests/lib" "$d/tests/fixtures" \
          "$d/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer" \
          "$d/plugins/sdd-lite/skills/lite-spec" \
          "$d/specs/epic-195-a7-compatibility"
        for r in tests/run-all.sh tests/run-all.ps1 \
                 tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 \
                 tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1 \
                 plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md \
                 plugins/sdd-lite/skills/lite-spec/SKILL.md \
                 specs/epic-195-a7-compatibility/design.md \
                 specs/epic-195-a7-compatibility/acceptance-tests.md \
                 specs/epic-195-a7-compatibility/tasks.md; do
          mkdir -p "$d/$(dirname "$r")"; cp "$r" "$d/$r"
        done
        cp -R tests/fixtures/structural-fixture-corpus "$d/tests/fixtures/"
        cp -R plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates \
          "$d/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/"
        cp -R plugins/sdd-lite/templates "$d/plugins/sdd-lite/"
      }
      make_unparseable() {
        d="$1"; c="$d/tests/fixtures/structural-fixture-corpus"
        jq "(.artifacts[] | select(.path == \"requirements.md\").content) = \"####### Broken\n\"" \
          "$c/f1-full.json" > "$c/f1-full.next" && mv "$c/f1-full.next" "$c/f1-full.json"
        printf "%s\n" "####### Broken" \
          > "$d/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/requirements.template.md"
      }
      twin=tests/structural-compatibility.tests.ps1
      prefix_rev=$(git log --format=%H -- "$twin" | sed -n 2p)
      if [ -z "$prefix_rev" ]; then
        echo "CONTROL ERROR: cannot resolve a pre-fix revision of $twin"; exit 2
      fi
      echo "pre-fix revision under test: $prefix_rev^{commit} (second-newest commit touching $twin)"
      if [ "$(git show "$prefix_rev:$twin" | shasum -a 256 | cut -d" " -f1)" = \
           "$(shasum -a 256 "$twin" | cut -d" " -f1)" ]; then
        echo "CONTROL ERROR: pre-fix twin is byte-identical to the delivered twin"; exit 2
      fi

      A="$work/post-fix"; mkdir -p "$A"; copy_surface "$A"; make_unparseable "$A"
      B="$work/pre-fix";  mkdir -p "$B"; copy_surface "$B"
      git show "$prefix_rev:$twin" > "$B/$twin"
      make_unparseable "$B"

      echo "--- A: delivered Bash twin, canonicalizer forced to fail to parse ---"
      STRUCTURAL_COMPAT_REPO_ROOT="$A" bash "$A/tests/structural-compatibility.tests.sh" 2>&1 | tail -4
      a_rc=${PIPESTATUS:-0}
      STRUCTURAL_COMPAT_REPO_ROOT="$A" bash "$A/tests/structural-compatibility.tests.sh" >/dev/null 2>&1
      a_rc=$?
      echo "A exit=$a_rc (expected non-zero)"

      echo
      echo "--- B: delivered PowerShell twin, identical condition ---"
      STRUCTURAL_COMPAT_REPO_ROOT="$A" pwsh -NoProfile -File "$A/tests/structural-compatibility.tests.ps1" 2>&1 \
        | grep -E "canonicalizes without parse fallback|passed, .* failed" | tail -3
      STRUCTURAL_COMPAT_REPO_ROOT="$A" pwsh -NoProfile -File "$A/tests/structural-compatibility.tests.ps1" >/dev/null 2>&1
      b_rc=$?
      echo "B exit=$b_rc (expected non-zero)"

      echo
      echo "--- C: PRE-FIX PowerShell twin from HEAD~1, identical condition ---"
      STRUCTURAL_COMPAT_REPO_ROOT="$B" pwsh -NoProfile -File "$B/tests/structural-compatibility.tests.ps1" 2>&1 \
        | grep -E "canonicalizes without parse fallback|passed, .* failed" | tail -3
      STRUCTURAL_COMPAT_REPO_ROOT="$B" pwsh -NoProfile -File "$B/tests/structural-compatibility.tests.ps1" >/dev/null 2>&1
      c_rc=$?
      echo "C exit=$c_rc (expected ZERO: cycle 1 false GREEN reproduced)"

      rm -rf "$work"
      echo
      if [ "$a_rc" -ne 0 ] && [ "$b_rc" -ne 0 ] && [ "$c_rc" -eq 0 ]; then
        echo "CRITICAL-CLOSED: pre-fix twin false-GREENs, delivered twins both hard-fail"
        true
      else
        echo "CRITICAL-NOT-CLOSED: unexpected exit codes"
        false
      fi
' || overall=1

run_log product-free-root.log \
"The epic's standing check: the suite must FAIL from a product-free root, so a
green run can never be produced without the shipped product surfaces. Recorded in
both of the forms cycle 1 distinguished -- 0/4 with the suite's own test assets
present but plugins/ and specs/ absent, and 0/9 from a wholly empty root." \
'
      set -u
      empty=$(mktemp -d "${TMPDIR:-/tmp}/qg-t004-empty.XXXXXX")
      assets=$(mktemp -d "${TMPDIR:-/tmp}/qg-t004-assets.XXXXXX")
      mkdir -p "$assets/tests/lib" "$assets/tests/fixtures"
      cp tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 "$assets/tests/"
      cp tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1 "$assets/tests/lib/"
      cp -R tests/fixtures/structural-fixture-corpus "$assets/tests/fixtures/"
      rc=0
      for root_dir in "$assets" "$empty"; do
        label=$([ "$root_dir" = "$assets" ] && echo "suite assets present, no product" || echo "wholly empty root")
        echo "--- $label ---"
        STRUCTURAL_COMPAT_REPO_ROOT="$root_dir" bash tests/structural-compatibility.tests.sh 2>&1 | tail -1
        STRUCTURAL_COMPAT_REPO_ROOT="$root_dir" bash tests/structural-compatibility.tests.sh >/dev/null 2>&1
        s=$?; echo "bash exit=$s"
        STRUCTURAL_COMPAT_REPO_ROOT="$root_dir" pwsh -NoProfile -File tests/structural-compatibility.tests.ps1 2>&1 | tail -1
        STRUCTURAL_COMPAT_REPO_ROOT="$root_dir" pwsh -NoProfile -File tests/structural-compatibility.tests.ps1 >/dev/null 2>&1
        p=$?; echo "pwsh exit=$p"
        echo
        [ "$s" -ne 0 ] && [ "$p" -ne 0 ] || rc=1
      done
      rm -rf "$empty" "$assets"
      [ "$rc" -eq 0 ] && echo "PRODUCT-FREE-ROOT: both twins fail in both forms"
      exit $rc
' || overall=1

run_log mutation-rerun.log \
"Cycle 1 Major #2: the recorded mutation count did not reproduce (101/13 against
a claimed 114/0). This is the gate host's own fresh run of the remediated
harness, pinned at COLUMNS=80 -- the width at which cycle 1's PowerShell
ConciseView wrapping produced the 13 false survivors -- followed by a
byte-comparison against the persisted log. Only the summary and the comparison
are kept here; the full transcript is the persisted mutation-proof.log itself." \
'
      set -u
      work=$(mktemp -d "${TMPDIR:-/tmp}/qg-t004-mut.XXXXXX")
      fresh="$work/fresh.log"
      persisted="$work/persisted.log"
      COLUMNS=80 bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh > "$fresh" 2>&1
      rc=$?
      echo "fresh run exit status: $rc"
      grep -E "^(CLASSIFIER-SELFTEST|MUTATION SUMMARY|MUTATION-SURVIVED)" "$fresh"
      echo
      grep -v "^EXIT_CODE=" specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.log > "$persisted"
      echo "$ diff persisted-without-EXIT_CODE-line fresh-run"
      if diff "$persisted" "$fresh" > "$work/delta" 2>&1; then
        echo "IDENTICAL: the fresh run reproduces the persisted mutation-proof.log byte-for-byte"
        echo "           (modulo the recorder-appended EXIT_CODE= line)"
      else
        echo "DIFFERS:"
        head -20 "$work/delta"
        rc=1
      fi
      rm -rf "$work"
      exit $rc
' || overall=1

run_log classifier-proof.log \
"The width- and ANSI-independence of the mutation classifier, re-run by the gate
host. Each of the two normalization operations is mutated independently and must
fail its own self-test; the restored classifier must pass." \
'bash specs/epic-195-a7-compatibility/verification/T-004/classifier-proof.sh' || overall=1

run_log malformed-red-audit.log \
"Cycle 1 Major #3: the delivered RED was a preflight missing-asset RED, not the
malformed-corpus RED tasks.md:683 requires. This audits the replacement capture
rather than trusting it -- it must contain the coherent malformed case running
through the real assertion path, exactly one PowerShell survivor, a 115/1
summary and a non-zero harness exit, and its survivor must be the same case the
current harness now kills in both runtimes. A hand-edited log would not satisfy
all four simultaneously with the current harness output format." \
'
      set -u
      red=specs/epic-195-a7-compatibility/verification/T-004/malformed-corpus-red.log
      cur=specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.log
      echo "--- survivor lines in the RED capture ---"
      grep -n "^MUTATION-SURVIVED" "$red"
      echo "--- summary and exit in the RED capture ---"
      grep -nE "^(MUTATION SUMMARY|EXIT_CODE)" "$red"
      echo "--- the same case in the current, post-fix log ---"
      grep -n "corpus-and-template-bad-heading" "$cur"
      echo
      n_surv=$(grep -c "^MUTATION-SURVIVED" "$red")
      ps_surv=$(grep -c "^MUTATION-SURVIVED: corpus-and-template-bad-heading \[ps1\] exit=0" "$red")
      summary=$(grep -c "^MUTATION SUMMARY: 115 killed, 1 survived" "$red")
      exitline=$(grep -c "^EXIT_CODE=1" "$red")
      kills=$(grep -c "^MUTATION-KILLED: corpus-and-template-bad-heading" "$cur")
      red_sh_kill=$(grep -c "^MUTATION-KILLED: corpus-and-template-bad-heading \[sh\]" "$red")
      echo "survivors=$n_surv (expect 1)"
      echo "survivor is the pwsh coherent-malformed case at exit=0: $ps_surv (expect 1)"
      echo "bash killed the same case in the RED capture: $red_sh_kill (expect 1)"
      echo "115/1 summary present: $summary (expect 1); EXIT_CODE=1 present: $exitline (expect 1)"
      echo "post-fix kills of that case in both runtimes: $kills (expect 2)"
      [ "$n_surv" -eq 1 ] && [ "$ps_surv" -eq 1 ] && [ "$red_sh_kill" -eq 1 ] \
        && [ "$summary" -eq 1 ] && [ "$exitline" -eq 1 ] && [ "$kills" -eq 2 ] \
        && echo "MALFORMED-RED: genuine pre-fix capture of the required malformed-corpus case"
' || overall=1

run_log regression.log \
"Targeted regression rather than tests/run-all.sh, because run-all is
structurally red in this repository until a human applies the staged human-copy
CI patch (the deterministic-lane self-check fails closed by design), so a full
run-all log would record a designed red and prove nothing about this task. The
precedent is this feature's own verification/T-001/regression-targeted.log and
verification/qg-backfill/regression.log.

The suite list is T-004's own shipped suite plus its blast-radius neighbours:
the three sibling suites sharing the run-all registration block T-004 edits, the
cross-epic shared loop driver, and gates.tests.sh, which owns the
risk-gate-matrix tier-minimum invariant this gate's own contract is validated
against." \
'
      rc=0
      for s in tests/structural-compatibility.tests.sh \
               tests/golden-baseline-contract.tests.sh \
               tests/compatibility-byte-identical.tests.sh \
               tests/install.tests.sh \
               tests/uninstall.tests.sh \
               tests/loop-driver.tests.sh \
               tests/gates.tests.sh; do
        echo "=========================================================="
        echo "[RUN] $s"
        echo "=========================================================="
        bash "$s" || rc=1
        echo
      done
      exit $rc
' || overall=1

run_log placeholder.log \
"Scan scope is recorded here so the argument list is auditable rather than
implied. The files are exactly the agent-editable production deliverables
traceability.md's \"Deliverables (Per Task)\" table attributes to T-004, plus the
two runner twins T-004 edits. Excluded on purpose:
tests/fixtures/structural-fixture-corpus/, which is recorded product output (a
fixture), not authored code -- check-placeholders is scoped to changed
production files per references/deterministic-check-policy.md, and scanning
recorded generation bytes would flag markers this feature never wrote." \
'sh plugins/sdd-quality-loop/scripts/check-placeholders.sh tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1 tests/lib/markdown-ast-canonicalizer.sh tests/lib/markdown-ast-canonicalizer.ps1 tests/run-all.sh tests/run-all.ps1' || overall=1

run_log traceability.log \
"REQ -> AC -> TEST -> evidence chain gate. The first command proves
traceability.json is still a faithful mechanical derivation of the reviewed
traceability.md; the second is the gate itself. T-004 is high tier, so
requirement-traceability is a required contract check
(references/risk-gate-matrix.md)." \
'
      python3 specs/epic-195-a7-compatibility/verification/qg-backfill/derive-traceability-json.py --check
      derive_rc=$?
      echo
      echo "$ sh plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-195-a7-compatibility/traceability.json ."
      sh plugins/sdd-quality-loop/scripts/check-traceability.sh \
         specs/epic-195-a7-compatibility/traceability.json .
      gate_rc=$?
      [ "$derive_rc" -eq 0 ] && [ "$gate_rc" -eq 0 ]
' || overall=1

run_log risk.log \
"Task-level risk gate: a valid Risk: tier, a non-empty Risk Rationale:, and --
because T-004 is high -- Required Workflow: tdd. The run covers every task in
the file at once." \
'sh plugins/sdd-quality-loop/scripts/check-risk.sh specs/epic-195-a7-compatibility/tasks.md' || overall=1

echo
echo "overall exit status: $overall"
exit $overall
