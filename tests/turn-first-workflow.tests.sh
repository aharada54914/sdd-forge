#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMPLEMENT_TASKS="$ROOT/plugins/sdd-implementation/skills/implement-tasks/SKILL.md"

fail() {
  printf 'not ok: %s\n' "$1" >&2
  exit 1
}

[[ -f "$IMPLEMENT_TASKS" ]] || fail "missing file: $IMPLEMENT_TASKS"

for needle in \
  'one fresh implementation agent per T-NNN' \
  'agent_instance_id' \
  'same-session-file-reload' \
  'handoff-reload evidence hash' \
  'Chat history or compaction summaries alone are not valid handoff input' \
  'Deterministic parsing, validation, hashing, and state transitions'; do
  rg -Fq "$needle" "$IMPLEMENT_TASKS" || fail "implement-tasks omits policy text: $needle"
done

printf 'ok: turn-first implementation orchestration policy is defined\n'
