#!/usr/bin/env bash
# bump-version.sh — SSOT-driven release version synchronizer (ADR-0056).
#
# Usage: scripts/bump-version.sh <new-version>   (e.g. scripts/bump-version.sh 2.2.0)
#
# Updates contracts/release-manifest.json and delegates ALL derived surfaces
# (all plugins, both marketplaces, all mcp/*/package.json & server.ts, README.md,
# and MCP dist/index.js rebuilds) to `node scripts/sync-ssot.mjs`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEW="${1:-}"

if ! printf '%s' "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Usage: scripts/bump-version.sh <new-version>  (semver, e.g. 2.2.0)" >&2
    exit 1
fi

MANIFEST="${ROOT}/contracts/release-manifest.json"
OLD="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version)' "${MANIFEST}")"
if [[ -z "$OLD" ]]; then
    echo "Error: could not read current version from ${MANIFEST}" >&2
    exit 1
fi
if [[ "$OLD" == "$NEW" ]]; then
    echo "Error: current version is already ${NEW}." >&2
    exit 1
fi

echo "Bumping SSOT release-manifest: ${OLD} -> ${NEW}"

if ! grep -Eq "^## v${NEW//./\\.}( |\$)" "${ROOT}/CHANGELOG.md"; then
    echo "Error: CHANGELOG.md has no '## v${NEW}' heading. Rename '## Unreleased' first." >&2
    exit 1
fi

# Update SSOT manifest cleanly via Node.js (zero sed portability pitfalls)
node -e '
const fs = require("node:fs");
const [file, ver] = process.argv.slice(1);
const data = JSON.parse(fs.readFileSync(file, "utf8"));
data.version = ver;
fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n", "utf8");
' "${MANIFEST}" "${NEW}"

# Regenerate all derived manifests, marketplaces, MCP packages, and README via SSOT CLI
node "${ROOT}/scripts/sync-ssot.mjs" --target manifests
node "${ROOT}/scripts/sync-ssot.mjs" --target release

# Rebuild every auto-discovered MCP bundle when dependencies are present
for pkg_dir in "${ROOT}"/mcp/*/; do
    [[ -f "${pkg_dir}/package.json" && -d "${pkg_dir}/node_modules" ]] || continue
    (cd "${pkg_dir}" && npm run build >/dev/null)
done

# Fail-closed verification
node "${ROOT}/scripts/sync-ssot.mjs" --check
echo "All release surfaces synchronized to ${NEW} via contracts/release-manifest.json."
