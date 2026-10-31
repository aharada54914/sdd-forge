# Attempt 18 recovery candidate — not an admitted review

**Superseded transport proof: do not apply this bundle.** A later regression
found that identical truncation of both the prompt file and native transcript
was accepted. See sibling `a7-attempt18-complete-prompt-candidate-20261005/`
for the replacement candidate and RED/GREEN evidence. Historical records and
the original candidate bytes below are retained, not validated retrospectively.

Recorded: 2026-10-05. This directory contains **non-final candidates only**. Do not use these paths as an immutable formal audit/contract, run attempt-18 precheck, or reserve reviewer identities until the launch transport is proven. To finalize, write the approval audit to a separately named formal path, read back its hash, update both `authority.path` and its evidence entry in the formal contract to that path/hash, write and hash the formal contract, and rerun the read-only recovery helper on those final bytes. A simple file copy is insufficient.

## Historical boundary

Attempt 17 completed its normal precheck and one reviewer-A reservation (ledger sequence 1204). Its native first-turn TTY paste delivered only the prompt tail, so no admitted review input was read and the response is diagnostic-only, not a specification FAIL/PASS. Preserve the private transcript locally; its SHA-256 is `c97147d1fe1e80faa39bfb63f4ae9fa086beed641e48ca927175d1a0bc783381`. Do not publish the private path or raw bytes, reuse that host/session, re-reserve, or create reviewer-B output for attempt 17. The attempt-17 blocker note is the pinned public inventory record.

The proposed attempt-18 contract retains terminal attempt 7, all contiguous partial attempts 8–17, the failed later round of attempt 15 and its completed NEEDS_WORK rounds 1 and 2, and the existing diagnostic-only disposition. It pins the four attempt-17 public records: precheck, A host allocation, A invocation, and launch blocker. It carries the same current specification hashes as attempt 17. The approval audit transcribes the user's existing continuing authorization for next attempt 18; it is not a signature, not a claim that a human wrote the JSON, and not a retrospective validation of past transitions.

SHA-256 of the current candidates: approval audit `c02521c3d03c77a0928356b2e9e6bf9546f97b603b06189be833a6e8655cf9b6`; contract `de5b42ce7cc05b5e377ddae6e5a6fae61a97a665d764c375522dcbfc4d5c4539`. Read-only installed helper validation:

```text
rtk proxy python3 plugins/sdd-review-loop/scripts/fresh-review-recovery.py . epic-195-a7-compatibility 18 reports/verification/a7-attempt18-recovery-candidate-20261005/fresh-review-contract-attempt18.candidate.json
exit 0; completed_rounds=(15/1 NEEDS_WORK, 15/2 NEEDS_WORK); terminal=7/2; all prior invocation paths through 17/1 returned
```

This is **recovery admission only**, not a formal reviewer verdict, precheck, reservation, or an independent code review.

## Transport boundary and proposed limited change

`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` lines 139–149 currently require fresh **host-issued** run/session IDs, an empty idle allocation with **no model turn**, then identity reservation, then the first reviewer turn in exactly that reserved context. `claude -p` reading a file from stdin was separately observed to deliver 1812/1812 bytes (SHA-256 `232f8bafc6beda68c8010d7cc46cef2567b3815d4b3647f74aa6582a9c5d85cd`, including its tail) in a new unreserved diagnostic session. It does **not** establish delivery into the preallocated idle host. `-p --resume` while that diagnostic background host was running refused with `That session is running in the background`; after stopping the idle host, it refused with `No conversation found with session ID`. An identity-only `-p` model turn before reservation is explicitly incompatible with the current idle/no-turn rule. The separate A8 operator reported a working `--session-id UUID --print` route using a caller-generated UUID under A8's different implementation-review contract; this is not independent A7 evidence and cannot satisfy A7's host-issued requirement as-is.

The bounded candidate in this directory changes only the spec-review launch instruction and adds one read-only non-TTY proof helper. Its opt-in local Claude branch uses a *caller-proposed* canonical UUIDv4, copied into the two required `run_id` and `host_session_id` fields as **one** identity. It does not claim host issuance, a separate run identity, or a no-turn allocation receipt. Before one ordinary reservation, the helper checks the current ledger hash, unused UUID and absent native transcript; a proposal record explicitly says host acceptance is still unproved. After the complete prompt is sent by file/stdin to a single `claude -p --session-id UUID --output-format json` first turn, the helper requires the CLI wrapper's accepted session ID, a sole exact native user turn, and matching reviewer output identities. The ordinary output/manifest validators remain mandatory. Any error leaves the reservation consumed and all model bytes diagnostic-only. The existing host-issued route is unchanged.

Candidate protected targets are `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` (old SHA-256 `25301e17e3069c26567e2b5ff107aafc46b824dde81a7e87f31533f57cd35227`, proposed `17758ae05353a46f60538a342154fa3d767329e5d12dc3d51fcbe2922bf3ee99`) and new `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` (proposed `487f1b6a40e4bb2079d876f5dd7815da6ae49d17f567445ff357fb6f4ad352cf`). `nontty-launch.patch` is SHA-256 `0d387304946dd4d94d3e410937c26a0bf2d0eee2be4dd520ba6aae5ffe47c274`. The default read-only human-runner check is:

```text
rtk proxy python3 -B reports/verification/a7-attempt18-recovery-candidate-20261005/human-apply-nontty.py --check
READY: old hash, new-file absence, patch hash and git apply --check match; no write
```

The synthetic negative fixture `nontty-launch.fixture.py` exits 0 with 15 PASS cases, including reuse, invalid/separate identity, absent/double reservation, host or model ID mismatch, host error, truncation and extra human user turn. An existing private native trace was inspected by shape only: tool results are `type:user` with `content:[{type:tool_result}]`, and a `file-history-snapshot` row lacks `sessionId`. The helper permits those exact structural forms while still requiring one first human prompt and matching IDs; no private content is published. This is not live host proof. A direct unreserved `claude -p --session-id UUID` probe returned API 429 before execution; its wrapper echo is **not** acceptance. Before formal use, an unreserved live diagnostic must prove a fresh caller UUID is accepted with exact non-TTY delivery and that an existing-session collision is rejected. Then independent technical review, human-protected application/readback, formal-path rebinding of approval/contract, normal precheck, separate A/B identity reservation, and all ordinary review validation remain. No protected code was changed here; no attempt-18 precheck, reservation or reviewer was launched.

Independent read-only technical audit by the separate A8 implementation agent confirmed the two candidate hashes, four current input pins and recovery helper exit 0, with terminal 7/2, completed 15/1 and 15/2, and historical invocations through 17/1. No JSON mismatch was found. It specifically required the formal-path rebinding sequence above and agreed that the transport remains a blocker. This was **not** a formal spec-review verdict or native reviewer launch.

A separate limited technical re-audit of the fixed non-TTY candidate independently matched the proposed skill/helper/patch hashes above and reran all 15 fixture cases with exit 0. It found no additional major defect in the reviewed diff. Its scope explicitly excludes proving the complete ledger chain, full reviewer output schema, trusted native capture, or live CLI acceptance; those remain normal-validator and live-diagnostic obligations, not fixture claims.
