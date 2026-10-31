# Issue 423 T-002 current-byte implementation addendum — 2026-10-07

Preparation for a new, independent quality evaluation only. This is not a replacement for the canonical implementation report, a new implementation run, a quality verdict, or a Done decision. The old report at `reports/implementation/sdd-domain-multitarget/T-002.md` remains frozen at SHA-256 `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4`; its Outputs and 28-test result describe an earlier byte snapshot. Its stale hashes do not establish the current state.

## Ownership and risk

Issue #423, T-002, owner checkout `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`, HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. The working tree is dirty with other contributors' changes; only the non-frozen T-002 preparation files named below were created for this follow-up. Approved task risk is medium, but the protected review/evidence boundary remains high-risk and retains its formal gate. Affected contracts: T-002 ownership/provider-neutrality and ci-mcp read-only Done When, WFI-036 Post-Fix Artifacts admission, current-byte evaluator inputs, independent verdict. No source, prior verdict, ledger, reservation, installer, or task-state bytes were edited for this addendum.

## Current T-002 post-fix bytes

| Path | SHA-256 | Meaning |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea` | T-002 source |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5` | Includes post-review recursive dictionary-key provider-term check |
| `specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py` | `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca` | Includes provider-key negative regression |
| `reports/verification/issue423-t002-formal-major-followup-20261007.md` | `d720645523aa86e12b23cf09334eacbff4e8532d9771c8a21d9c01b9634a885c` | Caller-owned 29/29 command output and old Major analysis |
| `reports/verification/issue423-t002-focused-diff-20261007.md` | `ecf55da74d39add6529c271d4cf5836e852748a04cf146dbe14360bf486caafd` | Complete owner-HEAD diff of only the three T-002 source/test paths |

The 29-test command and full stdout are in the formal-major follow-up. It passed locally (29/29, exit 0) but is neither an independent reviewer verdict nor current-head CI. The focused diff excludes `install.sh` and `tests/install.tests.sh`, whose separate dirty changes are not claimed as T-002 work. The previous mixed diff remains preserved as history and must not be admitted into the new T-002 evaluator input set.

## Remaining verification boundary

The T-002 contract still records historical failed acceptance/regression entries, and ci-mcp/integration, native hook activation, complete current-head CI, and merge are not proven by this addendum. An independent evaluator must inspect the new declared bytes under a fresh manifest, compare the current post-fix test evidence, and issue its own verdict. No historical report or prior `NEEDS_WORK` is promoted to PASS.
