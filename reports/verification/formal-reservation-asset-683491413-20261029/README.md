# Reservation verification with release asset 683491413

Date: 2026-10-29. Covered source and scope are unchanged from
`../formal-reservation-main-20261028/README.md`: source SHA-256
`47e7d8de3281e3b20b52a2c03ecde820167a20149bbdaac6022d7ebe4f7e9735` (checked
against `mapping.json`; the reservation tail SHA-256 is still
`099073aafef9082cab371bfab889a19afe4e40a3f9d791739ceb820052a4a92c`). The model,
property and requirements were not changed.

Three separate identities are recorded:

- Distribution tag: `v1.8.0` (a mutable label).
- Asset identity: GitHub release asset id `683491413`, created
  2026-10-28T01:50:09Z, SHA-256
  `fc6878c603f0fdc18b9fe3e5bf51860cb90ab5b1154e3c371660c036d6bdd63e`. The
  release API digest (`gh api repos/tlaplus/tlaplus/releases/tags/v1.8.0`) and
  `sha256sum` of the downloaded jar both match.
- Observed version: `TLC2 Version 2026.10.28.014557 (rev: 56d37a9)`.

The tag was re-pointed at new bytes after the earlier runs, so the `78f7e2...`
asset and its `2026.10.26.231022` build can no longer be fetched by tag. The
earlier reports remain unchanged and were produced by those other assets; this
directory is a new verification, not a reproduction of them.

Result (`report.json`, `passed: true`; TLC logs in `negative-tlc.txt` and `baseline-tlc.txt`, copied from the ignored `*/tlc.log`):

- Negative (lock removed): TLC reports `Invariant OneAccepted is violated`
  (exit 12); real-code replay of the extracted Bash tail accepted 2 contenders.
- Baseline (intact): `No error has been found` (exit 0); replay accepted 1.

Command: `python3 tests/verify-review-reservation.py --jar /tmp/sdd-forge-tla2tools.jar --output <this directory>`.
