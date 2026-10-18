#!/usr/bin/env bash
set -euo pipefail
repo="$(pwd)"
scratch=/tmp/cloud-T008-attempt5-01a15085
evidence="$repo/specs/cloud-orchestration/verification/T-008/attempt-5"
package="$repo/mcp/sdd-forge-mcp"
cd "$package"
npm run typecheck > "$evidence/typecheck.log" 2>&1
npm run build > "$evidence/build.log" 2>&1
cp dist/index.js "$scratch/dist-first.js"
npm run build >> "$evidence/build.log" 2>&1
cmp dist/index.js "$scratch/dist-first.js"
npm test > "$evidence/final-mcp-tests.log" 2>&1
node --test dist-test/tests/parsers-state/report-reuse.test.js > "$evidence/green-final.log" 2>&1
cd "$repo"
node "$evidence/probe.mjs" "$repo" "$package" "$scratch/after-final" > "$evidence/after-final-probe.log" 2>&1
cmp "$scratch/before/tool.json" "$scratch/after-final/tool.json"
cmp "$scratch/before/parses.json" "$scratch/after-final/parses.json"
node "$package/node_modules/@modelcontextprotocol/inspector/clients/launcher/build/index.js" --cli node "$package/dist/index.js" --root "$repo" -- --method tools/call --tool-name list_active_specs > "$scratch/inspector-after.json" 2> "$scratch/inspector-after.stderr"
cmp "$scratch/inspector-before.json" "$scratch/inspector-after.json"
printf 'typecheck/build/rebuild-byte-parity/full-MCP-tests/scoped-tests/real-root-tool-and-all-parses-byte-parity/Inspector-byte-parity: exit 0\n'
