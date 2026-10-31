# A8 v3 publication alignment — NOT APPLIED

## Formal baseline and conclusion

- `specs/epic-196-a8-integration/requirements.md:542-568` AC-026 requires a
  recorded single-use nonce and verified provenance/signatures. It does not
  require successful directory fsync or power-loss durability. AC-027 at
  lines 570-576 forbids classification substitution; it is not an fsync rule.
- `specs/epic-196-a8-integration/design.md:651-660` requires a lock-directory,
  temp-file, atomic-rename and guarded lock-release pattern for consumption.
  `infra-spec.md:176-184` restates concurrent/repeated-call correctness.
  Neither clause requires directory fsync to succeed.
- `requirements.md:364-368` AC-010 separates local macOS execution from
  existing Windows/Linux CI; `design.md:785-793` requires the REQ-004 fixture
  matrix on three OSes. These are not proof that the unimplemented broker
  already works on any OS. The proposed broker TEST-087–089 extend its own
  parity checks, without changing existing CI topology or live-host gates.
- Actual consumer `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py`
  lines 502-506 uses one mkdir and immediate contention failure; lines
  509-516 re-read/hash-check; lines 520-525 require file flush/fsync and
  atomic replace; lines 527-534 attempt directory fsync but catch OSError.

Conclusion: matching atomic publication plus mandatory file fsync and
best-effort directory fsync does not relax an identified formal AC/design
requirement. It DOES change v3's unadopted TEST-050 and ambiguous "durably"
wording. This proposal makes that candidate change explicit. It does not
assert crash/power-loss durability or completed cross-platform validation.

## Smallest v3 candidate edits proposed

1. Replace broker "durably appends" / "durable append" / "durable issuance"
   with "atomically publishes an entry before challenge delivery". Define
   publication completion as successful file flush/fsync and atomic replace,
   followed by a best-effort directory-open/fsync attempt. Catch only the
   latter directory attempt's OSError, like the consumer; do not suppress
   file fsync, write, chmod or replace errors. No challenge precedes replace.
   Retain post-publication failure entries; never rollback/reuse them.
   Success makes no power-loss persistence guarantee where directory fsync
   is unsupported or fails.
2. TEST-050 remains one parameterized row: file-fsync failure before replace
   means exit 4/no delivery/original ledger; directory-open/fsync OSError
   after successful replace is tolerated and leaves the complete new entry
   visible before challenge delivery; successful directory fsync follows the
   same visible ordering. No new TEST ID, consumer change or extra gate.
3. TEST-046 uses one mkdir/immediate failure (not "times out"). TEST-047/048
   require no lost update, not guaranteed success for both contenders.
4. Carry forward exact 88 ASCII canonical-base64 payload plus LF/CRLF;
   bound input to 91 bytes for overflow detection. TEST-067 and TEST-092/093
   retain their existing IDs with concrete payload/frame boundaries.
5. Distinguish the existing proof TTL (session_start minus issued_at >
   86400 seconds) from the proposed broker interactive-wait upper bound
   (wall-clock and monotonic elapsed >= 86400 seconds, separate clocks).
   The equal numeric value is a proposed operational limit, not an existing
   TTL-implied stdin rule. Keep consumer exactly-24-hour acceptance intact;
   parameterize TEST-055 and existing TEST-070/071, adding no test rows.

The preceding mandatory-directory-fsync proposal is NOT SELECTED by root.
Only non-frozen candidate notes were edited. Formal specs, source, approval,
keys, signatures, ledger, and review identities remain untouched. This is
read-only contract analysis, not an implementation or native Windows proof.
