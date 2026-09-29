# Issue #137: internal contract artifact GREEN

Scope: Approved T-001, internal structural schema only.

The fixed regression was committed and pushed before implementation in
`2b81788e4f39133f991b287b9c430df585821a00`.
Its SHA-256 remains
`e17f29aa11fa81100fbd315887c51a1a2f329dc364d7bf9f51049be35e00ae77`.

Added `contracts/sdd-context/schema-v1.schema.json`, SHA-256
`13e74678c13d8eb6904eea53f3d0c4457997e314bc80aba73bdf65e096abf513`.
It records 14 input encodings and nine closed Outcome branches, and reuses
the existing `taskEntry` contract by relative `$ref`. No dependency or
generic validator was added. Runtime validation code was unchanged.

Actual command, executed once:

```sh
rtk proxy node --test --test-reporter=tap tests/sdd-context/contract-artifact.test.mjs
```

Node v24.13.0, macOS arm64; UTC 2026-09-29 15:26:32–15:26:36.
Exit 0: 21 tests, 21 passed, 0 failed, 0 cancelled, 0 skipped; stderr empty.
Root independently checked raw log hashes, counts, 33 fixed input hashes,
10 prior GREEN files, 10 RED artifacts, and the append-only private report.

These checks compare the schema declarations with the existing runtime's
positive and negative cases. They are not an independent JSON Schema
engine conformance test, native Windows proof, host activation, full CI,
formal quality-gate verification, merge or Issue completion. Prior runtime
test results were preserved, not rerun here. T-001 remains In Progress.
