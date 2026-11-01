# RT002 recovery: reservation mapping maintenance

The full POSIX CI detected a stale source fingerprint after implementation-input validation changed. The ordinary regression first failed only its source-mapping check. Before refreshing that pin, the previous source hash was matched to main `2cea5aec8cdf77ae624ebd7d09b099a9b68940f0`; the extracted lock/check/append/release transaction was compared byte-for-byte and matched the unchanged recorded tail SHA-256 `099073aafef9082cab371bfab889a19afe4e40a3f9d791739ceb820052a4a92c`.

The production change adds refusal before reservation and does not change the modeled transaction or introduce a new ledger writer. The property, model and assumptions are unchanged. The current source is pinned in `report.json`; earlier proof records remain unchanged.

Following the existing verification profile, actually ran:

```
python3 tests/verify-review-reservation.py --jar /workspace/scratch/project-skill-formal/tla2tools-1.7.4.jar --output /workspace/scratch/rt002-formal-maintenance-20261101
```

The helper checked the pinned jar SHA-256 before running. The lock-removed model produced the expected counterexample (exit 12), and its real-code replay accepted both contenders. The intact model passed (exit 0), and its real-code replay accepted only one. Retained logs and report are original execution output. Ordinary regression passed 6/6; related project-skill lifecycle 43/43, profiles 5/5 and observation 40/40 also passed.

Scope remains two contenders with one original ledger hash, one attempt each, atomic mkdir/rename, cooperating writers and no hash collision. This does not prove crash/retry recovery, hostile filesystem safety, Windows semantics, all schedules or whole-application correctness. The replay extracts the reservation tail and substitutes unrelated validation setup; separate admission tests cover the new allowed_inputs checks.
