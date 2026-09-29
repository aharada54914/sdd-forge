# Issue 137 — Outcome / OwnerRegistry selected RED attempt

## Result

Test-only preflight and 25 appended test bodies prepared at checkpoint `b266c2a18a4e510aace9b4c5a220d308e6806d3b`. Production remains unchanged. **This execution is unsuitable as the contract RED checkpoint:** fixture cleanup interfered with the selected slice.

Executed once, without rerun:

```text
rtk proxy node --test --test-reporter=spec --test-name-pattern=^OR- tests/sdd-context/validation.test.mjs
```

UTC `2026-09-29T14:28:18.365441+00:00`–`2026-09-29T14:28:18.667429+00:00`; Node v24.13.0 / Darwin arm64 / login:false. Exit **1**; tests **25**, pass **4**, fail **21**, skipped **0**; stderr empty.

| Observed result | Bodies | Evidence limit |
| --- | ---: | --- |
| Outcome positives reject with `validation-rejected` | 13 | The content-free error cannot distinguish the missing fixture from the unimplemented contract. |
| Outcome rejection-only tests pass | 4 | These passes do not prove their named rejection boundaries. |
| Registry tests and shared guards fail fixture construction with `ENOENT` | 8 | Validation is not reached. |

## Cause and next checkpoint

The raw stack points to `validation.test.mjs:631`, where `registryEntry` calls `realpathSync` on the removed fixture. The same file registers scratch cleanup at line 15, then yields through top-level imports at lines 714–715 and 884 before registering this appended slice at line 939. The observed missing scratch is consistent with cleanup running during these yields when all earlier test bodies are filtered out. No extra execution was used to confirm scheduling.

Candidate repair for root review: load the existing modules before registering fixture cleanup/tests, preserving all original 125 test bodies. That changes the fixed prefix, so it was not applied. A corrected selected run needs a new authorization; the current raw attempt must be retained. Do not proceed to production GREEN from this attempt.

## Preservation and scope

All 31 prepared inputs were stable during execution; all 50 prior proof identities remain exact; HEAD unchanged. The original 54,480-byte / 125-test prefix is unchanged. Frozen artifacts, tasks, state, ledger, registry and fixed privacy tests retain their prepared identities. The new authority addendum SHA-256 is `543d36d02bfce3e1cb244b84f6c0f30ed3093f1025f06f97fe58b0a20f75096f`.

Private evidence directory: `specs/sdd-context-continuity/verification/T-001/outcome-registry-red-20260929-01a0ebb9/`. `red-run.json` SHA-256 `6b0981a757aea0044a81a3c22a6d99679bb923c29f1261853fe81c8231be7557`; stdout SHA-256 `5019b68055c2ff5468738a5ac81646dad2dfda6b71724ab2d589c0fbb0c6477e`; appended test SHA-256 `20a9dc53ee770df9fde33e8fba2c5343b11399292ed9f205ad78fe15ed962dd2`.

This is synthetic encoding/admission work only. No installer integration, sync, reconcile, persistence, foreign-log read, lock release or Git write authority is established. No worker commit/push or quality-gate verdict. T-001 remains incomplete; carried corrections 1/3, remaining 2. Stop for root review.

## Approved helper repair and fresh RED

Root authorized moving the existing prepareStore optional import and journalRedact import before fixture cleanup/test registration, integrating readFileSync/statSync into the static fs import. Early validate import, all 125 existing and 25 appended bodies, cleanup and assertions are unchanged. This is the explicit fixed-prefix exception recorded in the new delta, task correction **2/3**, remaining **1**. The preceding invalid attempt and its raw evidence remain immutable.

The same selected command above ran once more under this new authorization, UTC `2026-09-29T14:35:12.375801+00:00`–`2026-09-29T14:35:12.696514+00:00`, Node v24.13.0 / Darwin arm64 / login:false: exit **1**, tests **25**, pass **11**, fail **14**, skipped **0**, stderr empty. No `ENOENT`. All 14 positive bodies fail with the existing `validation-rejected`: nine kind positives, vocabulary, recovery, privacy, budget, and confirmed registry positive. The 11 rejection-only passes remain fail-closed evidence only; later branches after the first positive failure were not reached.

All 31 inputs were stable during this run; the original 50 proof identities and all 7 invalid-attempt artifacts remain exact; production, frozen artifacts, tasks, state, ledger, registry and HEAD unchanged. The complete test file equals the pre-repair snapshot with only the authorized import transformation; there is no top-level await after first after registration.

Fresh evidence: `specs/sdd-context-continuity/verification/T-001/outcome-registry-red-repair-20260929-01a0ebb9/`. Run SHA-256 `1c4e270d499f3b757915d00d764d0c12b72bba3305be133164ef5d1df8c473ed`; stdout SHA-256 `f420e62f426eff51020880600e05dcff765247369a424812c815937be380fcf9`; repaired test SHA-256 `dd450fe66c69ed3aa3037a028d3a0ae0e239820785180e9a3ea0ac1b39f82ff7`. This supersedes the preceding invalid attempt as the candidate RED checkpoint. No production repair, further rerun, Git mutation or review-status change. T-001 incomplete; stop for root checkpoint.
