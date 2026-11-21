#!/usr/bin/env bash
# bump-version.sh — synchronize every release surface to a new plugin version.
#
# Usage: scripts/bump-version.sh <new-version>   (e.g. scripts/bump-version.sh 1.7.0)
#
# Updates, in one pass:
#   - plugins/*/{.claude-plugin,.codex-plugin,.plugin}/plugin.json  "version" fields
#   - plugins/*/{gemini-extension.json,gemini/gemini-extension.json}
#   - .claude-plugin/marketplace.json and .agents/plugins/marketplace.json
#   - README.md current-release line (vX.Y.Z — ...)
#
# It does NOT create the CHANGELOG heading: rename "## Unreleased" to
# "## v<new-version> (<date>)" yourself so release notes stay intentional.
# The script verifies the heading exists and fails closed if it does not.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEW="${1:-}"

if ! printf '%s' "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Usage: scripts/bump-version.sh <new-version>  (semver, e.g. 2.0.1)" >&2
    exit 1
fi

OLD="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version)' "${ROOT}/plugins/sdd-ship/.claude-plugin/plugin.json")"
if [[ -z "$OLD" ]]; then
    echo "Error: could not derive the current version from plugins/sdd-ship/.claude-plugin/plugin.json" >&2
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

# Validate v2 test suite and doctor before mutating any release surface.
gate_log="$(mktemp)"
if ! (cd "${ROOT}" && node --test tests/v2-soft-guard.test.mjs tests/v2-spec-drift.test.mjs tests/v2-sdd-core-flow.test.mjs tests/v2-hooks-and-ci.test.mjs tests/v2-real-flows-e2e.test.mjs tests/v2-sdd-doctor.test.mjs tests/v2-software-factory.test.mjs && node plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs --root . --quiet-info) >"${gate_log}" 2>&1; then
    echo "Error: v2 pre-release checks failed; no release surface was modified." >&2
    cat "${gate_log}" >&2
    rm -f "${gate_log}"
    exit 1
fi
rm -f "${gate_log}"

OLD_PLAIN_RE="${OLD//./\\.}"

# Portable in-place sed helper (GNU sed and BSD/macOS sed).
sed_inplace() {
    local expr="$1" file="$2"
    if sed --version >/dev/null 2>&1; then
        sed -i "$expr" "$file"
    else
        sed -i '' "$expr" "$file"
    fi
}

# 1. Every plugin's host manifests (Claude, Codex, Copilot, Gemini) + both marketplaces.
for manifest in "${ROOT}"/plugins/*/.claude-plugin/plugin.json \
                "${ROOT}"/plugins/*/.codex-plugin/plugin.json \
                "${ROOT}"/plugins/*/.plugin/plugin.json \
                "${ROOT}"/plugins/*/gemini-extension.json \
                "${ROOT}"/plugins/*/gemini/gemini-extension.json \
                "${ROOT}/.claude-plugin/marketplace.json" \
                "${ROOT}/.agents/plugins/marketplace.json"; do
    [[ -f "$manifest" ]] || continue
    sed_inplace "s/\"version\": \"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"/\"version\": \"${NEW}\"/g" "$manifest"
done

# 2. README current-release line (first line starting with vX.Y.Z).
sed_inplace "s/^v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\([^0-9]\)/v${NEW}\1/" "${ROOT}/README.md"

# 3. Verify: no stale old-version strings remain on release surfaces.
stale=0
for f in "${ROOT}"/plugins/*/.claude-plugin/plugin.json \
         "${ROOT}"/plugins/*/.codex-plugin/plugin.json \
         "${ROOT}"/plugins/*/.plugin/plugin.json \
         "${ROOT}"/plugins/*/gemini-extension.json \
         "${ROOT}"/plugins/*/gemini/gemini-extension.json \
         "${ROOT}/.claude-plugin/marketplace.json" \
         "${ROOT}/.agents/plugins/marketplace.json" \
         "${ROOT}/README.md"; do
    [[ -f "$f" ]] || continue
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
