# Limited hook evidence contract repair

Run ID: hook-evidence-contract-20260909
Task Attempt Count: 1

Ticket: RT-20260909-002 (A1 T-008 repair, not the unrelated POSIX T-003).
State: authorized; proposed contract below is not an implemented or passed gate.
The existing T-008 Done record and every frozen review input remain untouched.

## Observed defect

The actual host response is retained verbatim in
`reports/verification/rt001-hook-response-20260909.json`. Its canary operation
was rejected. No host fields named `plugin_hooks_enabled` or
`denied_by_plugin_hooks` were supplied. `_verify_codex_cli` in
`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:321`
requires those fields and the original verifier returned exit 65.
Absence of metadata does not establish a disabled configuration.
The evidence remains historical and must not be modified into a passing result.

The owning task is `specs/epic-189-a1-project-context/tasks.md:1940`;
the CLI contract is `design.md:1078` in that feature. It is security-sensitive,
high risk and fixture-scoped. A8 live host proof is separate.

## Proposed bounded contract for independent scrutiny

1. Preserve the current three runtime evidence formats. Do not reinterpret
   explicit `plugin_hooks_enabled: false` as active. Missing metadata remains
   non-success unless the separately versioned host-response format below is
   completely validated. Improve the missing-metadata diagnostic without
   asserting a configuration fact that was not observed.
2. An explicit new evidence schema, `sdd-codex-host-denial/v1`, would contain
   `runtime: codex-cli`, the challenge nonce, boolean `executed: false`, and
   unmodified `raw_result` from the actual host tool dispatch. No synthesized
   plugin-flag booleans. Other runtime fields or contradictory flag values
   reject; an invalid new format never falls back to legacy acceptance.
3. The Codex challenge's fixed Add File canary patch would contain one line
   `sdd-hook-challenge:<nonce>` instead of an empty line. The verifier would
   compare the entire expected host denial envelope and echoed patch, including
   that nonce and the fixed relative target, not search for a substring. Only
   the observed envelope shape is in scope; no generic regex over error prose,
   arbitrary commands, terminal output, quoted examples, extra file operations,
   truncated replies or path normalization. An optional single terminal newline
   must be explicit in the contract if supported; no general whitespace trim.
4. Nonce mismatch and `executed: true` continue to fail. Duplicate JSON members
   reject rather than accepting the last contradictory member. Unknown schema,
   wrong runtime, non-string/raw null, missing/empty data and wrong types reject.
   The new mode's nonce must be exactly the generator's 32 lowercase hex digits;
   legacy fixture nonce syntax remains compatible.
5. The result proves only that this trusted session's recorded canary dispatch
   was denied with the named SDD guard signature. It does NOT independently
   prove a plugin feature flag, cryptographically authenticate caller-authored
   JSON, or provide a persistent replay ledger. A forged complete transcript
   cannot be distinguished by a plain-file verifier. The collector's trust
   boundary must be stated; exact matching is not an authenticity guarantee.
6. The current design's specific claim of `plugin_hooks`-mediated denial must
   be reconciled explicitly in a scoped new contract review before activation.
   A raw PreToolUse message alone cannot identify whether an equivalent guard
   was attached via a plugin or another host configuration. If the governing
   decision requires proof of plugin origin, this format must NOT yield
   HOOK_ACTIVE; an authentic host-origin/configuration evidence path is needed.

## Required preflight / regression matrix

| Persisted field or claim | Contract counterpart | Regression |
| --- | --- | --- |
| schema and runtime | selected new/legacy adapter | unknown schema and wrong runtime reject; no fallback |
| nonce | expected nonce and echoed exact patch | wrong outer nonce, changed inner nonce, old empty patch reject |
| executed | non-executed host denial | true, missing, null, numeric and string values reject |
| raw_result | exact host envelope and one fixed canary operation | prefixes/quotes/suffixes/truncation, unrelated errors, another path, extra operation reject individually |
| plugin flags when present | no contradictory state | false, null and wrong types reject individually |
| JSON members | unique field interpretation | repeated executed/nonce/raw/schema fields reject |
| HOOK_ACTIVE meaning | observed guard denial, not configuration attestation | no absent-field inference; A8 proof remains pending |

Positive cases must cover legacy evidence for all three runtimes and one new
nonce-bound host envelope. Every negative row must assert nonzero and no
HOOK_ACTIVE through both original wrappers. Existing cleanup/stale-start and
non-mutation suites remain required. A fixture success never counts as a live
handshake, and the old RT001 transcript cannot pass the new nonce-bound format.

## Execution / recovery boundary

Independent scrutiny of this contract comes first. Then add regression tests,
observe expected RED on the original verifier, prepare the smallest repair,
review it and run existing plus new checks. Protected rejection is not bypassed
by a copied executable, alternate command or editing installed cache files.
Any permitted inert candidate is data for review and human application only.

Formal bootstrap remains fail-closed while this repair is pending. An ordinary
independent security review here is not represented as the formal spec gate.
After legitimate application, obtain a NEW challenge, actual host tool result
and verifier outcome through the installed execution path; only then resume
formal reviews. No commit, push, merge, issue closure or status promotion has
been performed for this repair.

## Independent scrutiny and selected first slice

Ordinary independent reviewer: `/root/hook_contract_security_review`.
No formal reviewer reservation or gate verdict is claimed. The reviewer found:

- Major: the existing plugin-origin requirement cannot be satisfied by raw
  named-guard denial alone. The proposed activation meaning stays conditional.
- Major: ordinary review and human file application do not waive bootstrap's
  governing prerequisite. No raw-only activation is authorized by this report.
- Warning: any eventual raw format needs an exact key allowlist, dispatch before
  all runtime verifiers, explicit newline policy, and duplicate-member rejection
  for runtime and both flags as well as nonce/schema/executed/raw response.

Selected first implementation slice: only correct the misleading diagnostic;
retain the existing exit 65, reason category, all predicates, CLI and JSON output
shape. The legacy reason name is retained for compatibility, not taken as an
observed configuration fact. No new raw-response acceptance or parser is being
implemented in this slice. Three new fixtures per existing wrapper (missing,
null and string flag) assert continued unavailability and accurate stderr.

Preflight: the only affected output is stderr's configuration inference; its
counterpart is the recorded plugin flag, and each missing/null/string fixture
fails the diagnostic assertion on the original code while independently
asserting exit 65 and CAPABILITY_RUNTIME_UNAVAILABLE. No new persisted fields
or verdict semantics are introduced.

Pre-change baseline on the original repository paths: Bash 88 PASS / 0 FAIL,
PowerShell 87 PASS / 0 FAIL, both exit 0 on this macOS host; no native Windows
claim. `git diff --check` exited 0 before this slice. New tests then reproduced
exactly three expected diagnostic failures per wrapper: Bash 94 PASS / 3 FAIL,
PowerShell 93 PASS / 3 FAIL, both exit 1. All six new fail-closed assertions per
wrapper passed. Both RED processes terminated before production repair.

## Protected application boundary

The original-path test edits succeeded. The subsequent `apply_patch` changing
only the five Python diagnostic string lines was blocked by the real PreToolUse
guard. That denial was honored: no alternative executor, copied verifier or
installed-cache change was attempted. The original Python SHA-256 remains
`d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.

The inert reviewed application artifacts are:

- `reports/verification/hook-diagnostic-human-20260909.patch`
- `reports/verification/hook-diagnostic-human-apply-20260909.sh`

The patch replaces only the misleading diagnostic, not a predicate or reason.
`git apply --check` succeeded. The human script's `bash -n` and `--check` both
exited 0. The latter checked the original verifier, both modified tests and patch
hashes and applicability; it did not apply anything or create a backup. The
`--apply` mode is exclusively for the human and remains unexecuted by the agent.
It makes a private backup, applies only that patch and runs both original-path
suites, retaining output and failure codes. No post-application GREEN is claimed.

Remaining activation decision: the present contract requires plugin-mediated
origin, while the host response supplies named-guard denial only. Accepting the
latter as sufficient and using a recovery-specific independent review entry
would change that governing prerequisite, not merely its JSON spelling. This
report does not silently make that decision. A genuine origin-evidence route or
that explicitly scoped semantic/recovery amendment is still needed. Diagnostic
application alone cannot restart formal gates or close RT-20260909-002.

## Candidate review outcome

The same independent reviewer subsequently inspected the exact diagnostic-only
patch, both test diffs and the human application helper. No blocking findings:
only message text changes; the predicate, exit 65, category and all acceptance
paths remain unchanged; backup/hash checks preserve unrelated dirty work.
The reviewer did not execute the candidate or tests and supplied no formal gate
verdict. Application and subsequent GREEN verification remain outstanding.

Human command (run in a terminal, not through the agent):

```bash
bash /Users/jrmag/sdd-forge/reports/verification/hook-diagnostic-human-apply-20260909.sh --apply
```

Do not commit, push or merge from that step. Return the complete command output.
The helper's SHA-256 at review is
`5d3632df5c88eb776f5afea7788432ef3f3fa5080bce4e467ea730fdbc00901b`.
