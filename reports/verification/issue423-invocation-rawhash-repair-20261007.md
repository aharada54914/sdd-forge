# Issue #423 shared invocation raw-hash repair

Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
Pre-edit HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
Pre-existing dirty files included the four edited untracked launch/transport/test
files and many unrelated tracked and untracked files; all were retained.
Scope: approved common review launch repair. Risk: high, because it changes
exact command admission and native proof. Affected contracts are invocation
raw-hash proof, exact Bash permissions, ordered prompt, diagnostic parity and
pre-reservation native proof count. No ledger, reservation, verdict, frozen
evidence, installed baseline or A7 checkout was changed. No Git commit,
push or branch operation was performed.

Root cause: `launch_policy` admitted invocation Read, while `receipt_control`
did not admit its exact `shasum`, `control_prompt` omitted it from numbered
commands, and `native_delivery` omitted it from required hash results.
`probe-nontty-review` hashed the source invocation only because it appended
that separate file to admitted inputs. The repair requires the current
invocation's raw SHA-256 first in both formal and diagnostic paths. A wrong,
missing, failed or out-of-order hash remains a pre-review stop.

Preflight field/counterpart/mismatch checks: invocation raw digest versus
current invocation bytes: added focused Red test for missing permission,
prompt and policy entry; native required-hash mapping now uses `sha(invocation)`.
Diagnostic hash count versus formal count: updated probe and launcher parity
to `len(admitted inputs) + 5`; existing missing-proof test rejects absent
count before reservation. Receipt chain, identity and admitted-input hashes
retain their existing mismatch checks.

Focused test: `rtk proxy python3 tests/quality-nontty-transport.tests.py`
passed 12/12 after repair. The added test first failed with `TypeError` because
the old `receipt_control` accepted no invocation path. It also confirms that
the legacy non-strict spec control prompt is byte-identical with or without
the invocation path, and that changing invocation bytes makes native delivery
reject the saved prompt while the fixture ledger remains unchanged. Python compile check of
the four changed files passed. `rtk proxy git diff --check` passed for tracked
files; the edited launch files and test were untracked at this checkout, so
that command does not independently inspect their whitespace. No native Claude
probe, formal reservation, independent review, quality gate or CI was run here.
