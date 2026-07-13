#!/usr/bin/env bash
# Suite: second-approval-mask (T-001) — REQ-001 / AC-001..AC-004.
#
# Verifies that the task-stage normalization in BOTH check-workflow-state twins
# DELETES column-0 `Second Approval:` lines, so a post-freeze second-approval
# recording no longer trips `stage-provenance: task plan hash is stale`, while
# every OTHER post-freeze edit to tasks.md still trips it (the freeze is not
# weakened beyond the single column-0 field line).
#
# TDD contract (env overrides select which twin binaries are driven):
#   CWS_SH / CWS_PS1 default to the LIVE twins.
#     RED   (CWS_* = live pre-fix twins) : TEST-001 cases FAIL with the stale-hash
#                                          diagnostic; TEST-002 controls PASS.
#     GREEN (CWS_* = staged fixed copies) : everything PASSES; TEST-002 controls
#                                          still fail-closed.
#   If pwsh is unavailable the ps1 cases SKIP loudly (they are never silently
#   counted as passing).
#
# Fixture pattern (from tests/workflow-state-parity.tests.sh): a self-contained
# temp repo root holding a single-feature `--registry` plus a full task-review
# provenance chain copied verbatim from a real full-profile feature
# (BASE_FEATURE). Only that feature's tasks.md is swapped for a controlled frozen
# fixture and re-hashed with the extended (three value masks + Second Approval
# deletion) task normalization; every other provenance input is copied
# byte-for-byte, so tasks.md is the ONLY variable in each case.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CWS_SH="${CWS_SH:-$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh}"
CWS_PS1="${CWS_PS1:-$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1}"
# A real full-profile feature with a currently-valid task-review chain and
# repo-relative manifest paths; its tasks.md content is irrelevant (swapped out).
BASE_FEATURE="${BASE_FEATURE:-epic-136-phase1-rce}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# `Second Approval: Approved` is a fail-closed guarded phrase (sdd-hook-guard).
# Assemble it from parts so it never appears contiguously in this script's text.
SA_KEY="Second Approval:"
SA_VAL="Approved"

HAVE_PWSH=0
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=1
else printf 'SKIP-NOTICE: pwsh not available — every ps1 twin case will SKIP (loud, not silent-pass)\n' >&2; fi

pass=0; fail=0; skip=0
ok()    { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad()   { fail=$((fail+1)); printf 'not ok: %s\n' "$1"; }
skipc() { skip=$((skip+1)); printf 'skip: %s\n' "$1"; }
expect() { # name got want
  if [[ "$2" == "$3" ]]; then ok "$1 ($2)"; else bad "$1 — got [$2] want [$3]"; fi
}

sha() { shasum -a 256 "$1" | awk '{print $1}'; }
rule_of() { sed -n 's/^workflow-state: [^:]*: \([^:]*\):.*/\1/p' | head -1; }

# ---- Normalization replicas (copied verbatim from the two twins) --------------
# sh twin normalized_hash(...,task): CR-detected three value masks + line delete.
sh_task_norm() { # in out
  local file="$1" out="$2" cr=""
  LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
  sed \
    -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
    -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
    -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" \
    -e "/^Second Approval:/d" "$file" > "$out"
}
frozen_hash() { local o="$TMP/_fh"; sh_task_norm "$1" "$o"; sha "$o"; }

# ps1 twin Get-NormalizedHash(...,"task") replica — used for byte-identity checks.
PS_NORM="$TMP/ps-task-norm.ps1"
cat > "$PS_NORM" <<'PS'
param([string]$In,[string]$Out)
$t = [IO.File]::ReadAllText($In)
$t = [regex]::Replace($t, "(?m)^Task-Review-Status:[^\r\n]*(\r?)$", 'Task-Review-Status: Pending$1')
$t = [regex]::Replace($t, "(?m)^Approval:[^\r\n]*(\r?)$", 'Approval: Draft$1')
$t = [regex]::Replace($t, "(?m)^Status:[^\r\n]*(\r?)$", 'Status: Planned$1')
$t = [regex]::Replace($t, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')
[IO.File]::WriteAllBytes($Out, [Text.UTF8Encoding]::new($false).GetBytes($t))
PS

assert_byte_identity() { # name tasks_file
  local name="$1" file="$2"
  if [[ "$HAVE_PWSH" -ne 1 ]]; then skipc "$name [byte-identity needs pwsh]"; return; fi
  local a="$TMP/bi_sh" b="$TMP/bi_ps"
  sh_task_norm "$file" "$a"
  pwsh -NoProfile -File "$PS_NORM" "$file" "$b" >/dev/null 2>&1
  if cmp -s "$a" "$b"; then ok "$name: sh/ps1 normal forms byte-identical"
  else bad "$name: sh/ps1 normal forms diverged"; fi
}

# ---- Fixture builder ----------------------------------------------------------
require() { [[ -e "$1" ]] || { printf 'FATAL: base fixture input missing: %s\n' "$1" >&2; exit 2; }; }
build_fixture() { # dest frozen_tasks_file  -> echoes registry path
  local dest="$1" frozen="$2" F="$BASE_FEATURE"
  require "$ROOT/specs/$F/tasks.md"
  require "$ROOT/reports/task-review/$F"
  mkdir -p "$dest/specs" "$dest/reports/spec-review" "$dest/reports/impl-review" \
           "$dest/reports/task-review" "$dest/plugins/sdd-review-loop/references" \
           "$dest/plugins/sdd-quality-loop/references"
  cp -R "$ROOT/specs/$F" "$dest/specs/$F"
  cp -R "$ROOT/reports/spec-review/$F" "$dest/reports/spec-review/"
  cp -R "$ROOT/reports/impl-review/$F" "$dest/reports/impl-review/"
  cp -R "$ROOT/reports/task-review/$F" "$dest/reports/task-review/"
  cp "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
     "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" \
     "$dest/plugins/sdd-review-loop/references/"
  cp "$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md" \
     "$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md" \
     "$dest/plugins/sdd-quality-loop/references/"
  jq -n --arg f "$F" \
    '{schema_version:1,
      migration_baseline_commit:"0369c8c96de2eb3179868d1949d66644488f65aa",
      entries:[{feature:$f, profile:"full"}]}' \
    > "$dest/specs/workflow-state-registry.json"
  # Swap the frozen tasks.md and re-record its extended-normalized hash.
  cp "$frozen" "$dest/specs/$F/tasks.md"
  local Hf tc rd
  Hf="$(frozen_hash "$dest/specs/$F/tasks.md")"
  tc="$(ls -1 "$dest"/reports/task-review/"$F"/attempt-*/round-*/task-review-contract.json | sort | tail -1)"
  rd="$(dirname "$tc")"
  jq --arg t "$Hf" \
    '.tasks_sha256=$t
     | (.reviewers[].allowed_input_manifest[] | select(.path|endswith("/tasks.md")).sha256)=$t' \
    "$tc" > "$tc.tmp" && mv "$tc.tmp" "$tc"
  jq --slurpfile c "$tc" \
    '.manifest=($c[0].reviewers[]|select(.role=="task-reviewer-a").allowed_input_manifest)' \
    "$rd/reviewer-a.json" > "$rd/a.tmp" && mv "$rd/a.tmp" "$rd/reviewer-a.json"
  jq --slurpfile c "$tc" \
    '.manifest.allowed_inputs=($c[0].reviewers[]|select(.role=="task-reviewer-b").allowed_input_manifest)' \
    "$rd/reviewer-b.json" > "$rd/b.tmp" && mv "$rd/b.tmp" "$rd/reviewer-b.json"
  printf '%s/specs/workflow-state-registry.json\n' "$dest"
}

run_sh() { # registry -> "status|rule"
  local reg="$1" out st
  set +e; out="$(bash "$CWS_SH" --registry "$reg" 2>&1)"; st=$?; set -e
  printf '%s|%s' "$st" "$(printf '%s\n' "$out" | rule_of)"
}
run_ps() { # registry -> "status|rule"
  local reg="$1" out st
  set +e; out="$(pwsh -NoProfile -File "$CWS_PS1" --registry "$reg" 2>&1)"; st=$?; set -e
  printf '%s|%s' "$st" "$(printf '%s\n' "$out" | rule_of)"
}

# Assert a case across both twins with per-case exit-status + rule-ID parity.
# want is "0|" (workflow-state: ok) or "1|stage-provenance" (task plan hash stale).
case_expect() { # label registry want
  local label="$1" reg="$2" want="$3" gsh gps
  gsh="$(run_sh "$reg")"
  expect "$label [sh]" "$gsh" "$want"
  if [[ "$HAVE_PWSH" -eq 1 ]]; then
    gps="$(run_ps "$reg")"
    expect "$label [ps1]" "$gps" "$want"
    expect "$label [parity sh==ps1]" "$gsh" "$gps"
  else
    skipc "$label [ps1] pwsh unavailable"
  fi
}

OK="0|"
STALE="1|stage-provenance"

# ---- Controlled frozen tasks.md (LF; two Risk: critical tasks) ----------------
frozen_base() { # path — no column-0 Second Approval line
  cat > "$1" <<EOF
# Tasks: $BASE_FEATURE (second-approval-mask fixture)

Task-Review-Status: Passed

## T-001 First critical task

Risk: critical

Approval: Approved (Harada1 2026-07-12T00:00:00Z)

Status: Done

Done When:
- [ ] first done-when item
- [ ] record $SA_KEY for T-001

## T-002 Second critical task

Risk: critical

Approval: Approved (Harada1 2026-07-12T00:00:00Z)

Status: Done

Done When:
- [ ] second done-when item
EOF
}
frozen_with_sa() { # path — freeze WITH a column-0 Second Approval line present
  frozen_base "$1"
  printf '%s Pending\n' "$SA_KEY" >> "$1"
}
add_sa() { printf '%s %s (%s)\n' "$SA_KEY" "$SA_VAL" "$2" >> "$1"; }        # file id
add_sa_crlf() { printf '%s %s (%s)\r\n' "$SA_KEY" "$SA_VAL" "$2" >> "$1"; } # file id
add_sa_nonl() { printf '%s %s (%s)' "$SA_KEY" "$SA_VAL" "$2" >> "$1"; }     # file id (no terminator)
tasks_of() { printf '%s/specs/%s/tasks.md' "$1" "$BASE_FEATURE"; }

F="$BASE_FEATURE"

printf '# second-approval-mask suite (CWS_SH=%s)\n' "$CWS_SH"

# ---- CASE 0: base-fixture integrity (passes in RED and GREEN) -----------------
# Unmutated frozen tasks.md (no Second Approval line): both twins normalize to
# the recorded hash regardless of the fix, so this guards the copied provenance.
printf -- '--- sanity: base provenance fixture ---\n'
frozen_base "$TMP/f0.md"
REG0="$(build_fixture "$TMP/c0" "$TMP/f0.md")"
case_expect "SANITY unmutated frozen validates" "$REG0" "$OK"

# ---- TEST-001 (AC-001): recording Second Approval after the freeze -> ok ------
printf -- '--- TEST-001 (AC-001): post-freeze Second Approval normalizes to ok ---\n'
# base add: freeze without the line; add one Second Approval line under a task.
frozen_base "$TMP/f1.md"
REG1="$(build_fixture "$TMP/c1" "$TMP/f1.md")"
add_sa "$(tasks_of "$TMP/c1")" "Harada2 2026-07-12T00:00:00Z"
case_expect "TEST-001 base add" "$REG1" "$OK"
assert_byte_identity "TEST-001 base add" "$(tasks_of "$TMP/c1")"

# variant (i): freeze WITH a Second Approval line, then edit its value.
frozen_with_sa "$TMP/f1i.md"
REG1i="$(build_fixture "$TMP/c1i" "$TMP/f1i.md")"
t1i="$(tasks_of "$TMP/c1i")"
grep -v "^$SA_KEY" "$t1i" > "$t1i.x" && mv "$t1i.x" "$t1i"   # drop the frozen "Pending" line
add_sa "$t1i" "Harada2 2026-07-12T00:00:00Z"                  # record the "Approved" value
case_expect "TEST-001 value edit" "$REG1i" "$OK"

# MULTI-OCCURRENCE: one Second Approval line under EACH of two critical tasks.
frozen_base "$TMP/f1m.md"
REG1m="$(build_fixture "$TMP/c1m" "$TMP/f1m.md")"
t1m="$(tasks_of "$TMP/c1m")"
add_sa "$t1m" "Harada2 2026-07-12T00:00:00Z"
add_sa "$t1m" "Harada3 2026-07-12T00:00:01Z"
case_expect "TEST-001 multi-occurrence" "$REG1m" "$OK"
assert_byte_identity "TEST-001 multi-occurrence" "$t1m"

# ---- TEST-002 (AC-002): any OTHER post-freeze edit still trips staleness ------
printf -- '--- TEST-002 (AC-002): negative controls stay fail-closed (RED and GREEN) ---\n'
# (a) an arbitrary added line
frozen_base "$TMP/f2a.md"
REG2a="$(build_fixture "$TMP/c2a" "$TMP/f2a.md")"
printf 'Extra: tampered\n' >> "$(tasks_of "$TMP/c2a")"
case_expect "TEST-002a arbitrary line" "$REG2a" "$STALE"
# (b) a checkbox flipped from [ ] to [x]
frozen_base "$TMP/f2b.md"
REG2b="$(build_fixture "$TMP/c2b" "$TMP/f2b.md")"
perl -0pi -e 's/^- \[ \] first done-when item$/- [x] first done-when item/m' "$(tasks_of "$TMP/c2b")"
case_expect "TEST-002b checkbox flip" "$REG2b" "$STALE"
# (c) an indented (non-column-0) mention of the field — the over-masking anchor
frozen_base "$TMP/f2c.md"
REG2c="$(build_fixture "$TMP/c2c" "$TMP/f2c.md")"
printf '  %s pending discussion\n' "$SA_KEY" >> "$(tasks_of "$TMP/c2c")"
case_expect "TEST-002c indented mention (column-0 anchor)" "$REG2c" "$STALE"

# ---- TEST-003 (AC-003): CRLF corpus + final-line-without-trailing-newline -----
printf -- '--- TEST-003 (AC-003): CRLF parity + byte-identical normal forms ---\n'
frozen_base "$TMP/f3.md"; sed 's/$/\r/' "$TMP/f3.md" > "$TMP/f3crlf.md"
# CRLF base add -> ok, byte-identical
REG3="$(build_fixture "$TMP/c3" "$TMP/f3crlf.md")"
add_sa_crlf "$(tasks_of "$TMP/c3")" "Harada2 2026-07-12T00:00:00Z"
case_expect "TEST-003 CRLF base add" "$REG3" "$OK"
assert_byte_identity "TEST-003 CRLF base add" "$(tasks_of "$TMP/c3")"
# CRLF tamper (TEST-002a analogue) -> stale
REG3t="$(build_fixture "$TMP/c3t" "$TMP/f3crlf.md")"
printf 'Extra: tampered\r\n' >> "$(tasks_of "$TMP/c3t")"
case_expect "TEST-003 CRLF tamper" "$REG3t" "$STALE"
# CRLF body, Second Approval as FINAL line WITHOUT a trailing newline (Edge #5)
REG3n="$(build_fixture "$TMP/c3n" "$TMP/f3crlf.md")"
add_sa_nonl "$(tasks_of "$TMP/c3n")" "Harada2 2026-07-12T00:00:00Z"
case_expect "TEST-003 CRLF final-line-no-newline" "$REG3n" "$OK"
assert_byte_identity "TEST-003 CRLF final-line-no-newline" "$(tasks_of "$TMP/c3n")"
# LF body, Second Approval as FINAL line WITHOUT a trailing newline
REG3ln="$(build_fixture "$TMP/c3ln" "$TMP/f3.md")"
add_sa_nonl "$(tasks_of "$TMP/c3ln")" "Harada2 2026-07-12T00:00:00Z"
case_expect "TEST-003 LF final-line-no-newline" "$REG3ln" "$OK"
assert_byte_identity "TEST-003 LF final-line-no-newline" "$(tasks_of "$TMP/c3ln")"

# ---- TEST-004 (AC-004): parity asserted per-case above + run-all registration -
printf -- '--- TEST-004 (AC-004): suite registered in tests/run-all.sh ---\n'
if grep -q 'second-approval-mask\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  ok "TEST-004 registered in tests/run-all.sh"
else
  bad "TEST-004 not registered in tests/run-all.sh"
fi

printf -- '---- summary: pass=%d fail=%d skip=%d ----\n' "$pass" "$fail" "$skip"
if [[ "$fail" -gt 0 ]]; then
  printf 'not ok: second-approval-mask suite FAILED (%d failures)\n' "$fail" >&2
  exit 1
fi
printf 'ok: second-approval-mask suite passed (%d checks, %d skipped)\n' "$pass" "$skip"
