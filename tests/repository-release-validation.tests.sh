#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-release-validation.XXXXXX")"
fixture_root="$temporary_root/repository"
trap 'rm -rf "$temporary_root"' EXIT

mkdir -p "$fixture_root"
(
    cd "$repository_root"
    tar --exclude='./.git' -cf - .
) | (
    cd "$fixture_root"
    tar -xf -
)

cp "$fixture_root/README.md" "$temporary_root/README.md"
cp "$fixture_root/CHANGELOG.md" "$temporary_root/CHANGELOG.md"

validators=(
    "bash:$fixture_root/tests/validate-repository.sh"
    "pwsh:$fixture_root/tests/validate-repository.ps1"
)

run_validator() {
    local validator="$1"
    local runtime="${validator%%:*}"
    local script="${validator#*:}"

    if [[ "$runtime" == "bash" ]]; then
        "$script"
    else
        pwsh -NoProfile -File "$script"
    fi
}

expect_success() {
    local scenario="$1"
    local validator="$2"
    local output="$temporary_root/${scenario}-${validator%%:*}.log"

    if ! run_validator "$validator" >"$output" 2>&1; then
        printf 'FAIL: %s unexpectedly rejected by %s\n' "$scenario" "${validator%%:*}" >&2
        cat "$output" >&2
        return 1
    fi
}

expect_failure() {
    local scenario="$1"
    local expected_diagnostic="$2"
    local validator="$3"
    local output="$temporary_root/${scenario}-${validator%%:*}.log"

    if run_validator "$validator" >"$output" 2>&1; then
        printf 'FAIL: %s unexpectedly accepted by %s\n' "$scenario" "${validator%%:*}" >&2
        cat "$output" >&2
        return 1
    fi
    if ! grep -Fq "$expected_diagnostic" "$output"; then
        printf 'FAIL: %s from %s lacked diagnostic: %s\n' \
            "$scenario" "${validator%%:*}" "$expected_diagnostic" >&2
        cat "$output" >&2
        return 1
    fi
}

for validator in "${validators[@]}"; do
    expect_success "valid-tree" "$validator"
done

python3 - "$fixture_root/README.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
path.write_text(content.replace("v1.11.0 —", "v9.9.9 —", 1), encoding="utf-8")
PY
for validator in "${validators[@]}"; do
    expect_failure "mutated-readme" "README.md current release must be v1.11.0." "$validator"
done

cp "$temporary_root/README.md" "$fixture_root/README.md"
python3 - "$fixture_root/CHANGELOG.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
# Anchor on the changelog title (always present) rather than "## Unreleased",
# which disappears right after a release bump and would make this a no-op.
path.write_text(content.replace("# Changelog", "# Changelog\n\n## v1.11.0 duplicate", 1), encoding="utf-8")
PY
for validator in "${validators[@]}"; do
    expect_failure "mutated-changelog" "CHANGELOG.md must contain exactly one v1.11.0 release heading." "$validator"
done

cp "$temporary_root/CHANGELOG.md" "$fixture_root/CHANGELOG.md"
for validator in "${validators[@]}"; do
    expect_success "restored-valid-tree" "$validator"
done

printf 'Repository release validation parity tests passed: 8/8 checks.\n'
