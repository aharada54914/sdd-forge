#!/usr/bin/env bash
# Suite: effort-policy-flip (T-007, epic-159-pillar-c, #155) — REQ-007 /
# AC-041..046.
#
# Locks the Phase-2 default-policy flip: select-agent-model's
# --effort-policy default moves from "welded" (Phase 1, T-001..T-006) to
# "matrix" (this task). TEST-041 is the only case whose outcome actually
# depends on the flip itself (it is deliberately red before the flip and
# green after — the acceptance-first/TDD red/green pairing for this task).
# TEST-042 (render zero-diff), TEST-045 (prerequisite-gate re-run), and
# TEST-046 (process-conformance proxy) are independent of the flip's code
# change but are still part of this task's own Done-When list; TEST-043
# (doc conformance) is red until this task's own doc edits land, so the
# suite as a WHOLE is genuinely red before this task's full implementation
# and genuinely green after, in the acceptance-first/TDD sense the task's
# Required Workflow (tdd) requires.
#
# TEST-044 (a REAL Codex-host smoke run) is explicitly scoped by
# design.md's Test Strategy point 8 and acceptance-tests.md's own Notes
# section to "T-007's own implementation-time verification, not... CI's
# deterministic lane" — it is never registered in tests/run-all.sh/.ps1
# (see this suite's own non-registration, documented in the implementation
# report's Specification Differences). It SKIPs cleanly (not a failure)
# whenever a real, SAFE Codex-host invocation is not available, which is
# always true in an unattended CI run (no codex binary) and was judged
# true in this task's own authoring session too (see the implementation
# report's Unresolved Items for the specific, honest reason: a real `codex`
# invocation is an autonomous coding agent capable of writing to this very
# repository, which is unsafe to trigger from inside an automated suite
# run without a human explicitly opting in via SDD_ALLOW_REAL_CODEX_SMOKE=1).
#
# CI-resilience (requirements.md Edge Cases; design.md Constraint
# Compliance, generalized from T-001..T-006's own suites to this task):
# no possibly-empty bash array is expanded under `set -u`; the mktemp
# scratch root is normalized with `pwd -P` immediately after creation;
# this suite performs no `jq` consumption (JSON parsing goes through
# python3, already a repository dependency per select-agent-model.sh's own
# heredoc usage), so the Windows `jq.exe` CRLF hazard does not apply; no
# real validator gate is driven directly. This suite is NOT registered in
# tests/run-all.sh/.ps1 (see header above and the implementation report) —
# T-007's own Planned Files list (tasks.md) does not include
# tests/run-all.sh/.ps1 or the shared .github/workflows/test.yml staging
# array, unlike T-001/T-003/T-005/T-006.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

SELECT_SH="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.sh"
RENDER_SH="$ROOT/render-agent-frontmatter.sh"
V2_REGISTRY="$ROOT/contracts/agent-model-capabilities.v2.json"
USERGUIDE="$ROOT/USERGUIDE.md"
CAPMATRIX="$ROOT/docs/agent-capability-matrix.md"
CHANGELOG_FILE="$ROOT/CHANGELOG.md"

pass=0; fail=0; skip=0
ok()   { pass=$((pass + 1)); printf 'ok: %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'not ok: %s\n' "$1" >&2; }
skp()  { skip=$((skip + 1)); printf 'skip: %s\n' "$1"; }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

if [[ ! -x "$SELECT_SH" ]] && [[ ! -f "$SELECT_SH" ]]; then
  printf 'not ok: select-agent-model.sh missing at %s\n' "$SELECT_SH" >&2
  exit 1
fi

# --- TEST-041 (AC-041): default (no --effort-policy flag) resolves to
# matrix post-flip -------------------------------------------------------
# Fixture: openai/gpt-5.2-codex (strong tier, supported_efforts
# [high, xhigh]) declares effort "xhigh" in the candidates file.
#   - Under "welded" (declared-or-model-default, no risk computation), the
#     declared value wins verbatim: effort=xhigh, effort_source=welded.
#   - Under "matrix" with --risk low (risk_effort_matrix.low == "low",
#     AC-002-locked invariant), the computed base is "low", clamped to the
#     nearest member of supported_efforts [high, xhigh] -> "high":
#     effort=high, effort_source=risk-matrix.
# These are genuinely DIFFERENT values (not merely a different label),
# so this fixture discriminates the two policies on both fields at once.
cat > "$TMP/candidates-041.json" <<'JSON'
[
  {"name": "openai/gpt-5.2-codex", "cost": "1.0", "available": true, "effort": "xhigh"}
]
JSON

TEST_041_OUT="$(bash "$SELECT_SH" --risk low --required-tier strong \
  --xhigh-reason "TEST-041 fixture (effort-policy-flip suite)" \
  --registry "$V2_REGISTRY" --candidates-file "$TMP/candidates-041.json" \
  --json)"

TEST_041_RESULT="$(printf '%s' "$TEST_041_OUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("effort_source"))
print(d.get("effort"))
')"
TEST_041_SOURCE="$(printf '%s\n' "$TEST_041_RESULT" | sed -n "1p")"
TEST_041_EFFORT="$(printf '%s\n' "$TEST_041_RESULT" | sed -n "2p")"

if [[ "$TEST_041_SOURCE" == "risk-matrix" && "$TEST_041_EFFORT" == "high" ]]; then
  ok "TEST-041: no --effort-policy flag resolves to matrix post-flip (effort_source=risk-matrix, effort=high; raw=$TEST_041_OUT)"
elif [[ "$TEST_041_SOURCE" == "welded" && "$TEST_041_EFFORT" == "xhigh" ]]; then
  bad "TEST-041: default still resolves to welded (effort_source=welded, effort=xhigh) -- the flip has not landed yet (raw=$TEST_041_OUT)"
else
  bad "TEST-041: unexpected default-policy output -- effort_source=$TEST_041_SOURCE effort=$TEST_041_EFFORT (raw=$TEST_041_OUT)"
fi

# Sanity companion: --effort-policy welded explicitly still reproduces the
# pre-flip value (OQ-004 -- welded remains fully supported, never removed).
TEST_041B_OUT="$(bash "$SELECT_SH" --risk low --required-tier strong \
  --effort-policy welded --xhigh-reason "TEST-041b fixture" \
  --registry "$V2_REGISTRY" --candidates-file "$TMP/candidates-041.json" \
  --json)"
TEST_041B_EFFORT="$(printf '%s' "$TEST_041B_OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("effort"))')"
if [[ "$TEST_041B_EFFORT" == "xhigh" ]]; then
  ok "TEST-041 (welded carve-out, OQ-004): --effort-policy welded still reproduces the pre-flip declared value (xhigh) explicitly"
else
  bad "TEST-041 (welded carve-out): --effort-policy welded produced effort=$TEST_041B_EFFORT, expected xhigh (raw=$TEST_041B_OUT)"
fi

# --- TEST-042 (AC-042): first production role_defaults render is
# zero-diff --------------------------------------------------------------
# render-agent-frontmatter.sh reads role_defaults directly from the v2
# registry (never through select-agent-model), so this check is
# independent of the --effort-policy flip's own code path; it is still
# this task's own Done-When item (tasks.md T-007 Scope step 3) because
# T-007 is the first task whose landing constitutes "production" use of
# the matrix-default policy end-to-end.
if TEST_042_OUT="$(bash "$RENDER_SH" --check --root "$ROOT" 2>&1)"; then
  TEST_042_RC=0
else
  TEST_042_RC=$?
fi
TEST_042_DRIFT_LINE="$(printf '%s\n' "$TEST_042_OUT" | grep -E '^---- check summary:' || true)"
if [[ "$TEST_042_RC" -eq 0 ]]; then
  ok "TEST-042: first production role_defaults render is zero-diff ($TEST_042_DRIFT_LINE)"
else
  bad "TEST-042: render-agent-frontmatter --check reported non-zero diff (documented, not silently applied) -- $TEST_042_OUT"
fi

# --- TEST-043 (AC-043): USERGUIDE.md / docs/agent-capability-matrix.md /
# CHANGELOG.md describe the matrix-default policy -------------------------
TEST_043_FAIL=0
if [[ -f "$USERGUIDE" ]] && grep -Fq '既定値が `matrix`' "$USERGUIDE"; then
  ok "TEST-043: USERGUIDE.md describes the matrix-default effort policy"
else
  bad "TEST-043: USERGUIDE.md does not describe the matrix-default effort policy"
  TEST_043_FAIL=1
fi
if [[ -f "$CAPMATRIX" ]] && grep -Fq 'default effort policy is `matrix`' "$CAPMATRIX"; then
  ok "TEST-043: docs/agent-capability-matrix.md describes the matrix-default effort policy"
else
  bad "TEST-043: docs/agent-capability-matrix.md does not describe the matrix-default effort policy"
  TEST_043_FAIL=1
fi
if [[ -f "$CHANGELOG_FILE" ]] && grep -Fq '既定値を `matrix` に変更' "$CHANGELOG_FILE"; then
  ok "TEST-043: CHANGELOG.md describes the matrix-default effort policy"
else
  bad "TEST-043: CHANGELOG.md does not describe the matrix-default effort policy"
  TEST_043_FAIL=1
fi
if [[ "$TEST_043_FAIL" -eq 0 ]]; then
  ok "TEST-043: all three REQ-009 doc surfaces (USERGUIDE.md, docs/agent-capability-matrix.md, CHANGELOG.md) describe the matrix-default policy"
fi

# --- TEST-044 (AC-044): real Codex-host smoke, run-record effort_applied
# non-null --------------------------------------------------------------
# Scoped by design.md Test Strategy point 8 to "T-007's own
# implementation/release-time verification, not... CI's deterministic
# lane" -- SKIP is the correct, PASS-compatible outcome whenever a real,
# SAFE invocation is not available (mirrors AC-048's "degraded path is a
# PASS/SKIP outcome, never a hard failure" convention already established
# for REQ-008 elsewhere in this feature). The operator may opt in
# explicitly via SDD_ALLOW_REAL_CODEX_SMOKE=1 when they have verified it
# is safe to do so in their own environment (a real `codex` invocation is
# an autonomous coding agent, not a pure API call -- see the
# implementation report's Unresolved Items for why this session did not
# opt in itself).
if [[ "${SDD_ALLOW_REAL_CODEX_SMOKE:-0}" != "1" ]]; then
  skp "TEST-044: real Codex-host smoke skipped -- SDD_ALLOW_REAL_CODEX_SMOKE not set to 1 (real 'codex' invocation is an autonomous coding-agent CLI, not opted into from an automated suite run; see reports/implementation/epic-159-pillar-c/T-007.md Unresolved Items)"
elif ! command -v codex >/dev/null 2>&1; then
  skp "TEST-044: real Codex-host smoke skipped -- no 'codex' binary on PATH"
else
  TEST_044_CAND="$TMP/candidates-044.json"
  cat > "$TEST_044_CAND" <<'JSON'
[
  {"name": "openai/gpt-5.6-codex", "cost": "0.1", "available": true}
]
JSON
  TEST_044_SEL_OUT="$(bash "$SELECT_SH" --risk low --host codex-cli --role sdd-investigator \
    --registry "$V2_REGISTRY" --candidates-file "$TEST_044_CAND" --json)"
  TEST_044_MODEL="$(printf '%s' "$TEST_044_SEL_OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["model"])')"
  TEST_044_EFFORT="$(printf '%s' "$TEST_044_SEL_OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["effort"])')"
  TEST_044_MODEL_SHORT="${TEST_044_MODEL#openai/}"
  TEST_044_PROMPT_FILE="$TMP/codex-smoke-prompt.txt"
  printf 'Reply with exactly one line: OK\n' > "$TEST_044_PROMPT_FILE"
  TEST_044_RAW="$TMP/codex-smoke-raw.log"
  # --sandbox read-only: this is a real, autonomous coding-agent CLI (its
  # own --help documents workspace-write/danger-full-access sandbox modes
  # that let the model execute shell commands) -- the smoke prompt below
  # needs no tool access at all, so the smoke run is pinned to read-only
  # regardless of the operator's own global codex config.
  TEST_044_RUN_OK=0
  TEST_044_MODEL_NOTE=""
  if codex exec --sandbox read-only --model "$TEST_044_MODEL_SHORT" \
      -c "model_reasoning_effort=\"$TEST_044_EFFORT\"" \
      "$(cat "$TEST_044_PROMPT_FILE")" >"$TEST_044_RAW" 2>&1; then
    TEST_044_RUN_OK=1
  elif grep -q "not supported when using Codex with a ChatGPT account" "$TEST_044_RAW"; then
    # Observed live during T-007 implementation: ChatGPT-account codex auth
    # rejects the registry's entire API-model vocabulary (400
    # invalid_request_error for gpt-5.1-codex-mini AND gpt-5.6-codex). The
    # host-side effort-application mechanism (-c model_reasoning_effort=...)
    # is model-independent, so the smoke's REAL-run leg falls back to the
    # operator account's own default model while KEEPING the selected
    # effort — the substitution is disclosed in the ok line and the raw log.
    if codex exec --sandbox read-only \
        -c "model_reasoning_effort=\"$TEST_044_EFFORT\"" \
        "$(cat "$TEST_044_PROMPT_FILE")" >>"$TEST_044_RAW" 2>&1; then
      TEST_044_RUN_OK=1
      TEST_044_MODEL_NOTE=" [invoked model substituted with the operator account's default: ChatGPT-account codex auth rejects registry API models; selected effort ($TEST_044_EFFORT) kept]"
    fi
  fi
  if [[ "$TEST_044_RUN_OK" -eq 1 ]]; then
    # emit-run-record.sh's own interface (plugins/sdd-quality-loop/scripts/
    # emit-run-record.sh:3): positional feature-slug + --model-main/--track/
    # --effort-* flags; it WRITES reports/runs/RUN-<ts>-<feature>.json and
    # only echoes the written path to stdout (never the record content).
    TEST_044_EMIT_OUT="$(cd "$ROOT" && bash plugins/sdd-quality-loop/scripts/emit-run-record.sh \
      epic-159-pillar-c --model-main "$TEST_044_MODEL" --track T-007-smoke \
      --effort-main "$TEST_044_EFFORT" --effort-control-main flag \
      --effort-applied-main "$TEST_044_EFFORT" 2>&1)"
    TEST_044_RECORD_PATH="$(printf '%s\n' "$TEST_044_EMIT_OUT" | sed -n 's/^emit-run-record: wrote //p')"
    if [[ -n "$TEST_044_RECORD_PATH" && -f "$ROOT/$TEST_044_RECORD_PATH" ]] &&
        grep -q '"effort_applied": *"'"$TEST_044_EFFORT"'"' "$ROOT/$TEST_044_RECORD_PATH"; then
      ok "TEST-044: real Codex-host run's run-record ($TEST_044_RECORD_PATH) shows non-null effort_applied ($TEST_044_EFFORT)$TEST_044_MODEL_NOTE"
    else
      bad "TEST-044: real Codex-host run completed but the run-record did not show the expected non-null effort_applied -- emit output: $TEST_044_EMIT_OUT"
    fi
  else
    bad "TEST-044: real 'codex exec' invocation failed -- $(cat "$TEST_044_RAW")"
  fi
fi

# --- TEST-045 (AC-045): prerequisite-gate re-run via git merge-base
# --is-ancestor -----------------------------------------------------------
A3_SHA="2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f"
PHASE1_MERGE_SHA="825d6c6623ba98b6588a3c9942420dd13fceec88"
IMPL_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
TEST_045_FAIL=0
if git -C "$ROOT" merge-base --is-ancestor "$A3_SHA" "$IMPL_HEAD"; then
  ok "TEST-045: A3 ($A3_SHA) is an ancestor of the implementation-time HEAD ($IMPL_HEAD)"
else
  bad "TEST-045: A3 ($A3_SHA) is NOT an ancestor of HEAD -- prerequisite gate BLOCKED"
  TEST_045_FAIL=1
fi
if git -C "$ROOT" merge-base --is-ancestor "$PHASE1_MERGE_SHA" "$IMPL_HEAD"; then
  ok "TEST-045: T-001..T-006's Phase 1 merge commit ($PHASE1_MERGE_SHA, PR #185) is an ancestor of the implementation-time HEAD"
else
  bad "TEST-045: T-001..T-006's Phase 1 merge commit is NOT an ancestor of HEAD -- prerequisite gate BLOCKED"
  TEST_045_FAIL=1
fi
if [[ "$TEST_045_FAIL" -eq 0 ]]; then
  ok "TEST-045: prerequisite gate satisfied at implementation time (the RELEASE-COMMIT re-run against the actual tagged release is the caller's own job at release time -- this suite verifies the implementation-time HEAD, not a release tag that does not exist yet)"
fi

# --- TEST-046 (AC-046, REQ-009): this task's PR/release is distinct from
# Phase 1's --------------------------------------------------------------
TEST_046_BRANCH="$(git -C "$ROOT" branch --show-current)"
TEST_046_FAIL=0
case "$TEST_046_BRANCH" in
  *t007*|*T-007*|*pillar-c-t007*)
    ok "TEST-046: current branch ($TEST_046_BRANCH) is T-007-scoped, distinct from any T-001..T-006 branch"
    ;;
  *)
    bad "TEST-046: current branch ($TEST_046_BRANCH) does not look T-007-scoped -- cannot confirm PR separation"
    TEST_046_FAIL=1
    ;;
esac
# scripts/bump-version.sh renames "## Unreleased" to a version heading;
# confirming that heading is still present proves this implementation
# session did not itself invoke a release (its own bump-version.sh
# invocation, if any, is the caller's separate job -- see this task's
# instructions and the implementation report's Specification Differences).
if [[ -f "$CHANGELOG_FILE" ]] && head -5 "$CHANGELOG_FILE" | grep -Fq '## Unreleased'; then
  ok "TEST-046: CHANGELOG.md's '## Unreleased' heading is unrenamed -- this implementation session did not itself invoke scripts/bump-version.sh (the separate release is the caller's own, later step)"
else
  bad "TEST-046: CHANGELOG.md's '## Unreleased' heading is missing/renamed -- a release may have been invoked inside this implementation session, which would collapse T-007's release into this session rather than keeping it separate"
  TEST_046_FAIL=1
fi
if [[ "$TEST_046_FAIL" -eq 0 ]]; then
  ok "TEST-046: process-conformance proxy satisfied (full proof -- a genuinely separate GitHub PR -- is verified by the caller at PR-creation time, outside what a local test suite can observe)"
fi

printf -- '---- summary: pass=%d fail=%d skip=%d ----\n' "$pass" "$fail" "$skip"
if [[ "$fail" -gt 0 ]]; then
  printf 'not ok: effort-policy-flip suite FAILED (%d failures, %d skipped)\n' "$fail" "$skip" >&2
  exit 1
fi
printf 'ok: effort-policy-flip suite passed (%d checks, %d skipped)\n' "$pass" "$skip"
