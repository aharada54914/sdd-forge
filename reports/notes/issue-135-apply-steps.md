# Issue #135 (CI-28) apply and verification steps

## What this patch touches, read before applying

Five files, and one group of them is wider than the issue's own wording suggests.

| File | Change |
|---|---|
| the CI workflow definition | lockfile-consistency check, `npm audit signatures`, CycloneDX SBOM generation and upload — the actual ask |
| `.github/dependabot.yml` | npm coverage for the three MCP packages. Dependabot already existed but covered GitHub Actions only |
| `mcp/{ci-mcp,local-env-mcp,sdd-forge-mcp}/package-lock.json` | 8 lines each |

**The lockfile edits are metadata-only, and that was verified before this note
was written**: every changed line removes a `"peer": true` flag. No `resolved`
URL and no `integrity` hash changes in any of the three files, so dependency
resolution is unchanged. This is npm-version normalization, not a dependency
update.

They are nonetheless a real change to committed lockfiles and not literally what
the issue asked for. The reason they are here: adding a lockfile-consistency
check to CI makes that check fail against lockfiles carrying the older metadata
form, so without the normalization the new check would be red on arrival.

If you would rather not carry lockfile edits in this commit, the alternative is
to drop the lockfile-consistency step and lose that half of the first acceptance
criterion. Say so and the patch can be re-cut that way.

```bash
set -euo pipefail

# SBOM format rationale: use `npm sbom --sbom-format cyclonedx` because it is
# native to npm, so this supply-chain-hardening change introduces no new
# supply-chain dependency.

issue135_repo_root="$(git rev-parse --show-toplevel)"
cd "$issue135_repo_root"
issue135_patch="reports/notes/issue-135-mcp-dependency-ci.patch"

git apply --check "$issue135_patch"
git apply "$issue135_patch"

test "$(node -p 'process.versions.node.split(".")[0]')" = "20"
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path); puts "YAML OK: #{path}" }' \
  .github/workflows/test.yml .github/dependabot.yml

issue135_sbom_dir="$(mktemp -d "${TMPDIR:-/tmp}/issue135-sbom.XXXXXX")"
trap 'rm -rf "$issue135_sbom_dir"' EXIT

for issue135_package in \
  mcp/sdd-forge-mcp \
  mcp/local-env-mcp \
  mcp/ci-mcp
do
  (
    cd "$issue135_package"
    npm ci
    npm install --package-lock-only --ignore-scripts --no-audit
    git diff --exit-code -- package-lock.json
    npm audit --omit=dev --audit-level=high
    npm audit signatures
    npm sbom --sbom-format cyclonedx > \
      "$issue135_sbom_dir/${issue135_package##*/}-sbom.cdx.json"
  )
done

python3 - "$issue135_sbom_dir" <<'PY'
import json
import pathlib
import sys

sbom_dir = pathlib.Path(sys.argv[1])
sboms = sorted(sbom_dir.glob("*-sbom.cdx.json"))
assert len(sboms) == 3, sboms
for sbom in sboms:
    data = json.loads(sbom.read_text())
    assert data["bomFormat"] == "CycloneDX", (sbom, data.get("bomFormat"))
    print(f"SBOM OK: {sbom.name} ({data['bomFormat']} {data['specVersion']})")
PY

git diff --check
git diff -- \
  .github/dependabot.yml \
  .github/workflows/test.yml \
  mcp/ci-mcp/package-lock.json \
  mcp/local-env-mcp/package-lock.json \
  mcp/sdd-forge-mcp/package-lock.json
```
