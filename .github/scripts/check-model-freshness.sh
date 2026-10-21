#!/usr/bin/env bash
# check-model-freshness.sh -- weekly model-registry freshness check
# (T-003 / Issue #157 / epic-159-pillar-d REQ-002).
#
# Invoked by .github/workflows/model-freshness-check.yml on its weekly
# schedule or a manual workflow_dispatch. Best-effort fetches the official
# Anthropic and OpenAI model-listing sources, diffs the fetched text against
# the read-only shared model policy and legacy capability catalog, and
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
# issue body. Output uses fixed enum labels, validated dates and model IDs.
# Only model-ID tokens that pass the charset allowlist
# `[A-Za-z0-9.-]` (with a claude-/gpt-/o-digit prefix and at least one digit, this
# script's own conservative-heuristic noise filter -- Non-goals) ever reach
# an issue body. This script never opens any path under `contracts/` for
# writing (Security Boundaries B2) -- registry corrections remain a
# human-reviewed change (T-002-shaped), never automated here.
#
# Python standard library parses repository JSON and publication metadata; no
# provider SDK or extra JSON-query runtime is needed.
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
POLICY_FILE="${MODEL_FRESHNESS_POLICY_PATH:-${ROOT}/contracts/model-policy.v1.json}"
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

# Compare read-only policy/catalog metadata with conservative source observations.
# Only explicit table rows prove a deprecation candidate; absence proves nothing.
# Source dates are publication metadata, never the time this job fetched a page.
compute_divergence() {
  local anthropic_text="$1" openai_text="$2" registry_file="$3"
  printf '%s\0%s' "$anthropic_text" "$openai_text" | python3 -c '
import datetime
from html.parser import HTMLParser
import json
import re
import sys

TOKEN = re.compile(r"(?:claude-|gpt-|o[0-9])[A-Za-z0-9.-]*")
SOURCES = {"anthropic": "https://docs.anthropic.com/en/docs/about-claude/models",
           "openai": "https://platform.openai.com/docs/models"}

def model_token(value):
    return isinstance(value, str) and TOKEN.fullmatch(value) and re.search(r"[0-9]", value)

def valid_date(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}(?:T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?", value):
        return "unknown"
    try:
        datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return "unknown"
    return value

class Publication(HTMLParser):
    def __init__(self):
        super().__init__()
        self.dates = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta" and attrs.get("property") == "article:published_time":
            self.dates.append(valid_date(attrs.get("content")))

# These are trusted repository inputs, not fetched prose. Invalid policy/catalog
# stops comparison: it must not masquerade as an empty known-model inventory.
try:
    with open(sys.argv[1], encoding="utf-8") as stream:
        catalog = json.load(stream)
    with open(sys.argv[2], encoding="utf-8") as stream:
        policy = json.load(stream)
    if policy.get("schema") != "model-policy/v1" or not isinstance(policy.get("models"), list):
        raise ValueError("invalid policy")
    known = set()
    metadata = {}
    for item in catalog["models"]:
        name = item["name"]
        known.add(name.rsplit("/", 1)[-1])
    for item in policy["models"]:
        name = item["id"]
        token = name.rsplit("/", 1)[-1]
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9./-]*", name):
            raise ValueError("invalid model ID")
        known.add(token)
        vendor = "anthropic" if name.startswith("anthropic/") or token.startswith("claude-") else "openai"
        lifecycle = item.get("lifecycle")
        if lifecycle not in ("current", "candidate", "historical", "retired"):
            raise ValueError("invalid lifecycle")
        metadata[(vendor, token)] = (lifecycle, valid_date(item.get("source_date")))
    policy_date = valid_date(policy.get("source_date"))
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    print("Model freshness comparison unavailable: invalid policy/catalog metadata", file=sys.stderr)
    sys.exit(1)

texts = sys.stdin.read().split("\0")
rows = set()
for vendor, text in zip(SOURCES, texts):
    publication = Publication()
    publication.feed(text)
    dates = set(publication.dates)
    source_date = next(iter(dates)) if len(dates) == 1 else "unknown"
    deprecations: dict[str, str] = {}
    for line in text.splitlines():
        # shortcut: exact three-column Markdown rows only; add source-specific
        # parsers when official structured formats require broader coverage.
        match = re.fullmatch(r"\s*\|\s*([^|]+?)\s*\|\s*(deprecated|retired)\s*\|\s*([^|]*?)\s*\|\s*", line)
        if match and model_token(match[1]):
            token = match[1]
            expected = "anthropic" if token.startswith("claude-") else "openai"
            if vendor == expected:
                date = valid_date(match[3])
                previous = deprecations.get(token, date)
                deprecations[token] = date if previous == date else "unknown"
    for token, date in deprecations.items():
        lifecycle, model_date = metadata.get((vendor, token), ("unknown", "unknown"))
        rows.add(f"deprecation | {token} | {vendor} | sourceDate={date} | policyLifecycle={lifecycle} | policyModelSourceDate={model_date}")
    for token in text.split():
        if model_token(token) and token not in known and token not in deprecations:
            rows.add(f"candidate | {token} | {vendor} | sourceDate={source_date}")
if rows:
    print(f"policySourceDate={policy_date}")
    print("\n".join("- " + row for row in sorted(rows)))
' "$registry_file" "$POLICY_FILE"
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
  local rows="$1"
  printf '週次モデル鮮度チェック: shared policy / v2 catalog との乖離候補。\n\n%s\n\n%s\n\n候補・廃止候補は未検証です。sourceDate=unknown は公開日不明で、取得日時ではありません。policySourceDate と policyModelSourceDate は既存 policy の出典日です。モデル不在から廃止を推定しません。人間によるレビューと採用検証が必要です。このスクリプトは policy / registry / configuration を更新せず、自動採用・merge を行いません。\n' \
    "$rows" "$CANONICAL_SOURCE_LIST"
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
