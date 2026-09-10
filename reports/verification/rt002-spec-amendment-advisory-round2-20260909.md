# RT002 spec amendment advisory follow-through

Status: corrected inert candidate; not applied; formal review pending.

Candidate: `rt002-spec-amendment-candidate-20260909.patch`
SHA-256: `0df91892144c5af1f6e1c93e2dd27f0bcf702ddafb03d362f8873aca671c85a4`

The independent advisory reviewer `/root/hook_contract_security_review`
reported no remaining Critical/Warning in the bounded second-round recheck.
This is not an SDD gate verdict, identity reservation, or Done decision.

## Changes since the first advisory

- Added 21 explicit selector/runtime combinations, four self-consistent
  malformed-nonce cases, ten forbidden-flag value-type cases and two
  case-only envelope mutations: 37 added rows, 109 total Planned rows.
- Distinguished recording unavailable evidence during scoped repair review
  from mandatory fresh matching native dispatch at activation. The narrowly
  approved repair-review route stays open; unrelated entry stays closed.
- All previously specified acceptance rows remain. No exact-byte requirement,
  CI gate, cleanup check, or live-proof condition was relaxed.

`git apply --check --recount` against the current canonical files exited 0.
This validates diff applicability only; the patch has not been applied.

## Coverage limits and follow-through

The current Shell test at line 708 and PowerShell twin at line 614 already
use self-consistent invalid nonces of lengths 32, 31, 33 and 32 respectively.
The first has uppercase hex and the last has a non-hex z; those four values
do isolate the intended syntax boundaries. A tentative suspicion of wrong
literal lengths was disproved by direct character counting; no corrective
edit to those literals is justified.

Do not infer full implemented coverage from 109 Planned rows. The original
tests must still be mapped row-by-row, including exact diagnostic categories
and the new acceptance rows not present in the existing fixtures. Prior RED
results remain RED and do not prove the candidate implementation works.

Next: finalize the permitted human application path for the canonical spec
amendment, then use the existing sanctioned reset/precheck and independent
formal provenance reviews. Do not activate the production candidate or
resume unrelated blocked entry on the strength of this advisory.
