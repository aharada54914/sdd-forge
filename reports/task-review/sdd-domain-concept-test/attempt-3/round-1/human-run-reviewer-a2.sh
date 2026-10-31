#!/usr/bin/env bash
# Human-only launch for the already-reserved #290 task reviewer A (sequence 1203).
# Do not reserve this identity again. Do not use this script for a second launch.
set -euo pipefail
set -C

repo=/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge
cd "$repo"

round=reports/task-review/sdd-domain-concept-test/attempt-3/round-1
manifest=reports/review-context/sdd-domain-concept-test-task-a3r1-a2-invocation.json
envelope="$round/reviewer-a2-claude-envelope.json"
diagnostics="$round/reviewer-a2-claude-stderr.log"

rtk proxy bash plugins/sdd-review-loop/scripts/task-review-precheck.sh sdd-domain-concept-test 3 1 --verify-inputs

# Non-reserving validation of the existing reservation; the pre-append ledger
# digest in the manifest is intentionally stale after sequence 1203 was appended.
receipt=$(rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh "$manifest" "$repo")
expected='REVIEW_CONTEXT_OK cdaea05c805c5ba1b2f6d40ed9fa2d88f9b31e2cae786594042ee91cd2db56e3 sequence=1203 previous_record_sha256=f3e87c65dc91941ffafca5cf7f1896f366174496d35b7d392e01edfa3ef08d29 pre_append_tip_sequence=- identity_unique=yes'
if [[ "$receipt" != "$expected" ]]; then
  printf '%s\n' 'Existing reservation receipt differs; reviewer was not launched.' >&2
  exit 1
fi
printf '%s\n' "$receipt"

if [[ -e "$envelope" || -e "$diagnostics" ]]; then
  printf '%s\n' 'Reviewer output path already exists; refusing to overwrite.' >&2
  exit 1
fi

schema='{"type":"object","properties":{"schema":{"const":"task-reviewer-a/v1"},"stage":{"const":"task-review"},"role":{"const":"reviewer-a"},"feature":{"const":"sdd-domain-concept-test"},"attempt":{"const":3},"round":{"const":1},"run_id":{"type":"string"},"host_session_id":{"type":"string"},"manifest":{"type":"array"},"verdict":{"enum":["PASS","NEEDS_WORK","BLOCKED"]},"checks":{"type":"array"},"findings":{"type":"array"}},"required":["schema","stage","role","feature","attempt","round","run_id","host_session_id","manifest","verdict","checks","findings"]}'
prompt='Act as task-reviewer-a for post-implementation provenance re-review, feature sdd-domain-concept-test attempt 3 round 1. The sole invocation manifest is reports/review-context/sdd-domain-concept-test-task-a3r1-a2-invocation.json. The caller reserved it: REVIEW_CONTEXT_OK cdaea05c805c5ba1b2f6d40ed9fa2d88f9b31e2cae786594042ee91cd2db56e3 sequence=1203 previous_record_sha256=f3e87c65dc91941ffafca5cf7f1896f366174496d35b7d392e01edfa3ef08d29 pre_append_tip_sequence=1202 identity_unique=yes. Read review-context-boundary.md before checking provenance. Do not rerun validator. Read only allowed substantive inputs. Return canonical task-reviewer-a/v1 JSON, no Markdown. Do not write files.'

rtk proxy claude -p --model sonnet --effort medium \
  --session-id 41ac8975-bb4d-4516-9dd1-e48369d9d97c \
  --append-system-prompt-file plugins/sdd-review-loop/agents/task-reviewer-a.md \
  --tools Read,Grep,Glob,Bash --disallowedTools Write,Edit,NotebookEdit \
  --permission-mode plan --output-format json --json-schema "$schema" \
  "$prompt" > "$envelope" 2> "$diagnostics"
