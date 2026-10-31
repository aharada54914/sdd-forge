# Attempt 17 recovery candidate — non-formal verification

2026-10-05, revision 2. This is a non-protected candidate only. The previous patch hash `b10cc57146ab44e1b8d078156110f5e4c54fa3c6b80c1cee8eec193f0221f749` is superseded and must not be applied. No protected original, review reservation, verdict, or prior evidence was changed. It is not a formal review result or an attempt-17 admission.

## Scope

The mechanical `recovery.patch` changes exactly three protected paths: `plugins/sdd-review-loop/scripts/fresh-review-recovery.py`, `plugins/sdd-review-loop/scripts/failed-last-attempt.py`, and `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`. It preserves the ordinary v2 contract and adds an optional, strictly checked `historical_failed_rounds` list. This permits the explicitly identified attempt-15 failed round 3 to be inspected alongside the immediately preceding attempt-16 round-1 no-output partial. Completed rounds from both paths are accumulated and returned to the existing Bash and PowerShell callers, including when a historical failed round and an immediately preceding failed later round are both named. Existing helper validation continues to check pinned prior evidence, identities, manifests, and ledger; the new option is not a general reset or verdict override. Attempt-16 diagnostic transcript remains separately hash-pinned by the orchestrator; this candidate does not add a transcript parser or claim the review was completed.

## Exact candidate pins

| Artifact | SHA-256 |
|---|---|
| `fresh-review-recovery.py.candidate` | `8d95150acc8e0b539f3acba755e57fd402d315b0be7b591d9ec9c11f2732776e` |
| `failed-last-attempt.py.candidate` | `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f` |
| `SKILL.md.candidate` | `25301e17e3069c26567e2b5ff107aafc46b824dde81a7e87f31533f57cd35227` |
| `recovery.patch` | `e29da29237393940a6427497e12c669ce31704d2c9aafb9ccf0981f901ff497c` |
| `human-apply.py` | `7b463232e20ee98d2c524cc60438c5ecc4c731696bb8b9daf7de58c00a8f10dc` |
| `attempt17.fixture.py` | `e5a3e74196ad28d2c36ea8422d74975866662c81e0feb753128d70c544a28d24` |

Protected-original SHA-256 pins embedded in the runner, in patch target order: `a276ae4fd2f8acb0bbe3e1898a6d53495cb113a300f3560f19e6d68e937478fc`, `f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a`, `f11e6d93a45b3a43ac2b53075e50915d093bee24ce76e81b8f0591e3b6f5c323`.

## Verification

Superseding 2026-10-05 verification: the combined-history negative test below had a subprocess/mock false-positive defect. It now uses the same validation path for a successful repinned no-op control and mutation rejection with a specific binding error. Primary session 78837: 21 PASS, exit 0. Independent non-formal review confirmed the fix; formal/native admission remains unverified. See `../a7-attempt17-primary-verification-20261005.md`. Historical 20-PASS output below is retained, not relied on for the corrected mutation assertion.

- `rtk proxy python3 -B reports/verification/a7-attempt17-recovery-candidate-20261005/attempt17.fixture.py`: 20 PASS, exit 0. The prior candidate failed the new combined-history assertion with only `(16, 1)` returned; the revised candidate retains `(15, 1)`, `(15, 2)`, `(16, 1)` and rejects a repinned tampered earlier manifest. For this combined branch only, the fixture mocks the immediately preceding `inspect` result to avoid inventing host receipts; it proves the aggregation and earlier-history helper validation, not a full combined-path caller run. The original 18 checks use isolated temporary copies and include both full Bash and PowerShell callers for the actual attempt-15 completed history, replay rejection, completed-contract rejection and v2 compatibility. The earlier independent primary-agent 18 PASS applies to the superseded fixture only; revision 2 has not yet received independent review. These are synthetic/integration tests, not a native host review.
- `rtk proxy git apply --check reports/verification/a7-attempt17-recovery-candidate-20261005/recovery.patch`: exit 0; no write.
- `rtk proxy python3 -B reports/verification/a7-attempt17-recovery-candidate-20261005/human-apply.py --check`: exit 0, `READY: three old hashes and patch hash match; git apply --check passed; no write`. This checks only revision 2; it does not apply anything.

## Remaining boundary

The three protected originals remain at the old hashes. `human-apply.py --apply-human` is prepared for the human-only guarded application step; **it has not been run**. Its preconditions require the exact old hashes, exact patch hash and three-target inventory, and `git apply --check`; it takes a temporary backup before applying and checks all three new hashes after. A protected-operation refusal is a stop, not permission to use another path. After authorized application, an attempt-17 contract still needs the orchestrator's real hash-bound inputs and normal precheck; no reservation or reviewer launch is claimed here.

## Non-formal attempt-17 input candidates

The separate `approval-audit-attempt17.candidate.json` and `fresh-review-contract-attempt17.candidate.json` are **not** the final immutable audit/contract. They quote the actual continuing user authorization already transcribed for attempt 16, change `next_attempt` to 17, retain terminal attempt 7 and all partial attempts 8–16, place attempt 15's failed round 3 in `historical_failed_rounds`, and pin attempt 16's no-output round-1 evidence. They do not claim a signature, human-authored record, completed reviewer turn, or retrospective legality. The approval candidate SHA-256 is `7b8ce385bb454910a24301072f969ab227aa860446243925522c6751e93d362c`; the contract candidate SHA-256 is `dacad1c54f869d1df9700aa994a97fb2090e23a853b5329c973424dbca3db497` (66 evidence entries).

`rtk proxy python3 -B reports/verification/a7-attempt17-recovery-candidate-20261005/check-attempt17-contract-candidate.py` completed exit 0 on the current owner evidence: candidate helper validation returned completed rounds `(15, 1)` and `(15, 2)`. The check redirects only the internal failed-attempt helper to its candidate bytes in process; it never invokes the installed precheck or writes originals. Before any real attempt, the orchestrator must verify the authorization transcription and all current inputs, confirm protected patch application/readback, finalize immutable audit/contract paths and hashes, then run the normal precheck. Neither this candidate check nor prior fixture results prove actual caller admission or native reviewer launch.
