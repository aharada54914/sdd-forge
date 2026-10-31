# Bounded reservation verification for the combined candidate

The source `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`
was checked at SHA-256 `8d4397f7120d07b6eb0513049c519367de7e9cd1d61ea2814c1b8ffcd28dedcf`.
Research input authorization differs from the previous candidate outside the
reservation transaction; the extracted reservation tail remains byte-identical
at SHA-256 `099073aafef9082cab371bfab889a19afe4e40a3f9d791739ceb820052a4a92c`.
The prior `formal-reservation-main-20261028` reports remain historical evidence
for their original source hash and are not rewritten.

With the pinned TLC v1.8.0 asset and the local `verify-review-reservation`
procedure, the lock-removed negative model produced the expected invariant
counterexample and its synchronized real-code mutation accepted both contenders.
The baseline model passed and its real-code replay accepted one contender. See
`report.json`, the TLC logs, including the negative trace. The verification is bounded
to two contenders and one attempt each; it assumes atomic mkdir/rename and
cooperating writers, and excludes crash recovery, hostile filesystems, retries,
network filesystems and Windows semantics. It is not a proof of the full review
flow and does not confer task approval or authorize A9 promotion.
