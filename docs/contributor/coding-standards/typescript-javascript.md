# TypeScript / JavaScript

Apply [common rules](common.md), especially CS-001, CS-003, CS-004, CS-006, CS-008, CS-018, CS-021, CS-022, CS-023.

Preserve strict and noUncheckedIndexedAccess, build/typecheck/test entrypoints. Decode external values with the existing runtime parser before narrowing unknown; an assertion cannot validate JSON. Await promises and own rejection/cancellation; async forEach does not await work. Use bounded parallelism only for independent effects. Prefer textContent and URL APIs. Node spawn arguments do not validate executable paths, option injection or Windows shell wrappers.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.

## AI Pitfalls (Auto-Generated from `contracts/pitfalls-catalog.json`)

<!-- BEGIN GENERATED:pitfalls-ts-js -->
| ID | Severity | Symptom | Good Pattern | Layer | Status | Source |
|---|---|---|---|---|---|---|
| `PIT-TS-001` | high | Spawning .cmd/.bat shims via execFile(..., { shell: false }) fails on Windows Node.js >= 20.12 | Resolve explicit executable or invoke Node directly via process.execPath without batch wrappers | `ci-test` | `enforced-by-lint` | RT-20260708-001 |
| `PIT-TS-002` | high | Mixing node:fs / process.env side effects into pure readonly core modules breaks MCP no-write guarantees | Inject readonly IO adapters via parameters and keep pure core free of fs/env/child_process imports | `ci-test` | `enforced-by-lint` | ADR-0052 |
| `PIT-TS-003` | medium | Comparing process.argv[1] to import.meta.url without realpathSync skips CLI main() when launched through symlinks | Compare fs.realpathSync(path.resolve(process.argv[1])) === fs.realpathSync(fileURLToPath(import.meta.url)) | `ci-test` | `enforced-by-lint` | PR-869 |
| `PIT-TS-004` | medium | Omitting relative ESM extensions or narrowing JSON with `as` bypasses runtime validation | Always specify explicit ESM extensions and validate unknown parsed JSON before narrowing | `lint` | `active` | CS-003 |
<!-- END GENERATED:pitfalls-ts-js -->
