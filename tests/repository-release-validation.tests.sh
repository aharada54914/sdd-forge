#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"

# Both legs of this parity suite need PowerShell: validate-repository.ps1 is
# driven directly, and validate-repository.sh is only a thin wrapper that
# execs pwsh (tests/validate-repository.sh). This suite is registered in
# tests/run-all.sh, which developers run on machines where PowerShell may be
# absent, so skip loudly here instead of aborting the whole POSIX lane. CI's
# ubuntu/macos runners always ship pwsh, so enforcement there is unchanged.
# Mirrors the pwsh guard at the tail of tests/run-all.sh. Placed before the
# fixture copy so a skip costs nothing.
if ! command -v pwsh >/dev/null 2>&1; then
    printf 'SKIP: pwsh not found; repository-release-validation.tests.sh not run (both validator legs require PowerShell)\n'
    exit 0
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-release-validation.XXXXXX")"
fixture_root="$temporary_root/repository"
# Copied frozen snapshots need writable directories for removal; never follow links.
trap 'find -P "$temporary_root" -type d -exec chmod u+rwx {} + && rm -rf "$temporary_root"' EXIT

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

checks=0
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
    checks=$((checks + 1))
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
    checks=$((checks + 1))
}

for validator in "${validators[@]}"; do
    expect_success "valid-tree" "$validator"
done

python3 - "$fixture_root/README.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
path.write_text(content.replace("v1.23.0 —", "v9.9.9 —", 1), encoding="utf-8")
PY
for validator in "${validators[@]}"; do
    expect_failure "mutated-readme" "README.md current release must be v1.23.0." "$validator"
done

cp "$temporary_root/README.md" "$fixture_root/README.md"
python3 - "$fixture_root/CHANGELOG.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
# Anchor on the changelog title (always present) rather than "## Unreleased",
# which disappears right after a release bump and would make this a no-op.
path.write_text(content.replace("# Changelog", "# Changelog\n\n## v1.23.0 duplicate", 1), encoding="utf-8")
PY
for validator in "${validators[@]}"; do
    expect_failure "mutated-changelog" "CHANGELOG.md must contain exactly one v1.23.0 release heading." "$validator"
done

cp "$temporary_root/CHANGELOG.md" "$fixture_root/CHANGELOG.md"
# The Bash entry execs this same PowerShell validator; exercise each structural
# mutation once, while the surrounding release-version cases cover both entries.
for scenario in managed-entry policy-engine ci-cache cloud-entry role-reference ci-plan ci-observations ci-result cloud-marketplace payload-contracts model-schema-id ci-result-id; do
    case "$scenario" in
        managed-entry) relative="plugins/sdd-implementation/scripts/managed-model-entry.py"; diagnostic="Missing required file:" ;;
        policy-engine) relative="plugins/sdd-implementation/scripts/model-policy.py"; diagnostic="Missing required file:" ;;
        ci-cache) relative="tests/ci-dependency-cache.py"; diagnostic="Missing required file:" ;;
        cloud-entry) relative="plugins/sdd-azure-cloud/scripts/cloud.py"; diagnostic="Missing required file:" ;;
        role-reference) relative="contracts/model-policy.v1.json"; diagnostic="Model policy role references an unknown registry role:" ;;
        ci-plan) relative="contracts/verification-ci-plan.schema.json"; diagnostic="Missing required file:" ;;
        ci-observations) relative="contracts/verification-ci-observations.schema.json"; diagnostic="Missing required file:" ;;
        ci-result) relative="contracts/verification-ci-result.schema.json"; diagnostic="Missing required file:" ;;
        cloud-marketplace) relative=".agents/plugins/marketplace.json"; diagnostic="Cloud marketplace source or opt-cin policy differs" ;;
        payload-contracts) relative="install-payload.txt"; diagnostic="Install payload excludes required runtime:" ;;
        model-schema-id) relative="contracts/model-launch-controls.schema.json"; diagnostic="Schema identity differs:" ;;
        ci-result-id) relative="contracts/verification-ci-result.schema.json"; diagnostic="Schema identity differs:" ;;
    esac
    cp "$fixture_root/$relative" "$temporary_root/feature-original"
    python3 - "$fixture_root/$relative" "$scenario" <<'PY_MUTATE'
import json
from pathlib import Path
import sys
path, scenario = Path(sys.argv[1]), sys.argv[2]
if scenario in {'managed-entry', 'policy-engine', 'ci-cache', 'cloud-entry', 'ci-plan', 'ci-observations', 'ci-result'}:
    path.unlink()
elif scenario == 'payload-contracts':
    text = path.read_text(encoding='utf-8')
    assert '\ncontracts/\n' in text
    path.write_text(text.replace('\ncontracts/\n', '\n'), encoding='utf-8')
else:
    data = json.loads(path.read_text(encoding='utf-8'))
    if scenario == 'role-reference':
        data['roles']['diagnosis']['capability_role'] = 'missing-release-role'
    elif scenario == 'cloud-marketplace':
        entry = next(item for item in data['plugins'] if item['name'] == 'sdd-azure-cloud')
        entry['source']['path'] = './plugins/missing-cloud'
    elif scenario == 'model-schema-id':
        data['properties']['schema']['const'] = 'model-launch-controls/v999'
    else:
        data['$defs']['result']['properties']['schema']['const'] = 'verification-ci-result/v999'
    path.write_text(json.dumps(data) + '\n', encoding='utf-8')
PY_MUTATE
    expect_failure "$scenario" "$diagnostic" "${validators[0]}"
    cp "$temporary_root/feature-original" "$fixture_root/$relative"
done
for validator in "${validators[@]}"; do
    expect_success "restored-valid-tree" "$validator"
done

printf 'Repository release validation tests passed: %s checks.\n' "$checks"
