# Attempt 17 candidate: primary-agent verification

Status: application/readback confirmed; independent formal review remains incomplete.

## Post-application readback — 2026-10-05

The primary agent ran `rtk proxy shasum -a 256` in this owner worktree after the human application. Exit 0; all three protected targets match the candidate pins:

- `plugins/sdd-review-loop/scripts/fresh-review-recovery.py`: `8d95150acc8e0b539f3acba755e57fd402d315b0be7b591d9ec9c11f2732776e`
- `plugins/sdd-review-loop/scripts/failed-last-attempt.py`: `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f`
- `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`: `25301e17e3069c26567e2b5ff107aafc46b824dde81a7e87f31533f57cd35227`

This supersedes the historical application-pending statements below, not their test limitations. The attempt-18 recovery README records attempt-17 normal precheck and a consumed reviewer-A reservation, followed by incomplete TTY prompt delivery and no formal verdict. No identity is reused or new reservation made by this readback. The proposed non-TTY route still requires its live transport checks and authorized application before a new formal attempt; CI, merge and Done are not established here.

## Superseding verification after independent finding

The original combined-history tamper assertion below was not reliable: its subprocess did not inherit the inspection mock and could reject unchanged input for an unrelated inventory mismatch. Do not use that original assertion as tamper-detection evidence.

The fixture now validates both a repinned no-op control and a changed manifest through the same in-process mocked path, requiring the specific `last-attempt manifest differs from its precheck` error only for the mutation. Primary session 62800 first exposed a mismatched expected diagnostic; after correcting that expectation, session 78837 completed with exit 0 and 21 PASS lines, including both full Bash/PowerShell callers and replay rejection. Fixture SHA-256: `e5a3e74196ad28d2c36ea8422d74975866662c81e0feb753128d70c544a28d24`.

Independent non-formal reviewer `/root/a7_attempt17_review` inspected the corrected path and reported no additional finding. This does not establish formal review or real host admission. The protected recovery patch and its application helper are unchanged and remain pending human application.

## Historical execution (qualification above applies)

The primary agent executed `rtk proxy python3 -B reports/verification/a7-attempt17-recovery-candidate-20261005/attempt17.fixture.py` in the owner worktree on 2026-10-05. Execution session 22899 finished with exit 0 and 20 PASS lines, including Bash/PowerShell full caller checks, replay rejection, historical manifest/receipt tampering, combined-history preservation, and original v2 compatibility.

This independently repeats the revision-2 fixture execution. The combined-history test mocks the immediately preceding inspection result; it does not establish native reviewer execution or actual attempt-17 admission. The test does not replace protected-source readback, the normal precheck, fresh reviewer identities, or independent formal review. No reservation, verdict, approval, task status, commit, push, or merge was performed by this verification.

The primary agent also inspected the candidate README and its history-preservation boundary. Contract/audit candidates remain non-formal; their final placement and current-input verification are pending protected application.
