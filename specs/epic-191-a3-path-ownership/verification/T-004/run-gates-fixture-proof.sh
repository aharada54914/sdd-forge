#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
LIVE_SUITE="${REPO_ROOT}/tests/gates.tests.sh"
CANDIDATE_SUITE="${REPO_ROOT}/specs/epic-191-a3-path-ownership/human-copy/tests/gates.tests.sh"
CHECKER="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-contract.py"
PRODUCER="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-component-coverage.py"
PROOF_ROOT="$(mktemp -d)"
trap 'rm -rf "$PROOF_ROOT"' EXIT

extract_contract() {
    local source="$1"
    local marker="$2"
    local output="$3"
    awk -v marker="$marker" '
        index($0, marker) { copying = 1; next }
        copying && $0 == "EOF" { exit }
        copying { print }
    ' "$source" > "$output"
    [[ -s "$output" ]]
}

create_referenced_files() {
    local contract="$1"
    local root="$2"
    python3 - "$contract" "$root" <<'PY'
import json
import pathlib
import sys

contract = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])
data = json.loads(contract.read_text(encoding="utf-8"))
for check in data.get("checks", []):
    for field in ("evidence", "red_evidence", "green_evidence"):
        rel = check.get(field)
        if not rel or check.get("id") == "check-component-coverage":
            continue
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("standalone fixture evidence\n", encoding="utf-8")
PY
}

component_evidence_path() {
    local contract="$1"
    python3 - "$contract" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for check in data.get("checks", []):
    if check.get("id") == "check-component-coverage":
        print(check["evidence"])
        break
else:
    raise SystemExit("component coverage check not found")
PY
}

run_fixture() {
    local ordinal="$1"
    local label="$2"
    local marker="$3"
    local case_root="${PROOF_ROOT}/${ordinal}"
    local before_root="${case_root}/before"
    local after_root="${case_root}/after"
    local before_contract="${before_root}/contract.json"
    local after_contract="${after_root}/contract.json"
    local evidence_rel
    local before_output
    local after_output
    local before_status
    local after_status

    mkdir -p "$before_root" "$after_root"
    extract_contract "$LIVE_SUITE" "$marker" "$before_contract"
    extract_contract "$CANDIDATE_SUITE" "$marker" "$after_contract"
    create_referenced_files "$before_contract" "$before_root"
    create_referenced_files "$after_contract" "$after_root"

    evidence_rel="$(component_evidence_path "$after_contract")"
    mkdir -p "$(dirname "${after_root}/${evidence_rel}")"
    python3 "$PRODUCER" --repo-root "$after_root" > "${after_root}/${evidence_rel}"

    set +e
    before_output="$(python3 "$CHECKER" "$before_contract" "$before_root" 2>&1)"
    before_status=$?
    after_output="$(python3 "$CHECKER" "$after_contract" "$after_root" 2>&1)"
    after_status=$?
    set -e

    printf 'FIXTURE %s\n' "$label"
    printf '  extracted-before: tests/gates.tests.sh :: %s\n' "$marker"
    printf '  before-exit: %s\n' "$before_status"
    printf '  before-output: %s\n' "$before_output"
    printf '  extracted-after: human-copy/tests/gates.tests.sh :: %s\n' "$marker"
    printf '  producer: check-component-coverage.py (live)\n'
    printf '  after-exit: %s\n' "$after_status"
    printf '  after-output: %s\n' "$after_output"

    [[ "$before_status" -ne 0 ]]
    [[ "$before_output" == *"requires check 'check-component-coverage' present"* ]]
    [[ "$after_status" -eq 0 ]]
}

fixtures=(
    'T-003.7|T-003.7.contract.json'
    'T-003.8|T-003.8.contract.json'
    'T-012.7|T-012.7.contract.json'
    'T-004.3|t004_test3/T-003.contract.json'
    'T-004.7|t004_test7/T-007.contract.json'
    'T-006.3b / T-007a.9|T-100.contract.json'
    'T-007a.1d|T-200.contract.json'
    'T-007a.5|T-201.contract.json'
    'CM.1|CM-1.contract.json'
    'CM.3|CM-3.contract.json'
    'CM.4|CM-4.contract.json'
)

printf 'Standalone fixture proof against live check-contract.py\n'
printf 'Live checker: %s\n' "$CHECKER"
printf 'Live producer: %s\n\n' "$PRODUCER"

ordinal=0
for fixture in "${fixtures[@]}"; do
    ordinal=$((ordinal + 1))
    IFS='|' read -r label marker <<< "$fixture"
    run_fixture "$ordinal" "$label" "$marker"
    printf '\n'
done

printf 'RESULT: 11 repaired contracts failed before and passed after; 12 suite assertions covered.\n'
