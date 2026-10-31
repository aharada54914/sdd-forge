# Revision 2 primary recheck

2026-10-05. Candidate verification only; protected originals unchanged.

- Re-executed `attempt17.fixture.py`: exit 0, 20 PASS, including combined-history preservation and rejection of a tampered earlier manifest.
- Re-executed `human-apply.py --check`: exit 0, READY; old target hashes, patch hash and `git apply --check` matched.
- Inspected the full application helper: three pinned targets, retained original-byte backups, pre-application recheck and post-application readback.
- Candidate patch SHA-256: `e29da29237393940a6427497e12c669ce31704d2c9aafb9ccf0981f901ff497c`.

The combined-history fixture mocks the immediately preceding inspection result. It does not prove full combined-path caller execution or real host admission. The historical technical finding remains preserved separately. No formal verdict, reservation, protected application, commit, push or merge was performed by this recheck.
