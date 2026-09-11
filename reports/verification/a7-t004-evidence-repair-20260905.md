# A7 T-004 evidence repair — 2026-09-05

This is a remediation review record, not a quality-gate report or Done decision.

## Scope and independent review

Worktree: `/Users/jrmag/.local/share/sdd-forge-a7-t004-evidence-20260905`; branch `codex/a7-t004-evidence-20260905`; base `ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf`.

RT-20260814-001 repair changes only the implementation report and T-004's `malformed-corpus-red.log`, `independent-test.md`, and `independent-implementation-review.md`. Binary diff SHA-256: `b39b89c2b7c1f52f10cf7a7a8287f9ff77513a786c0d64c0208236eed4c11e04`. `git diff --check` succeeds. No commit, push, ticket closure, fourth quality gate, or task state transition occurred.

Independent reviewer `a7_recovery_authority_review` (GPT-6 Astra) returned patch PASS: exact four-file scope, authentic raw output, corrected active claims, historical transcripts preserved, changed output hashes matching, current failures disclosed. The reviewer did not rerun suites and did not grant quality-gate PASS.

## Actual executions

Historical RED fixture `/tmp/t004-red.3zg2ns/src`: all 6070 tracked blobs checked against `b14dcbd202e5e836b58a6587efd5abce0cf850f2`, with exactly the intended PowerShell twin taken from `abc7ab4a01d1aaec2647fdc78a84b0b8f9eb73e6`. Primary ran the unchanged mutation harness with scoped system Bash PATH. Actual exit 1, 113 unique kills and 3 PowerShell survivors. Raw combined log `/tmp/t004-red-primary.8c5Rsa/combined.log` SHA-256 `bc06a51e13ddcb5e8ef768a463f8c0b5a6e9baa87ac5a07f896b1d7ad36b6f63`. Saved log is byte-identical plus observed `EXIT_CODE=1` footer, SHA-256 `e38f94a7f9410899c78b9ae7fa37f5826fc90491b42335d3befcc164b3c40847`.

Current repair-tree standalone suites: SH 44 passed / 0 failed, exit 0; PS 43 passed / 1 failed, exit 1. Both retain four named dependency SKIPs. Full current mutation execution `/tmp/t004-current-primary.zO2ytp/combined.log` exits 1 after 116 kill lines and 0 survivor lines, during restoration; **no final mutation summary exists**. SHA-256 `f2ea525df1039e22cc4730491a347afeb3c4bfc3b362b090b7fca92b3a774860`. These are not GREEN results. A delegated claim based on the old tracked 40/0 log was rejected as non-fresh evidence.

Failure: `tests/structural-compatibility.tests.ps1:204–205` compares an exact double-quoted registration line; `tests/run-all.ps1:71` has the registered path as a single-quoted, comma-terminated entry. Registration exists. Fix needs case-sensitive syntax-tolerant recognition plus positive quote variants and an absent-entry negative. This fits the already-approved T-004 test scope, but is separate from the four-file ticket remediation. No test repair has been applied.

## Remaining evidence and authority conditions

- Changed output SHA-256 values: independent-test `4c0aecbf6bd33152d30a04273b9d7d738a01ccfb1de7eabd934dd3239d1ac506`; independent-implementation-review `c9f5cb2c1b0c2d9a0fd387018869f8cc98ae1dfa65ab61a0d3c8ee3acc23a952`; RED as above.
- Actual Outputs table has 38 rows, not the ticket's historical 37. Any new canonical manifest must derive the real allowed-input set; do not blindly reuse the historical 49-entry recipe. CHANGELOG and run-all SH/PS have pre-existing unrelated hash drift; these were not silently refreshed.
- Installed `/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-ship/1.17.0/skills/ship/SKILL.md:360` says after three reports for an unfinished task, “do **not** invoke quality-gate again”; the cap persists across sessions. Independent Astra confirms broad completion/admin-review-bypass approval is not an explicit exception to this cap.
- Required narrow human decision: authorize exactly one additional T-004 evaluator cycle after evidence and registration repairs and fresh successful tests, acknowledging three consumed cycles. No further retry, hook bypass, ledger fabrication, or rule change; normal identity reservation must succeed. Do not exploit a counter undercount.
- Ticket remains open and T-004 remains Implementation Complete. Other issues and integration work are not complete.

## Latest continuation — supersedes the pending cycle decision above

The human explicitly authorizes A7 T-004 alone to repeat repair, successful tests, and additional evaluation until PASS. Cheap agents implement; Astra reviews. This resolves the cycle-cap exception; do not request another one-cycle authorization. It does not grant external panel consent or waive enforcement.

Cheap worker `a7_registration_repair` changed only `tests/structural-compatibility.tests.ps1` beyond the four preserved evidence edits. Astra required matching quote pairs, not independently optional opening/closing quotes. The final case-sensitive, anchored backreference expression accepts single/double quote registrations, optional comma and trailing whitespace; seven regression assertions cover accepted forms, absence, mis-case, mismatched quotes and comments. Final test-source SHA-256: `9897215a9b8ad1c9509ce94b0abe8e36a730d7630ca61b1763880d785e1620cb`. Primary reviewed the final diff and `git diff --check` passes. This is patch review, not formal task PASS.

Worker standalone logs in `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/tmp.7QFd6DSN3n/`: SH 44/0 and PS 51/0, reported exit 0; primary inspected both result footers. Four named dependency SKIPs remain per suite. Primary full mutation rerun is recorded separately below when complete; never substitute the old tracked 40/0 logs for fresh evidence.

### Actual cross-model consent blocker

The supported `prepare-panelist-input.sh --task T-004 --feature epic-195-a7-compatibility --input specs/epic-195-a7-compatibility/verification/T-004/ --spec-root specs --max-bytes 1048576` invocation in the repair worktree exits 1: `consent denied for T-004 — no Cross-Model: enabled flag ... and no valid SDD_SUDO token`. No new panel was launched. Historical `consent: sudo` text in an old bundle is not present consent.

Installed ship SKILL.md:296–322 requires a same-invocation cross-model run for `Security-Sensitive: true` before the quality gate. Installed cross-model-verify SKILL.md:17–18 and :87 requires enabled consent or a valid token. T-004 currently records `Cross-Model: not enabled`. Enabling it changes frozen task-body content (not a normalized status field); obtain explicit authorization for this amendment and provenance re-review, including sanitized inputs to the required non-OpenAI panel. Astra remains the requested reviewer. Do not manufacture a token, silently waive this gate, or reinterpret the cycle exception as panel consent.

### First fresh post-registration full mutation execution

Primary ran the complete harness in the repair worktree: actual exit **1**, final summary **115 killed, 1 survived**. Restoration now succeeds (SH 44/0, PS 51/0), but `runner-ps1` survives. Raw log `/tmp/a7-primary-registration.L4tZqD/mutation.log`, SHA-256 `9880dc99eb1e0efc804aa201e05f89768d440edb3a6baae889af150c694c4212`. This is not full mutation PASS.

The mutation at `mutation-proof.sh:187` still deletes only the old double-quoted/no-comma registration. On current main it does nothing. Primary independently reran both standalone suites, actual exits 0, SH 44/0 and PS 51/0, four named dependency SKIPs each. The cheap worker is assigned a minimal mutation repair with an actual-change assertion and targeted RED/restored-GREEN evidence. The approved repeat-until-PASS exception applies. No formal quality gate has been run.

### Final scoped repair verification

Cheap worker repaired the mutation using matching quote pairs, an explicit no-match failure, and the existing source-change hash assertion. Final harness SHA-256 `b579039004fa33356f54ec8b04078da139c5ae16d01cda48de3f813d5e4dda48`; final PS suite hash remains `9897215a9b8ad1c9509ce94b0abe8e36a730d7630ca61b1763880d785e1620cb`. Primary Astra reviewed both changes; Bash syntax and whitespace checks exit 0. No remaining patch-level finding was identified; formal quality-gate PASS is not implied.

Primary executed the full unchanged-size mutation matrix again: **exit 0, 116 killed, 0 survived**, including `runner-ps1` at log line 115. Restoration SH 44/0 and PS 51/0; four named dependency SKIPs remain per suite. Log `/tmp/a7-primary-registration.L4tZqD/mutation-fixed.log` SHA-256 `cc65595bc98baab4cec971c9719a2137e60c37335d5498266c88b9fc8eb5fdd1`. Both source hashes were rechecked after the run and are unchanged. Historical failed logs remain intact.

Worker targeted fixture `/tmp/t004-runner-ps1.OoZ38W` removes the actual registration (primary confirmed absent); runner hash changes from `6865172c96ad890fbce4de83555cb738f3720912e7ad198291d0287463c8d079` to `b2e6844983cc753614048ef150d1209b51a78b72f14df41f8a814cc21a6d0ff4`. Worker additionally reports historical double/no-comma RED and absent-registration mutation failure in `/tmp/t004-synth.ND9GGZ`; these supplemental results are delegated evidence, not a claim of primary execution.

Six changed files now comprise the earlier four-file evidence repair plus the PS assertion and mutation harness. No commit, push, merge, ticket closure or Done transition occurred. Cross-model consent and subsequent authorized provenance/evidence/identity checks still gate formal completion. The all-issues/main-integration goal is unfinished.

### Additional verification authorized — supersedes consent blocker

Human approved the explicit T-004 Cross-Model enabled amendment, provenance re-review and sanitized Claude panel input. Only T-004's Cross-Model field was changed in the repair worktree (now seven modified files). Consent is resolved, not pending. No frozen evidence was declared rebound merely by this edit.

The real collector invocation now passes consent but exits 1 for declared output hash mismatches in CHANGELOG.md, tests/run-all.ps1 and tests/run-all.sh. It separately recognizes mutation-proof.sh and structural-compatibility.tests.ps1 at declaration commit 6f1e093 with subsequent drift. A read-only cheap-agent audit is investigating truthful evidence binding; historical hashes have not been silently refreshed.

Claude CLI auth status exits 1 and reports loggedIn false / authMethod none. No panel input has been sent. Verified human subscription login command: `rtk proxy claude auth login --claudeai`; verify with `rtk proxy claude auth status`. Do not substitute another vendor or create API billing credentials.

Provenance task-review precheck attempt 7 round 1 was invoked normally but has not completed (session 44065, child check-workflow-state). Its waiting processes are under read-only diagnosis. No precheck PASS, reviewer reservation, formal QG PASS, commit, push or merge is claimed.

That stalled invocation was subsequently stopped by terminating only its five confirmed process IDs; session 44065 exited 143. Pipe inheritance is a diagnostic hypothesis, not a proved cause or a successful precheck. No protected script was modified. Work independent of A7 T-004 was dispatched in parallel: A6 remaining acceptance audit and A8 existing-branch verification planning. Main confirms A8 T-001 and T-004 are Approved with no task dependencies; the existing A8 branch already contains a T-004 implementation/report, so reuse and fresh verification precede any new implementation.

### Declaration-anchor follow-up

Primary re-read `prepare-panelist-input.sh:866-921` in the A7 repair worktree. The collector caches ONE anchor for the complete Outputs section, not one declaration commit per row. An addendum outside that section cannot move the anchor; an uncommitted section edit falls back to the most recent report commit. Consequently the lightweight investigator's suggestion that a provenance addendum by itself lets the collector correctly re-anchor mixed historical rows is not established and is not adopted. No collector edit, hash refresh or retry was performed. A current-state re-declaration would require explicit evidence about every active output and preservation of the historical declaration; merely recomputing file hashes would not establish the validity of the test evidence they contain.

### Implementation-report continuation verified

A cheap worker added a dated current-status section outside the Outputs table in the T-004 implementation report, retaining the older failed observations. Astra reviewed it, removed an unsupported identifier through worker correction, and corrected its above/below reference. Independent tester `a8_t002_verify` checked the exact PS source, mutation harness and raw-log hashes against the report and confirmed 116 killed / 0 survived, restored SH 44/0 and PS 51/0, and F3/F4/F5/F6 dependency skips. Scoped report-accuracy PASS only; the exit-0 attribution is the primary's earlier actual execution, not a new harness execution. Primary `git diff --check` also exits 0. The Outputs table was not changed by this continuation.

Fresh `rtk proxy claude auth status` still exits 1 with `loggedIn: false` and `authMethod: none`. No panel was sent. Historical binding, provenance review, formal quality gate and Done remain unresolved; the all-issues goal is not complete.

### Collector versus evaluator declaration channels

Read-only delegated inventory reports 38 Outputs rows: 33 current hash matches and five drifted rows (CHANGELOG, both run-all twins, mutation harness, PowerShell structural suite). Of the matching rows, three had no matching commit in the investigator's scanned history; this is a limited search result, not proof that no provenance exists.

Primary source inspection confirms that quality-gate step 8 permits a hash-pinned `gate_report_declaration` with a new gate report's Post-Fix Artifacts table, while the cross-model `prepare-panelist-input.sh` completeness check still reads the implementation report's Outputs table and uses one whole-section anchor. The evaluator channel must not be represented as a working cross-model collector remedy. Historical reports remain preserved; no Outputs hash refresh or collector modification was made.

The investigator additionally identifies a scope discrepancy between T-004 report claims about the human-copy CI workflow and the T-011 ownership assigned by tasks.md/traceability.md. This is distinct from hash drift and still needs primary scope reconciliation before formal completion.

Primary confirmed the discrepancy on 2026-09-06: `T-004.md:208-219` explicitly acknowledges the scope problem, yet its Outputs rows at :229-230 still include the human-copy workflow and manifest. `tasks.md:45-50`, :65-68 and :1560-1572 assign that staging surface to T-011, as does `traceability.md:150`. These existing files may remain historical references, but they cannot substantiate T-004-owned completion. No frozen Outputs row, task ownership, or collector rule was rewritten; a valid reconciliation must preserve that history and pass the applicable provenance boundary.

### Current-state declaration path — primary clarification

Primary inspected the repair worktree collector at `prepare-panelist-input.sh:1161-1253`: an existing candidate whose hash equals its declared hash is captured directly at lines 1235-1245. The single section-wide git anchor is consulted only for missing or mismatched candidates. Therefore a truthful current-state Outputs declaration does not inherently require a collector change or a new commit to establish a historical anchor. This is a source-level finding, not a successful collector execution.

The remaining constraint is substantive: validate each current artifact and distinguish historical observations from fresh test evidence, preserve the earlier declaration, and reconcile T-011-owned staging references without removing required review inputs to make the collector pass. Read-only investigator `a7_redeclaration_requirements` is deriving the concrete verification requirements for that path. No declaration hashes, collector code, task state or historical logs were changed by this clarification.

Primary rejected the investigator's first result for citing another feature (`claude-workflow-compatibility`) and the wrong unqualified report path. Its corrected result verified the A7 suite and mutation-source hashes and the raw mutation log/hash above. Primary also rejected its final preference for a prose-only addendum: that leaves the failing Outputs rows unchanged and cannot implement the proposed current-state declaration path. The report's Latest Continuation explicitly supersedes its earlier non-GREEN status; the older paragraph must not be cited as the current result.

Primary task-contract check at `specs/epic-195-a7-compatibility/tasks.md:555-716` narrows the run-all obligation to registration of both structural suites (Planned Files and Done When), not a claim that every unrelated run-all test passes. A truthful re-declaration must verify those current registrations and retain this limitation. It must preserve the two human-copy staging artifacts as disclosed review context without implying T-004 owns their implementation or that the existing scope finding is resolved. The current suite/harness hashes plus the verified fresh raw log can support their current declarations; they cannot turn the older `green-*.log` and `mutation-proof.log` files into fresh results. No new test execution, implementation edit, or gate PASS is implied.

### Approval and authentication update — 2026-09-06

The user explicitly approved expanding the review ticket to update declarations
using the verified current artifacts. The user then supplied a successful Claude
authentication status. Primary independently confirmed `loggedIn: true`,
`authMethod: claude.ai`, `apiProvider: firstParty`, `subscriptionType: pro` with
`rtk proxy sh -c 'claude auth status | jq "{loggedIn, authMethod, apiProvider, subscriptionType}"'`.
This supersedes the earlier logout and declaration-approval blockers; no personal
account identifiers are retained here. Authentication success is not a completed
panelist execution or evidence of review success.

Worker `pr364_doc_fix` is assigned only the current declaration supersession and
ticket approval audit in the A7 worktree. Historical declarations, failed reviews,
and the open T-011 ownership finding must remain visible. The next checks are the
current 38-row hash audit and actual collection, followed by the still-required
provenance/readiness/identity checks before any fresh blind panel or quality gate.
## 2026-09-06 declaration repair and real collector result

Cheap worker `pr364_doc_fix` updated only the T-004 implementation report and RT-20260814-001 for the approved declaration expansion. The current exact `## Outputs` table contains 38 audited current hashes; the previous table remains under `## Historical Outputs`. The T-011 ownership finding and historical test evidence remain explicit. Primary reviewed both changes and requested the dated authentication/declaration supersession before collection.

The primary then executed the real unmodified collector once:

```sh
rtk proxy /bin/bash plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh --task T-004 --feature epic-195-a7-compatibility --input specs/epic-195-a7-compatibility/verification/T-004/ --spec-root specs --max-bytes 1048576 --out specs/epic-195-a7-compatibility/verification/T-004.declaration-refresh-20260906.panelist-input.txt
```

Worktree: `/Users/jrmag/.local/share/sdd-forge-a7-t004-evidence-20260905`. Actual exit 0; emitted input digest `6dfdb9cc0b84ca2dc04ab968992a0538cda16d225e8b881d178ddf8004806713`. This resolves the previously observed stale-declaration collector failure; it is not a panel or quality-gate PASS.

Pre-panel inspection found that this successful collector output still contains the prior independent review at line 6734, prior independent test at 6796, the T-004 implementation report at 7927, and other tasks' implementation reports at 12211, 12524 and 12818. The installed cross-model-verify skill's Blind & Parallel Isolation Rules prohibit passing prior reviews and Implementation Complete reports to blind panelists. The skill's later collection description contradictorily includes the task implementation report; the explicit isolation prohibition is preserved. No panel received this bundle. Four evidence logs were visibly elided by the collector's size policy; source completeness and the enumerable coverage manifest require separate readiness checks. Authentication is available, but availability does not resolve input isolation.

No collector source, historical evidence, frozen specification, reviewer identity or task status was altered by this continuation. No new A7 commit, push, formal gate or issue closure is claimed.
