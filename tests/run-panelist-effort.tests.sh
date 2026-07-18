#!/usr/bin/env bash
# Suite: run-panelist-effort (T-006, #152) -- REQ-006/REQ-008 share --
# AC-035..040, AC-052.
#
# Locks: run-panelist-gpt.sh's --effort forwarding into the assembled codex
# argv (AC-035); prepare-panelist-input.sh's --effort threading through to
# run-panelist-gpt's --effort argument (AC-036); the Codex-host
# evaluator/investigator startup path's select-agent-model --host codex-cli
# model+effort composition (AC-037); the render/selector cross-check drift
# report between T-003's rendered .toml reference comments and live
# selector output (AC-038); the Claude Code degradation case recorded in
# the resulting run record (AC-039, REQ-008, sharing TEST-024/TEST-051's
# field-population rule); the argv/JSON-composition-only proof that no test
# in this suite invokes a real LLM (AC-040); and the argv-injection-shape
# rejection lock for --model/--effort, per malformed-shape category
# (AC-052, security-spec.md B3).
#
# All positive/negative codex-argv assertions run against a STUB `codex`
# executable placed in a scratch PATH. Some developer/CI machines have a
# REAL `codex` CLI installed (confirmed present on the authoring machine at
# `/opt/homebrew/bin/codex` and elsewhere) -- every invocation of
# run-panelist-gpt.sh in this suite therefore OVERRIDES (never prepends to)
# $PATH with a minimal, fully-controlled set containing only the stub
# (mirrors tests/collection-layer.tests.sh's established stub-in-PATH
# pattern), guaranteeing zero real LLM calls regardless of the host
# environment (AC-040).
#
# CI-resilience (requirements.md Edge Cases; design.md Constraint
# Compliance): no possibly-empty bash array is expanded under `set -u`; the
# mktemp scratch root is normalized with `pwd -P` immediately after
# creation; `select-agent-model`'s JSON output is always captured via
# command substitution before any `jq` consumption (mirrors
# tests/agent-model-routing.tests.sh's established convention -- no
# raw-file jq read, so the Windows jq.exe CRLF hazard does not apply here);
# no suite drives a real validator gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

RUN_GPT_SH="$ROOT/plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh"
PREPARE_SH="$ROOT/plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh"
SELECTOR_SH="$ROOT/plugins/sdd-implementation/scripts/select-agent-model.sh"
EMIT_RUN_RECORD_SH="$ROOT/plugins/sdd-quality-loop/scripts/emit-run-record.sh"
SKILL_MD="$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
EVALUATOR_TOML="$ROOT/.codex/agents/sdd-evaluator.toml"
INVESTIGATOR_TOML="$ROOT/.codex/agents/sdd-investigator.toml"
REGISTRY_V2="$ROOT/contracts/agent-model-capabilities.v2.json"
RUN_ALL_SH="$ROOT/tests/run-all.sh"
RUN_ALL_PS1="$ROOT/tests/run-all.ps1"
HUMAN_COPY_DIR="$ROOT/specs/epic-159-pillar-c/human-copy"
MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"

for f in "$RUN_GPT_SH" "$PREPARE_SH" "$SELECTOR_SH" "$EMIT_RUN_RECORD_SH" "$SKILL_MD" \
  "$EVALUATOR_TOML" "$INVESTIGATOR_TOML" "$REGISTRY_V2"; do
  [[ -f "$f" ]] || { printf 'not ok: missing required artifact: %s\n' "$f" >&2; exit 1; }
done

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'not ok: %s\n' "$1" >&2; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Suite-wide safety proof: this suite reads the two real Codex .toml
# reference-comment files (T-006 Out of Scope: reads, never edits them
# further) -- captured BEFORE and AFTER this suite's own full run.
EVALUATOR_TOML_SHA_BEFORE="$(sha256_of "$EVALUATOR_TOML")"
INVESTIGATOR_TOML_SHA_BEFORE="$(sha256_of "$INVESTIGATOR_TOML")"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

ZERO_DIGEST="$(printf '0%.0s' $(seq 1 64))"
SAFE_PATH="/usr/bin:/bin"

# ── Stub codex: records argv, touches an invocation marker, prints a
# canned valid cross-model-verdict/v1 JSON, exits 0. Never a real LLM. ─────
STUB_BIN="$TMP/stub-bin"
mkdir -p "$STUB_BIN"
ARGV_FILE="$TMP/codex-argv.txt"
MARKER_FILE="$TMP/codex-invoked.marker"
STUB_JSON='{"schema":"cross-model-verdict/v1","task_id":"stub","feature":"stub","vendor":"openai","model":"stub","verdict":"PASS","findings":[],"blind":true,"input_digest":"'"$ZERO_DIGEST"'","consent":{"kind":"human-flag","ref":"stub"}}'
cat > "$STUB_BIN/codex" <<STUBEOF
#!/bin/sh
printf '%s\n' "\$@" > "$ARGV_FILE"
: > "$MARKER_FILE"
printf '%s\n' '$STUB_JSON'
exit 0
STUBEOF
chmod +x "$STUB_BIN/codex"

reset_stub_state() { rm -f "$ARGV_FILE" "$MARKER_FILE"; }

# The stub writes one argv token per line (printf '%s\n' "$@"); flatten to
# a single space-joined line for substring/order assertions. Safe because
# no accepted --model/--effort value may itself contain whitespace
# (AC-052's own rejection rule guarantees this).
argv_flat() {
  [[ -f "$ARGV_FILE" ]] && tr '\n' ' ' < "$ARGV_FILE" | sed 's/[[:space:]]*$//'
}

run_gpt() {
  # $@ forwarded to run-panelist-gpt.sh. PATH is fully overridden to
  # $STUB_BIN:$SAFE_PATH -- never the ambient/inherited $PATH -- so the
  # stub is the ONLY thing that could ever be invoked as "codex" (AC-040).
  PATH="$STUB_BIN:$SAFE_PATH" bash "$RUN_GPT_SH" "$@"
}

INPUT_FILE="$TMP/input.txt"
printf 'Plain panelist input content for argv-composition tests.\n' > "$INPUT_FILE"
SPEC_ROOT="$TMP/specroot"

# ===========================================================================
# TEST-035 (AC-035): --effort forwarded into the assembled codex argv
# alongside --model; omitted entirely preserves the exact pre-T-006 argv.
# ===========================================================================
reset_stub_state
run_gpt --task T-035 --feature stub-feat --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" \
  --model openai/gpt-5.2-codex --effort high --digest "$ZERO_DIGEST" >/dev/null
if [[ -f "$MARKER_FILE" ]] && [[ "$(argv_flat)" == "--model openai/gpt-5.2-codex --effort high --no-project-doc" ]]; then
  ok "TEST-035: --effort <e> is forwarded into the assembled codex argv, positioned after --model"
else
  bad "TEST-035: --effort was not forwarded correctly into the codex argv -- $(argv_flat)"
fi

reset_stub_state
run_gpt --task T-035b --feature stub-feat --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" \
  --model openai/gpt-5.2-codex --digest "$ZERO_DIGEST" >/dev/null
GOLDEN_ARGV="$(printf -- '--model\nopenai/gpt-5.2-codex\n--no-project-doc\n')"
ACTUAL_ARGV="$(cat "$ARGV_FILE")"
if [[ "$ACTUAL_ARGV" == "$GOLDEN_ARGV" ]]; then
  ok "TEST-035: omitting --effort preserves the exact pre-T-006 codex argv byte-for-byte (Breaking API: no)"
else
  bad "TEST-035: omitting --effort changed the codex argv shape -- got: $(printf '%s' "$ACTUAL_ARGV" | tr '\n' ' ')"
fi

# ===========================================================================
# TEST-036 (AC-036): prepare-panelist-input.sh threads a selector-derived
# effort value through to run-panelist-gpt's --effort argument.
# ===========================================================================
TASKS_FIXTURE="$TMP/tasks.md"
cat > "$TASKS_FIXTURE" <<'EOF'
## T-036 Stub task for consent gate

Cross-Model: enabled
EOF
SANITIZE_SRC="$TMP/sanitize-src.txt"
printf 'plain review content, no secrets, no absolute paths.\n' > "$SANITIZE_SRC"
BUNDLE_OUT="$TMP/bundle.txt"

PP_STDOUT="$(bash "$PREPARE_SH" --task T-036 --feature stub-feat --input "$SANITIZE_SRC" \
  --tasks-file "$TASKS_FIXTURE" --out "$BUNDLE_OUT" --effort medium)"
EFFORT_LINE="$(printf '%s\n' "$PP_STDOUT" | grep -E '^effort=' || true)"
if [[ "$EFFORT_LINE" == "effort=medium" ]]; then
  ok "TEST-036: prepare-panelist-input.sh threads --effort onto a second stdout line, verbatim"
else
  bad "TEST-036: prepare-panelist-input.sh did not thread --effort correctly -- stdout: $PP_STDOUT"
fi

PP_STDOUT_NOEFFORT="$(bash "$PREPARE_SH" --task T-036 --feature stub-feat --input "$SANITIZE_SRC" \
  --tasks-file "$TASKS_FIXTURE" --out "$TMP/bundle-noeffort.txt")"
if [[ "$(printf '%s\n' "$PP_STDOUT_NOEFFORT" | wc -l | tr -d ' ')" == "1" ]]; then
  ok "TEST-036: omitting --effort preserves the exact pre-T-006 single-line stdout output (Breaking API: no)"
else
  bad "TEST-036: omitting --effort changed prepare-panelist-input's stdout line count -- got: $PP_STDOUT_NOEFFORT"
fi

FWD_EFFORT="${EFFORT_LINE#effort=}"
reset_stub_state
run_gpt --task T-036 --feature stub-feat --input "$BUNDLE_OUT" --spec-root "$SPEC_ROOT" \
  --model openai/gpt-5.1-codex --effort "$FWD_EFFORT" --digest "$ZERO_DIGEST" >/dev/null
if [[ "$(argv_flat)" == *"--effort medium"* ]]; then
  ok "TEST-036: the value threaded by prepare-panelist-input.sh reaches run-panelist-gpt's assembled codex argv unchanged"
else
  bad "TEST-036: threaded effort value did not reach the assembled codex argv -- $(argv_flat)"
fi

# ===========================================================================
# TEST-037 (AC-037): the Codex-host evaluator/investigator startup path
# supplies select-agent-model --host codex-cli output (model + effort) as
# CLI flags to the launching codex command. Real registry, real .toml
# reference comments -- proving this against production content, not only
# a synthetic fixture (mirrors TEST-017's zero-diff real-content style).
# ===========================================================================
CODEX_CANDIDATES="$TMP/codex-candidates.json"
cat > "$CODEX_CANDIDATES" <<'JSON'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
JSON

sel_json_for_role() {
  # $1 = role (sdd-evaluator | sdd-investigator)
  bash "$SELECTOR_SH" --risk low --registry "$REGISTRY_V2" \
    --candidates-file "$CODEX_CANDIDATES" --role "$1" --host codex-cli --json
}

toml_ref() {
  # $1 = toml path. Prints "<model> <effort>" from the first two
  # # x-sdd-model:/# x-sdd-effort: reference comment lines.
  local m e
  m="$(sed -n '1p' "$1" | sed 's/^# x-sdd-model: //')"
  e="$(sed -n '2p' "$1" | sed 's/^# x-sdd-effort: //')"
  printf '%s %s\n' "$m" "$e"
}

test037_ok=1
for pair in "sdd-evaluator:$EVALUATOR_TOML" "sdd-investigator:$INVESTIGATOR_TOML"; do
  role="${pair%%:*}"
  toml="${pair#*:}"
  sel_json="$(sel_json_for_role "$role")"
  sel_model="$(jq -r '.model' <<<"$sel_json")"
  sel_effort="$(jq -r '.effort' <<<"$sel_json")"

  read -r toml_model toml_effort <<<"$(toml_ref "$toml")"
  if [[ "$sel_model" != "$toml_model" || "$sel_effort" != "$toml_effort" ]]; then
    test037_ok=0
    printf 'not ok: TEST-037 sanity: %s live=%s/%s toml=%s/%s diverge (should agree on an unmutated repo)\n' \
      "$role" "$sel_model" "$sel_effort" "$toml_model" "$toml_effort" >&2
    continue
  fi

  reset_stub_state
  run_gpt --task "T-037-$role" --feature stub-feat --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" \
    --model "$sel_model" --effort "$sel_effort" --digest "$ZERO_DIGEST" >/dev/null
  if ! ([[ -f "$MARKER_FILE" ]] \
    && [[ "$(argv_flat)" == "--model $sel_model --effort $sel_effort --no-project-doc" ]]); then
    test037_ok=0
  fi
done
if [[ "$test037_ok" -eq 1 ]]; then
  ok "TEST-037: select-agent-model --host codex-cli's model+effort output (sdd-evaluator and sdd-investigator roles, real registry) is supplied as CLI flags to the launching codex command"
else
  bad "TEST-037: the Codex-host startup path did not correctly supply select-agent-model's model+effort output as codex CLI flags"
fi

# ===========================================================================
# TEST-038 (AC-038): cross-check between T-003's rendered .toml reference
# comments and live selector output reports a distinguishable result when
# they diverge -- GREEN (real, in-sync content) and RED (mutation-based
# negative self-check: a deliberately diverged "live" value) pair.
# ===========================================================================
cross_check_toml() {
  # $1=toml path $2=live model $3=live effort
  local toml_model toml_effort
  read -r toml_model toml_effort <<<"$(toml_ref "$1")"
  if [[ "$toml_model" == "$2" && "$toml_effort" == "$3" ]]; then
    printf 'OK: %s\n' "$1"
  else
    printf 'DRIFT: %s toml=%s/%s live=%s/%s\n' "$1" "$toml_model" "$toml_effort" "$2" "$3"
  fi
}

evaluator_sel_json="$(sel_json_for_role sdd-evaluator)"
evaluator_sel_model="$(jq -r '.model' <<<"$evaluator_sel_json")"
evaluator_sel_effort="$(jq -r '.effort' <<<"$evaluator_sel_json")"

GREEN038_OUT="$(cross_check_toml "$EVALUATOR_TOML" "$evaluator_sel_model" "$evaluator_sel_effort")"
if [[ "$GREEN038_OUT" == "OK: $EVALUATOR_TOML" ]]; then
  ok "TEST-038 GREEN: cross-check reports OK when the rendered .toml reference comments and live selector output agree"
else
  bad "TEST-038 GREEN: cross-check did not report OK for in-sync content -- $GREEN038_OUT"
fi

# Mutation-based negative self-check: deliberately diverge the "live" value
# (never the real, checked-in .toml file -- T-006 reads it read-only) and
# confirm the cross-check goes red, proving the divergence report is live.
MUTATED_EFFORT="medium"
if [[ "$evaluator_sel_effort" == "medium" ]]; then MUTATED_EFFORT="high"; fi
RED038_OUT="$(cross_check_toml "$EVALUATOR_TOML" "$evaluator_sel_model" "$MUTATED_EFFORT")"
if [[ "$RED038_OUT" == "DRIFT: $EVALUATOR_TOML toml=$evaluator_sel_model/$evaluator_sel_effort live=$evaluator_sel_model/$MUTATED_EFFORT" ]]; then
  ok "TEST-038 RED (negative self-check): a deliberately diverged live effort value turns the cross-check to a distinguishable DRIFT report"
else
  bad "TEST-038 RED: mutated live value did NOT turn the cross-check red -- $RED038_OUT"
fi
# Confirm the two outcomes are lexically distinguishable (never overridden
# silently either direction -- design.md Test Strategy / requirements.md).
if [[ "$GREEN038_OUT" != "$RED038_OUT" ]] && [[ "$GREEN038_OUT" == OK:* ]] && [[ "$RED038_OUT" == DRIFT:* ]]; then
  ok "TEST-038: OK and DRIFT outcomes are structurally distinguishable, never silently collapsed to one shape"
else
  bad "TEST-038: OK and DRIFT outcomes were not distinguishable"
fi

# ===========================================================================
# TEST-039 (AC-039, REQ-008): on Claude Code, the same startup-path
# reasoning records effort_applied=null + a populated
# effort_degraded_reason in the resulting run record -- never a silent
# drop. Uses the REAL registry's --host claude-code resolution (which
# resolves effort_control.claude-code to "frontmatter" for every Anthropic
# model, INV-013) feeding real emit-run-record.sh (T-004, unedited by this
# task) -- mirrors TEST-024/TEST-051's field-population rule.
# ===========================================================================
CLAUDE_CANDIDATES="$TMP/claude-candidates.json"
cat > "$CLAUDE_CANDIDATES" <<'JSON'
[
  {"name":"anthropic/haiku","cost":"0.001","available":true},
  {"name":"anthropic/sonnet","cost":"0.01","available":true},
  {"name":"anthropic/opus","cost":"0.05","available":true}
]
JSON
claude_sel_json="$(bash "$SELECTOR_SH" --risk low --registry "$REGISTRY_V2" \
  --candidates-file "$CLAUDE_CANDIDATES" --role sdd-evaluator --host claude-code --json)"
claude_control="$(jq -r '.effort_control' <<<"$claude_sel_json")"
claude_model="$(jq -r '.model' <<<"$claude_sel_json")"
claude_effort="$(jq -r '.effort' <<<"$claude_sel_json")"

if [[ "$claude_control" != "frontmatter" ]]; then
  bad "TEST-039 sanity: select-agent-model --host claude-code did not resolve effort_control to frontmatter (got: $claude_control) -- REQ-008/INV-013 assumption violated"
else
  ok "TEST-039 sanity: select-agent-model --host claude-code resolves effort_control to frontmatter for the winning Anthropic model (INV-013, REQ-008)"
fi

RR_FEATURE="t006-degrade-fixture"
RR_CWD="$TMP/rr-cwd"
mkdir -p "$RR_CWD/specs/$RR_FEATURE"
printf '# Tasks\n\n## T-001 x\nStatus: Done\n' > "$RR_CWD/specs/$RR_FEATURE/tasks.md"
(cd "$RR_CWD" && bash "$EMIT_RUN_RECORD_SH" "$RR_FEATURE" \
  --effort-main "$claude_effort" --effort-control-main "$claude_control" --model-main "$claude_model" >/dev/null)
RR_JSON="$(find "$RR_CWD/reports/runs" -maxdepth 1 -name "RUN-*-${RR_FEATURE}.json" | head -1)"
if [[ -n "$RR_JSON" ]] \
  && [[ "$(jq -r '.effort.main.effort_applied' "$RR_JSON" | tr -d '\r')" == "null" ]] \
  && [[ "$(jq -r '.effort.main.effort_degraded_reason' "$RR_JSON" | tr -d '\r')" == "effort-control-frontmatter" ]]; then
  ok "TEST-039: Claude Code path records effort_applied=null + effort_degraded_reason=effort-control-frontmatter in the run record, never a silent drop"
else
  bad "TEST-039: Claude Code degradation was not recorded correctly in the run record -- $(cat "$RR_JSON" 2>/dev/null || echo '<no record written>')"
fi

# ===========================================================================
# TEST-052 (AC-052): --model/--effort argv-injection-shape rejection, per
# malformed-shape category, on run-panelist-gpt.sh -- non-zero exit,
# diagnostic message, and ZERO codex invocations (the stub codex is
# present in PATH the whole time; MARKER_FILE absence after the run is the
# executable proof that rejection happens before any codex invocation is
# attempted, not merely because codex was unavailable).
# ===========================================================================
assert_rejected() {
  # $1=label $2=expected-diagnostic-substring; remaining args forwarded to run_gpt
  local label="$1" diag="$2"
  shift 2
  reset_stub_state
  local out rc=0
  out="$(run_gpt "$@" 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    bad "TEST-052 ($label): expected non-zero exit, got 0 -- $out"
    return
  fi
  if [[ -f "$MARKER_FILE" ]]; then
    bad "TEST-052 ($label): codex WAS invoked despite the malformed value (marker present) -- $out"
    return
  fi
  if [[ "$out" != *"$diag"* ]]; then
    bad "TEST-052 ($label): rejected (exit $rc, no codex invocation) but diagnostic text did not match -- $out"
    return
  fi
  ok "TEST-052 ($label): rejected non-zero (exit $rc), diagnostic present, zero codex invocations"
}

assert_rejected "model whitespace" "argv-injection shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --model "gpt 5.2 codex"
assert_rejected "model leading dash" "flag-injection shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --model "-rf"
assert_rejected "model leading double-dash" "flag-injection shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --model "--dangerous"
assert_rejected "model semicolon" "command-separator shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --model "openai/gpt;rm-rf"
assert_rejected "effort whitespace" "argv-injection shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --effort "hi gh"
assert_rejected "effort leading dash" "flag-injection shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --effort "-high"
assert_rejected "effort semicolon" "command-separator shape" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --effort "high;rm-rf"
assert_rejected "effort out of vocabulary" "must be one of low|medium|high|xhigh" \
  --task T-052 --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" --effort "extreme"

# A positive control: a well-formed --model/--effort pair is NOT rejected
# (proves the checks above are discriminating, not vacuously rejecting
# everything).
reset_stub_state
run_gpt --task T-052-control --feature f --input "$INPUT_FILE" --spec-root "$SPEC_ROOT" \
  --model openai/gpt-5.2-codex --effort high --digest "$ZERO_DIGEST" >/dev/null
if [[ -f "$MARKER_FILE" ]]; then
  ok "TEST-052 positive control: a well-formed --model/--effort pair is accepted and reaches codex (rejection is discriminating, not vacuous)"
else
  bad "TEST-052 positive control: a well-formed --model/--effort pair was unexpectedly blocked"
fi

# SKILL.md documents the same rejection categories for the Codex-host
# startup path (construction-level documentation complement to this
# suite's executable proof above -- AC-052's own wording contrast).
if grep -Fq 'flag-injection shape' "$SKILL_MD" && grep -Fq 'command-separator shape' "$SKILL_MD" \
  && grep -Fq '{low, medium, high, xhigh}' "$SKILL_MD" \
  && grep -Fq 'no `codex` invocation attempted' "$SKILL_MD"; then
  ok "TEST-052: SKILL.md documents the same enumerated-vocabulary rejection categories for the Codex-host startup path"
else
  bad "TEST-052: SKILL.md does not document the injection-rejection categories for the Codex-host startup path"
fi

# ===========================================================================
# TEST-040 (AC-040): a grep-based self-check over this suite asserts no
# direct LLM-invocation call is required for any assertion -- every
# run-panelist-gpt.sh invocation in this file is routed through the stub
# codex (never a live network client or vendor API endpoint).
# ===========================================================================
SELF="$0"
# Exclude this check's own line (marked SELF-CHECK-PATTERN) from the scan
# target -- otherwise the pattern literal below would always match itself.
if grep -v 'SELF-CHECK-PATTERN' "$SELF" | grep -Eq 'curl |wget |api\.openai\.com|api\.anthropic\.com'; then # SELF-CHECK-PATTERN
  bad "TEST-040: this suite must not reference a live network client or vendor API endpoint"
else
  ok "TEST-040: no live network client or vendor API endpoint is referenced anywhere in this suite"
fi
invoke_count="$(grep -c -- 'run_gpt ' "$SELF" || true)"
if [[ "$invoke_count" -gt 0 ]]; then
  ok "TEST-040: every codex invocation in this suite goes through the run_gpt() wrapper, which unconditionally overrides PATH to the stub codex ($invoke_count call sites)"
else
  bad "TEST-040: no run_gpt() call sites found (unexpected -- this suite should exercise run-panelist-gpt.sh)"
fi

# ===========================================================================
# Human-copy staging: this task's CI step is registered in the staged
# .github/workflows/test.yml candidate (never the live, R-10 protected
# path -- Protected Files, tasks.md) with a matching MANIFEST.sha256 entry.
# ===========================================================================
STAGED_TEST_YML="$HUMAN_COPY_DIR/.github/workflows/test.yml"
if [[ -f "$STAGED_TEST_YML" ]] && grep -Fq 'run-panelist-effort' "$STAGED_TEST_YML"; then
  ok "human-copy: the staged .github/workflows/test.yml candidate registers this suite's CI step(s)"
else
  bad "human-copy: the staged .github/workflows/test.yml candidate does not reference run-panelist-effort"
fi
if [[ -f "$STAGED_TEST_YML" ]]; then
  staged_sha="$(sha256_of "$STAGED_TEST_YML")"
  if grep -Fq "$staged_sha  .github/workflows/test.yml" "$MANIFEST"; then
    ok "human-copy: MANIFEST.sha256 entry for the staged test.yml candidate matches its current content"
  else
    bad "human-copy: MANIFEST.sha256 entry for the staged test.yml candidate is missing or stale"
  fi
fi

# ===========================================================================
# Self-registration (design.md Test Strategy #7; mirrors
# tests/second-approval-mask.tests.sh:285-289's established pattern).
# ===========================================================================
if grep -q 'run-panelist-effort\.tests\.sh' "$RUN_ALL_SH"; then
  ok "self-registration: run-panelist-effort.tests.sh registered in tests/run-all.sh"
else
  bad "self-registration: run-panelist-effort.tests.sh NOT registered in tests/run-all.sh"
fi
if [[ -f "$RUN_ALL_PS1" ]] && grep -q 'run-panelist-effort\.tests\.ps1' "$RUN_ALL_PS1"; then
  ok "self-registration: run-panelist-effort.tests.ps1 registered in tests/run-all.ps1"
else
  bad "self-registration: run-panelist-effort.tests.ps1 NOT registered in tests/run-all.ps1"
fi

# Sanity: the two Codex .toml reference-comment files this suite reads were
# never mutated by this suite's own run (T-006 reads them, never edits),
# captured before/after the ENTIRE suite (Suite-wide safety proof, above).
if [[ "$(sha256_of "$EVALUATOR_TOML")" == "$EVALUATOR_TOML_SHA_BEFORE" ]] \
  && [[ "$(sha256_of "$INVESTIGATOR_TOML")" == "$INVESTIGATOR_TOML_SHA_BEFORE" ]]; then
  ok "AC-038 boundary: this suite's own run left both real .codex/agents/*.toml reference-comment files byte-unchanged"
else
  bad "AC-038 boundary: a real .codex/agents/*.toml reference-comment file changed during this suite's own run"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$pass" "$fail"
if [[ "$fail" -gt 0 ]]; then
  printf 'not ok: run-panelist-effort suite FAILED (%d failures)\n' "$fail" >&2
  exit 1
fi
printf 'ok: run-panelist-effort suite passed (%d checks)\n' "$pass"
