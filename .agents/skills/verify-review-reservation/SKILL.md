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
identity history. `tests/fixtures/project-skills/formal-review-reservation/mapping.json`
pins the source and maps atomic mkdir, the
post-lock hash comparison, staged append/rename and lock release to model actions.
The finite model has two actors, one attempt each, and no crash, retry, stale-lock
recovery, malicious filesystem or Windows semantics. All writers must honor the
same lock; mkdir and same-directory rename must be atomic and hashes collision-free.
A finite-model PASS is not a proof of all implementation schedules or operating
systems.

The covered source is `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`
in the combined integration candidate, SHA-256
`8d4397f7120d07b6eb0513049c519367de7e9cd1d61ea2814c1b8ffcd28dedcf`.
The unchanged acquire/hash-check/append/rename/release tail has SHA-256
`099073aafef9082cab371bfab889a19afe4e40a3f9d791739ceb820052a4a92c`.
Evidence for the combined candidate is in
`reports/verification/formal-reservation-combined-20261028/`. The separately
recorded historical asset check (id 683491413) is in
`reports/verification/formal-reservation-asset-683491413-20261029/`; earlier
main-based evidence remains historical. Use the local
`pstack-maintain-formal-verification-skill` procedure when the mapping drifts.

## Tool choice and setup

TLC from the fixed `v1.7.4` release asset explores the interleavings directly
and is smaller here than translating shell/jq/filesystem operations into a
code-level verifier. Java must be installed. Release asset `184694200` is
available from `https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar`;
query `gh api repos/tlaplus/tlaplus/releases/assets/184694200` for metadata.
Download the jar outside the repository and verify SHA-256
`936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`.
The helper rejects all other bytes before creating an evidence directory.
These bytes report `TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)`.

The previously selected v1.8.0 asset `683491413` returned HTTP 404 on 2026-10-31;
assets under that tag had already been replaced repeatedly. The stable release
is sufficient for this unchanged finite model and avoids following the moving
asset. This does not guarantee perpetual upstream availability: if the exact
asset disappears or differs, stop rather than accepting a new jar implicitly.
Historical v1.8.0 evidence remains unchanged. The new tool's negative, baseline
and actual-code race observations are recorded separately in
`reports/verification/formal-reservation-stable-20261031/`.
Bash, jq and sha256sum are required for the Linux real-code replay. No network
call occurs during verification.

## Run and observe

From the source repository, execute:

```sh
python3 tests/verify-review-reservation.py --jar /path/to/tla2tools-1.7.4.jar --output /path/to/new-evidence-directory
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
