# Acceptance Tests: epic-136-phase2-gates

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | cross-runtime regression | Escaped `grep` expression, `2>&1`, `ls`/`cat`/`find` inspection of protected paths are allowed by `.py`/`.js`/`.ps1` | Planned |
| AC-002 | REQ-001 | TEST-002 | security regression | Redirect, `tee`, `cp`, `rm`, and ambiguous payloads still deny protected writes in every guard runtime | Planned |
| AC-003 | REQ-002 | TEST-003 | unit / security | 64-hex validation plus full 32-byte XOR helper accepts a valid HMAC and rejects first-, middle-, and last-byte changes | Planned |
| AC-004 | REQ-002 | TEST-004 | static compatibility | The PS helper has a fixed 32-iteration compare loop, accumulates XOR, has no `return`/`break`/short-circuit in that loop, decides only after it, has no `FixedTimeEquals` or direct signature string comparator, and remains ASCII/no-BOM PS5.1 compatible | Planned |
| AC-005 | REQ-003 | TEST-005 | regression | `evidence`, `red_evidence`, and `green_evidence` reject absolute/traversal/unresolvable cases with complete field-specific output exactly matching pre-refactor golden fixtures | Planned |
| AC-006 | REQ-003 | TEST-006 | unit / regression | Valid in-root evidence for all three fields and missing-file failure preserve previous contract behavior | Planned |
| AC-007 | REQ-004 | TEST-007 | policy unit / parity | Auth, access token(s), credential(s), MCP, external/third-party API(s), secret(s), and GitHub Actions fixtures force full; `design token(s)`, `API design`, and ordinary text do not | Planned |
| AC-008 | REQ-004 | TEST-008 | workflow conformance | lite-spec stops before writing a lite spec on a policy hit, and ship chooses full even when invoked with `--lite` | Planned |
| AC-009 | REQ-004 | TEST-009 | fail-closed workflow | A risk-hit feature missing full artifacts stops with a bootstrap/full-track diagnostic and never invokes the lite gate | Planned |
| AC-010 | REQ-005 | TEST-010 | generator determinism | Canonical data generates byte-identical `.py`, `.js`, `.ps1`, and `.sh` modules with every required v1 shell key/export; generated modules contain the declared schema version and constants | Planned |
| AC-011 | REQ-005 | TEST-011 | CI drift / security | `generate-guard-invariants.py --check` fails without writing on stale output, missing output, invalid schema/type, unsupported version, or generator error; CI runs it before guard suites | Planned |
| AC-012 | REQ-005 | TEST-012 | static/runtime parity | Guard runtimes fixed-resolve native generated modules from their own script directory, reject missing/poisoned modules or an unconsumed v1 shell export, do not read/parse canonical JSON at runtime, and retain the shared decision corpus from a different CWD | Planned |
| AC-013 | REQ-005 | TEST-013 | human-copy integrity | A disposable human-reviewed batch manifest has exact set equality with the canonical target inventory and canonical source-to-target binding; the immutable R-10 runner reads canonical/manifest/source bytes through root-handle-relative no-follow opens, hashes and copies each source through the same held handle, holds destination parents against substitution, prepares and verifies all same-parent temporaries before replacement, atomically replaces entries without following hard-link aliases, rejects hash/mapping/omission/duplicate/escape/link/reparse/native-capability cases, and cleans temporary files on a pre-replacement failure. A fixture-only instrumented copy injects rename failure after a fixed inventory index, proves exit 2 and the exact candidate-prefix/previous-suffix digest state, then a reviewed complete rollback batch restores all recorded pre-install digests and passes post-install verification; normal install preserves protected-write denial including CI workflow | Planned |

Notes:

- This is CLI/CI enforcement work with no user-facing UI; the UI integration
  checklist is not applicable.
- The normative protected target set is
  [requirements.md#protected-phase-2-target-inventory](requirements.md#protected-phase-2-target-inventory).
  Tests are authored outside the protected test set; live protected changes are
  staged under `human-copy/` for a human copy.
- TEST-001 through TEST-004 and TEST-010 through TEST-013 run on Windows and
  POSIX CI lanes as applicable. The PowerShell source check explicitly targets
  Windows PowerShell 5.1 compatibility.
