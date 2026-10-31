# A7 attempt-18 non-TTY post-application verification — 2026-10-05

Issue #195, A7 owner checkout `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, detached HEAD `654ce55d2b23b3a0cd0d72c3e45e46144399e90e`. The existing dirty tree was preserved. This is a high-risk review-input/identity change; the affected contract is the opt-in local Claude non-TTY launch in `spec-review-loop/SKILL.md` and its read-only proof helper. No protected source was edited in this verification. The earlier candidate `preflight.md` and the owner tree's dirty status identify the edit scope; this record adds only post-application observations.

## Readback and local regression

- `rtk proxy shasum -a 256` in the owner checkout exited 0. Applied `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` is `f860a4449e7a2edfc35a61f17c88f62399a8bf425df2f3743356d08da6a2f4af`; applied `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` is `1fa826ac3b8a336c3ee9badadd0002a5078c9a660dff30b83e44b81900a6f075`. Both compare byte-for-byte (`cmp` exit 0) with the latest complete-prompt candidate files. The two-target patch is `5d4ea29338300e7e6c41c7c327187bf9702310781939b84744c78d695eb43dd6`. These hashes show current bytes, not who applied them or whether a formal review passed.
- `rtk proxy python3 -B reports/verification/a7-attempt18-complete-prompt-candidate-20261005/nontty-launch.fixture.py` exited 0 with 21 PASS cases. They include simultaneous prompt/native truncation, modified receipt and invocation, missing/false identity uniqueness, reused conversation and double reservation. This is synthetic behavioral evidence. The fixture imports the candidate helper; the applied helper was separately compared byte-for-byte with it.

## Unreserved native delivery and collision diagnostic

The diagnostic used a fresh, unreserved caller UUID `b8bee21a-c8af-4091-9210-f6035228ccdf`. It did not use a reviewer role, review input, the identity ledger, or attempt-18 precheck. The exact command in the owner checkout was:

```text
rtk proxy claude -p --session-id b8bee21a-c8af-4091-9210-f6035228ccdf --model sonnet --effort low --permission-mode dontAsk --tools '' --output-format json < reports/verification/a7-nontty-prompt-transport-probe-20261005.txt
```

The first call exited 0. The CLI JSON wrapper reported `session_id=b8bee21a-c8af-4091-9210-f6035228ccdf`, model `claude-sonnet-5-5`, `is_error=false`, and `result=RECEIVED`. A read-only parse of the local native JSONL found one text user turn and the same session ID. The turn matched the input file byte-for-byte: expected/actual 1812 bytes, both SHA-256 `232f8bafc6beda68c8010d7cc46cef2567b3815d4b3647f74aa6582a9c5d85cd`. The native transcript's path and raw contents stay local.

The identical command with the same UUID was then run as a collision negative. It exited 1 immediately with `Error: Session ID b8bee21a-c8af-4091-9210-f6035228ccdf is already in use.` A subsequent read-only native parse still counted one text user turn. No retry with another ID occurred in this diagnostic.

## Remaining boundary

The following paragraph records the boundary at the time of the initial post-apply diagnostic. Subsequent formal admission and interruption are recorded in `reports/spec-review/epic-195-a7-compatibility/attempt-18/round-1/launch-blocker-note.md`; attempt 18 did not produce an admissible verdict. Unreserved Sonnet permission diagnostics subsequently proved that the ECC Fact-Forcing Gate rejects the first Bash call, then permits an identical hash-only command after its requested facts are stated; a narrow `--allowedTools` grant was required under `dontAsk`, and out-of-scope `rtk proxy touch` remained denied with no file created. The second diagnostic native transcript SHA-256 is `feb8857e006bacb3cd14300456856c9ac2012521815129bbee791e4ab25be826`. The current spec-review-loop permits hook-authorized retry within the same first turn, and its fixed template and reviewer role do not prohibit stating the requested facts; no protected role/template relaxation is needed. A later attempt needs a new recovery contract/precheck, a hash-only launcher allowance, exact reserved `--session-id`, and native postflight. A18 reservation sequence 1205 remains consumed.

This establishes one live, unreserved acceptance/delivery/collision sample for the optional local Claude route. It does not authenticate a formal reservation receipt, validate an attempt-18 invocation/ledger chain, prove reviewer output schema, or turn the attempt-17 interrupted output into a verdict. The sibling recovery README's candidate approval audit and contract remain non-final. Before any attempt-18 reservation, bind the audit to a separate formal path, read back its hash, update the formal contract's `authority.path` and matching evidence hash, read back the contract hash, run the read-only recovery helper on the formal bytes, then run the normal precheck. Coordinate ledger reservation and separate A/B reviewer launches with the primary owner. Independent formal review, quality gate, exact-head CI, commit/push/merge and post-merge verification remain unproven here.
