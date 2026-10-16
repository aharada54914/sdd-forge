# Cloud publication checkpoint — 2026-10-16

This is a publication and resumption record, not a quality-gate verdict, task
transition, release, baseline promotion or native-host activation receipt.
The user authorized selected commits and pushes to existing remote branches.
Original owner checkouts, indexes, approvals and historical evidence remain
untouched. Official session-stop inspection is unavailable in this environment;
the publication checkout is independent and does not certify any owner idle.

## T-002 provider-key repair

Publication base: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`, existing branch
`codex/issue423-boundary-checkpoint`. The remote head matched that base before
publication. This unit publishes an existing reviewed repair without changing
its source bytes or the task plan.

The Registry contamination walker previously visited dictionary values while
missing provider names in keys. The existing repair also visits keys; the
regression covers direct, nested and list-contained keys in trigger and
conditional predicates, including uppercase terms. No schema is changed.

| Published artifact | SHA-256 |
| --- | --- |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5` |
| `specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py` | `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca` |

Both hashes match the owner record
`reports/verification/issue423-t002-independent-codex-20261014.md` and the
earlier provider-key repair review. Those records remain local; this paragraph
is a derivative summary, not a replacement for their larger evidence closure.
The independent review was an explicitly authorized Codex exception outside
the formal identity ledger; no new reviewer reservation is claimed here.

Executed in the clean publication checkout on macOS:

- RED: copied only the existing regression to the unmodified publication base;
  `python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root .`
  ran 29 tests and exited 1 with 192 failing provider-key subcases.
- GREEN: after transferring the exact reviewed validator bytes, the same command
  ran 29 tests successfully, exit 0.
- `bash tests/validate-capability-registry.tests.sh`: 27 passed, 0 failed, exit 0.
- `pwsh -NoProfile -File tests/validate-capability-registry.tests.ps1`:
  27 passed, 0 failed, exit 0. This is PowerShell on macOS, not Windows evidence.
- An initial command used the nonexistent `tests/capability-registry.tests.sh`
  path and exited 127; the real suite paths above were then used.
- `git diff --check`: exit 0. The selected sources were checked for private
  owner paths, private-key headers and common credential-token patterns.

These results cover this repair on the publication base. The complete local
T-002 completion record, evidence bundle and later task transitions are not
published by this unit. No current-head CI, installer, full-task acceptance or
merge result is inferred from these local checks.
