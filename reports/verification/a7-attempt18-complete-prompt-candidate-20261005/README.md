# Complete-prompt candidate — NOT APPLIED

Supersedes the transport-proof portion of the sibling attempt18 recovery
candidate, not its historical records or formal admission requirements.

## Observed regression

The previous validator accepted a prompt file and native first user turn
when both contained only the same final four bytes. The new negative fixture
raised `AssertionError: ACCEPTED both-prompt-and-transcript-truncated` against
the unchanged previous implementation (exit 1).

The candidate independently reconstructs the entire fixed launch prompt from
the invocation's relative path, SHA-256, role and exact reservation receipt.
The prompt file and native first turn must equal that complete template.
Receipt syntax checking is not authentication: the ordinary canonical
validator must still authenticate the receipt/ledger and validate all inputs
and complete reviewer output. No new reservation or formal verdict was made.

## Verification

`rtk proxy python3 -B reports/verification/a7-attempt18-complete-prompt-candidate-20261005/nontty-launch.fixture.py`

Observed exit 0, 21 cases passed, including simultaneous truncation, receipt
replacement, malformed receipt, invocation change and the original transport
negative cases. Synthetic fixtures only; native admission remains unverified.

Independent technical review found the initial receipt fixture omitted the
actual validator's `identity_unique=yes` suffix (.sh:1164, .ps1:1285).
The candidate and fixture now require it, including missing/false negatives;
the initial ledger's `previous_record_sha256=-` representation is accepted.
Technical re-review confirmed the prior Major resolved with no additional
defect in its bounded inspection and 20-fixture execution. The main agent
subsequently confirmed all 21 fixtures, including false uniqueness rejection.
The regenerated two-target patch is pinned to SHA-256
`5d4ea29338300e7e6c41c7c327187bf9702310781939b84744c78d695eb43dd6`.
The current helper's `--check` passed the old source hash, new-file absence,
patch hash and `git apply --check`; no protected application occurred.
Use this directory's `human-apply-nontty.py --apply-human` only from a human
terminal. Do not run the superseded sibling helper. No protected source,
review status, identity reservation, commit, push or merge was changed.
