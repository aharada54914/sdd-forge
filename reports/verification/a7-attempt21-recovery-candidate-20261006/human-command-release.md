# Human command release — 2026-10-06

Independent four-target package review: PASS, Critical 0, Major 0; see `independent-four-target-package-review.md`. The previously reviewed 53 unique candidate cases remain bound to unchanged candidate bytes.

The owner authorized continued limited repair/review. The coordinator released the bounded human helper after the package review: `RELEASE_READY=True`, truthful release docstring/default output, and fixture-only final test message. No target pins, patch bytes, validation logic or application logic changed.

- Released helper SHA256: `ab83246608dc68b54608f917071ad692376a90d71ccb16daf3a023cfda721726`.
- Helper test SHA256: `b23b39a3f84528c35637721ade40616e028118a9de7fded28285b1ecf09dddf7`.
- Patch SHA256: `8359ff939c5da6fc5dfab435ebabb73097c62f7af1283debb1e90508277970ca`.

Executed after release: `rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 reports/verification/a7-attempt21-recovery-candidate-20261006/human-apply.tests.py` exited 0, all 10 disposable fixture cases passed. Owner check-only `rtk proxy python3 -B reports/verification/a7-attempt21-recovery-candidate-20261006/human-apply.py` exited 0: `CHECK_OK: fixed patch/source/candidate hashes; no writes`.

Owner protected targets remain unapplied. Human application is still required by the protected-application policy. No ledger reservation, verdict, task state or Git history changed. Original-path regression, ordinary A21 precheck/admission, formal review, native verification, CI and merge remain pending. Release of this helper is not any of those gates.
