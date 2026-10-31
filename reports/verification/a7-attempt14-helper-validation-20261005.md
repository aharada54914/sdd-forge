# A7 attempt 14 fresh-review helper validation (2026-10-05)

Scope: read-only admission helper and isolated fixture. The normal Bash/PowerShell precheck callers have not received the protected change at this point. No precheck reset, identity reservation, reviewer launch, or verdict was performed.

The four live admitted-file SHA-256 values were measured with `rtk proxy shasum -a 256 --`:

- requirements: `b04eff0242f5143c52c8c92a7d05ee90cc2034e9e9635379601946a35c950acc`
- acceptance tests: `4e3f4916c8bb6fd20ceb7bd51b0b18e7d3bf9522e7fabcde44aa80b77e0f3192`
- investigation: `d730b8ec35c285baa6f9e2f91533b04a4e5202206aa75839d2921f07d0547908`
- calibration: `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`

The existing helper's composite rule is SHA-256 of ASCII `requirements_sha256:acceptance_sha256:investigation_sha256`, without calibration. Recomputed value: `62e829bd12c95d426ca45dfff450f755cb7484a8f16a45bf1047dd4cd76227f2`. The as-yet-unused attempt-14 approval and contract were corrected from an erroneous composite; historical attempts 13 and earlier were unchanged. Approval SHA after correction: `bbb3b25a25314d0e6f91d6c9f0197bed22d68136d22f57fa3177144f7377a2fa`; contract SHA after authority repin: `6ba0221a48eaa39d71b4d30130addf77e66dc9d77ef6177826bb55c3fb759d94`.

`rtk proxy python3 plugins/sdd-review-loop/scripts/fresh-review-recovery.py <owner-root> epic-195-a7-compatibility 14 <attempt-14-contract>` exited 0 and returned the six historical A-invocation paths (attempts 8 through 13). This only validates the fresh-review recovery contract; it is not the normal precheck or a review outcome.

`rtk proxy python3 specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py --helper-only` exited 0: 13 isolated cases passed, comprising amended live input versus pinned history (positive); altered historical manifest SHA, invocation sequence mismatch, ledger chain corruption, duplicate ledger record, missing historical reservation; and seven historical invocation-envelope negatives (wrong input mode, wrong fallback mode, extra or missing key, malformed ledger digest, sequence 1, malformed previous-record digest). The fixture copies evidence into temporary directories and does not edit owner history. The ledger digest is checked for format only: comparing it to today's ledger would incorrectly reject a valid earlier reservation.

An independent audit found that removing the normal validator would otherwise leave historical invocation `input_mode`, `fallback_mode`, exact key set, and digest/sequence formats unchecked. The helper now validates those invariant envelope fields without comparing old document hashes to current documents.

Helper SHA: `2cff54f410ead4c1904808f97aaa8d8b852ee95cf37c95a45fad838ff84621a3`. Fixture SHA: `ce71c2194860233ed6ea506c0b60760e586c09179d748512eaae85686ba90112`. A final type guard rejects a non-object invocation before `.get` access; the 13 helper fixture cases were rerun and passed after that guard.

Remaining boundary: the protected caller/skill edits were rejected by the repository hook and are pending the separate authorized human-apply path. Integrated Bash/PowerShell fresh-review precheck has not been claimed green; no formal attempt-14 review has been started.
