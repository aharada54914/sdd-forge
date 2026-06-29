#!/usr/bin/env bash
# TEST-016: preserve the Draft-to-Approved authorization boundary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
GUARD_DIR="$ROOT/plugins/sdd-quality-loop/scripts"
IMPLEMENT_TASK="$ROOT/plugins/sdd-implementation/skills/implement-task/SKILL.md"
PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok() {
  printf 'ok: %s\n' "$*"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  FAIL=$((FAIL + 1))
}

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    ok "$name"
  else
    fail "$name (expected $expected, got $actual)"
  fi
}

write_task() {
  local approval="$1"
  cat >"$WORK/tasks.md" <<EOF
## T-900 Approval fixture

Approval: $approval

Status: Planned
EOF
}

task_is_eligible() {
  awk '
    /^Approval:/ {
      value = $0
      sub(/^Approval:[[:space:]]*/, "", value)
      approved = (value == "Approved" || value ~ /^Approved \(.+\)$/)
    }
    /^Status:/ {
      value = $0
      sub(/^Status:[[:space:]]*/, "", value)
      planned = (value == "Planned")
    }
    END { exit !(approved && planned) }
  ' "$WORK/tasks.md"
}

approval_payload() {
  python3 - "$WORK/tasks.md" <<'PY'
import json
import sys

print(json.dumps({
    "tool_name": "edit",
    "tool_input": {
        "file_path": sys.argv[1],
        "old_string": "Approval: Draft",
        "new_string": "Approval: Approved",
    },
}))
PY
}

mint_sudo_token() {
  local expires="$1"
  local signature_mode="${2:-valid}"
  python3 - "$WORK" "$expires" "$signature_mode" >"$WORK/SDD_SUDO" <<'PY'
import hashlib
import hmac
import os
import sys
import time

repo = os.path.realpath(sys.argv[1])
expires = int(sys.argv[2])
signature_mode = sys.argv[3]
issued = int(time.time()) - 1
issuer = "approval-boundary-test"
nonce = "a5" * 32
canonical = "\n".join([issuer, nonce, repo, str(issued), str(expires)])
signature = hmac.new(
    b"approval-boundary-test-key",
    canonical.encode("utf-8"),
    hashlib.sha256,
).hexdigest()
if signature_mode == "invalid":
    signature = "0" * 64
print(
    f"issuer: {issuer}\n"
    f"nonce: {nonce}\n"
    f"repo: {repo}\n"
    f"issued-epoch: {issued}\n"
    f"expires-epoch: {expires}\n"
    f"sig: {signature}",
    end="",
)
PY
}

guard_exit() {
  local runtime="$1"
  local payload="$2"
  local code=0
  if [[ "$runtime" == "python" ]]; then
    printf '%s' "$payload" |
      CLAUDE_PROJECT_DIR="$WORK" SDD_SUDO_KEY="$SDD_SUDO_KEY" \
        python3 "$GUARD_DIR/sdd-hook-guard.py" --emit exit \
        >/dev/null 2>&1 || code=$?
  else
    printf '%s' "$payload" |
      CLAUDE_PROJECT_DIR="$WORK" SDD_SUDO_KEY="$SDD_SUDO_KEY" \
        node "$GUARD_DIR/sdd-hook-guard.js" --emit exit \
        >/dev/null 2>&1 || code=$?
  fi
  printf '%s' "$code"
}

command -v python3 >/dev/null 2>&1 || {
  echo "FAIL: python3 is required" >&2
  exit 1
}
command -v node >/dev/null 2>&1 || {
  echo "FAIL: node is required" >&2
  exit 1
}

export SDD_SUDO_KEY="approval-boundary-test-key"
PAYLOAD="$(approval_payload)"

grep -Fq 'task with `Approval: Approved` and `Status: Planned`' "$IMPLEMENT_TASK" &&
  ok "implement-task selects only Approved + Planned tasks" ||
  fail "implement-task Approved + Planned selection rule is missing"
grep -Fq 'Do not start a task whose approval is not `Approved`.' "$IMPLEMENT_TASK" &&
  ok "implement-task explicitly rejects non-Approved tasks" ||
  fail "implement-task non-Approved rejection rule is missing"

write_task "Draft"
rm -f "$WORK/SDD_SUDO"
for runtime in python node; do
  assert_eq "$runtime denies Draft-to-Approved without authorization" 2 \
    "$(guard_exit "$runtime" "$PAYLOAD")"
done
if task_is_eligible; then
  fail "Draft task is ineligible for implement-task"
else
  ok "Draft task is ineligible for implement-task"
fi

# A human approval is a direct on-disk edit outside the agent hook.
write_task "Approved (human-reviewer 2026-06-29T00:00:00Z)"
if task_is_eligible; then
  ok "human-approved Planned task is eligible"
else
  fail "human-approved Planned task is eligible"
fi

write_task "Draft"
mint_sudo_token "$(( $(date +%s) + 3600 ))"
for runtime in python node; do
  assert_eq "$runtime accepts active signed sudo" 0 \
    "$(guard_exit "$runtime" "$PAYLOAD")"
done
write_task "Approved (sudo 2026-06-29T00:00:00Z)"
if task_is_eligible; then
  ok "active-sudo-approved Planned task is eligible"
else
  fail "active-sudo-approved Planned task is eligible"
fi

for mode in expired invalid; do
  write_task "Draft"
  if [[ "$mode" == "expired" ]]; then
    mint_sudo_token "$(( $(date +%s) - 60 ))"
  else
    mint_sudo_token "$(( $(date +%s) + 3600 ))" invalid
  fi
  for runtime in python node; do
    assert_eq "$runtime rejects $mode signed sudo" 2 \
      "$(guard_exit "$runtime" "$PAYLOAD")"
  done
  if task_is_eligible; then
    fail "$mode-sudo Draft task remains ineligible"
  else
    ok "$mode-sudo Draft task remains ineligible"
  fi
done

# After additive fixtures are removed, this assertion command exits 0 only
# when the baseline Draft rejection still occurs.
write_task "Draft"
rm -f "$WORK/SDD_SUDO"
baseline_code="$(guard_exit python "$PAYLOAD")"
if [[ "$baseline_code" == "2" ]]; then
  ok "baseline Draft-rejection assertion exits 0"
else
  fail "baseline Draft-rejection assertion exits 0 (guard exit $baseline_code)"
fi

printf '\nTEST-016 results: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
