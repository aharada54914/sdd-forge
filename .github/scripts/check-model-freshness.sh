#!/usr/bin/env bash
# check-model-freshness.sh -- weekly model-registry freshness check
# (T-003 / Issue #157 / epic-159-pillar-d REQ-002).
#
# Invoked by .github/workflows/model-freshness-check.yml on its weekly
# schedule or a manual workflow_dispatch. Best-effort fetches the official
# Anthropic and OpenAI model-listing sources, diffs the fetched text against
# contracts/agent-model-capabilities.v2.json's models[].name entries, and
# either:
#   - fetch fails for EITHER vendor -> posts/updates a "取得不能" (fetch
#     unavailable) comment on a dedicated tracking issue and exits 0. This
#     is the ONE fail-SOFT branch in this script (requirements.md Edge
#     Cases "External-dependency fail-soft", AC-006) -- a source outage
#     must never fail the CI job.
#   - both fetches succeed and a divergence is found -> files (or dedupes
#     against an already-open) an issue labeled `workflow-improvement`
#     titled with the `[model-freshness-divergence]` stable marker (AC-007).
#   - both fetches succeed and no divergence is found -> exits 0 with zero
#     side effects (AC-020).
#
# Security boundaries (Security Boundaries B1/B2, AC-021): fetched content
# is untrusted diff input only -- it is NEVER executed, NEVER written
# verbatim into any repository file, and NEVER embedded verbatim into an
# issue body. Only model-ID tokens that pass the charset allowlist
# `[A-Za-z0-9.-]` (and additionally contain at least one digit, this
# script's own conservative-heuristic noise filter -- Non-goals) ever reach
# an issue body. This script never opens any path under `contracts/` for
# writing (Security Boundaries B2) -- registry corrections remain a
# human-reviewed change (T-002-shaped), never automated here.
#
# Structured as three separable, independently-testable functions
# (design.md API/Contract Plan):
#   fetch_source_or_unavailable  -- fixture-injectable fetch (or curl)
#   compute_divergence            -- pure allowlist-validated diff
#   file_or_dedupe_issue          -- marker-literal dedup filing via gh
#
# Test injection points (read by tests/model-freshness-check.tests.sh, never
# by a live run): ANTHROPIC_FIXTURE_SOURCE / OPENAI_FIXTURE_SOURCE (local
# file paths substituted for the real network fetch) and
# MODEL_FRESHNESS_REGISTRY_PATH (a fixture-scoped registry copy substituted
# for the real contracts/agent-model-capabilities.v2.json -- security-spec.md
# B4: fixtures are mktemp-scoped and never the real repository/network
# state).
#
# No `.ps1` twin of this script exists (recorded non-twin, REQ-004/AC-016):
# it only ever runs inside a GitHub Actions ubuntu-latest runner, mirroring
# the existing `.github/scripts/self-improvement-pr-guard.sh` non-twin
# precedent. Its LOCKING suite (tests/model-freshness-check.tests.sh/.ps1)
# IS a full twin pair.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

# Stable title markers (requirements.md Field Definitions) -- the literal,
# dedup-bearing substrings shared verbatim with D1's manual-filing checklist
# text (docs/contributor/workflow-detail.md).
DIVERGENCE_MARKER='[model-freshness-divergence]'
UNAVAILABLE_MARKER='[model-freshness-fetch-unavailable]'

DIVERGENCE_TITLE="Model registry divergence detected ${DIVERGENCE_MARKER}"
UNAVAILABLE_TITLE="Model freshness check: source fetch unavailable ${UNAVAILABLE_MARKER}"

# Canonical source list -- cited verbatim, identical to REQ-001's own
# checklist text (docs/contributor/workflow-detail.md), so a human reading
# either surface sees the same list (Global Constraints: "T-003 is blocked
# on T-001 ... so the two surfaces cite ONE canonical source list").
CANONICAL_SOURCE_LIST='参照する正典ソース: Anthropic 公式 docs（models overview）/ Anthropic blog、OpenAI developers docs（Codex）/ OpenAI blog、各 CLI（Claude Code / Codex CLI / Copilot CLI）のリリースノート'

# Real vendor source URLs (env-overridable; never read when a fixture
# injection point is set -- see fetch_source_or_unavailable). Recorded in
# the implementation report (design.md External Integrations).
ANTHROPIC_SOURCE_URL="${ANTHROPIC_SOURCE_URL:-https://docs.anthropic.com/en/docs/about-claude/models}"
OPENAI_SOURCE_URL="${OPENAI_SOURCE_URL:-https://platform.openai.com/docs/models}"

REGISTRY_FILE="${MODEL_FRESHNESS_REGISTRY_PATH:-${ROOT}/contracts/agent-model-capabilities.v2.json}"
REPO="${GITHUB_REPOSITORY:-}"

# ---------------------------------------------------------------------------
# fetch_source_or_unavailable <vendor> <url>
#   vendor: "anthropic" | "openai" -- selects the fixture injection point.
#   Prints the fetched text to stdout and returns 0 on success; returns 1 on
#   any failure (curl error/timeout, or a fixture path that does not exist)
#   WITHOUT ever exiting the script itself (INV-009's fail-soft mandate --
#   the caller, main(), decides what a failure means).
# ---------------------------------------------------------------------------
fetch_source_or_unavailable() {
  local vendor="$1"
  local url="$2"
  local fixture_path=""

  case "$vendor" in
    anthropic) fixture_path="${ANTHROPIC_FIXTURE_SOURCE:-}" ;;
    openai)    fixture_path="${OPENAI_FIXTURE_SOURCE:-}" ;;
  esac

  if [ -n "$fixture_path" ]; then
    # Test injection point set (tests/model-freshness-check.tests.sh) --
    # never a live network call from this branch (security-spec.md B4).
    if [ -f "$fixture_path" ]; then
      cat "$fixture_path"
      return 0
    fi
    return 1
  fi

  # Real network path -- only ever reached on a live GitHub Actions run
  # (no fixture injection point set). curl failure/timeout returns non-zero
  # without raising; `|| return 1` keeps this fully fail-soft.
  curl -fsSL --max-time 15 "$url" 2>/dev/null || return 1
}

# ---------------------------------------------------------------------------
# compute_divergence <anthropic_text> <openai_text> <registry_file>
#   Pure function: no network, no gh. Extracts whitespace-delimited
#   candidate tokens from the fetched text, keeping only tokens that (a)
#   consist ENTIRELY of the allowlisted charset [A-Za-z0-9.-] and (b)
#   contain at least one digit (this script's own conservative-heuristic
#   noise filter, discarding ordinary prose words -- Non-goals: "false
#   negatives acceptable... not a precise parser"). Any token failing the
#   allowlist is discarded outright and never appears in the output
#   (Security Boundaries B1, AC-021) -- markdown injection, instruction-like
#   text, and script fragments virtually never consist entirely of the
#   allowlisted charset, so they are filtered before this point.
#   Prints the sorted, unique, newline-separated list of candidate tokens
#   that are NOT already present in the registry's models[].name entries
#   (full name or the post-"vendor/" basename) -- empty output means no
#   divergence.
# ---------------------------------------------------------------------------
compute_divergence() {
  local anthropic_text="$1"
  local openai_text="$2"
  local registry_file="$3"

  local known
  known="$(extract_registry_tokens "$registry_file")"

  local candidates
  candidates="$(
    {
      printf '%s\n' "$anthropic_text"
      printf '%s\n' "$openai_text"
    } | extract_candidate_tokens
  )"

  [ -z "$candidates" ] && return 0

  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    if [ -z "$known" ] || ! printf '%s\n' "$known" | grep -qxF "$tok"; then
      printf '%s\n' "$tok"
    fi
  done <<TOKENS
$candidates
TOKENS
}

# extract_candidate_tokens -- reads text on stdin, prints sorted-unique
# whitespace-delimited words that match the full charset allowlist
# [A-Za-z0-9.-] end-to-end AND contain at least one digit.
extract_candidate_tokens() {
  tr -s '[:space:]' '\n' | grep -E '^[A-Za-z0-9.-]+$' | grep -E '[0-9]' | sort -u || true
}

# extract_registry_tokens <file> -- prints each models[].name value AND its
# post-"vendor/" basename, one per line (never writes; read-only, Security
# Boundaries B2). Prints nothing (not an error) if the file is absent, so a
# missing fixture-scoped registry copy degrades to "everything looks
# divergent" rather than crashing the script.
extract_registry_tokens() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" \
    | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
    | while IFS= read -r n; do
        printf '%s\n' "$n"
        printf '%s\n' "${n##*/}"
      done
}

# ---------------------------------------------------------------------------
# find_open_issue_by_marker <marker>
#   Prints the first open issue number whose title contains <marker>, or
#   nothing if none is found. No jq dependency: gh's own --json output for
#   a single "number" field is simple enough to extract with grep.
# ---------------------------------------------------------------------------
find_open_issue_by_marker() {
  local marker="$1"
  local out
  out="$(gh issue list --repo "$REPO" --search "\"${marker}\" in:title" --state open --json number 2>/dev/null || true)"
  printf '%s' "$out" | grep -oE '[0-9]+' | head -n1 || true
}

# ---------------------------------------------------------------------------
# file_or_dedupe_issue --unavailable <vendor>
# file_or_dedupe_issue --divergence <tokens>
#   --unavailable: search-existing-or-create (self-improvement.yml's own
#     established failure-issue pattern) against the DEDICATED
#     [model-freshness-fetch-unavailable] tracking issue -- a DIFFERENT
#     issue thread from a genuine divergence report (design.md Design
#     Decisions). Comments "取得不能" if found; creates it if this is the
#     very first fetch failure ever recorded.
#   --divergence: search the [model-freshness-divergence] marker (the SAME
#     literal string D1's manual filing path requires, AC-002/AC-007);
#     takes NO action if a match is already open (dedup, no-bypass on
#     genuine drift is preserved by never suppressing the FIRST filing);
#     otherwise creates a new issue labeled workflow-improvement whose body
#     is built EXCLUSIVELY from compute_divergence's allowlist-validated
#     tokens plus fixed template text (AC-021).
# ---------------------------------------------------------------------------
file_or_dedupe_issue() {
  local mode="$1"
  case "$mode" in
    --unavailable)
      local vendor="$2"
      local existing
      existing="$(find_open_issue_by_marker "$UNAVAILABLE_MARKER")"
      if [ -n "$existing" ]; then
        gh issue comment "$existing" --repo "$REPO" --body "$(build_unavailable_body "$vendor")"
      else
        gh issue create --repo "$REPO" --title "$UNAVAILABLE_TITLE" --label workflow-improvement --body "$(build_unavailable_body "$vendor")"
      fi
      ;;
    --divergence)
      local tokens="$2"
      local existing
      existing="$(find_open_issue_by_marker "$DIVERGENCE_MARKER")"
      if [ -n "$existing" ]; then
        return 0
      fi
      gh issue create --repo "$REPO" --title "$DIVERGENCE_TITLE" --label workflow-improvement --body "$(build_divergence_body "$tokens")"
      ;;
    *)
      printf 'file_or_dedupe_issue: unknown mode %s\n' "$mode" >&2
      return 2
      ;;
  esac
}

build_unavailable_body() {
  local vendor="$1"
  printf 'モデル鮮度チェック: %s の公式ソース取得が取得不能でした。\n\nこの実行は fail-soft として exit 0 で終了しています（ネットワーク到達性または一時的な障害の可能性があり、CI ラン自体は失敗としません）。次回の週次実行で自動的に再試行します。\n\n%s\n' \
    "$vendor" "$CANONICAL_SOURCE_LIST"
}

build_divergence_body() {
  local tokens="$1"
  local bullet_list
  bullet_list="$(printf '%s\n' "$tokens" | sed 's/^/- /')"
  printf '週次モデル鮮度チェックが v2 レジストリ (contracts/agent-model-capabilities.v2.json) との乖離候補を検出しました。\n\n差分候補トークン（charset allowlist [A-Za-z0-9.-] 検証済みのみ）:\n%s\n\n%s\n\nこの issue は保守的ヒューリスティックによる自動生成です。誤検知の可能性があるため、人間によるレビュー・トリアージを経てからレジストリを更新してください。このスクリプト自身はレジストリへの書き込みを一切行いません。\n' \
    "$bullet_list" "$CANONICAL_SOURCE_LIST"
}

# ---------------------------------------------------------------------------
# main -- see module header for the branch summary.
# ---------------------------------------------------------------------------
main() {
  local anthropic_text openai_text divergence

  if ! anthropic_text="$(fetch_source_or_unavailable anthropic "$ANTHROPIC_SOURCE_URL")"; then
    file_or_dedupe_issue --unavailable anthropic
    exit 0
  fi

  if ! openai_text="$(fetch_source_or_unavailable openai "$OPENAI_SOURCE_URL")"; then
    file_or_dedupe_issue --unavailable openai
    exit 0
  fi

  divergence="$(compute_divergence "$anthropic_text" "$openai_text" "$REGISTRY_FILE")"
  if [ -z "$divergence" ]; then
    exit 0
  fi

  file_or_dedupe_issue --divergence "$divergence"
}

main "$@"
