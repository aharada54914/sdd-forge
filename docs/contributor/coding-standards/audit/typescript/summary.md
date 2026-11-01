# TypeScript / JavaScript correction evidence (#690)

Audit base: `82b53695`; implementation commits begin `67648d61`, `3af2299b`.
This record concerns executable source, scripts and tests, with bundled dist rebuilt by each package's existing build. Frozen report/human-copy JavaScript snapshots were not edited.

## Reproductions and checks

- In a detached checkout of `82b53695`, compile the original CI and SDD MCP tests using the same installed lockfile dependencies, copy only the new compiled regression tests, then run `node --test --test-name-pattern 'malformed upstream|oversized rate-limit|directory cycles'` on `upstream-shape.test.js`, `error-normalizer.test.js`, and `list-guarded-files-diagnostics.test.js`. All six fail: four unchecked upstream-body cases, invalid Date range, and recursive directory cycle. The corresponding corrected tests pass. This is an actual baseline replay, not an inferred pre-fix count.
- The public JS hook test with a correctly signed token and `issued-epoch` suffixed `oops` failed before the epoch fix: actual exit `0`, expected `2`. Complete decimal parsing now rejects `oops`, `.5`, and `e0`; valid signed token still allows.
- `python tests/guard-stop-inspection.tests.py`: nine Node tests pass. Both JS entrypoints encounter a real kernel EACCES from an inaccessible parent directory (run as an unprivileged uid when the test itself is root). EIO is injected and explicitly scoped as injection. Absent/directory/regular-file controls retain the existing marker contract; Copilot emits a structured denial. Windows ACL permission behavior is not established by the POSIX fixture.
- `npm ci --ignore-scripts`, existing `npm run typecheck`, existing `npm run build`, and `npm test` executed for all three packages. Final local package suite results before cross-lane integration: CI 155 passed, local-env 53 passed, SDD 314 passed, zero skipped. All bundled changes came from esbuild.
- An actual local HTTP server sends headers and a partial log without ending its body. The CI transport cancellation regression aborts that real Fetch body and returns a sanitized error; partial data does not appear in the envelope. This does not contact GitHub or certify all upstream network behavior.
- Status-view tests fetch the delivered HTML, execute its embedded script in a VM DOM fixture, and resolve two feature refresh responses out of order. The latest selection survives. HTTP loopback/Host/Origin/method checks remain exercised by actual requests. This is not a browser accessibility or native-host evaluation.
- The stdio entrypoint rejects `--unknown` with exit 1 and empty protocol stdout. Missing option values and positional arguments are rejected by standard `parseArgs`.
- `bash tests/guard-parity.tests.sh`: 262 passed, zero failed after stop-marker changes; the later decimal-parser correction has its additional signed-token regression above.
- `node tests/adversarial-review-contracts.tests.mjs` passes normally and through a symlink named `repo 日本語 with spaces` with `--preserve-symlinks-main`. `fileURLToPath` replaces URL pathname interpretation.

## Review boundaries and deliberate separations

Runtime JSON from GitHub stays unknown until each action's existing Zod dependency validates consumed fields. Unknown upstream properties are allowed but never copied wholesale into output. JSON/text body semantics remain separate. Fixed GET, token gate, host construction, allowlisted local commands, MCP envelope and stdout contracts remain unchanged.

The local-env input boundary accepts unknown before its existing schema. Test helpers now use the SDK's `CallToolResultSchema` rather than `as never`; AJV validators need no double assertion. Node's supported mock API replaces child-process module casts. The status UI DOM fixture has an explicit small interface. Remaining test shape assertions are followed by concrete assertions or contract-schema validation; malformed input fixtures are intentional evidence, not production validation bypasses.

Reviewed injection sinks include argument-array subprocess wrappers, fixed inspector startup commands (the Windows npm.cmd shell branch has fixed arguments), structured JSON serialization, literal generated fixture programs with JSON-serialized data, escaped dynamic regex inputs, fixed contract/header regex keys, percent-encoded URL components, and status DOM `textContent`. No SQL execution surface was identified in the current JS/TS source. Similar approval/WFI/domain/second-approval hook functions retain distinct policy ownership; they were not collapsed solely because their shapes resemble each other.

Directory enumeration tracks active canonical ancestors, so a symlink cycle stops with diagnostics while separate aliases still enumerate normally. Existing tolerant consumers continue their documented treatment of enumeration diagnostics; this patch does not silently replace their public envelope contract.

The native TS 7.0.2 scanner from #687 checks the tracked population, syntax, and selected AST rules. Its zero findings are not proof of complete semantic safety; contextual flows and runtime evidence above are separate. Native macOS/Windows and actual Claude/Copilot/Codex host execution were not performed in this Linux lane. Final integrated counts, generated diagnostic copies, CI/catalog wiring and independent reconciliation belong to #692.

## Embedded installer JavaScript follow-up

The shell lane identified four literal embedded Node programs in `install.sh`, `install.ps1`, `uninstall.sh`, and `uninstall.ps1`. Arguments already crossed as data, but read errors and temporary-file creation were unsafe. Installer read errors previously became an empty configuration; uninstaller read errors became silent success. Both writer pairs used a predictable temporary path without exclusive creation or private permissions.

The correction ignores only ENOENT, uses `wx` temporary-file creation with mode 0600, and cleans up only its own created temporary file after a failed rename. A pre-existing `.sdd-forge.tmp` now makes registration/unregistration report failure and preserve both files; it is not automatically deleted. Existing wrapper behavior continues processing other clients after the warning.

`tests/mcp-json-boundaries.tests.mjs` extracts and executes the exact four shipped Node bodies. Twelve cases fail on `82b53695` and all twelve pass after correction: real POSIX EACCES without loss of existing JSON, pre-existing temporary file preservation, normal mutation retaining unrelated keys and Unicode paths, and private file mode under an explicit umask022. The shared Python wrapper now runs 21 Node regressions total. These tests establish embedded-program behavior; native Windows PowerShell/ACL behavior remains a separate host boundary.

After those embedded-program changes, actual installer wrappers were exercised on Linux: `bash tests/install.tests.sh` (51 passed), `bash tests/uninstall.tests.sh` (25 passed), the required local pwsh launcher running `tests/install.tests.ps1 -Lane clients` (passed), and `tests/uninstall.tests.ps1` (all scenarios passed). The PowerShell results are Linux pwsh results, not native Windows results.
