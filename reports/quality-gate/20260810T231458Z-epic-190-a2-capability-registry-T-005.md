Task: Author the registry_digest generator
Task ID: T-005
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-005-seq0673
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-005-0673
Ledger Sequence: 673
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-005-seq0673-manifest.json (sha256 857f85c7d893747bad9b166f55fdfd28d4be75b8d3f5871ec650f64710ad07e4)
Attempt: 4
VERDICT: PASS

This is the post-escalation cycle RT-20260809-001 prescribes. Three prior
cycles (ledger sequences 663, 665, 667/668) returned NEEDS_WORK, the cap was
reached, and the ticket's `proposed_resolution` directs exactly one further
reserve-and-launch in a fresh session with Done recorded on PASS.
`check-quality-gate-cycle-limit.sh T-005 epic-190-a2-capability-registry`
still prints `Escalate-Human` (exit 1); that is the escalation this cycle
discharges, not a new one.

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 673, stage `quality`, role `sdd-evaluator`,
  `task_id` T-005, `input_mode` file-manifest, `fallback_mode` none,
  `read_only` true, and the run ID / host-session ID assigned above.
- The validator made the reservation; no ledger record was hand-written.
  `validate-review-context-set.sh <manifest> . --reserve` returned
  `REVIEW_CONTEXT_OK 8d37794b7c8573924e1fa761ec752e605a65c8feca836ecd9addfdbfbc7dd662`,
  which equals the appended record's `record_sha256`.
- `previous_record_sha256` d037814fb149673a4c8cd2f21df49937cb44120c203eeee9408b81e55c6410cc
  (the task-reviewer-b record at sequence 672).
  `identity_ledger_sha256` 954c436ef940ef9f725f44096cffe6fc1b9888998fa6c50f6522e92c869cf602
  binds the PRE-reservation ledger, so re-running the validator without
  `--reserve` cannot succeed after launch. The evaluator discharged the gate
  the only way that is possible: `jq 'del(.records[-1])' | shasum -a 256`
  reproduced the pinned hash exactly, and it then recomputed every one of the
  673 records' hashes and links (`records=673 problems=0`) and confirmed no
  earlier record reuses this run or session identity.
- 35 allowed-input entries: nine feature specification layer files,
  `quality-gate-calibration.md`, the T-005 implementation report, and all 24
  paths the report's `## Outputs` table declares. `investigation.md` and
  `risk-gate-matrix.md` are excluded; neither is role-authorized for
  `quality:sdd-evaluator`.
- Evaluator role provenance checked rather than assumed. The installed plugin
  is behind the repository (sdd-quality-loop 1.10.0 installed vs 1.14.0 in
  tree) and the installed copy is what executes, so
  `agents/evaluator.md` and the five references the role leans on
  (`quality-gate-calibration.md`, `evaluation-rubric.md`,
  `deterministic-check-policy.md`, `risk-classification-policy.md`,
  `integrity-policy.md`) were diffed between the two. All byte-identical, so
  no stale-role input could distort this verdict.
- The evaluator's own `ALLOWED_INPUT_MANIFEST` line reported the manifest
  hash as `45f8de52…`. Measured directly, before and after the run, with the
  file untracked and unmodified throughout, it is
  `857f85c7d893747bad9b166f55fdfd28d4be75b8d3f5871ec650f64710ad07e4`. The
  evaluator's transcription is wrong; the header above carries the measured
  value. This is recorded rather than quietly corrected. It does not touch
  the verdict: the evaluator's CHECKED section shows it ran `shasum -a 256 -c`
  over all 35 entries and got `OK` on every one, and its launch-gate
  arithmetic reproduced the ledger and record hashes exactly.
- Working tree carried no evaluator writes. Closing `git status --porcelain`
  showed only this gate's own reservation artifacts.

## Default-FAIL Verification Contract (Risk: medium; Required Workflow: acceptance-first)

| Check | Type | passes | red_evidence | green_evidence / evidence |
|---|---|---|---|---|
| digest suite (sh) | acceptance-tests (acceptance-first) | true | verification/T-005/red-sh.log (14-check era) | Evaluator re-ran `bash tests/generate-registry-digest.tests.sh` -> pass=17 fail=0, exit 0; gate re-ran it independently, same result |
| digest suite (ps1) | acceptance-tests (acceptance-first) | true | verification/T-005/red-ps1.log (14-check era) | Evaluator re-ran `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/generate-registry-digest.tests.ps1` -> pass=17 fail=0, exit 0 |
| fragment identity (AC-024) | differential | true | n/a | Evaluator rebuilt all four fragments itself and matched the CLI: cap-alpha 17c9c096…, gate-b 44799094…, union c3ad0dcd…, multi-cap 9510419b… |
| order/duplicate independence (AC-024) | differential | true | n/a | `--capability-ids cap-alpha,cap-beta,cap-alpha` and `--capability-ids cap-beta,cap-alpha` both emit c5c4f050…; the gate-ids pair both emit 3436c906… |
| non-vacuity of the suite | mutation | true | n/a | Seven mutants against a scratch copy, all killed. TEST-024(9) is the sole detector of a dropped capability sort; TEST-024(10) the sole detector of a `--whole` that re-sorts. Both were added by the 2026-08-09 remediation |
| canonicalizer delegation (AC-023) | source | true | n/a | Imports are stdlib + `registry_discovery` only — no `unicodedata`, no YAML library — while the script shells out to `canonicalize-sdd-yaml.py --input-format json --hash-only`. Byte-different NFC fixtures yielding one digest proves normalization happens in the delegate. Canonicalizer pinned at b357a825… matches byte-for-byte |
| canonicalization vectors (AC-032) | fixture-integrity | true | n/a | JCS pair differs in member order AND number spelling (1e+0/1.0, 0.000001/1e-6, 1000000000000000000000/1e21); NFC pair differs in raw bytes (98 vs 103). Real vectors, not restatements |
| fail-closed error paths | negative | true | n/a | `fragment-selector-required`, `unknown-fragment-id` (capability and gate), `fragment-selector-conflict`, `canonicalizer-unavailable`, duplicate-id and dangling-reference registry rejection — all rc=1, stderr-only |
| wrapper parity (REQ-006 share) | ci-resilience | true | n/a | sh/js/ps1 `--whole` all emit e663cda2…; `--capability-ids durable-workflow` emits 3e4ab716… — the exact values the report claims. Both suites compare raw bytes and assert `64 hex + LF` |
| suite registration (Done-When 4) | ci-resilience | true | n/a | Registered in tests/run-all.sh:99-105 and tests/run-all.ps1:58-64 between T-004's and T-006's entries. Live `.github/workflows/test.yml` byte-unchanged: HEAD blob and worktree blob both 93d035ee |
| shared-fixture repair | regression | true | n/a | `bash tests/validate-capability-registry.tests.sh` -> pass=27 fail=0, confirming the merge regression T-005's own commit closed |
| declared-output integrity | output-binding | true | n/a | 24 declared rows, every hash matching its file; `git diff --stat HEAD` over the generator, both suites, both runners and the fixture directory is empty, so the table describes committed state |

## Findings

Critical: 0
Major: 0
Minor: 6 (recorded, non-blocking)

Verbatim, as returned:

- [Minor] `reports/implementation/epic-190-a2-capability-registry/T-005.md:234-239,294` — "Specification Differences" item 1 and Session Handoff still assert the staged-CI portion of Done-When 4 is "deferred/unmet"; that is stale, the condition is satisfied at the current repository state — `bash tests/capability-registry-parity.tests.sh` prints `ok: human-copy/ staged workflow carries every one of this feature's suite pairs in task order` and `ok: human-copy: staged workflow sha256 matches MANIFEST.sha256`; `bash tests/generate-gate-capabilities.tests.sh` prints `ok: QG-fix: rebuilt CI workflow candidate carries the gate-capabilities --check step and the generate-registry-digest suite`. `git log --oneline -- .../human-copy/.github/workflows/test.yml .../human-copy/MANIFEST.sha256` shows the staging landed in `86b9aa7b`/`326eeace`, not in T-005's own commits (`git show --name-only 0d45fdb7 1790bacd | grep -c human-copy/` returns 0). I could not read the staged workflow myself — it is outside the authorized manifest — so this rests on those two scripted gates, not on my own inspection of the file.
- [Minor] `specs/epic-190-a2-capability-registry/verification/T-005/green-sh.log` and `green-ps1.log` — the committed GREEN evidence for Done-When 5 records `pass=14 fail=0`, but the suites now contain 17 checks; the three checks added by `1790bacd` (TEST-024(9), TEST-024(10), the version grep) have no RED counterpart in `red-sh.log`/`red-ps1.log` and no refreshed GREEN log. Disclosed by the report's Snapshot Notice, and I substituted my own execution (17/17 both runtimes) plus mutation analysis, so it is not blocking.
- [Minor] `tests/generate-registry-digest.tests.sh:238-257` (and `tests.ps1:143-152`) — the semver-grep check is labelled `Done When #4 (tasks.md)` and quotes "a grep self-check confirms no version string was mutated outside scripts/bump-version.sh". T-005's Done-When 4 in tasks.md is the Suite/CI-registration item and contains no such clause; the quoted text belongs to a different task. The check itself is harmless extra coverage, but the citation is wrong.
- [Minor] `tests/generate-registry-digest.tests.sh:58-64` — TEST-023's "banned" half is a fixed identifier blocklist (`jcs_serialize`, `_format_jcs_number`, `parse_yaml_bytes`, `import yaml`, `ruamel.yaml`); an inline RFC 8785 reimplementation under different names would pass it. AC-023 asks for exactly a "code-inspection-style check", and I confirmed real delegation independently (see CHECKED), so this is a proxy weakness rather than a failed criterion.
- [Minor] `plugins/sdd-quality-loop/scripts/generate-registry-digest.py:100-104` — a `capabilities[]` entry with no `gate_ids` key is rejected as `invalid-registry: capability 'c1' gate_ids must be a string array` (observed rc=1). Whether that is over-strict depends on whether `gate_ids` is `required` in `contracts/capability-registry.schema.json`, which is outside the authorized manifest and which I therefore did not inspect. No AC in T-005's scope covers it; verification target is that schema's `capabilities` `required` list.
- [Minor] `plugins/sdd-quality-loop/scripts/generate-registry-digest.py:127-129` — `--whole` combined with `--capability-ids`/`--gate-ids` is rejected with `fragment-selector-conflict`, behavior named nowhere in requirements.md/design.md/acceptance-tests.md. It is fail-closed and consistent with the contract's other selector rules, and the report discloses it as Specification Difference item 5.

### Disposition of the two escalation-ticket Majors

RT-20260809-001 carried two Majors into this cycle. Their state now:

1. **Outputs-table coverage — closed.** Verified by this gate before
   reserving, not taken from the report: all 24 declared rows re-measured
   against live (0 stale, 0 missing), and the real population derived from
   `git show --name-only` over T-005's own commits (`0d45fdb7`, plus the
   T-005 half of the shared remediation commit `1790bacd`). Derived set and
   declared set are identical — zero undeclared, zero orphaned. The two
   files that went missing for three consecutive cycles,
   `registry-digest-fragment-multi-cap.json` and
   `validate-registry-fully-clean.json`, are both declared and both current.
2. **Stale acceptance-evidence logs — still open, downgraded to Minor by the
   evaluator.** The committed GREEN logs record a 14-check suite; the suite
   is now 17 checks. The ticket's item 2 (re-capture the logs) was not
   performed. The evaluator did not treat this as blocking because it did
   not rely on the logs: it executed both suites itself at 17/0 and then
   went further than the logs ever could, killing seven mutants and showing
   that two of the three undocumented checks are the sole detectors of two
   distinct regressions. The evidence ladder puts observed command output
   above a saved log, so the substitute is stronger than the missing
   artifact. Recorded as Minor 2 above; it remains a real documentation gap.

## Domain Surfaces

- Security: not touched. The generator reads a Registry and emits a digest;
  no secrets, credentials, or provider detail appear in any fixture, and the
  script holds no access-control or Gate-blocking surface (T-004's validator
  is the trust boundary, per the task's own Risk Rationale).
- Performance / Accessibility: not touched — out of scope for a CLI digest
  primitive.

## Decision

Zero Critical, zero Major. Every Done-When item is satisfied at the current
repository state:

1. Canonicalizer delegation (AC-023) — verified by import inspection plus the
   byte-different NFC fixtures collapsing to one digest.
2. Fragment identity (AC-024) — verified by independent reconstruction of all
   four fragments and by mutation.
3. Canonicalization vectors (AC-032) — verified by reading the fixtures, which
   are genuine JCS and NFC vectors.
4. Suite/CI registration — both runners register the suite in the required
   position; the live workflow is byte-unchanged; the staged candidate now
   carries this suite's steps and matches its MANIFEST entry, confirmed
   through two scripted gates.
5. Acceptance-first evidence — RED and GREEN both exist; the GREEN logs
   describe a smaller suite than today's, which the evaluator replaced with
   its own execution and mutation analysis rather than accepting on trust.

T-005 -> Done.

## Checked (self-executed by the gate, independent of the evaluator)

- Re-measured all 24 `## Outputs` rows in T-005's report against the live
  tree before reserving: rows=24 ok=24 stale=0 missing=0.
- Derived the real file population from `git show --name-only` over
  `0d45fdb7`, `1790bacd` and `340f0149`, filtered spec/plan/evidence paths,
  and diffed it against the declared set. The only apparent extras are the
  T-006 half of the shared remediation commit `1790bacd` (the nine
  `drafts/human-copy-candidate/` files and the two
  `generate-gate-capabilities` suites), every one of which is declared in
  T-006's own report. Attributed correctly, T-005's population is exactly
  its 24 declared rows.
- Ran `bash tests/generate-registry-digest.tests.sh` myself: pass=17 fail=0.
  Compared against the committed `green-sh.log` (pass=14) and identified the
  three additional checks by name.
- Confirmed the staged workflow candidate now registers this suite
  (`grep -c registry-digest` on `human-copy/.github/workflows/test.yml`
  returns 4) and that `tests/run-all.sh:103` carries the registration.
- Diffed the installed sdd-quality-loop 1.10.0 evaluator role and its five
  supporting references against the repository's 1.14.0 copies: identical.
- Recomputed the pre-reservation ledger hash by dropping the tail record and
  confirmed it equals the manifest's `identity_ledger_sha256` before handing
  the launch-gate procedure to the evaluator, so the instruction it was given
  was known-dischargeable rather than assumed so.

## Follow-ups this gate does NOT perform

- The task plan hash is now stale, structurally: recording Done mutates
  `tasks.md`, and the attempt-5 binding stored the raw bytes of a
  status-mixed plan. WFI-025 already covers the underlying matching rule. A
  task-review re-bind is needed and is a separate gate with its own reviewer
  invocations; a quality gate does not manufacture a task-review verdict as a
  side effect.
- RT-20260809-001 stays open until its item 2 (re-capturing the GREEN logs at
  the current suite shape) is performed. That is a documentation action, not
  a Done condition, and it is Minor 2 above.
