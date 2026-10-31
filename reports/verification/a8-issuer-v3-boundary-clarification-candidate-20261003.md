# A8 v3 boundary clarification — NOT APPLIED

Scope: proposed clarification of the existing v3 candidate only. No source,
frozen specification, approval, ledger, key, or signature is changed. No new
TEST IDs or CLI/schema interfaces are proposed. Requires root disposition.

Disposition update: root did NOT select the mandatory directory-fsync branch
below. It is retained as rejected history, not an applicable instruction.
The narrower replacement is recorded in
`a8-issuer-v3-publication-alignment-candidate-20261003.md`.

## Read-only findings

- Existing `design.md:648-650` and
  `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py:489-494`
  specify record/session TTL: issuance strictly precedes session start, and
  expiration means session start is **more than** 24 hours after issuance.
  This is not a broker interactive-input deadline. The old non-frozen design
  candidate (`a8-issuer-repair-design-candidate-20261003.md:95-101`) proposes
  88 ASCII payload characters and a 24-hour wall/monotonic wait, but v3 does
  not carry these concrete limits into its proposed design clause.
- Consumer `strict_b64` at `validate-live-host-proof.py:125-134` requires
  canonical decode/re-encode equality; its call at line 326 requires 64 raw
  bytes. Thus canonical Ed25519 base64 payload is 88 ASCII characters.
  There is no existing consumer stdin framing or input-wait contract.
- Consumer lines 502-506 use `Path(str(ledger_path) + ".lock").mkdir()` and
  fail immediately on contention, not after a retry timeout. Lines 509-516
  re-read and compare the original ledger hash under that lock. Lines
  520-525 use a same-directory temp, file flush/fsync, preserved mode and
  `os.replace`. Lines 527-534 attempt directory fsync **but swallow OSError**.
  Lines 535-544 clean only this invocation's temp and acquired lock.
  Therefore v3 TEST-050's directory-fsync failure prohibition is a proposed
  broker guarantee, not an existing consumer guarantee. No consumer parity
  claim or consumer implementation change is justified by this inspection.

## Minimal replacement wording proposed for the v3 broker clause

Use `issued_at` sampled immediately after successful A1 challenge generation
and a monotonic start sampled at the same point. Broker issuance must finish
before both `issued_at + 86400 seconds` and `monotonic_start + 86400 seconds`.
At either boundary (`>=`), cancel input waiting, fail with exit 6 and empty
stdout. Recheck both clocks immediately before publication; a wall clock
earlier than `issued_at` also fails closed. This is a conservative **new
broker** deadline; the existing consumer's `session_start - issued_at >
86400` expiry rule and exactly-24-hour acceptance remain unchanged.

Read one binary stdin frame: exactly 88 canonical-base64 ASCII payload
bytes, followed by LF or CRLF (89 or 90 total bytes). EOF before the frame
terminator, an invalid payload, or a frame exceeding 90 bytes fails with
exit 2, empty stdout and no append. Use a bounded reader (at most 91 bytes
to detect excess), interruptible by the above deadlines; never use an
unbounded line read. LF/CRLF are framing, never part of signed bytes.

Acquire the consumer's identical `PATH + ".lock"` directory with one mkdir;
contention fails immediately with broker exit 4. Do not wait, retry or remove
a pre-existing lock. Under the acquired lock, re-read/validate the latest
ledger and registry, reject registry drift and duplicates, then append
without losing a consumer update completed while the human was signing.
Use same-directory temp, flush/file-fsync, original mode and atomic replace.
After replace, attempt directory fsync before challenge delivery. Unlike the
current consumer, **any directory open/fsync failure is broker exit 4 with
no challenge delivery**; the already-replaced entry is retained and must
not be rolled back or reused. This fail-closed durability requirement may
make issuance unavailable on a host without directory fsync support; it is
not a claim of cross-platform success and must be tested before adoption.
Only remove this invocation's own temp/acquired lock in cleanup.

## Existing parameterized TEST rows to refine, not multiply

| Existing row | Concrete parameters / assertion |
|---|---|
| TEST-055 expiry | wall elapsed and monotonic elapsed independently: 86399, 86400, 86401 seconds; at/above limit exit 6/no append; wall rollback fails closed; blocked reader is interrupted at deadline |
| TEST-067 oversized | payload 89 bytes or frame 91 bytes: exit 2/no append; bound allocation/read independently of attacker line length |
| TEST-038 canonical input | 88-byte noncanonical/invalid encoding and wrong decoded length: reject; no whitespace trimming |
| TEST-053 EOF | EOF before LF/CRLF: no append and no challenge |
| TEST-092/093 framing | valid 88-byte signature plus LF / CRLF accepted as respective framing fixtures, with identical verification bytes |
| TEST-046 lock | pre-existing lock: immediate exit 4, unchanged ledger, foreign lock retained |
| TEST-047 concurrency | sequential successful issuance appends preserve both entries; overlapping lock acquisition rejects one invocation immediately rather than promising both succeed |
| TEST-048 concurrency | consumer update before broker lock is preserved; consumer racing broker sees existing lock or changed-byte rejection, never lost update; no assertion that both racing invocations must succeed |
| TEST-050 durability | file fsync before replace: original ledger retained; directory open/fsync after replace: entry retained, empty stdout, exit 4; inject each independently |
| TEST-070/071 consumer | existing exactly-24-hour acceptance / greater-than-24-hour expiry remain unchanged |

These are specification proposals, not executed broker tests. Read-only
source inspection found no need to change the consumer, A1, or signing model.
The directory-fsync availability tradeoff needs explicit root selection; do
not silently turn it into a portability fallback or label three-OS parity PASS.
