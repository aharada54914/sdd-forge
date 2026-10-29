---
name: verify-review-reservation
description: Recheck the bounded identity-ledger reservation invariant after lock, hash-check or publication changes.
---

# Verify review reservation

This opt-in verification profile is for the sdd-forge source repository. It is
supplemental evidence; it never replaces normal tests, review or task gates.

## Property and scope

Two contenders holding the same original ledger hash cannot both succeed in one
reservation attempt. The user harm is two reviewers admitted against conflicting
identity history. `mapping.json` pins the source and maps atomic mkdir, the
post-lock hash comparison, staged append/rename and lock release to model actions.
The finite model has two actors, one attempt each, and no crash, retry, stale-lock
recovery, malicious filesystem or Windows semantics. All writers must honor the
same lock; mkdir and same-directory rename must be atomic and hashes collision-free.
A finite-model PASS is not a proof of all implementation schedules or operating
systems.

## Tool choice and setup

TLC from the pinned `v1.8.0` release asset explores the interleavings directly and is smaller here than translating
shell/jq/filesystem operations into a code-level verifier. Java must be installed.
The tag `v1.8.0` is only a distribution label; the maintainers have replaced the asset
under it more than once, so the tag alone does not identify the tool. Identify it by asset:
GitHub release asset id `683491413` (created 2026-10-28T01:50:09Z), queried via
`gh api repos/tlaplus/tlaplus/releases/assets/683491413` (metadata; the bytes are fetched
with `Accept: application/octet-stream` or from the tag URL
`https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar`, outside
the repository). Required SHA-256 is
`fc6878c603f0fdc18b9fe3e5bf51860cb90ab5b1154e3c371660c036d6bdd63e`; the helper rejects
any other bytes. These bytes report `TLC2 Version 2026.10.28.014557 (rev: 56d37a9)`,
recorded as the observed version, separate from the tag and the asset identity.
Earlier evidence used other assets under the same tag (2026-10-25
`d15655eeaff4b3f7b3d65c46b838bc0f35d131b2ef4b1e473689b62c98d4726f`; 2026-10-27
`78f7e2c6bf9a8b65eda665a23e94431255587e0b43a834a4e2af1723562d9b4a`, build
`2026.10.26.231022`). Because those assets were replaced, tag-only reproduction of
that evidence is no longer possible; it is historical and was not re-run with this tool.
Bash, jq and sha256sum are required for the Linux real-code replay. No network call
occurs during verification.

## Run and observe

From the source repository, execute:

```sh
python3 tests/verify-review-reservation.py --jar /path/to/tla2tools-1.8.0.jar --output /path/to/new-evidence-directory
```

The output directory must not exist. The helper first verifies the source pin,
then runs the lock-removed negative model and the intact baseline. It retains TLC
logs, counterexample traces, tool hash, source hash and measured time. It also
extracts the actual reservation transaction from the pinned Bash script into
isolated scratch state and invokes two competing processes. The negative mutates
that extracted code's acquire/release guard; both calls must succeed. The intact
code must accept only one. The fixture replaces unrelated input-validation setup,
so this proves the reservation tail's observed behavior, not the whole review CLI.
For the negative replay the parent releases both contenders only after both
reach the post-hash-check barrier; timeout is a synchronization failure.

## Maintenance and cleanup

A source-pin mismatch is blocked. Inspect changed code/model correspondence before
updating the pin; do not update it solely to make the command pass. A baseline
counterexample is a product/model investigation, never permission to weaken the
property. Scratch mutations stay outside the product checkout and are removed
when each replay finishes; retained evidence survives. No scheduled invocation or
host-support claim is implied. Re-run normal project tests independently.
