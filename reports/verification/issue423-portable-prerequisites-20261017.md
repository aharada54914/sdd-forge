# Issue 423: portable prerequisite verification

Scope: restore the already-reviewed T-002 helper typing and reuse main's successful-install cleanup correction before revalidating T-001/T-002 prerequisites for T-003. No approval, frozen verdict, identity, or authorization changes are included.

Owner: branch `codex/issue423-cloud-publish`, isolated publication checkout.
Starting HEAD: `8f66fc30407f9da0e2ca0f77d64a3fc5c6bd55fd`; working tree was clean.
Classification: routine restoration of approved behavior; existing task completion gates remain mandatory.

Affected surfaces: registry discovery helper and validator imports, installer EXIT cleanup, installer regression fixtures. Registry discovery order, fail-closed validation and installation rollback on errors remain unchanged.

Required validation: pinned Ruff/mypy, registry discovery Bash/PowerShell, T-002 contract boundaries, installed payload parity and validator execution, installer regressions, T-003 selected-obligation tests, independent diff review. Historical reports remain historical; new results do not retroactively replace their failures or prove native activation.

Pre-change observation: Ruff reported an unused hashlib import; strict mypy reported six untyped helper definitions. Main already contains the installer correction that avoids reporting registration failure after a successful FilesOnly installation. Reuse only this correction and its existing tests.

Publication excludes backups, host paths, credentials, raw local logs and unrelated shared-enforcement changes. Canonical completion evidence must be regenerated from verified portable inputs before marking any prerequisite or T-003 Done.

## Executed validation

The installer and its test changes are identical to commit `164767d998240b33f8622849729fb46f55e0a3d3` (#544), contained in observed `origin/main` at `f10c2c61f93e5deca46f73497ca8feaa0315df26`. The restored helper matches the previously reviewed SHA-256 `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea`.

| Check | Observed result |
| --- | --- |
| `tests/install.tests.sh` | 43 passed, 0 failed |
| `tests/installer-idempotency.tests.sh` (independent reviewer) | 7 passed, 0 failed |
| Registry discovery Bash / PowerShell on macOS | 21 passed, 0 failed each |
| T-002 `contract-boundaries.tests.py` | 29 passed |
| `tests/sdd-domain-multitarget-T-003.tests.py` | 28 passed |
| Ruff 0.13.3, helper and validator | passed |
| mypy 1.18.2, strict validator and imported helper | passed |
| Isolated `install.sh --target FilesOnly`, plugin/agent/MCP registration disabled | installation succeeded; helper and validator byte-identical; installed validator passed all 9 checks |
| Bash syntax and whitespace | passed |

Fresh-context, read-only independent Codex reviewer `portable_prerequisite_review` inspected all four proposed files and independently repeated installer, idempotency, discovery, lint, type and syntax checks. Verdict: PASS, no corrective findings. This is a diff review, not a formal task completion verdict.

Not performed by this repair: native Windows execution, native plugin activation, full CI, canonical T-001/T-002/T-003 quality gates or Done transitions. Successful current runs do not rewrite historical failures.
