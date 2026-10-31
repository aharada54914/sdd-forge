# T-010 contract reconciliation (2026-10-01)

Status: verification addendum only. T-010 remains `Planned`; this note does not amend a frozen specification, approve a task, or supply an independent quality-gate verdict.

## Later shared-contract changes

The task plan's T-010 Goal/Scope and the frozen `design.md` Data Plan require exactly five assertion IDs (`AC-004`, `AC-007`, `AC-021`, `AC-042`, `AC-043`), the literal JSONC-example fingerprint values, and an `activation_condition` grammar limited to `merged(...)` and `fingerprint_match(...)` combined by `AND`/`OR` (`tasks.md:1391-1490`; `design.md:395-579`). The checked-in manifest retains those five IDs, but no longer matches that example byte-for-byte:

| Surface | Frozen input | Current implementation and provenance |
|---|---|---|
| A5 fingerprint in `AC-004` and `AC-021` | `design.md:1886-1915`, digest `9b549be9…` | `design.md:2139-2179`, digest `1bf6f2e2…` in `tests/fixtures/skip-allowlist-manifest.json`; introduced by `99fcbc2e` for later A5 source movement. |
| Activation predicates | `merged`, `fingerprint_match` only | `file_contains` added by `99fcbc2e`; `executable_contains` added by `c58bc5e3`, yielding four implemented predicates in both evaluators. Current `AC-004` and `AC-021` require `executable_contains(plugins/sdd-bootstrap,resolve-project-context)` in addition to their merge predicates. |
| A5 activation meaning | A5 merged is sufficient | The later shared-contract repair checks for a live executable caller on `main` before retiring the A5-dependent SKIP. It avoids treating a documentation-only marker as an installed caller. |

These later commits are part of the current repository history and should not be reverted merely to make the old JSONC example match. Conversely, a passing current test cannot silently replace the frozen task/design contract. An independent reviewer needs to decide whether this addendum is an adequate authorized post-review reconciliation or whether an explicit spec/task amendment and provenance re-review is required under `AGENTS.md`'s post-review freeze rules.

## Current verification and remaining work

At HEAD `3a9141eece88695612831a82336e53a8688cb779`, `tests/skip-allowlist-manifest.tests.sh` passed 20/20 and `tests/skip-allowlist-manifest.tests.ps1` passed 23/23 on 2026-10-01. An independent LF-normalized SHA-256 computation over the current A5 `design.md:2139-2179` yielded the manifest's full digest `1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c`. The suites cover each of the three AC-035 hard-fail cases and a clean fixture. The present AC-034 test verifies the five current manifest entries, not literal equality to the frozen JSONC example. These focused results are implementation evidence, not T-010 completion or independent review.

Before raising T-010 from `Planned`, review the checked-in manifest and both evaluators against `requirements.md` REQ-007 / AC-016, AC-034, AC-035, the frozen `design.md` Data Plan, the two later commits above, the A5 caller contract, and the Bash/PowerShell focused tests. Check that the A5 replacement fingerprint resolves to the intended source window and that `executable_contains` fails closed when `main` or the caller is absent. Confirm all five assertion IDs remain the only allowlisted entries and each named SKIP reads the manifest. Preserve the frozen inputs and record any authorized contract amendment and re-review separately before a formal quality-gate launch. No T-010 status, implementation report, review verdict, or traceability field was changed here.
