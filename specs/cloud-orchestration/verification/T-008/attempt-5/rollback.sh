#!/usr/bin/env bash
set -euo pipefail
repo="$(pwd)"
scratch=/tmp/cloud-T008-attempt5-01a15085
evidence="$repo/specs/cloud-orchestration/verification/T-008/attempt-5"
checkout="$scratch/rollback"
mkdir "$checkout"
git archive HEAD | tar -x -C "$checkout"
package=mcp/sdd-forge-mcp
cp -a "$repo/$package/node_modules" "$checkout/$package/node_modules"
files=("$package/src/parsers/report-lookup.ts" "$package/src/parsers/task-validation.ts" "$package/src/parsers/tasks.ts" "$package/src/tools/core.ts" "$package/dist/index.js" README.md)
# Exact entry bytes, not an assumed clean HEAD baseline.
for file in "${files[@]}"; do cp "$scratch/initial/$file" "$checkout/$file"; done
# The original two acceptance tests only use pre-existing callable boundaries.
# New factory-specific tests cannot compile against an implementation without it.
sed '/^import {$/,$d' "$repo/$package/tests/parsers-state/report-reuse.test.ts" > "$checkout/$package/tests/parsers-state/report-reuse.test.ts"
(cd "$checkout"; sha256sum "${files[@]}" "$package/tests/parsers-state/report-reuse.test.ts") > "$evidence/rollback-before.sha256"
cd "$checkout/$package"
npm run typecheck > "$evidence/rollback-typecheck.log" 2>&1
npm run build > "$evidence/rollback-build.log" 2>&1
cmp dist/index.js "$scratch/initial/$package/dist/index.js"
set +e
npm test > "$evidence/rollback-mcp-tests.log" 2>&1
status=$?
set -e
printf 'rollback npm test exit=%s (expected 1: original two read-count assertions)\n' "$status"
[[ "$status" == 1 ]]
grep -q 'ℹ fail 2' "$evidence/rollback-mcp-tests.log"
grep -q '6 !== 1' "$evidence/rollback-mcp-tests.log"
grep -q '12 !== 1' "$evidence/rollback-mcp-tests.log"
for file in "${files[@]}"; do cp "$repo/$file" "$checkout/$file"; done
cp "$repo/$package/tests/parsers-state/report-reuse.test.ts" "$checkout/$package/tests/parsers-state/report-reuse.test.ts"
(cd "$checkout"; sha256sum "${files[@]}" "$package/tests/parsers-state/report-reuse.test.ts") > "$evidence/reapply.sha256"
npm run typecheck > "$evidence/reapply-typecheck.log" 2>&1
npm run build > "$evidence/reapply-build.log" 2>&1
cmp dist/index.js "$repo/$package/dist/index.js"
npm test > "$evidence/reapply-mcp-tests.log" 2>&1
printf 'reapply typecheck/build/dist-byte-parity/full MCP tests exit=0\n'
