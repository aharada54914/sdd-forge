# Required CI dependency repair

Owner: shared-review-launch-integration/sdd-forge
Baseline HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Scope: the three MCP package locks and their generated dist/index.js bundles.
The MCP paths were clean before this repair; unrelated integration changes are retained.

Classification: routine dependency correction within existing manifest ranges. No
authorization, review identity, evidence schema, transport or required check changes.
The existing production audit fails on SDK 1.30.0, proxy-addr 2.0.7 and ip-address
10.4.0. Initial registry checks identified fixed releases 1.31.0, 2.0.8 and
10.7.1; resolution within existing ranges selected SDK 1.32.1, proxy-addr 2.0.8
and ip-address 10.7.3. Package manifests and application sources are unchanged.
SDK runtime code does change; unchanged application sources do not imply identical
dependency behavior.

Required verification: clean installation, typecheck, existing tests (including
stdio/golden coverage), production audit, reproducible bundle rebuild, independent
diff review and latest-head three-platform CI. Local success is not CI success.
## Executed local results

- Clean `npm ci --ignore-scripts`, typecheck and build succeeded in all three MCP
  packages. Existing tests passed: ci-mcp 148, local-env-mcp 51, sdd-forge-mcp 272
  (471 total, zero failures or skips). The forge suite includes golden and stdio
  transport coverage.
- Production dependency audits succeeded with zero vulnerabilities in each package.
  Development-inclusive installation audits still reported four high findings;
  this repair does not claim those findings are resolved.
- A second build reproduced all three committed-output candidates byte-for-byte:
  ci-mcp `b5a9fc69b6318e966196fad652ed739890704df152ae386e69fcb5eca8b24b1f`,
  local-env-mcp `32e7d5c930ce2f6396e28f99a6c7a320251e1faa03ba5da673a28b8d26cfc2c5`,
  sdd-forge-mcp `87ff7fe2ea5c39b33868029b8775d3554d9a01f55b1d8d9d36a273dafeab1995`.
- Independent diff reviewer `dependency_ci_audit` inspected all six changed files,
  confirmed only the three resolved package versions changed (remaining lock
  changes are peer/funding metadata), independently reproduced bundles using
  esbuild `write:false`, reran production audits and checked whitespace. No blocking
  defect was found. This is a diff review, not a formal task verdict.

Pending: exact-final-head three-platform CI and integration acceptance. The ongoing
full-shell regression snapshots predate this dependency repair; their results must
not be presented as coverage of these new locks and bundles.
