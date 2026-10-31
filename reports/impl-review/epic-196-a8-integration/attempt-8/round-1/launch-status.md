# Attempt 8 round 1 launch status — 2026-10-05

Status: REVIEWER A COMPLETE; REVIEWER B LAUNCH BLOCKED (latest addendum). This is an operational record,
not a reviewer verdict or an integrated review contract.

The human reported applying `reports/verification/a8-nonce-design-human-apply.mjs
--apply`. Owner-worktree readback verified all four candidate hashes:

| File | SHA-256 |
|---|---|
| `specs/epic-196-a8-integration/design.md` | `6485d5585fd37fe9ce298b295168ad2304d6dec6a1c7dc768bf76bbebf8c1aa3` |
| `specs/epic-196-a8-integration/tasks.md` | `44b3658c28a1e216239b46a5bd80e58776099e1a4efd7e9e77b0728118634f6b` |
| `docs/adr/README.md` | `0d99d8f8215cbca6e7d92d218fec1e3a62364d5b581c90f891fec5d322018786` |
| `docs/adr/0035-a8-two-contribution-handoff-oracle.md` | `50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923` |

The normal `impl-review-precheck.sh epic-196-a8-integration 8 1
--provenance-rereview` command exited 0. Its stale implementation-design hash
warning is the explicitly supported provenance-rebinding advisory, not a
waiver of reviewer checks. `precheck-result.json` SHA-256 is
`c9d07b7bb29d614373c3b53003c77a75c9a27c987930268a9ed45594f73503e2`;
its `adr_inputs` binds ADR 0035 above. Existing Passed status was not changed.

An input-free, isolated reviewer-A allocation attempt failed before creation:
`collab spawn failed: agent thread limit reached`. No reviewer identity was
reserved, no invocation manifest was persisted, and no substantive input was
supplied. No identity may be inferred from that failed allocation. Historical
verdicts are not new proof for the amended design or ADR.

Resume at impl-review-loop STEP 2 once a fresh isolated context is available:
verify the current precheck inputs read-only, persist a one-role invocation
bound to the actual fresh session and current ledger tip, reserve exactly once,
require REVIEW_CONTEXT_OK, and then launch reviewer A. Reviewer B must be a
separate fresh context after A completes. Do not replace an incomplete review
with fabricated checks. Task-stage re-review remains pending predecessor
completion. Driver adoption, behavioral/native verification and quality gate
remain unperformed and are not authorized by this record.

## Allocation retry and CLI contract inspection

One requested fresh-allocation retry also returned exactly
`collab spawn failed: agent thread limit reached`; no identity was reserved.

The owner impl skill STEP 2/4 and reviewer roles (A line 26, B line 28)
require fresh independent contexts, caller-provided fresh run IDs, distinct
nonblank host-session IDs, and reservation before launch. They do not impose
the specification-stage host-issued two-identity allocation requirement.
The currently installed `claude --help` documents `--session-id <uuid>` as
using that UUID for the conversation. Thus a newly generated UUID used both
in the reservation and in a new, non-resumed CLI process can satisfy the impl
identity contract, provided the actual runtime output confirms the mapping.
It must not be described as a host-issued UUID merely because the CLI accepts it.

Identity compatibility does not establish executable tool availability.
The existing `reports/verification/a8-claude-read-tty-diagnostic-20261005.md`
records a background Read omission and an inconclusive normal-TTY probe;
`a8-t004-task-rereview-transport-audit-20261004.md` records receipt-command
permission refusals and a later successful separately authorized launch.
These are constraints to honor, not permissions to disable hooks, broaden
tool permissions, change executors after refusal, or reuse sessions. No CLI
review process was started during that inspection. Before adopting any CLI
review, preserve its actual read-only trace, require complete admitted-input
reads/hash checks and receipt verification, and stop on any refusal without
fabricating a verdict.

## Capability verified; reviewer A launched

The separately authorized unreserved Sonnet diagnostic session
`64a1d5b3-36e0-4a18-824b-cf49300f8448` successfully Read the precheck file and
executed its exact `rtk proxy shasum -a 256 -- <precheck path>` command after
the Fact-Forcing Gate's prescribed fact statement and identical-command retry.
The result matched `c9d07b7bb29d614373c3b53003c77a75c9a27c987930268a9ed45594f73503e2`.
A fixed-string receipt-hash diagnostic also succeeded with exact component
allow rules: `rtk proxy printf %s a8-receipt-diagnostic | rtk proxy shasum -a 256`,
yielding `75a51bf6cedbf23b60ed3a2acc2dfb568eb5fabe3223669c9fc1d417db16b5b2`.
No hook or deny setting was removed; no formal identity was used in diagnostics.
Debug traces are `/tmp/a8-impl-read-hash-diagnostic-20261005.log`,
`/tmp/a8-impl-read-hash-diagnostic-retry-20261005.log`, and
`/tmp/a8-impl-receipt-diagnostic-20261005.log`.

For formal A, the first input-verification command incorrectly combined two
mutually exclusive mode arguments and returned `round destination already
exists (replay is forbidden)` without changing the precheck. Inspecting the
documented `[--verify-inputs|--provenance-rereview]` syntax, then invoking only
`--verify-inputs`, succeeded. This was a CLI usage correction, not a regenerated
precheck or a bypass of input verification.

A fresh session `cee62cfc-66e3-4458-8b59-3538fb37d0c0` and run
`RUN-epic196-impl-a8r1-a-cee62cfc` were reserved once. The receipt was:

```text
REVIEW_CONTEXT_OK 13b9f2ededfe33d5e83245aea5917310322a0ad08dfc38ea9225cee4662e7300 sequence=1202 previous_record_sha256=089950e974d62ab38c6dc1721da0ee5ead190d6b408e3711c6e0868f65975dff pre_append_tip_sequence=1201 identity_unique=yes
```

The new non-resumed Sonnet process was then launched with that exact session
UUID, owner role/boundary instructions, the 11-file manifest, and exact-command
allow rules limited to raw input hashes, input-digest/record hashing and the
domain-directory existence probe. Read-only tools, hooks and deny settings
remain active. Its debug trace is `/tmp/a8-impl-a8r1-a-20261005.log`.
The launch was subsequently completed; see the addendum below.

## Reviewer A complete; reviewer B interrupted before execution

A returned canonical `impl-reviewer-a/v1`: PASS, 8 PASS / 3 SKIP / 0 FAIL.
`reviewer-a-cli-raw.json` preserves the CLI wrapper and `reviewer-a.json`
preserves its unmodified JSON. The session trace confirms all 11 admitted
paths were read, no outside substantive path was read, input digest/receipt
and every raw hash matched, and only Read/Bash were used. Minor advisories
within PASS findings remain in the original output, not waived or removed.
The counts-only `integrated-summary.json` hash is
`b251f27b4451969baa21ef83f36d115626a936e33fdec40deacf63ad8c94f92d`.

B's fresh invocation binds the same 11 inputs plus that counts-only summary.
Immediately before reservation, `impl-review-precheck.sh
epic-196-a8-integration 8 1 --verify-inputs` exited 0. Reservation succeeded once:

```text
REVIEW_CONTEXT_OK 1c0799ac0ac306f5a8b9844dc9d15eb56881225dd45854e8f30b3ddf673be9dd sequence=1203 previous_record_sha256=13b9f2ededfe33d5e83245aea5917310322a0ad08dfc38ea9225cee4662e7300 pre_append_tip_sequence=1202 identity_unique=yes
```

Run: `RUN-epic196-impl-a8r1-b-c5d81ae8`; reserved session:
`c5d81ae8-7e29-4fee-b2bd-182656bd3258`. The non-TTY Sonnet CLI launch
was rejected by the caller's PreToolUse hook before command execution:

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.
```

No B process or review output is claimed. The reservation remains consumed;
it was not repeated, repinned or reused. No alternative encoding, transport,
executor or hook setting was used after refusal. This interrupted round has
no integrated verdict or completed contract. B is NOT EVALUATED, not FAIL.
Formal design completion, task re-review, driver adoption, behavioral/native
verification and quality gate remain pending. Resolve the actual launch-hook
refusal through an authorized path before resuming under the interrupted-round
contract; this record does not grant a reset or identity reuse.

## Read-only refusal diagnosis

No launch retry was made. `launch-command-diagnostic.json` preserves the exact
rejected B command as data and an A reconstruction from the saved A prompt,
manifest and same CLI option shape (not claimed as original command bytes).
Importing the installed Python guard with bytecode writes disabled and calling
its pure decision helpers on those strings produced:

```text
A: tokenizer_none=true cwd_write=false patch_apply=false protected_path=true write_matches=[] write_safe=false deny_predicate=false
B: tokenizer_none=true cwd_write=false patch_apply=false protected_path=true write_matches=[">"] write_safe=false deny_predicate=true
```

The sole B write-regex match is the `>` in quoted prose `older role round>1
wording`, not a shell redirect. The installed dispatch script selects Python;
`sdd-hook-guard.py:1093` cannot tokenize the shell's escaped-apostrophe form,
`:1625` falls back to protected-path substring matching (the admitted role
instruction path matches), and `:1683` combines that with raw write-regex
matching and the fail-closed `:1241` write-target analysis. This explains A
success versus B refusal without a protected write being requested.

Installed Python SHA-256:
`248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227`.
Owner Python SHA-256:
`dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448`.
These differ; no owner patch can be claimed as installed-host remediation.
No guard source or setting was edited. A general fix would need approved
quote-aware shell analysis across the native guard runtimes with regressions
for quoted prose, actual redirects, escaped apostrophes and executable shell
expansion. Broad command allowlisting or disabling fail-close is not proposed.
That protected implementation scope is outside this design review; no speculative
patch is presented as ready to apply. Changing B's wording or transport simply
to evade the already-recorded refusal was not attempted.

A's 11 manifest hashes were rechecked after the refusal and all still match.
Saved raw output SHA-256:
`300de9a1b10c4d3fe010e6730d6f3649a33703352295caf9e8e5bf54d0e9e95f`.
Saved canonical A output SHA-256:
`e666f96b5f2e2847637f026308671dde03b2a05ed8fd852ad224d2f609c1e16a`.
