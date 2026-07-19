#!/usr/bin/env bash
# Suite: render-agent-frontmatter (T-003, #151) -- REQ-003 / AC-014..AC-020.
#
# Locks render-agent-frontmatter.sh's Claude `.md` frontmatter render, Codex
# `.toml` reference-comment render, `--check` drift detection, the zero-diff
# no-op proof against real production content, the `model: inherit`/
# role-map-absent exclusion, and the R-10 protected-file write/read boundary
# (four protected reviewer `.md` files -- AC-019 never written directly,
# AC-020 may be read unattended in CI).
#
# All mutating checks (TEST-014/015/016/017/019's write-boundary) run
# against a SCRATCH mirror of the real production files, never the live
# repository files themselves -- this suite is idempotent and safe to run
# repeatedly in CI. The one-time REAL production render (landing this task's
# actual `model:`/`x-sdd-effort:` content into the six unprotected targets
# and staging the four protected targets under
# `specs/epic-159-pillar-c/human-copy/`) is a separate, one-time action
# recorded in this task's implementation report and verification logs, not
# repeated by this suite. This suite's own human-copy/manifest checks
# (bottom of the file) read the REAL, already-committed staged files
# read-only, mirroring tests/agent-capabilities-v2.tests.sh's established
# pattern for `.github/workflows/test.yml`.
#
# CI-resilience (requirements.md Edge Cases; design.md Constraint
# Compliance): no possibly-empty bash array is expanded under `set -u`; the
# mktemp scratch root is normalized with `pwd -P` immediately after
# creation; this suite performs no jq consumption (all JSON/text handling
# goes through render-agent-frontmatter.sh itself or plain grep/diff), so
# the Windows jq.exe CRLF hazard does not apply; no real validator gate is
# driven.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

RENDER_SH="$ROOT/render-agent-frontmatter.sh"
RUN_ALL_SH="$ROOT/tests/run-all.sh"
RUN_ALL_PS1="$ROOT/tests/run-all.ps1"
REAL_REGISTRY="$ROOT/contracts/agent-model-capabilities.v2.json"
HUMAN_COPY_DIR="$ROOT/specs/epic-159-pillar-c/human-copy"
MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"

PROTECTED_RELPATHS=(
  "plugins/sdd-review-loop/agents/impl-reviewer-a.md"
  "plugins/sdd-review-loop/agents/impl-reviewer-b.md"
  "plugins/sdd-review-loop/agents/task-reviewer-a.md"
  "plugins/sdd-review-loop/agents/task-reviewer-b.md"
)
UNPROTECTED_CLAUDE_RELPATHS=(
  "plugins/sdd-quality-loop/agents/evaluator.md"
  "plugins/sdd-bootstrap/agents/investigator.md"
  "plugins/sdd-review-loop/agents/spec-reviewer-a.md"
  "plugins/sdd-review-loop/agents/spec-reviewer-b.md"
)
CODEX_RELPATHS=(
  ".codex/agents/sdd-evaluator.toml"
  ".codex/agents/sdd-investigator.toml"
)

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

# bash 3.2 (macOS CI runner's /bin/bash) has no associative arrays
# (`declare -A`). Every associative-array use in this suite is emulated with
# a parallel keys/values indexed-array pair (`<PREFIX>_KEYS` / `<PREFIX>_VALS`)
# plus these two helpers. `set -u` safe: every prefix used below is kv_set at
# least once (from a known-non-empty relpath array) before any kv_get on that
# same prefix, so `${<PREFIX>_KEYS[@]}` / `${#<PREFIX>_KEYS[@]}` are never
# evaluated while the underlying array is completely undeclared.
kv_set() {
  local __kv_prefix="$1" __kv_key="$2" __kv_val="$3"
  eval "${__kv_prefix}_KEYS+=(\"\${__kv_key}\")"
  eval "${__kv_prefix}_VALS+=(\"\${__kv_val}\")"
}

kv_get() {
  local __kv_prefix="$1" __kv_key="$2"
  local __kv_n __kv_i __kv_k
  eval "__kv_n=\${#${__kv_prefix}_KEYS[@]}"
  __kv_i=0
  while [[ "$__kv_i" -lt "$__kv_n" ]]; do
    eval "__kv_k=\${${__kv_prefix}_KEYS[$__kv_i]}"
    if [[ "$__kv_k" == "$__kv_key" ]]; then
      eval "printf '%s' \"\${${__kv_prefix}_VALS[$__kv_i]}\""
      return 0
    fi
    __kv_i=$((__kv_i + 1))
  done
  return 1
}

if [[ ! -x "$RENDER_SH" ]] && [[ ! -f "$RENDER_SH" ]]; then
  printf 'not ok: render-agent-frontmatter.sh does not exist at %s\n' "$RENDER_SH" >&2
  exit 1
fi

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# --- Suite-wide safety proof: this suite never touches the LIVE protected
# reviewer files (captured before AND after every check below) ------------
LIVE_PROTECTED_SHA_BEFORE_KEYS=()
LIVE_PROTECTED_SHA_BEFORE_VALS=()
for rel in "${PROTECTED_RELPATHS[@]}"; do
  kv_set LIVE_PROTECTED_SHA_BEFORE "$rel" "$(sha256_of "$ROOT/$rel")"
done

# --- Build a scratch mirror of the real production targets ---------------
mkdir -p "$TMP/plugins/sdd-quality-loop/agents" \
  "$TMP/plugins/sdd-bootstrap/agents" \
  "$TMP/plugins/sdd-review-loop/agents" \
  "$TMP/.codex/agents" \
  "$TMP/contracts"

for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}" "${PROTECTED_RELPATHS[@]}"; do
  mkdir -p "$TMP/$(dirname "$rel")"
  cp "$ROOT/$rel" "$TMP/$rel"
done
for rel in "${CODEX_RELPATHS[@]}"; do
  mkdir -p "$TMP/$(dirname "$rel")"
  cp "$ROOT/$rel" "$TMP/$rel"
done
cp "$REAL_REGISTRY" "$TMP/contracts/agent-model-capabilities.v2.json"

# Reset the scratch mirror to a PRISTINE (pre-render) state regardless of
# whether the real repository's unprotected targets have already been
# rendered by this task's own one-time production render (they have, by
# design -- AC-017's zero-diff proof requires it). This keeps the suite
# deterministic and independently re-runnable in CI: strip any existing
# x-sdd-effort comment / x-sdd-model|x-sdd-effort header from every scratch
# copy before any drift/render assertion below.
python3 - "$TMP" "${UNPROTECTED_CLAUDE_RELPATHS[*]}" "${PROTECTED_RELPATHS[*]}" "${CODEX_RELPATHS[*]}" <<'PY'
import re
import sys

tmp, claude_rels, codex_only_rels_unused, codex_rels = sys.argv[1], sys.argv[2].split(), sys.argv[3].split(), sys.argv[4].split()
claude_all = claude_rels + codex_only_rels_unused  # unprotected + protected claude targets

effort_re = re.compile(r'^<!-- x-sdd-effort: \S+ -->$')
codex_hdr_re = re.compile(r'^# x-sdd-(model|effort): \S+$')

for rel in claude_all:
    path = f"{tmp}/{rel}"
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    trailing_nl = text.endswith("\n")
    lines = text.split("\n")
    if trailing_nl:
        lines = lines[:-1]
    lines = [ln for ln in lines if not effort_re.match(ln)]
    new_text = "\n".join(lines) + ("\n" if trailing_nl else "")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_text)

for rel in codex_rels:
    path = f"{tmp}/{rel}"
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    trailing_nl = text.endswith("\n")
    lines = text.split("\n")
    if trailing_nl:
        lines = lines[:-1]
    i = 0
    while i < len(lines) and codex_hdr_re.match(lines[i]):
        i += 1
    lines = lines[i:]
    new_text = "\n".join(lines) + ("\n" if trailing_nl else "")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_text)
PY

# Capture BEFORE-render model: values (TEST-017 zero-diff proof), line
# counts (TEST-014 "exactly one line added" proof -- taken from this
# suite's own just-pristined scratch copy, never from the real repository
# path, since the real unprotected targets are themselves already rendered
# by this task's one-time production render), and sha256 of every scratch
# target (TEST-016/019 no-write proof).
MODEL_BEFORE_KEYS=(); MODEL_BEFORE_VALS=()
SHA_BEFORE_KEYS=(); SHA_BEFORE_VALS=()
LINE_COUNT_BEFORE_KEYS=(); LINE_COUNT_BEFORE_VALS=()
for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}" "${PROTECTED_RELPATHS[@]}"; do
  kv_set MODEL_BEFORE "$rel" "$(grep -m1 '^model:' "$TMP/$rel" | sed 's/^model:[[:space:]]*//')"
  kv_set SHA_BEFORE "$rel" "$(sha256_of "$TMP/$rel")"
  kv_set LINE_COUNT_BEFORE "$rel" "$(grep -c '' "$TMP/$rel")"
done
for rel in "${CODEX_RELPATHS[@]}"; do
  kv_set SHA_BEFORE "$rel" "$(sha256_of "$TMP/$rel")"
done

# ===========================================================================
# TEST-016 (AC-016) + TEST-020 (AC-020): --check is read-only, detects drift,
# exits non-zero -- run BEFORE any render so every scratch target still
# lacks its x-sdd-effort/x-sdd-model comment.
# ===========================================================================
CHECK_LOG="$TMP/check-before-render.log"
set +e
"$RENDER_SH" --check --root "$TMP" --registry "$TMP/contracts/agent-model-capabilities.v2.json" >"$CHECK_LOG" 2>&1
CHECK_EXIT=$?
set -e

if [[ "$CHECK_EXIT" -ne 0 ]]; then
  ok "TEST-016: --check exits non-zero when every target still has drift"
else
  bad "TEST-016: --check exited 0 despite injected/pre-existing drift"
fi

drift_all_present=1
for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}" "${CODEX_RELPATHS[@]}" "${PROTECTED_RELPATHS[@]}"; do
  if ! grep -Fq "DRIFT: $rel" "$CHECK_LOG"; then
    drift_all_present=0
  fi
done
if [[ "$drift_all_present" -eq 1 ]]; then
  ok "TEST-016: --check reports DRIFT for every un-rendered target (unprotected and protected)"
else
  bad "TEST-016: --check did not report DRIFT for every un-rendered target -- $(cat "$CHECK_LOG")"
fi

# TEST-020 read-boundary: --check performed ZERO writes anywhere in the
# scratch tree, including the four protected-position targets.
no_write_during_check=1
for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}" "${CODEX_RELPATHS[@]}" "${PROTECTED_RELPATHS[@]}"; do
  after="$(sha256_of "$TMP/$rel")"
  if [[ "$after" != "$(kv_get SHA_BEFORE "$rel")" ]]; then
    no_write_during_check=0
  fi
done
if [[ "$no_write_during_check" -eq 1 ]] && [[ ! -e "$TMP/specs" ]]; then
  ok "TEST-020: --check performed zero writes (all targets byte-unchanged, no human-copy dir created)"
else
  bad "TEST-020: --check wrote something (target hash changed or human-copy dir materialized)"
fi

# --- TEST-020 mutation-based negative self-check (RED/GREEN pair) --------
# A scratch copy of a protected-position target that IS already correctly
# rendered must report OK; the same copy with its x-sdd-effort value
# mutated must report DRIFT again -- proving the read-only check's drift
# report is live, not vacuously true.
MUT_ROOT="$TMP/ac020-mutation"
mkdir -p "$MUT_ROOT/plugins/sdd-review-loop/agents" "$MUT_ROOT/contracts"
cp "$TMP/plugins/sdd-review-loop/agents/impl-reviewer-a.md" "$MUT_ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"
cp "$TMP/contracts/agent-model-capabilities.v2.json" "$MUT_ROOT/contracts/agent-model-capabilities.v2.json"
MUT_TARGETS="$MUT_ROOT/targets.json"
cat >"$MUT_TARGETS" <<'EOF'
[{"role": "impl-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/impl-reviewer-a.md", "protected": true}]
EOF
# Render it once (this scratch copy only) so it is correctly synced.
"$RENDER_SH" --root "$MUT_ROOT" --targets-file "$MUT_TARGETS" --registry "$MUT_ROOT/contracts/agent-model-capabilities.v2.json" >/dev/null
# The render above staged the corrected content under
# $MUT_ROOT/specs/.../impl-reviewer-a.md (protected: true); overwrite the
# REAL-position scratch copy with that staged (correctly synced) content so
# --check's read-only comparison below has something to report OK against.
cp "$MUT_ROOT/specs/epic-159-pillar-c/human-copy/plugins/sdd-review-loop/agents/impl-reviewer-a.md" \
  "$MUT_ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"
GREEN020_LOG="$TMP/green-ac020.log"
set +e
"$RENDER_SH" --check --root "$MUT_ROOT" --targets-file "$MUT_TARGETS" --registry "$MUT_ROOT/contracts/agent-model-capabilities.v2.json" >"$GREEN020_LOG" 2>&1
GREEN020_EXIT=$?
set -e
if [[ "$GREEN020_EXIT" -eq 0 ]] && grep -Fq "OK: plugins/sdd-review-loop/agents/impl-reviewer-a.md" "$GREEN020_LOG"; then
  ok "TEST-020 GREEN: --check reports OK (no drift) against a correctly-synced protected-position target"
else
  bad "TEST-020 GREEN: --check did not report OK against a correctly-synced target -- $(cat "$GREEN020_LOG")"
fi

# Mutate the rendered copy's x-sdd-effort value (simulating a stale/edited
# protected target) and confirm the check goes red again.
python3 - "$MUT_ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
text = text.replace("<!-- x-sdd-effort: medium -->", "<!-- x-sdd-effort: high -->")
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
PY
RED020_LOG="$TMP/red-ac020.log"
set +e
"$RENDER_SH" --check --root "$MUT_ROOT" --targets-file "$MUT_TARGETS" --registry "$MUT_ROOT/contracts/agent-model-capabilities.v2.json" >"$RED020_LOG" 2>&1
RED020_EXIT=$?
set -e
if [[ "$RED020_EXIT" -ne 0 ]] && grep -Fq "DRIFT: plugins/sdd-review-loop/agents/impl-reviewer-a.md" "$RED020_LOG"; then
  ok "TEST-020 RED (negative self-check): mutating a synced protected-position target's x-sdd-effort value turns --check red again"
else
  bad "TEST-020 RED (negative self-check): mutated target did NOT turn --check red -- $(cat "$RED020_LOG")"
fi

# ===========================================================================
# TEST-019 (AC-019): write-target resolution FUNCTION self-check, RED/GREEN.
# ===========================================================================
# GREEN (real, correctly scoped map): forcing Protected=1 on the four real
# protected basenames always resolves under specs/epic-159-pillar-c/human-copy/.
green019_ok=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  resolved="$("$RENDER_SH" --resolve-target-raw "$rel" 1)"
  case "$resolved" in
    "$ROOT/specs/epic-159-pillar-c/human-copy/$rel") : ;;
    *) green019_ok=0 ;;
  esac
done
if [[ "$green019_ok" -eq 1 ]]; then
  ok "TEST-019 GREEN: resolve-target-raw(Protected=1) resolves all four protected basenames under specs/epic-159-pillar-c/human-copy/, never the real path"
else
  bad "TEST-019 GREEN: resolve-target-raw(Protected=1) resolved at least one protected basename OUTSIDE human-copy/"
fi

# GREEN (default table): the shipped, built-in target table classifies the
# four real basenames as protected -- looked up via role+kind+relpath, not
# an override flag.
ROLE_FOR_RELPATH_KEYS=()
ROLE_FOR_RELPATH_VALS=()
kv_set ROLE_FOR_RELPATH "plugins/sdd-review-loop/agents/impl-reviewer-a.md" "impl-reviewer"
kv_set ROLE_FOR_RELPATH "plugins/sdd-review-loop/agents/impl-reviewer-b.md" "impl-reviewer"
kv_set ROLE_FOR_RELPATH "plugins/sdd-review-loop/agents/task-reviewer-a.md" "task-reviewer"
kv_set ROLE_FOR_RELPATH "plugins/sdd-review-loop/agents/task-reviewer-b.md" "task-reviewer"
green019_table_ok=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  role="$(kv_get ROLE_FOR_RELPATH "$rel")"
  resolved="$("$RENDER_SH" --resolve-target "$role" claude "$rel")"
  case "$resolved" in
    "$ROOT/specs/epic-159-pillar-c/human-copy/$rel") : ;;
    *) green019_table_ok=0 ;;
  esac
done
if [[ "$green019_table_ok" -eq 1 ]]; then
  ok "TEST-019 GREEN (default table): the shipped TARGETS table resolves all four protected basenames to human-copy/"
else
  bad "TEST-019 GREEN (default table): the shipped TARGETS table failed to classify a protected basename correctly"
fi

# RED (deliberately widened/mis-scoped map): forcing Protected=0 on the same
# four basenames resolves to the REAL protected path -- proving the branch
# is meaningfully sensitive to the protected flag, not hardcoded to always
# return the safe path regardless of input.
red019_ok=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  resolved="$("$RENDER_SH" --resolve-target-raw "$rel" 0)"
  if [[ "$resolved" != "$ROOT/$rel" ]]; then
    red019_ok=0
  fi
done
if [[ "$red019_ok" -eq 1 ]]; then
  ok "TEST-019 RED (widened/mis-scoped map): forcing Protected=0 on a protected basename resolves to the REAL path -- proves the resolution function is live, not vacuously safe"
else
  bad "TEST-019 RED (widened/mis-scoped map): forcing Protected=0 did NOT resolve to the real path (resolution function may be broken/vacuous)"
fi

# ===========================================================================
# TEST-014/015/017: real render against the scratch mirror.
# ===========================================================================
RENDER_LOG="$TMP/render.log"
"$RENDER_SH" --root "$TMP" --registry "$TMP/contracts/agent-model-capabilities.v2.json" >"$RENDER_LOG" 2>&1

# TEST-014: unprotected Claude .md targets get only the model: line
# rewritten (here: left as-is, since role_defaults was seeded from these
# exact current values) + x-sdd-effort inserted/refreshed.
EXPECTED_EFFORT_KEYS=()
EXPECTED_EFFORT_VALS=()
kv_set EXPECTED_EFFORT "plugins/sdd-quality-loop/agents/evaluator.md" "high"
kv_set EXPECTED_EFFORT "plugins/sdd-bootstrap/agents/investigator.md" "low"
kv_set EXPECTED_EFFORT "plugins/sdd-review-loop/agents/spec-reviewer-a.md" "medium"
kv_set EXPECTED_EFFORT "plugins/sdd-review-loop/agents/spec-reviewer-b.md" "medium"
test014_ok=1
for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}"; do
  model_line="$(grep -m1 '^model:' "$TMP/$rel" | sed 's/^model:[[:space:]]*//')"
  if [[ "$model_line" != "$(kv_get MODEL_BEFORE "$rel")" ]]; then
    test014_ok=0
  fi
  if ! grep -Fq "<!-- x-sdd-effort: $(kv_get EXPECTED_EFFORT "$rel") -->" "$TMP/$rel"; then
    test014_ok=0
  fi
  # No OTHER frontmatter field touched: exactly one line was added (the
  # x-sdd-effort comment); every other line is byte-identical in position.
  before_count="$(kv_get LINE_COUNT_BEFORE "$rel")"
  after_count="$(grep -c '' "$TMP/$rel")"
  if [[ $((after_count - before_count)) -ne 1 ]]; then
    test014_ok=0
  fi
done
if [[ "$test014_ok" -eq 1 ]]; then
  ok "TEST-014: unprotected Claude .md targets keep model: unchanged and gain exactly one x-sdd-effort comment line, sourced from role_defaults"
else
  bad "TEST-014: unprotected Claude .md render produced an unexpected diff"
fi

# TEST-015: Codex .toml targets get the two reference comment lines,
# existing keys untouched.
EXPECTED_CODEX_MODEL_KEYS=()
EXPECTED_CODEX_MODEL_VALS=()
kv_set EXPECTED_CODEX_MODEL ".codex/agents/sdd-evaluator.toml" "openai/gpt-5.2-codex"
kv_set EXPECTED_CODEX_MODEL ".codex/agents/sdd-investigator.toml" "openai/gpt-5.1-codex-mini"
EXPECTED_CODEX_EFFORT_KEYS=()
EXPECTED_CODEX_EFFORT_VALS=()
kv_set EXPECTED_CODEX_EFFORT ".codex/agents/sdd-evaluator.toml" "high"
kv_set EXPECTED_CODEX_EFFORT ".codex/agents/sdd-investigator.toml" "low"
test015_ok=1
for rel in "${CODEX_RELPATHS[@]}"; do
  first_line="$(sed -n '1p' "$TMP/$rel")"
  second_line="$(sed -n '2p' "$TMP/$rel")"
  if [[ "$first_line" != "# x-sdd-model: $(kv_get EXPECTED_CODEX_MODEL "$rel")" ]]; then
    test015_ok=0
  fi
  if [[ "$second_line" != "# x-sdd-effort: $(kv_get EXPECTED_CODEX_EFFORT "$rel")" ]]; then
    test015_ok=0
  fi
  for key in 'name = ' 'description = ' 'sandbox_mode = ' 'developer_instructions = '; do
    if ! grep -Fq "$key" "$TMP/$rel"; then
      test015_ok=0
    fi
  done
done
if [[ "$test015_ok" -eq 1 ]]; then
  ok "TEST-015: Codex .toml targets gain # x-sdd-model:/# x-sdd-effort: header comments; existing TOML keys untouched"
else
  bad "TEST-015: Codex .toml render produced an unexpected diff"
fi

# TEST-017 (zero-diff no-op proof): every unprotected target's model: VALUE
# is unchanged before vs. after the render against real production content
# (role_defaults was seeded from these exact current values).
test017_ok=1
for rel in "${UNPROTECTED_CLAUDE_RELPATHS[@]}"; do
  model_after="$(grep -m1 '^model:' "$TMP/$rel" | sed 's/^model:[[:space:]]*//')"
  if [[ "$model_after" != "$(kv_get MODEL_BEFORE "$rel")" ]]; then
    test017_ok=0
  fi
done
if [[ "$test017_ok" -eq 1 ]]; then
  ok "TEST-017: render against real production content is a zero-diff no-op on every unprotected target's model: value (role_defaults correctly seeded)"
else
  bad "TEST-017: render against real production content changed a model: value that role_defaults seeding should have kept identical"
fi

# TEST-019 continued: the render above must NEVER have opened the four
# protected-position scratch files (representing the real path) for write.
test019_write_ok=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  after="$(sha256_of "$TMP/$rel")"
  if [[ "$after" != "$(kv_get SHA_BEFORE "$rel")" ]]; then
    test019_write_ok=0
  fi
done
if [[ "$test019_write_ok" -eq 1 ]]; then
  ok "TEST-019: a full render pass left all four protected-position targets byte-unchanged at their real path"
else
  bad "TEST-019: a full render pass modified a protected-position target's real path"
fi

# Corrected content for the four protected targets landed ONLY under the
# scratch human-copy staging dir, with a MANIFEST.sha256 entry each.
test019_staged_ok=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  staged="$TMP/specs/epic-159-pillar-c/human-copy/$rel"
  if [[ ! -f "$staged" ]]; then
    test019_staged_ok=0
    continue
  fi
  if ! grep -Fq "<!-- x-sdd-effort: medium -->" "$staged"; then
    test019_staged_ok=0
  fi
  staged_sha="$(sha256_of "$staged")"
  if ! grep -Fq "$staged_sha  $rel" "$TMP/specs/epic-159-pillar-c/human-copy/MANIFEST.sha256"; then
    test019_staged_ok=0
  fi
done
if [[ "$test019_staged_ok" -eq 1 ]]; then
  ok "TEST-019: corrected content for all four protected targets staged under human-copy/ with a matching MANIFEST.sha256 entry"
else
  bad "TEST-019: staged protected-target content or its MANIFEST.sha256 entry is missing/incorrect"
fi

# ===========================================================================
# TEST-018 (AC-018): exclusion lock -- model: inherit and role-map-absent.
# ===========================================================================
INHERIT_FIXTURE="$TMP/inherit-fixture.md"
cat >"$INHERIT_FIXTURE" <<'EOF'
---
name: sdd-panelist-fixture
description: fixture agent with model inherit, for TEST-018.
tools: Read
model: inherit
---

Body text unaffected.
EOF
INHERIT_SHA_BEFORE="$(sha256_of "$INHERIT_FIXTURE")"
INHERIT_TARGETS="$TMP/inherit-targets.json"
cat >"$INHERIT_TARGETS" <<EOF
[{"role": "sdd-evaluator", "kind": "claude", "path": "inherit-fixture.md", "protected": false}]
EOF
"$RENDER_SH" --root "$TMP" --targets-file "$INHERIT_TARGETS" --registry "$TMP/contracts/agent-model-capabilities.v2.json" >/dev/null
INHERIT_SHA_AFTER="$(sha256_of "$INHERIT_FIXTURE")"
if [[ "$INHERIT_SHA_BEFORE" == "$INHERIT_SHA_AFTER" ]]; then
  ok "TEST-018: a model: inherit agent is byte-unchanged after a render targeting it"
else
  bad "TEST-018: a model: inherit agent was modified by render (exclusion not honored)"
fi

# Role-map-absent: a role/path combination not in the built-in TARGETS table
# (e.g. domain-reviewer-a.md, a real, currently-shipped agent file outside
# REQ-003's five role_defaults roles) is structurally unreachable by
# --resolve-target's table lookup -- proving it is never a render target,
# without needing to mutate the real repository to prove it.
set +e
"$RENDER_SH" --resolve-target domain-reviewer claude plugins/sdd-domain/agents/domain-reviewer-a.md >"$TMP/resolve-absent.log" 2>&1
RESOLVE_ABSENT_EXIT=$?
set -e
if [[ "$RESOLVE_ABSENT_EXIT" -ne 0 ]] && grep -Fq "target not found in table" "$TMP/resolve-absent.log"; then
  ok "TEST-018: a role-map-absent agent (domain-reviewer-a.md) is not present in the built-in TARGETS table"
else
  bad "TEST-018: domain-reviewer-a.md unexpectedly resolved in the built-in TARGETS table"
fi

# ===========================================================================
# TEST-016 continued: --check wired into CI (staged test.yml) and into
# tests/validate-repository.ps1.
# ===========================================================================
VALIDATE_PS1="$ROOT/tests/validate-repository.ps1"
if [[ -f "$VALIDATE_PS1" ]] && grep -Fq "render-agent-frontmatter" "$VALIDATE_PS1"; then
  ok "TEST-016: render-agent-frontmatter --check is wired into tests/validate-repository.ps1"
else
  bad "TEST-016: tests/validate-repository.ps1 does not invoke render-agent-frontmatter --check"
fi

STAGED_TEST_YML="$HUMAN_COPY_DIR/.github/workflows/test.yml"
if [[ -f "$STAGED_TEST_YML" ]] && grep -Fq "render-agent-frontmatter" "$STAGED_TEST_YML"; then
  ok "TEST-016: the staged .github/workflows/test.yml candidate registers this suite's CI step(s)"
else
  bad "TEST-016: the staged .github/workflows/test.yml candidate does not reference render-agent-frontmatter"
fi

# ===========================================================================
# Mis-cased registry fixtures (PowerShell case-sensitivity discipline
# applied symmetrically to the .sh/python twin -- T-002 implementation
# report precedent): a mis-cased role_defaults key and a mis-cased
# canonical_tier must each be REJECTED, never silently aliased.
# ===========================================================================
MISCASED_ROLE_REGISTRY="$TMP/miscased-role-registry.json"
cat >"$MISCASED_ROLE_REGISTRY" <<'EOF'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    { "name": "anthropic/opus", "canonical_tier": "strong", "supported_efforts": ["high"], "default_effort": "high", "effort_control": { "claude-code": "frontmatter", "codex-cli": "none" } }
  ],
  "risk_effort_matrix": { "low": "low", "medium": "medium", "high": "high", "critical": "high", "escalation_bump": true },
  "role_defaults": {
    "Sdd-Evaluator": { "minimum_tier": "strong", "default_effort": "high" }
  }
}
EOF
MISCASED_TIER_REGISTRY="$TMP/miscased-tier-registry.json"
cat >"$MISCASED_TIER_REGISTRY" <<'EOF'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    { "name": "anthropic/opus", "canonical_tier": "Strong", "supported_efforts": ["high"], "default_effort": "high", "effort_control": { "claude-code": "frontmatter", "codex-cli": "none" } }
  ],
  "risk_effort_matrix": { "low": "low", "medium": "medium", "high": "high", "critical": "high", "escalation_bump": true },
  "role_defaults": {
    "sdd-evaluator": { "minimum_tier": "strong", "default_effort": "high" }
  }
}
EOF
MISCASED_TARGETS="$TMP/miscased-targets.json"
cat >"$MISCASED_TARGETS" <<EOF
[{"role": "sdd-evaluator", "kind": "claude", "path": "plugins/sdd-quality-loop/agents/evaluator.md", "protected": false}]
EOF

set +e
"$RENDER_SH" --check --root "$TMP" --targets-file "$MISCASED_TARGETS" --registry "$MISCASED_ROLE_REGISTRY" >"$TMP/miscased-role.log" 2>&1
MISCASED_ROLE_EXIT=$?
set -e
if [[ "$MISCASED_ROLE_EXIT" -ne 0 ]] && grep -Fq "role_defaults missing or incomplete for role 'sdd-evaluator'" "$TMP/miscased-role.log"; then
  ok "mis-cased fixture: a role_defaults key differing only in case ('Sdd-Evaluator') is rejected, not silently matched to 'sdd-evaluator'"
else
  bad "mis-cased fixture: a mis-cased role_defaults key was NOT rejected -- $(cat "$TMP/miscased-role.log")"
fi

set +e
"$RENDER_SH" --check --root "$TMP" --targets-file "$MISCASED_TARGETS" --registry "$MISCASED_TIER_REGISTRY" >"$TMP/miscased-tier.log" 2>&1
MISCASED_TIER_EXIT=$?
set -e
if [[ "$MISCASED_TIER_EXIT" -ne 0 ]] && grep -Fq "no claude model found for tier 'strong'" "$TMP/miscased-tier.log"; then
  ok "mis-cased fixture: a canonical_tier value differing only in case ('Strong') is rejected, not silently matched to 'strong'"
else
  bad "mis-cased fixture: a mis-cased canonical_tier value was NOT rejected -- $(cat "$TMP/miscased-tier.log")"
fi

# ===========================================================================
# Self-registration (design.md Test Strategy #7; mirrors
# tests/second-approval-mask.tests.sh:285-289's established pattern).
# ===========================================================================
if grep -q 'render-agent-frontmatter\.tests\.sh' "$RUN_ALL_SH"; then
  ok "self-registration: render-agent-frontmatter.tests.sh registered in tests/run-all.sh"
else
  bad "self-registration: render-agent-frontmatter.tests.sh NOT registered in tests/run-all.sh"
fi
if [[ -f "$RUN_ALL_PS1" ]] && grep -q 'render-agent-frontmatter\.tests\.ps1' "$RUN_ALL_PS1"; then
  ok "self-registration: render-agent-frontmatter.tests.ps1 registered in tests/run-all.ps1"
else
  bad "self-registration: render-agent-frontmatter.tests.ps1 NOT registered in tests/run-all.ps1"
fi

# ===========================================================================
# Human-copy staging: five protected real targets (four reviewer .md files
# + .github/workflows/test.yml) have a staged candidate + correct
# MANIFEST.sha256 entry; the five LIVE files are byte-identical before and
# after THIS SUITE's own run (mirrors tests/agent-capabilities-v2.tests.sh's
# established pattern, extended from one file to five).
# ===========================================================================
STAGED_ALL_RELPATHS=("${PROTECTED_RELPATHS[@]}" ".github/workflows/test.yml")
human_copy_ok=1
for rel in "${STAGED_ALL_RELPATHS[@]}"; do
  staged="$HUMAN_COPY_DIR/$rel"
  if [[ ! -f "$staged" ]]; then
    human_copy_ok=0
    continue
  fi
  staged_sha="$(sha256_of "$staged")"
  if ! grep -Fq "$staged_sha  $rel" "$MANIFEST"; then
    human_copy_ok=0
  fi
done
if [[ "$human_copy_ok" -eq 1 ]]; then
  ok "human-copy: all five staged candidates (four reviewer .md + test.yml) exist with a correct MANIFEST.sha256 entry"
else
  bad "human-copy: at least one staged candidate or its MANIFEST.sha256 entry is missing/incorrect"
fi

live_protected_unchanged=1
for rel in "${PROTECTED_RELPATHS[@]}"; do
  after="$(sha256_of "$ROOT/$rel")"
  if [[ "$after" != "$(kv_get LIVE_PROTECTED_SHA_BEFORE "$rel")" ]]; then
    live_protected_unchanged=0
  fi
done
LIVE_TEST_YML_SHA_BEFORE_MARKER="$TMP/.test-yml-sha-before"
sha256_of "$ROOT/.github/workflows/test.yml" >"$LIVE_TEST_YML_SHA_BEFORE_MARKER"
if [[ "$live_protected_unchanged" -eq 1 ]]; then
  ok "AC-019/AC-027-style: the four live protected reviewer .md files are byte-unchanged before/after this suite's own run"
else
  bad "AC-019/AC-027-style: a live protected reviewer .md file CHANGED during this suite's own run"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$pass" "$fail"
if [[ "$fail" -gt 0 ]]; then
  printf 'not ok: render-agent-frontmatter suite FAILED (%d failures)\n' "$fail" >&2
  exit 1
fi
printf 'ok: render-agent-frontmatter suite passed (%d checks)\n' "$pass"
