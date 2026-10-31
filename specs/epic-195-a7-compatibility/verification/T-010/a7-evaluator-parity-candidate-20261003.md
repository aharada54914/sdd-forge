# T-010 four-predicate parity candidate (2026-10-03)

Candidate only. Neither patch was applied to its target files. T-010 remains Approved / Planned; this is not an implementation, review PASS, CI result, quality-gate decision, or Done evidence.

## Exact source preimages (SHA-256)

Five frozen contract files:

| File | SHA-256 |
|---|---|
| `requirements.md` | `7af43a41f52d7fee4144ea603eba10cd5fe9ccf6468bcfe778afd212546f5a79` |
| `design.md` | `ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96` |
| `acceptance-tests.md` | `f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815` |
| `tasks.md` | `fee9e7323ea2d3da9b4e30aedda5d7a80c80afa83775d41db360163fe94ce321` |
| `traceability.md` | `676d2e3de2c0e311b1aa796dd4a7b21950e5ac47a030dd0fba3611617805cd31` |

Four code/test files:

| File | SHA-256 |
|---|---|
| `tests/lib/skip-allowlist-evaluator.sh` | `3e2430559547b6a06c27e19e70ac7003acb99924004c2a0ba259ef46e1c28b87` |
| `tests/lib/skip-allowlist-evaluator.ps1` | `6daae2e88a65ca7fd1b9f215f93e869215d21ee82380101cc69b5245229a1197` |
| `tests/skip-allowlist-manifest.tests.sh` | `f8a2dada6cb6db3705bef501166ff1ae9ad4d7397edf650c2db9402c17620371` |
| `tests/skip-allowlist-manifest.tests.ps1` | `66a2ffe8bb7406e5b34513f8c81aacdf2bc217cdd78108c8966ec11b94d32c4c` |

The five-spec amendment candidate is `contract-amendment-candidate-20261001.patch`. Its design hunk had an incorrect unified-diff line count; this candidate fixes that metadata only. Plain `git apply --check` now succeeds, but applying it requires the approved frozen-artifact amendment/re-review path. The four-file evaluator/test candidate is `file-contains-literal-candidate-20261003.patch`, expanded here to cover all four audit findings. Plain `git apply --check` succeeds. The Bash evaluator needs no source change.

## Regression expectations in evaluator/test candidate

| Primitive | True (exit 0) | False (exit 1) | Invalid (exit 2) |
|---|---|---|---|
| `file-contains` | exact text and literal `?*[]` in a tracked file on `main` | case variant, metachar-looking absent strings, missing path, unavailable `main` | empty path or literal |
| `executable-contains` | lower-case `.sh` without executable bit, executable file with no extension, caller after merge to `main` | non-executable `.md`/`.SH`, missing root, unavailable `main`, caller before merge | empty root |

The PowerShell test now calls `file-contains <repo> <ref> <path> <literal>` and requires **exactly** exit 1 for unavailable ref; the old five-argument call could exit 2 and still pass. The duplicate Bash unavailable-ref condition test is removed; its labeled file-contains check is replaced by a direct primitive invocation with exact exit 1. Existing AC-035 active-assertion, unknown-SKIP, and fingerprint-drift checks remain in place, as do the four predicates and their left-to-right `AND`/`OR` grammar.

## Verification boundary and next action

Observed: repository structural check OK; both candidate patches pass plain `git apply --check` against the above preimages. Not observed: patched shell/PowerShell test execution, CI, independent implementation review, re-review of the five frozen specs, or quality gate. Before applying, recheck every preimage hash and use the repository's protected/frozen-artifact procedure. Do not bypass a hook refusal. After authorized application, run the Bash and PowerShell manifest suites, their containing `run-all` suites, and current-head CI, then obtain independent review and quality-gate evidence. A candidate patch is not authorization to mark T-010 Done.
