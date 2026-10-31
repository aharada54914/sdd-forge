# T-001 branch evidence addendum

2026-09-27。既存証拠の整理のみ。正式quality-gate判定、Done、凍結traceabilityの更新ではない。未確認枝をsuite総数から補完しない。

## Evidence identity

対象candidate head: `91d1c32fb9f9b90a39209f19e9ec1d032d27e5ab`。旧verifier baseline: `c0aaf3a639f4cb4798b16acd115f0b05db44493f`。

| Artifact | SHA-256 |
| --- | --- |
| candidate verifier / installed 1.17.0 verifier | bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5 |
| genuine old verifier | d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064 |
| identical current Bash suite on baseline/candidate | 56efbe14c4c5d84e2f9886123eeed538447fe27bbdb32d8a016a7b3a13cecb3e |
| identical current PowerShell suite on baseline/candidate | c62fa8dfd5d6d943b1ffbb0363497e24572080bd13ff9a39835e7d8e0c875357 |

Source: `verification/differential-20260927.md:7–21`。各treeでの実コマンドは `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` と `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`。旧baselineは両方198 PASS/212 FAIL/exit 1、candidateおよびmerged headは両方410 PASS/0 FAIL/exit 0。raw artifact名は `baseline-bash.log`, `current-bash.log`, `pwsh-baseline.log`, `pwsh-current.log`, `merged-bash.log`, `merged-pwsh.log`（maintainer-local differential archive）。個人用絶対パスはこのaddendumに載せない。

以下の `L` は既存current `pwsh-current.log` の行番号。各拒否の3行組はexit・status・reasonを個別assertする。source `S` は `tests/check-hook-activation-handshake.tests.ps1` の行番号。Bash全体成功は記録されているが、ここで列挙する枝の直接証拠はPowerShellのassertionであり、native Windows実測ではない。

## Requirement / acceptance binding

| Requirement | AC | Branch evidence | 状況 |
| --- | --- | --- | --- |
| REQ-001 | AC-001 | TEST-001 | local fixture evidenced |
| REQ-002 | AC-002 | TEST-002–035, TEST-061 | local fixture evidenced |
| REQ-002 | AC-003 | TEST-036–057 | local fixture evidenced |
| REQ-003 | AC-004 | TEST-058–082, TEST-086 | partial: TEST-078/082 gaps below |
| REQ-004 | AC-005 | TEST-083–086; stale behavior TEST-081/082 | partial: TEST-082 gap |
| REQ-005 | AC-006 | TEST-087–089 | partial: Windows / evaluator / formal gate / merge pending |

Frozen binding: `requirements.md:20–24,36–41`; `traceability.md:7–11,24`; task Done When: `tasks.md:62–70`。

## Direct branch index

| TEST | Individual branch / expected result | Source; observed log |
| --- | --- | --- |
| 001 | exact five fields: 0 / HOOK_ACTIVE | S533–538; L97–98 |
| 002 | unknown selector, each Claude/Codex/Copilot: 64 | S655–675; L301–303 / 325–327 / 349–351 |
| 003 | null selector, each adapter: 64 | same; L283–285 / 307–309 / 331–333 |
| 004 | true selector, each adapter: 64 | same; L286–288 / 310–312 / 334–336 |
| 005 | false selector, each adapter: 64 | same; L289–291 / 313–315 / 337–339 |
| 006 | number selector, each adapter: 64 | same; L292–294 / 316–318 / 340–342 |
| 007 | array selector, each adapter: 64 | same; L295–297 / 319–321 / 343–345 |
| 008 | object selector, each adapter: 64 | same; L298–300 / 322–324 / 346–348 |
| 009 | known version selector over otherwise legacy success, each adapter: 64 | same; L304–306 / 328–330 / 352–354 |
| 010 | missing schema: legacy missing evidence 65 | S573–603; L156–158 |
| 011 | missing runtime: 64 | same; L159–161 |
| 012 | missing nonce: 64 | same; L162–164 |
| 013 | missing executed: 64 | same; L165–167 |
| 014 | missing raw_result: 64 | same; L168–170 |
| 015 | executed null: 64 | same; L171–173 |
| 016 | executed string: 64 | same; L174–176 |
| 017 | executed true: 63 | same; L177–179 |
| 018 | executed zero: 64 | same; L180–182 |
| 019 | executed one: 64 | same; L183–185 |
| 020 | recorded Claude / CLI Codex: 64 | same; L195–197 |
| 021 | recorded Copilot / CLI Codex: 64 | same; L198–200 |
| 022 | recorded Codex / CLI Claude: 64 | same; L201–203 |
| 023 | recorded Codex / CLI Copilot: 64 | same; L204–206 |
| 024 | both runtimes Claude: 64 | S750–765; L402–404 |
| 025 | both runtimes Copilot: 64 | same; L405–407 |
| 026 | extra plugin_hooks_enabled true: 64 | S573–603; L207–209 |
| 027 | extra plugin_hooks_enabled false: 64 | same; L210–212 |
| 028 | extra denied_by_plugin_hooks true: 64 | same; L213–215 |
| 029 | extra denied_by_plugin_hooks false: 64 | same; L216–218 |
| 030 | arbitrary extra key: 64 | same; L219–221 |
| 031 | raw null: 64 | S540–570; L141–143 |
| 032 | raw boolean: 64 | same; L144–146 |
| 033 | raw number: 64 | same; L147–149 |
| 034 | raw array: 64 | same; L150–152 |
| 035 | raw object: 64 | same; L153–155 |
| 036 | outer nonce mismatch: 62 | S573–603; L186–188 |
| 037 | echoed nonce mismatch: 62 | same; L189–191 |
| 038 | uppercase nonce, self-consistent / outer-only: 64 | S621–653; L252–254 / 265–267 |
| 039 | short nonce, both variants: 64 | same; L255–257 / 268–270 |
| 040 | long nonce, both variants: 64 | same; L258–260 / 271–273 |
| 041 | nonhex nonce, both variants: 64 | same; L261–263 / 274–276 |
| 042 | outer nonce null: 64 | same; L277–279 |
| 043 | outer nonce number: 64 | same; L280–282 |
| 044 | raw prefix: 64 | S540–570; L99–101 |
| 045 | raw quoting: 64 | same; L102–104 |
| 046 | raw suffix: 64 | same; L105–107 |
| 047 | raw truncation: 64 | same; L108–110 |
| 048 | changed English guard: 64 | same; L111–113 |
| 049 | changed Japanese guard: 64 | same; L114–116 |
| 050 | guard case: 64 | same; L120–122 |
| 051 | other target: 64 | same; L117–119 |
| 052 | target case: 64 | same; L123–125 |
| 053 | extra operation: 64 | same; L126–128 |
| 054 | old empty-line patch: 64 | same; L129–131 |
| 055 | terminal LF: 64 | same; L132–134 |
| 056 | leading LF: 64 | same; L135–137 |
| 057 | CRLF: 64 | same; L138–140 |
| 058 | no-schema Claude success: 0 / HOOK_ACTIVE | S127–131; L1–2 |
| 059 | no-schema Copilot success: 0 / HOOK_ACTIVE | S163–167; L12–13 |
| 060 | no-schema Codex success: 0 / HOOK_ACTIVE | S195–199; L19–20 |
| 061 | malformed JSON / truncated JSON: 61 | S241–242,768–774; L36 / 408–410 |
| 062 | duplicate schema: 61 | S707–720; L366–368 |
| 063 | duplicate runtime: 61 | same; L369–371 |
| 064 | duplicate nonce: 61 | same; L372–374 |
| 065 | duplicate executed: 61 | same; L375–377 |
| 066 | duplicate raw_result: 61 | same; L378–380 |
| 067 | nested duplicate: 61 | same; L381–383 |
| 068 | executed true then false duplicate: 61 | same; L384–386 |
| 069 | executed false then true duplicate: 61 | same; L387–389 |
| 070 | cleanup true then false duplicate: 71 / unconfirmed | S723–731; L390–392 |
| 071 | cleanup false then true duplicate: 71 / unconfirmed | same; L393–395 |
| 072 | nested cleanup duplicate: 71 / unconfirmed | S734–740; L396–398 |
| 073 | legacy duplicate: 61 | S742–748; L399–401 |
| 074 | valid cleanup: 0 / confirmed, capability unavailable | S316–325; L49–51 |
| 075 | absent cleanup record: 70 / unconfirmed | S328–335; L52–54 |
| 076 | cleanup executed false: 72 | S337–342; L55–56 |
| 077 | cleanup stale nonce: 62 | S344–347; L57 |
| 078 | malformed cleanup JSON / non-boolean executed: 71 | NOT established by the inspected branch log; L92 only proves missing executed, not these branches |
| 079 | known schema irrelevant to cleanup, executed true: 0 / confirmed / unavailable | S691–697; L359–361 |
| 080 | unknown schema irrelevant to cleanup, executed false: 72 / unconfirmed / unavailable | S698–705; L362–365 |
| 081 | regular stale sentinel: diagnostic, fresh challenge, bytes unchanged | S357–386; L58–64 |
| 082 | dangling symlink: diagnostic / no follow / no mutation | implementation uses lexists at verifier:233–240; no direct matching execution established here; pending |
| 083 | emitted patch exact generated nonce / bytes | S679–682; L355–356 |
| 084 | complete Claude Write object unchanged | S683–689; L357 |
| 085 | complete Copilot Write object unchanged | same; L358 |
| 086 | sentinel and sidecar non-mutation across emission / verify / cleanup | S294–305,424–432; L44–47,67–68 (fixture observations, not live approval edits) |
| 087 | repair-only reviews / human approval / historical preservation | tasks.md:3,13,15; existing review reports; formal identity/hash revalidation not executed by this addendum |
| 088 | both local original suites / native Windows / latest-head CI | differential.md:15–21 local exit 0; native Windows handshake pending; existing CI totals do not prove excluded suite |
| 089 | installed original verifier / one native dispatch / unchanged response | installed-host-activation-20260927.md:5–13 and JSON:2–6; current-session evidence only; fresh independent evaluator activation pending |

## Installed application / restoration provenance

Recovered maintainer application receipt records `rtk proxy python3 specs/epic-189-a1-rt002-repair/verification/apply-installed-verifier-human.py --apply`, installed hash above, maintainer-local preserved `prior.py`, and exact human-only restoration command. The prior backup hash is `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`. Exact private paths remain in the maintainer continuation audit; a sanitized restoration form is `rtk proxy python3 specs/epic-189-a1-rt002-repair/verification/apply-installed-verifier-human.py --restore <maintainer-local-backup>/prior.py` (placeholder, not an executed command).

This receipt establishes the reported application and preserved backup. It does not invent a separate timestamped pre-application observation. `installer-isolation-20260927.md:9–22` records `--self-test`, exit 0, temporary apply/restore/hash-refusal/symlink cases; this is isolation evidence, not an actual installed rollback. No installed rollback was needed or performed here.

TEST-089 actual session evidence records nonce `42fc17d12c5c38d5bf9f3ea1646c73bf`, one denied native dispatch, unchanged response, installed verifier exit 0 / HOOK_ACTIVE and sentinel absence. The later differential addendum records another own-session nonce `b0f2d9a0eb4e403134bad224a7a9b6cf`; neither capture admits a different evaluator/session. Older `installed-host-probe` limitations and fixture captures are not live proof.

## Explicit remaining acceptance gaps

- TEST-078 malformed/non-boolean cleanup and TEST-082 dangling symlink require direct branch evidence; source behavior alone is not PASS.
- Native Windows execution of the handshake suite is pending. Existing workflow exclusion is documented at `differential-20260927.md:41`; the human application candidate has no receipt in this evidence set. No alternate executor or refused operation was retried.
- Independent evaluator requires its own fresh installed activation before ordinary quality-gate entry. Existing author/session HOOK_ACTIVE is not transferable.
- Formal implementation quality-gate with canonical identity/count fields is absent; scoped no-findings review and local regression are not QG PASS. Task remains In Progress.
- Current `spec_revision` provenance binding and required component-coverage result are not established in this evidence set. Implementation Run ID / Task Attempt Count exist at implementation report:5–6, but do not substitute for them.
- Coordinator's existing current-root checks report `check-risk.sh` for this task and `check-workflow-state.sh --feature epic-189-a1-rt002-repair`, both exit 0. This is attributed existing evidence, not execution by this document's author; it does not establish component coverage or a quality-gate verdict.
- PR528 exact-head CI was later reported green by the coordinator, but this addendum does not convert that report into native handshake evidence. Any workflow application changes head and requires new-head mandatory checks; merge and post-merge confirmation are pending.
- Strict pre-apply timestamped prior-hash observation cannot be reconstructed from a recovered receipt. Preserve the actual receipt/backup and disclose this provenance limit to the independent evaluator.

No new tests, native dispatch, reservation, session, status, verdict, commit or push was performed to create this document. Unrelated dirty root changes are preserved.

## 2026-09-27 supplemental branch verification

This supplement supersedes only the TEST-078/082 local-fixture gaps above; the historical 410/0 evidence and its source hashes remain unchanged. In the RT002 integration checkout, the two existing suites now directly exercise malformed cleanup JSON, non-boolean `executed`, and a dangling sentinel symlink. Product verifier and candidate HEAD remain unchanged. These added cases verify existing behavior; they are not claimed as a failing-before product regression.

| Suite | Current SHA-256 | Observed result | Direct assertions in maintainer-local log |
| --- | --- | --- | --- |
| Bash | 4d246e61042efd790831ea9eccbb16b3a7eb2df52f341d59d09ad71142e070de | 423 PASS, 0 FAIL, exit 0, no SKIP | `rt002-test078082-bash-20260927.log:411–423` |
| PowerShell | 12580e2d000e51c25e5415579d2c397cfe3ccf095a3aaf8b90a35b8234761a33 | 423 PASS, 0 FAIL, exit 0, no SKIP | `rt002-test078082-pwsh-final-20260927.log:97–109` |

Commands: `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` and `rtk proxy pwsh -NoProfile -File tests/check-hook-activation-handshake.tests.ps1`, executed on macOS. Each cleanup branch asserts exit 71, `CLEANUP_RESULT_UNREADABLE`, unconfirmed cleanup, and unavailable capability. The symlink branch asserts challenge success, stale-sentinel diagnostic, fresh nonce, unchanged relative link, and absence of the target. Unexpected PowerShell fixture-creation errors fail; Windows privilege denial alone remains an explicit pending SKIP, never proof of this branch.

Root final diff review and `git diff --check` succeeded. The existing Windows workflow application candidate's bound PowerShell hash was updated; its default validation succeeded without applying the protected workflow. Native Windows execution, independent activation, formal quality-gate, new-head CI, merge and post-merge verification remain pending. No task status, review verdict, commit or push changed.

## 2026-10-02 current two-envelope evidence addendum

This addendum supersedes only the earlier-candidate and missing-raw-log limitations above. It changes no frozen REQ/AC binding, approval, status or verdict. Exact bare and once-wrapped Codex denial acceptance is covered by TEST-090/091; malformed wrapper and related negative cases are covered by TEST-092–097 in both original suite paths. The versioned field/body negative matrix is exercised for both exact envelopes. These are local fixture assertions, not distinct native host activations.

| Stage | Verifier SHA-256 | Bash raw log | PowerShell raw log | Counts observed in raw logs | Exits recorded separately |
| --- | --- | --- | --- | --- | --- |
| Committed RED before two-envelope fix | `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5` | `e8361f4975b2bcdf1cc9fa0d262690e2481dea583bdd6d15fcb2c762a8d706e5` | `7037c9c4d9bbb749db636045553aea433514083bc287c7760060ec2a46ccbb0e` | Bash 980/4; PowerShell 981/4 PASS/FAIL | 1 each in `red-pinned-handoff.md` |
| Applied GREEN | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` | `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d` | `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040` | Bash 984/0; PowerShell 985/0 PASS/FAIL | 0 each in `reports/verification/rt002-two-envelope-validation-20260929.md` |

RED is bound to regression commit `6aa67116af3b7c8609767df4ee367f8741254811`, with Bash suite SHA-256 `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` and PowerShell suite SHA-256 `e61f786b18d59a0a764cae70fe223153d360f25b80be246b7d44802962ac8103`. Git ancestry places it before fix commit `ed936b69c15cb9fdeb9d6d4caa9d1975f54d0587`. Each RED log fails precisely the bare TEST-090 exit/status pair and bare inner-nonce mismatch exit/reason pair. The separately refused focused command was never run. Current suite SHA-256 values are Bash `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` and PowerShell `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`; later PowerShell disposal work makes the retained logs historical, not fresh current-suite/current-HEAD runs.

The integration checkout's `reports/verification/rt002-t001-current-evidence-20261002.md` inventories six Done When conditions. Its `verification/T-001/native-20261002-f11bbd/observation.md` records one installed native denial and HOOK_ACTIVE, with the installed hash matched only by a later read-only check, not at dispatch time. The attempted later sentinel-absence probe was refused before execution. The earlier-candidate backup/restore receipt does not establish a current-application backup or rollback. Current `spec_revision`, component coverage, task-scoped provenance and independent quality-gate acceptance remain unestablished. T-001 remains In Progress; T-002 remains Draft / Planned.

### Current-run reconciliation — 2026-10-02

This addendum supersedes the stale current-run and native-acceptance limitations above, without changing historical evidence or verdicts. The owner report `reports/verification/rt002-t001-current-evidence-20261002.md` records fresh executions after the PowerShell disposal change at PR #528 head `1e86fb272643e798db4e1ca0c89f0402317a2fc8`: Bash 984 PASS / 0 FAIL / exit 0; PowerShell 985 PASS / 0 FAIL / exit 0. Both retained log summaries and SHA-256 values were independently read again and match the preceding GREEN hashes. All 38 PR checks were rechecked as SUCCESS. These macOS executions and CI do not establish native Windows coverage.

The current source branches are Bash suite lines 599–661 and 826–840, and PowerShell suite lines 578–626 and 763–785. The native observation supplies TEST-089's fresh nonce, single denied dispatch, unchanged response and installed-verifier HOOK_ACTIVE; a dispatch-instant hash or second sentinel probe is not an additional task condition. Source-checkout `spec_revision` is `dd6c53d41ea62dd121f89aa49b218727e78a5614350dc571fb4302247fe709d3`, as recorded with individual input hashes in the owner implementation report's Current-candidate reconciliation section; this is not yet an owner-worktree gate bundle.

The remaining T-001 conditions are the historical pre-application backup/restore-record gap, task-scoped component coverage and owner-input provenance, and independent quality-gate acceptance. Isolated restoration/refusal tests now pass, but cannot prove a restoration command existed before application. No task status, approval or review verdict is changed here.

### Supplemental deterministic checks — 2026-10-02

The owner checkout executed `check-component-coverage.sh --config sdd/project-context.yaml --repo-root . --source-rev HEAD --target-rev origin/main`: exit 0, state `not-applicable (disabled-legacy)`, manifest `not-consulted`, no failures or warnings. Producer SHA-256: `d6505e2909ea988384c0694c3f4b865e8f4539ba25eb71dab85d21ed447882fd`. This closes the missing execution above; it is not evidence that component ownership was checked while disabled.

`T-001-traceability.json` maps the existing REQ-001–004 / AC-001–005 / TEST identifiers to this evidence addendum. It excludes T-002's REQ-005 / AC-006 and does not replace the frozen traceability document or a formal gate bundle. Native TEST-089 remains separately documented above. Owner-input provenance, the historical pre-application record gap and independent quality-gate acceptance remain pending.

Executed in the source checkout: `bash plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-189-a1-rt002-repair/verification/T-001-traceability.json . require-evidence`; exit 0, `Traceability check passed for epic-189-a1-rt002-repair: 5 link(s).` This checks structure and evidence-file presence, not independent acceptance or owner-bundle readiness.

### Amended restoration condition — 2026-10-03

The human-authorized T-001 Done When 4 now tests the current SHA-256-pinned permitted restoration procedure, retained maintainer backup with prior SHA-256, and isolated restoration/refusal results. It explicitly does not assert that the command existed before the historical installation. The source task-plan SHA-256 at this read is `75d0e1d8a837ef22ea6d6df4e90d57c6328a87828205c668de4bd26b6a0fe696`; this paragraph supersedes only the older conclusion above that missing historical chronology blocks the amended criterion.

The owner evidence inventory records the retained 29,144-byte mode-0600 backup with SHA-256 `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. Its human-only helper `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` has SHA-256 `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1` and pins the `--restore BACKUP --installed` target to current SHA-256 `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` and the backup to the prior hash. The retained `--self-test` log SHA-256 `1f68c488567e0e608414302215fffcfcd8f4a142a2866b9384f68d4b99c72f26` reports exit 0, isolated restore, two hash refusals and two symlink refusals. No installed restore or historical pre-application command is claimed. Independent re-review and quality-gate acceptance remain pending; T-001 stays In Progress.

The already-created task-review attempt-3/round-1 precheck binds this amended body by normalized SHA-256 `94ccc8f60f89f09f2f91fd81b6b14a8a45480444f7b76d3dbe274cfa0f460dd2`; its normal `--verify-inputs` passed on 2026-10-03. The round has no adoptable reviewer A output, reviewer B reservation, or integrated verdict. The recorded latest A output bound the raw rather than normalized task hash; prior launch/output-format problems are preserved in `launch-blocker.md`. No re-review PASS is inferred, and the existing round must not be replayed or overwritten.

### Additional independent-review authorization — 2026-10-03

The human explicitly approved "RT002は独立レビューの追加４回を承認する". This is recorded as a cap of four *individual reviewer launches*, not four A/B rounds; stop after one valid passing A/B pair. Attempts 1–3, their reserved identities, non-adopted outputs, and verdict history remain unchanged. Attempt 4 round 1 was created with the normal `--provenance-rereview` precheck; it exited 0 while disclosing the expected stale prior task-plan binding and generated fresh precheck/graph inputs. Consumption at this point: 0/4 reviewer launches. Any later launch must record its own fresh reservation and consumed count; a precheck is not a reviewer result.

Reviewer A launch 1/4: the normal input verification exited 0; `validate-review-context-set.sh --reserve` accepted `reports/review-context/epic-189-a1-rt002-repair-task-a4r1-a-invocation.json` with `REVIEW_CONTEXT_OK d9efe3563d6e318c26cb951fb71ea7b8d8fed7e256b5889d4a26b01bc2f172ad sequence=1019 previous_record_sha256=32b81f9176dca2af56daba67f0c23d6381b0de1f98b24dd0c3f1d1a10b11ac55 pre_append_tip_sequence=1018 identity_unique=yes`. A fresh independent Sol reviewer was launched using that reserved identity. This line records one consumed reviewer launch, not a finding or verdict.

Reviewer A returned standalone canonical JSON with 14 PASS checks and no findings. Its persisted `attempt-4/round-1/reviewer-a.json` passed exact manifest/identity/schema/count comparison against its reservation. The derived `integrated-summary.json` contains only check IDs and counts. Reviewer B launch 2/4: normal input verification exited 0; a separate `task-reviewer-b` manifest was reserved with `REVIEW_CONTEXT_OK 3fbd3537927d064dd3a728f78c3a24a1516be615cbe09420bc8a891fd4cd7cfd sequence=1020 previous_record_sha256=d9efe3563d6e318c26cb951fb71ea7b8d8fed7e256b5889d4a26b01bc2f172ad pre_append_tip_sequence=1019 identity_unique=yes`. B was launched in a fresh independent Sol context without A raw output. Consumption: 2/4 individual reviewer launches; no merged verdict is yet claimed.

Reviewer B returned standalone canonical JSON with 9 PASS checks and no findings. Its persisted `attempt-4/round-1/reviewer-b.json` passed exact manifest/identity/schema/count comparison against its reservation. The round's `integrated-verdict.json` and `task-review-contract.json` record a clean PASS for the amended task plan. A read-only cross-check of the contract's two allowed-input manifests against the two reserved invocations, both finding arrays, and the integrated verdict returned `true` (exit 0). The normal persisted-state check, `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-189-a1-rt002-repair`, returned `workflow-state: ok` (exit 0). This is current task-decomposition re-review, not independent implementation quality-gate acceptance or a Done decision. Exactly 2/4 authorized individual reviewer launches were used; the unused two were not launched. T-001 remains In Progress, and T-002 remains Draft/Planned pending its own human approval.

### Fresh owner-checkout native activation and local suites — 2026-10-03

The new owner-checkout [native observation](verification/T-001/native-owner-cli-20261003-f31929/observation.md) and [five-field host response](verification/T-001/native-owner-cli-20261003-f31929/host-response.json) supersede only any earlier assertion that a fresh owner native TEST-089 dispatch is pending. Codex CLI 0.160.0 in the owner checkout emitted nonce `f319296577f0515fb95f3b29cf131580` through the original installed wrapper, submitted its exact relative patch once through native `apply_patch`, and received a real PreToolUse refusal. The raw-result string was copied from the same-call-ID `custom_tool_call_output`, not from agent prose; strict string equality with the persisted CLI rollout returned true. The source and installed verifier hashes both equal `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. The installed original verifier returned `HOOK_ACTIVE`, exit 0. The sentinel remained absent; there was no second canary attempt.

After activation, the owner checkout ran both complete original-path local suites: Bash 984 PASS / 0 FAIL / exit 0 and macOS PowerShell 985 PASS / 0 FAIL / exit 0. These checks do not prove native Windows, latest-head CI, merge, or T-002 final AC-006 acceptance. Independent T-001 quality-gate evaluation and its exclusive Done decision remain pending; approval/status fields and historic verdicts are unchanged.

### Current backup, restoration and handoff reconciliation — 2026-10-03

This dated addendum supersedes the older claims above that the `bb388...c3d5` backup was the historical installed prior or that its 1.17.0-targeted helper is the current 1.18.0 restoration command. Those historical paragraphs and their measured results remain unchanged. Read-only inspection finds the real maintainer-owned `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5` backup in a source-checkout application batch (29,144 bytes; owner-only mode 0600; single-link regular file). Its Git blob ID `c0d24c9435e7cb731c5b5a50d3955733d99b4c34` equals the verifier in committed pre-fix regression `6aa67116af3b7c8609767df4ee367f8741254811`. The separate retained installed 1.18.0 `prior.py` backups hash to `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`; they are not relabeled as `bb388`.

The current 1.18.0 human-only restoration adapter is `verification/T-001/restore-installed-118-human.py` (SHA-256 `410a34408f02ba577c0c0c9491a309963378369d1189210b5a15e24060a72c8a`), using reviewed helper `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` (SHA-256 `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1`). The adapter pins installed-current `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`, actual prior `bb388...c3d5`, regular/single-link and owner/mode checks, and has a maintainer-only `--restore` branch. Its `--self-test` with the actual backup exited 0 in isolation: exact prior restored; wrong-current, wrong-backup, backup-symlink and target-symlink inputs refused without test-target mutation. The sanitized [readback](verification/T-001/red-and-restore-readback-20261003.md) and two fresh original-path [Bash](verification/T-001/two-envelope-red-bash-20261003.txt) / [PowerShell](verification/T-001/two-envelope-red-pwsh-20261003.txt) RED logs are persisted. No actual installed restore was performed; the current source and installed 1.18.0 verifier both remain `1057...e0d`.

The canonical [implementation report](../../../reports/implementation/epic-189-a1-rt002-repair/T-001.md) declares exact current candidate hashes: verifier `1057...e0d`, Bash suite `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c`, PowerShell suite `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd`; owner native TEST-089 and current 984/985 full-suite evidence are also declared there. Task T-001 is now `Implementation Complete`, not Done. Independent quality-gate and T-002 release conditions remain pending; historical advance restoration preparation is explicitly unverified under the human-authorized amendment.
