# Issue #137: internal contract artifact RED checkpoint

The approved T-001 requires an internal encoding contract. Runtime validation
exists, but `contracts/sdd-context/schema-v1.schema.json` is absent. This
checkpoint commits the failing regression before creating that artifact.

Executed once on Node v24.13.0, macOS arm64:

```sh
rtk proxy node --test --test-reporter=tap tests/sdd-context/contract-artifact.test.mjs
```

UTC start/end: 2026-09-29T15:18:50.339299+00:00 /
2026-09-29T15:18:52.133794+00:00. Exit 1; 21 tests, 1 pass, 20 fail,
0 cancelled, 0 skipped. Runtime positive fixtures passed. Every failure was
the assertion `internal contract artifact is absent`; stderr was empty.

SHA-256 bindings:

- Test: `e17f29aa11fa81100fbd315887c51a1a2f329dc364d7bf9f51049be35e00ae77`
- Raw stdout: `8ae7c341786a39bb8a04678c49b0926c25d38967dfa9324eb8d425054e83430c`
- Raw stderr: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Private execution record: `6ff2db2145a1eafb7a4eb069f5975e394d1ae55fe12013bdd534829dbd9607e8`

The maintainer independently checked the raw-log hashes and assertion counts,
31 guarded inputs and 10 prior GREEN evidence files. The existing 184 tests
were unchanged, not rerun in this checkpoint. WFI-001 field/counterpart/mismatch
rows were recorded before the new test. The production schema remains absent.

This is expected RED evidence, not a review PASS, implementation completion,
native Windows/host activation, CI result, quality-gate verdict or Issue closure.
Private raw evidence and unrelated local state are excluded from this commit.
