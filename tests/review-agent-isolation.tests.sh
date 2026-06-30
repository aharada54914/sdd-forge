#!/usr/bin/env bash
# T-005: review roles must remain distinct fresh-context agents.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="$ROOT/plugins/sdd-review-loop/agents"
EVALUATOR="$ROOT/plugins/sdd-quality-loop/agents/evaluator.md"
QUALITY_GATE="$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
VALIDATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
VALIDATOR_PS1="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

for stage in spec impl task; do
  for reviewer in a b; do
    file="$AGENTS/${stage}-reviewer-${reviewer}.md"
    [[ -f "$file" ]] || fail "missing ${stage} reviewer ${reviewer}"
    grep -Fq "name: ${stage}-reviewer-${reviewer}" "$file" || fail "wrong name in ${file##*/}"
    grep -Fq 'disallowedTools: Write, Edit, NotebookEdit' "$file" || fail "${file##*/} must be read-only"
    tr '\n' ' ' < "$file" | grep -Eqi 'fresh.*context|never share context' || fail "${file##*/} must require a fresh independent context"
    grep -Fq '"stage"' "$file" || fail "${file##*/} must emit stage"
    grep -Fq '"role"' "$file" || fail "${file##*/} must emit role"
    grep -Fq '"run_id"' "$file" || fail "${file##*/} must emit run ID"
    grep -Fq '"host_session_id"' "$file" || fail "${file##*/} must emit host session ID"
    grep -Fq '"allowed_input_manifest"' "$file" || fail "${file##*/} must emit allowed input manifest"
    for blocked in spec impl task; do
      grep -Fq "reports/$blocked-review/**/reviewer-*.json" "$file" || fail "${file##*/} must deny $blocked raw reviewer reports"
    done
  done
done

[[ -f "$EVALUATOR" && -f "$QUALITY_GATE" ]] || fail "evaluator isolation artifacts are missing"
grep -Fq 'fresh context' "$EVALUATOR" || fail "evaluator must require a fresh context"
grep -Fq 'never share' "$EVALUATOR" || fail "evaluator must reject implementation context reuse"
grep -Fq 'disallowedTools: Write, Edit, NotebookEdit' "$EVALUATOR" || fail "evaluator must be read-only"
grep -Fq 'allowed-input manifest' "$EVALUATOR" || fail "evaluator must require an allowed-input manifest"
grep -Fq 'canonical repository-relative path' "$EVALUATOR" || fail "evaluator inputs must use canonical paths"
grep -Fq 'lowercase SHA-256' "$EVALUATOR" || fail "evaluator inputs must be hash-bound"
for rejection in 'manifest is missing' 'unlisted path' 'hash mismatch' 'chat-only input' 'reuses any implementation/review/evaluation session'; do
  grep -Fq "$rejection" "$EVALUATOR" || fail "evaluator must reject $rejection"
done
for field in RUN_ID HOST_SESSION_ID ALLOWED_INPUT_MANIFEST; do
  grep -Fq "$field:" "$EVALUATOR" || fail "evaluator output must bind $field"
done
grep -Fq 'No same-session fallback is permitted for the evaluator.' "$QUALITY_GATE" ||
  fail "quality gate must fail closed instead of using evaluator fallback"
grep -Fq 'persist a canonical allowed-input manifest' "$QUALITY_GATE" ||
  fail "quality gate must persist the evaluator input boundary"
grep -Fq 'Reverify every hash immediately before launch' "$QUALITY_GATE" ||
  fail "quality gate must verify evaluator inputs at launch"
[[ -x "$VALIDATOR_SH" && -f "$VALIDATOR_PS1" ]] ||
  fail "paired deterministic review-context validators are missing"

# The persisted contract representation must be able to prove six independent
# reviewer sessions and reject raw reviewer-report paths in their manifests.
fixture='[
 {"stage":"spec","role":"spec-reviewer-a","run_id":"r1","host_session_id":"s1","allowed_input_manifest":[{"path":"specs/f/requirements.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
 {"stage":"spec","role":"spec-reviewer-b","run_id":"r2","host_session_id":"s2","allowed_input_manifest":[{"path":"specs/f/requirements.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
 {"stage":"impl","role":"impl-reviewer-a","run_id":"r3","host_session_id":"s3","allowed_input_manifest":[{"path":"specs/f/design.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
 {"stage":"impl","role":"impl-reviewer-b","run_id":"r4","host_session_id":"s4","allowed_input_manifest":[{"path":"specs/f/design.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
 {"stage":"task","role":"task-reviewer-a","run_id":"r5","host_session_id":"s5","allowed_input_manifest":[{"path":"specs/f/tasks.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
 {"stage":"task","role":"task-reviewer-b","run_id":"r6","host_session_id":"s6","allowed_input_manifest":[{"path":"specs/f/tasks.md","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}
]'
printf '%s\n' "$fixture" | jq -e 'length == 6 and ([.[].role] | unique | length == 6) and ([.[].run_id] | unique | length == 6) and ([.[].host_session_id] | unique | length == 6) and all(.[]; all(.allowed_input_manifest[]; (.path | contains("reviewer-") | not)))' >/dev/null || fail 'six-role contract must carry unique sessions and no raw reports'

# The launch boundary validates all six reviewers plus the evaluator together,
# including real hashes and exclusion of earlier implementation identities.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repository/specs/f"
printf 'requirements\n' > "$tmp/repository/specs/f/requirements.md"
input_hash="$(sha256 "$tmp/repository/specs/f/requirements.md")"
roles='["spec-reviewer-a","spec-reviewer-b","impl-reviewer-a","impl-reviewer-b","task-reviewer-a","task-reviewer-b","sdd-evaluator"]'
jq -n --argjson roles "$roles" --arg hash "$input_hash" '
  {
    schema:"review-context-set/v1",
    input_mode:"file-manifest",
    fallback_mode:"none",
    reserved_run_ids:["implementation-run"],
    reserved_host_session_ids:["implementation-session"],
    contexts:[$roles[] as $role |
      {
        role:$role,
        run_id:($role + "-run"),
        host_session_id:($role + "-session"),
        read_only:true,
        allowed_input_manifest:[
          {path:"specs/f/requirements.md",sha256:$hash}
        ]
      }
    ]
  }' > "$tmp/valid.json"

run_bash() {
  "$VALIDATOR_SH" "$1" "$tmp/repository" >/dev/null 2>&1
}
run_pwsh() {
  pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
    -Manifest "$1" -RepositoryRoot "$tmp/repository" >/dev/null 2>&1
}
run_bash "$tmp/valid.json" || fail 'Bash rejected a valid seven-role context set'
if command -v pwsh >/dev/null 2>&1; then
  run_pwsh "$tmp/valid.json" || fail 'PowerShell rejected a valid seven-role context set'
fi

assert_rejected() {
  local name="$1" filter="$2" candidate="$tmp/${name}.json"
  jq "$filter" "$tmp/valid.json" > "$candidate"
  if run_bash "$candidate"; then fail "Bash accepted invalid context set: $name"; fi
  if command -v pwsh >/dev/null 2>&1 && run_pwsh "$candidate"; then
    fail "PowerShell accepted invalid context set: $name"
  fi
}
assert_rejected missing-manifest 'del(.contexts[0].allowed_input_manifest)'
assert_rejected unlisted-path '.contexts[0].allowed_input_manifest[0].path = "specs/f/unlisted.md"'
assert_rejected hash-mismatch '.contexts[0].allowed_input_manifest[0].sha256 = ("b" * 64)'
assert_rejected chat-only '.input_mode = "chat-only"'
assert_rejected reused-review-session '.contexts[6].host_session_id = .contexts[0].host_session_id'
assert_rejected reused-implementation-session '.contexts[6].host_session_id = .reserved_host_session_ids[0]'
assert_rejected writable-context '.contexts[6].read_only = false'
assert_rejected fallback-enabled '.fallback_mode = "same-session-file-reload"'

printf 'ok: spec, implementation, and task review roles are distinct and isolated\n'
