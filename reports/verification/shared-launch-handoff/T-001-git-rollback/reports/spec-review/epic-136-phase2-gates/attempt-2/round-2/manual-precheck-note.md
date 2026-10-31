# Manual Precheck Note: epic-136-phase2-gates / attempt 2 / round 2

Date: 2026-07-13T23:48:38Z

## Deviation

The automatic round-2 precheck validated the status, hashes, and prior summary,
then rejected the prior contract because its validator compares an absolute
calibration path with the canonical repository-relative reviewer manifests.
The identity reservation validator requires those repository-relative paths,
so both conditions cannot be represented by one manifest. This is the review
launch precheck defect tracked in issue #61.

## Human authorization

The active human `sdd-sudo` 24-hour authorization, option-A specification
authorization, and instruction to continue provide explicit approval for this
narrow issue-#61 manual-precheck deviation. Review findings are not waived.

## Manual checks performed

- Attempt 2 round 1 has two distinct reserved reviewers, schema-valid outputs,
  a sanitized summary, a NEEDS_WORK verdict, and three Major findings all
  pointing to the same missing partial-install recovery acceptance surface.
- Requirements and AC-013 changed after round 1 to require a fixed-index
  rename fault, exact candidate-prefix/previous-suffix digest state, exit 2,
  and complete reviewed rollback restoring every recorded prior digest.
- Current input hashes and the non-replay round-2 destination are bound in the
  adjacent precheck result.
- Reviewer identities will again be reserved sequentially before launch.

## Result

Manual precheck passed under the temporary issue-#61 fallback.
