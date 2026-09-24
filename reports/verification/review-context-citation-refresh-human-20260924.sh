#!/usr/bin/env bash
set -euo pipefail

# Human-only repair for protected citation/test files. The agent must not run
# this script: it writes the protected review contract and its protected test.
[[ "${REVIEW_CONTEXT_CITATIONS_APPLY:-}" == 1 ]] || {
  printf '%s\n' 'Set REVIEW_CONTEXT_CITATIONS_APPLY=1 to authorize the protected-file repair.' >&2
  exit 2
}

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
DOC="$ROOT/plugins/sdd-review-loop/references/review-context-boundary.md"
TEST="$ROOT/tests/review-context-boundary.tests.sh"

expected_validator=69f82417be3ad814ba2450a8984b97e19c827037c975799941effb8fff10f155
expected_doc=d446abece49ac3ec012e78050352e76d7bb4d84f90953e2ea78be1a5e554263c
expected_test=bc964328412ec05725be3721ffe99dce98a2556db0165a2d81b660d8f927f481

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
[[ "$(sha256_file "$VALIDATOR")" == "$expected_validator" ]] || {
  printf 'validator hash mismatch; refusing to patch\n' >&2; exit 1;
}
[[ "$(sha256_file "$DOC")" == "$expected_doc" ]] || {
  printf 'document hash mismatch; refusing to patch\n' >&2; exit 1;
}
[[ "$(sha256_file "$TEST")" == "$expected_test" ]] || {
  printf 'test hash mismatch; refusing to patch\n' >&2; exit 1;
}

backup="$(mktemp -d /tmp/sdd-review-context-citations.XXXXXX)"
cp "$DOC" "$backup/review-context-boundary.md"
cp "$TEST" "$backup/review-context-boundary.tests.sh"
trap 'printf "Backup: %s\n" "$backup"' EXIT

python3 - "$VALIDATOR" "$DOC" "$TEST" <<'PY'
import re
import sys
from pathlib import Path

validator_path, doc_path, test_path = map(Path, sys.argv[1:])
validator = validator_path.read_text()
test = test_path.read_text()
doc = Path(doc_path).read_text()

match = re.search(r"anchors\(\) \{\n(.*?)\nANCHORS\n\}", test, re.S)
if not match:
    raise SystemExit("anchor table not found")

rows_by_citation = {}
for raw in match.group(1).splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    row = re.match(r"(:\d+(?:-\d+)?)\s+(\S+)\s+(.+)$", line)
    if not row:
        continue
    citation, subject, pattern = row.groups()
    if subject != "validator":
        continue
    rows_by_citation.setdefault(citation, []).append(pattern)

lines = validator.splitlines()
replacement = {}
for citation, patterns in rows_by_citation.items():
    hits = []
    for pattern in patterns:
        found = [index + 1 for index, candidate in enumerate(lines) if pattern in candidate]
        if not found:
            raise SystemExit(f"validator anchor disappeared: {citation} {pattern}")
        hits.extend(found)
    start, end = min(hits), max(hits)
    replacement[citation] = f":{start}" if start == end else f":{start}-{end}"

def replace_citation(text: str) -> str:
    for old, new in sorted(replacement.items(), key=lambda item: -len(item[0])):
        text = text.replace(old, new)
    return text

updated_test = replace_citation(test)
updated_doc = replace_citation(doc)
if updated_test == test or updated_doc == doc:
    raise SystemExit("no citation changed; refusing a no-op repair")
test_path.write_text(updated_test)
Path(doc_path).write_text(updated_doc)
print(f"updated {len(replacement)} validator citation groups")
for old, new in sorted(replacement.items()):
    print(f"{old} -> {new}")
PY

printf '%s\n' 'Protected citation and anchor updates applied.'
printf '%s\n' 'Run: rtk proxy bash tests/review-context-boundary.tests.sh'
printf '%s\n' 'Do not commit, push, or merge until that test and the required CI checks pass.'
