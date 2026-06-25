#!/usr/bin/env bash
# T-006: review roles must remain distinct fresh-context agents.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="$ROOT/plugins/sdd-review-loop/agents"
fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

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

printf 'ok: spec, implementation, and task review roles are distinct and isolated\n'
