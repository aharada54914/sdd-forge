#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CORPUS="$ROOT/tests/fixtures/structural-fixture-corpus"
CANON="$ROOT/tests/lib/markdown-ast-canonicalizer.sh"
STATE=""
FIXTURE=""
DRY=0
while (($#)); do
  case "$1" in
    --state) STATE="${2:?missing state}"; shift 2 ;;
    --fixture) FIXTURE="${2:?missing fixture}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "usage: ${0##*/} --state F1|F2|F3|F4 [--fixture file | --dry-run]" >&2; exit 2 ;;
  esac
done
[[ "$STATE" =~ ^F[1-4]$ ]] || { echo 'state must be F1 through F4' >&2; exit 2; }
if [[ -z "$FIXTURE" && "$DRY" -eq 0 ]]; then
  [[ -n "${SDD_LIVE_MODEL_CMD:-}" ]] || { echo 'SDD_LIVE_MODEL_CMD is required' >&2; exit 2; }
  FIXTURE="$(mktemp "${TMPDIR:-/tmp}/live-refresh.XXXXXX")"
  trap 'rm -f -- "$FIXTURE"' EXIT
  printf '%s\n' "Generate the complete structural-fixture-corpus/v1 JSON envelope for $STATE. Return JSON only; do not use markdown fences." | "$SDD_LIVE_MODEL_CMD" > "$FIXTURE"
fi

case "$STATE" in F1) target="$CORPUS/f1-full.json"; track=full;; F2) target="$CORPUS/f2-lite.json"; track=lite;; F3) target="$CORPUS/f3-advisory.json"; track=full;; F4) target="$CORPUS/f4-required.json"; track=full;; esac
tmp="$(mktemp -d "${TMPDIR:-/tmp}/live-refresh-check.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
[[ -f "$FIXTURE" ]] || fail 'fixture input does not exist'
jq -e --arg state "$STATE" --arg refresh 'tests/structural-compatibility-live-refresh.tests.sh' \
  '.schema == "structural-fixture-corpus/v1" and .fixture_state == $state and (.recorded_at_model | type == "string" and length > 0) and (.recorded_at_commit | type == "string" and test("^[0-9a-f]{40}$")) and (.artifacts | type == "array" and length > 0 and all(.[]; (.path | type == "string" and length > 0) and (.content | type == "string"))) and ([.artifacts[].path] | length == (unique | length)) and .refresh_procedure == $refresh' "$FIXTURE" >/dev/null || fail 'invalid corpus envelope'

skill="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
if [[ "$track" == full ]]; then
  mapfile -t expected < <(awk '/^## Required Outputs$/ { on=1; next } on && /^Phase 2 outputs/ { exit } on && /^- `specs\/<feature>\/[^`]+\.md`$/ { x=$0; sub(/^- `specs\/<feature>\//,"",x); sub(/`$/,"",x); print x }' "$skill")
else
  skill="$ROOT/plugins/sdd-lite/skills/lite-spec/SKILL.md"
  mapfile -t expected < <(awk '/次の3ファイルを `specs\/<feature>\/` に生成/ { on=1; next } on && /^4\./ { exit } on && /- `[^`]+\.md`/ { x=$0; sub(/^.*- `/,"",x); sub(/`.*/,"",x); print x }' "$skill")
fi
jq -r '.artifacts[].path' "$FIXTURE" | LC_ALL=C sort > "$tmp/actual"
printf '%s\n' "${expected[@]}" | LC_ALL=C sort > "$tmp/expected"
cmp -s "$tmp/expected" "$tmp/actual" || fail 'required output paths/count differ'
while IFS= read -r path; do
  jq -er --arg path "$path" '.artifacts[] | select(.path == $path) | .content' "$FIXTURE" > "$tmp/artifact.md" || fail "missing $path"
  bash "$CANON" "$tmp/artifact.md" > "$tmp/live.ast" || fail "invalid markdown structure: $path"
  template="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/${path%.md}.template.md"
  if [[ "$track" == lite ]]; then
    case "$path" in requirements.md) template="$ROOT/plugins/sdd-lite/templates/requirements-lite.md";; design.md) template="$ROOT/plugins/sdd-lite/templates/design-lite.md";; tasks.md) template="$ROOT/plugins/sdd-lite/templates/tasks-lite.md";; esac
  fi
  bash "$CANON" "$template" > "$tmp/template.ast" || fail "invalid reference template: $path"
  cmp -s "$tmp/live.ast" "$tmp/template.ast" || fail "structural mismatch: $path"
done < "$tmp/expected"
if [[ "$DRY" -eq 1 ]]; then
  if [[ "${SDD_LIVE_REFRESH_SELF_CHECK:-0}" == 1 ]]; then echo 'PASS: fixture validates'; exit 0; fi
  echo 'PASS: fixture validates; dry-run left corpus unchanged'
  before="$(shasum -a 256 "$target" | awk '{print $1}')"
  jq '.artifacts[0].content = "---\nbroken frontmatter"' "$target" > "$tmp/rejected.json"
  if SDD_LIVE_REFRESH_SELF_CHECK=1 "$0" --state "$STATE" --fixture "$tmp/rejected.json" --dry-run >/dev/null 2>&1; then fail 'malformed fixture was accepted'; fi
  after="$(shasum -a 256 "$target" | awk '{print $1}')"
  [[ "$before" == "$after" ]] || fail 'rejected fixture modified corpus'
  echo 'PASS: malformed fixture rejected without corpus modification'
  exit 0
fi
jq --arg model "${SDD_LIVE_MODEL_NAME:-${SDD_LIVE_MODEL_CMD:-live-model}}" --arg commit "$(git -C "$ROOT" rev-parse HEAD)" '.recorded_at_model=$model | .recorded_at_commit=$commit' "$FIXTURE" > "$target.tmp.$$" || fail 'cannot prepare corpus JSON'
mv -f -- "$target.tmp.$$" "$target"
echo "PASS: refreshed $STATE corpus entry"
