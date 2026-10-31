# T-010 activation grammar correction — local TDD evidence

Status: local implementation evidence only; not formal quality gate, Implementation Complete, Done, or live-host T-008 spy. Commands ran in the A7 owner checkout on macOS on 2026-10-04 through `rtk proxy`; no Git ref, review identity, frozen specification, or task status was changed.

## Boundary and RED

The Approved T-010 contract permits only `merged` and `fingerprint_match` predicates with AND/OR. The frozen A7 AC-004/AC-021 activation is merge-only; an extra caller-text predicate delayed activation after merge. Tests were changed first and run against the then-current implementation:

| Command | Exit | Observed RED |
|---|---:|---|
| `rtk proxy bash tests/skip-allowlist-manifest.tests.sh --case=primitives` | 1 | 10 pass, 2 fail: both unsupported predicates returned 1 instead of malformed-input 2. |
| `rtk proxy bash tests/skip-allowlist-manifest.tests.sh --case=manifest-contract` | 1 | 0 pass, 1 fail: shipped activation strings included the extra predicate. |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case primitives` | 1 | 10 pass, 2 fail: both unsupported predicates returned 1, not 2. |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case manifest-contract` | 1 | 2 pass, 1 fail: compound rendering retained the extra predicate. |

These are actual pre-change failures, not injected RED. The new merged-only positive fixture was added before final GREEN; its no-caller-marker path is also checked in both runtimes.

## Local correction and GREEN

The two manifest activation strings now match the frozen merge conditions. Both evaluators reject the extra predicates as malformed (exit 2) and no longer expose their direct CLI helpers. Existing merge/fingerprint behavior, independent zero-SKIP fingerprint audit, and failure diagnostics were retained. Both runtime suites now assert the closed grammar and merge-only activation without a caller marker.

| Command | Exit | Result |
|---|---:|---|
| `rtk proxy bash tests/skip-allowlist-manifest.tests.sh` | 0 | 28 passed, 0 failed. |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1` | 0 | 31 passed, 0 failed. |
| `rtk proxy bash tests/structural-compatibility.tests.sh` | 0 | 61 passed, 0 failed. |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/structural-compatibility.tests.ps1` | 0 | 68 passed, 0 failed. |
| `rtk proxy bash -n tests/lib/skip-allowlist-evaluator.sh tests/skip-allowlist-manifest.tests.sh` | 0 | Syntax accepted. |
| `rtk proxy git diff --check` | 0 | No whitespace errors. |
| `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility` | 0 | Workflow state OK; the checker emitted only its existing investigation-amendment tolerance note. |

PowerShell ran on macOS, not Windows. These local runs do not substitute for current-head CI, formal review, QG, or T-008's real-host invocation spy. The current A5 item-10 normalized digest is already used by the manifest, but its current four-sub-item semantics exceeds the older A7 three-fixture citation; the frozen normative A7 artifacts need explicit semantic reconciliation and independent re-review before any completion claim. Current report `Outputs` hashes predate this correction and must be refreshed before formal evaluation.
