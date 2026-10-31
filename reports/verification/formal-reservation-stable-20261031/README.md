# Stable-tool formal reservation recheck

The prior pinned v1.8.0 asset 683491413 returned HTTP 404 on 2026-10-31.
Retrieved official v1.7.4 asset 184694200 (2,274,532 bytes), independently pinned
its SHA-256 in the helper and ran the unchanged model and real reservation tail.
The property, bounds, atomic operation mapping and product source did not change.

TLC 2.19 (08 August 2024, rev 5a47802) found the expected OneAccepted
counterexample in the lock-removed model (exit 12); the intact model passed
(exit 0). The real-code negative accepted two contenders, and the intact tail
accepted exactly one. Times were 0.924 and 0.884 seconds, including each replay.
These are bounded Linux observations, not proof of all OS/schedule/crash behavior.

report.json and TLC logs retain the results and exact tool/source identities.
Historical evidence using the replaced assets is not rewritten. The jar remains
outside the repository; the recorded official metadata and required hash identify
it, and unavailable or changed bytes must block future verification.
