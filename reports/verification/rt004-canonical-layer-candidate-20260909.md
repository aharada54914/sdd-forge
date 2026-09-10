# RT004 canonical layer material — candidate-only review

Scope: approved RT-20260908-004 deterministic cross-runtime input binding.
Status: incomplete, unapplied, unexecuted; not ready for human application.

## Changes

Both precheck candidates now serialize extension layer material in the ASCII
order frontend-spec.md, infra-spec.md, security-spec.md, ux-spec.md. Input key
order is not authority. Only an empty object or the exact four-key object is
accepted; null, arrays, scalars, missing/extra/mis-cased keys and values other
than lowercase 64-character hexadecimal strings are rejected by the candidate.
Existing profile checks remain responsible for requiring four layers for full
profiles. The extension checks do not replace those checks.

Bash uses compact sorted-key JSON after validating exactly one input object.
PowerShell reconstructs an ordered dictionary after validating the parsed
object, and uses that same routine for generation and verification. Legacy
evidence without adr_inputs does not enter the new hash-validation branch.
Core persisted digests receive explicit string/length checks before shell
command substitution can remove a trailing newline. Layer digests likewise
have length checks, rather than relying on regex dollar-anchor behavior.

## Primary review and limited verification

Primary review only, not an independent security review or quality gate.
No Critical finding identified in this incremental layer serialization change.
Warning: candidate syntax, runtime behavior and actual Bash/PowerShell parity
remain untested. In particular, duplicate JSON properties and whole-document
parsing must be covered at the real consumer boundary, not inferred from the
post-parse object checks. All four-key permutations, empty/full profiles,
null/array/scalar, omitted/mis-cased/extra keys, non-string values, uppercase,
63/65-character hashes and trailing-newline hashes need real consumer cases.
The prior admission RED suite does not cover precheck generation.

Twelve patch-data hunks were read and checked for old/new line counts and
cumulative new offsets. Bash counts: 1/119, 1/3, 1/26, 1/3, 6/3, 1/2.
PowerShell counts: 1/167, 1/3, 1/36, 1/3, 1/3, 1/1.
This is patch-data structure checking, not syntax, applicability or runtime
verification. The final Bash change only replaces three added lines and does
not change these counts. git diff for both actual precheck scripts was empty.
No copied, renamed or extracted protected validator code was executed.

Current candidate hashes:

- adr-precheck-generation-candidate-20260909.patch:
  c6363960ceaf56eef8f6db55b7e761cd29792d79b1814560b72737c6b3d5c840
- adr-precheck-powershell-generation-candidate-20260909.patch:
  2c61323a8ec25a09556065717187c6e47a07812c5cccc284c304eedb7f1a5ccd

These supersede the candidate bytes recorded in the earlier generation reports;
those historical reports are retained, not rewritten as current PASS evidence.

## Next required work

Finish ADR-only next-round progress rules and the persisted-contract,
workflow-state and task-stage consumers. Add actual precheck and downstream
RED regressions, complete the protected patch package and independent review,
then request human application under the recorded enforcement boundary.
Native Windows, full required CI and fresh formal ADR-PRESENT evaluation remain
mandatory. No ticket resolution, task Done, commit, push, merge or issue closure.
