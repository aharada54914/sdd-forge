#!/usr/bin/env bash
# criterion-freeze.tests.sh — WFI-045 guard coverage.
#
# The guard refuses a commit that rewrites frozen criterion prose in a reviewed
# tasks.md while also changing files outside specs/. Every case below builds a
# real scratch git repository and drives the guard against a real commit, so the
# test exercises commit composition rather than a string.
#
# Both runtimes are covered: the sh dispatcher (python3 path) and the PowerShell
# twin. When pwsh is absent the ps1 cases report a visible `skip -` line rather
# than vanishing, and the tally stays legible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-criterion-freeze.sh"
GUARD_PS1="$ROOT/plugins/sdd-quality-loop/scripts/check-criterion-freeze.ps1"

PASS=0
FAIL=0
ok()   { echo "ok: $*";     PASS=$((PASS+1)); }
bad()  { echo "not ok: $*"; FAIL=$((FAIL+1)); }
skip() { echo "skip - $*"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

HAVE_PWSH=0
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=1; fi

# --- fixture repository -----------------------------------------------------
# One reviewed feature (Task-Review-Status: Passed) and one unreviewed feature,
# so the "not frozen yet" branch is exercised against a real file too.
REPO="$WORK/repo"
mkdir -p "$REPO/specs/demo" "$REPO/specs/unreviewed" "$REPO/src"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.invalid
git -C "$REPO" config user.name "fixture"

write_tasks() {
  # $1 = path, $2 = Task-Review-Status value, $3 = item-5 criterion text,
  # $4 = checkbox char, $5 = Status value
  cat > "$1" <<EOF
# Tasks: demo

Task-Review-Status: $2

## T-001 Demo task

Approval: Approved
Status: $5
Risk: high

### Done When
- [$4] The gate rejects a malformed input
- [$4] $3

## T-002 Second task

Approval: Approved
Status: Planned

### Done When
- [ ] Untouched by these fixtures
EOF
}

write_tasks "$REPO/specs/demo/tasks.md" "Passed" \
  "Independent reviewer \`demo-independent-reviewer\` records PASS" " " "Planned"
write_tasks "$REPO/specs/unreviewed/tasks.md" "Pending" \
  "Independent reviewer \`demo-independent-reviewer\` records PASS" " " "Planned"
echo "initial" > "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "baseline"

run_guard_sh() { COMMIT="" bash "$GUARD_SH" "$1" "$REPO" 2>&1; }
run_guard_ps1() {
  pwsh -NoProfile -File "$GUARD_PS1" -Commit "$1" -RepoRoot "$REPO" 2>&1
}

# expect_case <label> <commit> <expected-exit> [needle]
expect_case() {
  label="$1"; commit="$2"; want="$3"; needle="${4:-}"
  out_sh="$(run_guard_sh "$commit")"; rc_sh=$?
  if [ "$rc_sh" -ne "$want" ]; then
    bad "$label (sh): expected exit $want, got $rc_sh: $out_sh"
  elif [ -n "$needle" ] && ! printf '%s' "$out_sh" | grep -Fq "$needle"; then
    bad "$label (sh): diagnostic missing '$needle': $out_sh"
  else
    ok "$label (sh)"
  fi

  if [ "$HAVE_PWSH" -eq 1 ]; then
    out_ps="$(run_guard_ps1 "$commit")"; rc_ps=$?
    if [ "$rc_ps" -ne "$want" ]; then
      bad "$label (ps1): expected exit $want, got $rc_ps: $out_ps"
    elif [ -n "$needle" ] && ! printf '%s' "$out_ps" | grep -Fq "$needle"; then
      bad "$label (ps1): diagnostic missing '$needle': $out_ps"
    elif [ "$out_sh" != "$out_ps" ]; then
      bad "$label: twin outputs diverge.
sh : $out_sh
ps1: $out_ps"
    else
      ok "$label (ps1, byte-identical to sh)"
    fi
  else
    skip "$label (ps1): pwsh not available on this host"
  fi
}

# --- CF.1 the RT-20260821-018 maneuver: code + criterion rewrite -------------
write_tasks "$REPO/specs/demo/tasks.md" "Passed" \
  "Independent reviewer \`demo-review-agent-04\` records PASS" "x" "Implementation Complete"
echo "feature work" >> "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feat: implement T-001 (and quietly reword its criterion)"
expect_case "CF.1: implementation commit rewriting its own frozen criterion is refused" \
  HEAD 1 "specs/demo/tasks.md: T-001"
git -C "$REPO" revert --no-edit HEAD >/dev/null

# --- CF.2 lifecycle-only edits alongside code are permitted ------------------
write_tasks "$REPO/specs/demo/tasks.md" "Passed" \
  "Independent reviewer \`demo-independent-reviewer\` records PASS" "x" "Implementation Complete"
echo "more work" >> "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feat: implement T-001 (ticks boxes, flips status)"
expect_case "CF.2: checkbox ticks and status flips alongside code pass" HEAD 0 \
  "keeps frozen criterion prose intact"

# --- CF.3 specs-only criterion amendment is the sanctioned route -------------
write_tasks "$REPO/specs/demo/tasks.md" "Passed" \
  "An independent reviewer with an isolated identity records PASS" "x" "Implementation Complete"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "docs(specs): amend the T-001 criterion via the frozen-document route"
expect_case "CF.3: specs-only criterion amendment passes" HEAD 0 "is specs-only"

# --- CF.4 an unreviewed tasks.md is not frozen ------------------------------
write_tasks "$REPO/specs/unreviewed/tasks.md" "Pending" \
  "A completely different criterion" "x" "Implementation Complete"
echo "unreviewed work" >> "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feat: work against an unreviewed spec"
expect_case "CF.4: criterion edits in an unreviewed tasks.md pass" HEAD 0 \
  "keeps frozen criterion prose intact"

# --- CF.5 Second Approval and Task-Review-Status are lifecycle too ----------
python3 - "$REPO/specs/demo/tasks.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("Approval: Approved\nStatus:",
                    "Approval: Approved\nSecond Approval: Approved (fixture 2026-08-23)\nStatus:", 1)
open(path, "w", encoding="utf-8").write(text)
PY
echo "even more work" >> "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feat: record a second approval alongside code"
expect_case "CF.5: adding a Second Approval alongside code passes" HEAD 0 \
  "keeps frozen criterion prose intact"

# --- CF.6 a criterion DELETION is caught, not only a rewrite ----------------
python3 - "$REPO/specs/demo/tasks.md" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = re.sub(r"^- \[[ x]\] The gate rejects a malformed input\n", "", text, count=1, flags=re.M)
open(path, "w", encoding="utf-8").write(text)
PY
echo "deleting work" >> "$REPO/src/app.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "feat: drop an inconvenient Done-When item"
expect_case "CF.6: deleting a frozen Done-When item alongside code is refused" \
  HEAD 1 "specs/demo/tasks.md: T-001"
git -C "$REPO" revert --no-edit HEAD >/dev/null

# --- CF.7 the historical regression fixture (WFI-045 Verification Metric) ---
# Replay the real forgery commit's composition in this repository.
if git -C "$ROOT" rev-parse -q --verify 'e28707f0^{commit}' >/dev/null 2>&1; then
  hist_out="$(bash "$GUARD_SH" e28707f0 "$ROOT" 2>&1)"; hist_rc=$?
  if [ "$hist_rc" -ne 1 ]; then
    bad "CF.7: historical forgery commit e28707f0 was not refused (exit $hist_rc)"
  elif ! printf '%s' "$hist_out" | grep -Fq "specs/agent-cost-context-isolation/tasks.md: T-005"; then
    bad "CF.7: historical refusal does not name T-005: $hist_out"
  else
    ok "CF.7: the historical RT-20260821-018 commit is refused, naming T-005"
  fi
else
  skip "CF.7: commit e28707f0 not present in this checkout"
fi

# --- CF.8 fail-closed on a bad ref ------------------------------------------
expect_case "CF.8: an unknown ref is a runtime error, not a silent pass" \
  "not-a-real-ref" 2 "not a commit"

printf '\nResults: %s passed, %s failed.\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
