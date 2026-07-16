#!/usr/bin/env bash
# bump-version.sh — synchronize every release surface to a new plugin version.
#
# Usage: scripts/bump-version.sh <new-version>   (e.g. scripts/bump-version.sh 1.7.0)
#
# Updates, in one pass:
#   - plugins/*/{.claude-plugin,.codex-plugin,.plugin}/plugin.json  "version" fields
#   - .claude-plugin/marketplace.json and .agents/plugins/marketplace.json
#   - README.md current-release line (vX.Y.Z — ...)
#   - tests/validate-repository.ps1 expected versions and README/CHANGELOG assertions
#   - tests/repository-release-validation.tests.sh mutation fixtures
#
# It does NOT create the CHANGELOG heading: rename "## Unreleased" to
# "## v<new-version> (<date>)" yourself so release notes stay intentional.
# The script verifies the heading exists and fails closed if it does not.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEW="${1:-}"

if ! printf '%s' "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Usage: scripts/bump-version.sh <new-version>  (semver, e.g. 1.7.0)" >&2
    exit 1
fi

OLD="$(sed -n 's/.*"sdd-ship"[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "${ROOT}/tests/validate-repository.ps1" | head -1)"
if [[ -z "$OLD" ]]; then
    echo "Error: could not derive the current version from tests/validate-repository.ps1" >&2
    exit 1
fi
if [[ "$OLD" == "$NEW" ]]; then
    echo "Error: current version is already ${NEW}." >&2
    exit 1
fi

echo "Bumping release surfaces: ${OLD} -> ${NEW}"

# CHANGELOG heading must exist before surfaces are synchronized (fail closed).
if ! grep -Eq "^## v${NEW//./\\.}( |\$)" "${ROOT}/CHANGELOG.md"; then
    echo "Error: CHANGELOG.md has no '## v${NEW}' heading. Rename '## Unreleased' first." >&2
    exit 1
fi

# Loop-suite prerequisite (issue #148): both suites must pass before any
# release surface is mutated. Fail closed; no bypass.
for suite in tests/loop-consistency.tests.sh tests/loop-inventory.tests.sh; do
    suite_log="$(mktemp)"
    if ! "${ROOT}/${suite}" >"${suite_log}" 2>&1; then
        echo "Error: ${suite} failed; no release surface was modified." >&2
        cat "${suite_log}" >&2
        rm -f "${suite_log}"
        exit 1
    fi
    rm -f "${suite_log}"
done

# Version strings appear in two syntactic forms:
#   plain     1.6.0      (JSON fields, PowerShell hashtable values, prose, messages)
#   escaped   1\.6\.0    (regex literals inside the validator)
OLD_PLAIN_RE="${OLD//./\\.}"          # sed pattern matching the plain form
OLD_ESCAPED_RE="${OLD//./\\\\.}"      # sed pattern matching the regex-escaped form
NEW_ESCAPED="${NEW//./\\\\.}"         # sed replacement emitting a regex-escaped form

# 1. Plugin manifests (18 files) + both marketplaces.
for manifest in "${ROOT}"/plugins/*/.claude-plugin/plugin.json \
                "${ROOT}"/plugins/*/.codex-plugin/plugin.json \
                "${ROOT}"/plugins/*/.plugin/plugin.json \
                "${ROOT}/.claude-plugin/marketplace.json" \
                "${ROOT}/.agents/plugins/marketplace.json"; do
    [[ -f "$manifest" ]] || continue
    sed -i "s/\"version\": \"${OLD_PLAIN_RE}\"/\"version\": \"${NEW}\"/g" "$manifest"
done

# 2. README current-release line (first line starting with vX.Y.Z).
sed -i "s/^v${OLD_PLAIN_RE}\([^0-9]\)/v${NEW}\1/" "${ROOT}/README.md"

# 3. Repository validator: escaped regex form first, then plain form.
sed -i "s/${OLD_ESCAPED_RE}/${NEW_ESCAPED}/g; s/${OLD_PLAIN_RE}/${NEW}/g" \
    "${ROOT}/tests/validate-repository.ps1"

# 4. Release-validation test fixtures that assert the literal version.
sed -i "s/${OLD_ESCAPED_RE}/${NEW_ESCAPED}/g; s/${OLD_PLAIN_RE}/${NEW}/g" \
    "${ROOT}/tests/repository-release-validation.tests.sh"

# 5. Verify: no stale old-version strings remain on release surfaces.
stale=0
for f in "${ROOT}"/plugins/*/.claude-plugin/plugin.json \
         "${ROOT}"/plugins/*/.codex-plugin/plugin.json \
         "${ROOT}"/plugins/*/.plugin/plugin.json \
         "${ROOT}/.claude-plugin/marketplace.json" \
         "${ROOT}/.agents/plugins/marketplace.json" \
         "${ROOT}/README.md" \
         "${ROOT}/tests/validate-repository.ps1" \
         "${ROOT}/tests/repository-release-validation.tests.sh"; do
    if grep -q "${OLD_PLAIN_RE}" "$f" 2>/dev/null; then
        echo "WARNING: stale ${OLD} reference remains in: ${f#"$ROOT"/}" >&2
        stale=1
    fi
done

if [[ $stale -eq 1 ]]; then
    echo "Bump completed with warnings — review the files above manually." >&2
    exit 2
fi

echo "All release surfaces now identify ${NEW}."
