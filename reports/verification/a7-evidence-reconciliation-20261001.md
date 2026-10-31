# A7 evidence and contract reconciliation — 2026-10-01

## Follow-up audit — 2026-10-02

Independent read-only audit (`copilot_candidate_review`) verified the new
`red-accounting-20261002-a1bf96a-{red,green}.log` files against the hashes in
`verification/T-004/red-accounting-correction-20260927.md:119-123`.
RED records 113 kills / 3 survivors and exit 1; GREEN records 116 / 0 and
exit 0. These new measurements resolve the lack of inspectable raw evidence
for the current replay, not the absence of the historical September 27 logs.
The historical 115 / 1 claim remains withdrawn. RT-20260814-001 remains open
at three review cycles; this audit is not a fresh quality-gate verdict or
authorization for an additional cycle.

T-009 does not require a new implementation or specification amendment for
the block-id-only case: the four combinations in `design.md:638-653` and
AC-033 concern effort and enforcement. Both implementations reject a lone
block ID before output (`emit-run-record.sh:98-115`, `.ps1:77-91`), with
existing coverage in `tests/emit-run-record-feature-scope.tests.sh:391-412`
and `.ps1:411-432`. The audit found no safety defect in this behavior.
No tests were rerun and no task, ticket, reservation or verdict was changed.

Scope: read-only comparison of saved artifacts at `a1bf96a6d7348dc6c4f48494d68b964dfe56fa20`. This addendum changes no frozen specification, task approval/status, ticket, verdict, or identity reservation. It is not a quality-gate run.

## T-004 / RT-20260814-001

The ticket's defect is historically valid, not a current product failure. The retained `malformed-corpus-red.log` still hashes to `25f1d633426a432407e30cf0412bf1a9185f3fd23ec4c309c269ff805629cea8` and states 115 killed / 1 survived. The dated correction `verification/T-004/red-accounting-correction-20260927.md` withdraws that count. Its saved machine-count extraction (`red-accounting-20260927-counts.log`, SHA-256 `c0ed9c2d55be145fd9cf33f5ac8906610d2f6616a212ba320703c371cbaf509b`) records RED 113 classified kills / 3 classifier survivors (the three PowerShell corpus cases), and current GREEN 116 / 0, exit 0. The three survivors are classifier outcomes; their individual suites exited 1 for other reasons. Dated supersession notices are present at the top of the implementation report and both independent records.

The two raw replay logs named by the correction are **absent in this checkout**. A read-only exact-basename search with `rg --files --hidden --no-ignore`, excluding `.git` and `node_modules`, also found neither log under the primary repository or managed-worktree roots on this host. The correction says they were retained locally rather than committed, so this negative scoped search does **not** establish global loss; their documented SHA-256 digests (`dff468d0e5d53525178384c72bd02b0d4d407218aab84c03f98365d1549e4283` RED, `203245a690e494038c0205be590f0d06b762e3140f404333e4ac60da2104ace7` GREEN) could not be checked against raw files here. The ticket is still `open`, cycle count 3, and its requested fresh quality-gate decision has not occurred. Thus the misleading 115/1 claim has been explicitly superseded, but the ticket's complete proposed resolution and a new independent verdict are **not** demonstrated. Do not mark T-004 Done or treat the cycle-limit script's `continue` as a fourth-cycle authorization. A reviewer must decide whether the preserved transcript plus correction/counts is admissible or requires a new raw RED/GREEN replay; any new gate must honor the persisted 3-cycle limit and explicit exception workflow.

## T-010 minimal amendment candidate (not applied)

Frozen `requirements.md:625-626` and `design.md:554-579` restrict activation grammar to `merged` and `fingerprint_match`; `tasks.md:1407-1412,1442-1445,1468-1480` requires literal equality to the five-entry design example. The current five-entry manifest has the same IDs, but AC-004 and AC-021 use `merged(A5) AND executable_contains(plugins/sdd-bootstrap,resolve-project-context)` (AC-021 also uses `merged(A1)`). Its A5 fingerprint is the later 2139-2179 window and digest `1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c`, whereas frozen requirements/design cite 1886-1915 and `9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`. The evaluators also implement `file_contains` and `executable_contains`. The existing T-010 contract addendum records the later shared commits and focused twin results; these are not approval or review.

Proposed smallest coherent wording change, subject to explicit human authorization and fresh spec/design/task re-review:

1. Amend AC-034's grammar and the design grammar section to enumerate four predicates (`merged`, `fingerprint_match`, `file_contains`, `executable_contains`), with exact argument grammar, source tree (`main`), absent-file/command failure behavior, and AND/OR precedence. Preserve AC-035's independent fingerprint-drift hard fail; define `executable_contains` as an additional A5 readiness condition, not a substitute for `merged` or fingerprint validation. Add negative acceptance rows for absent `main` caller and non-executable/text-only marker. If `file_contains` has no live manifest use, either remove that extension from both evaluators or justify and specify it explicitly; leaving an undocumented accepted predicate is not a coherent minimal amendment.
2. Rebind every normative A5 citation by identifier sweep, including requirements AC-036, design JSONC AC-004/AC-021 and later design prose, from old window/digest to the verified current A5 source window/digest. Preserve the old citation in a dated supersession note, not as a current fingerprint.
3. Change T-010's literal-example wording to “the five assertion IDs and schema in the re-reviewed design Data Plan, with fingerprints recomputed against their named current source windows” and explicitly require the A5 executable caller condition. Keep the high-risk preflight, TDD cases, and three AC-035 hard-fail fixtures. Update acceptance tests and traceability for the added negative cases before a new task review; do not mark T-010 `Implementation Complete` on the existing focused twin results alone.

Baseline SHA-256 package before any amendment: `requirements.md` `7af43a41f52d7fee4144ea603eba10cd5fe9ccf6468bcfe778afd212546f5a79`; `design.md` `ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96`; `acceptance-tests.md` `f77158ea4ad4263910439cd37ca0ed5296fc3f4e29e1d4e8c963d659ed799815`; `tasks.md` `fee9e7323ea2d3da9b4e30aedda5d7a80c80afa83775d41db360163fe94ce321`; `traceability.md` `676d2e3de2c0e311b1aa796dd4a7b21950e5ac47a030dd0fba3611617805cd31`. Current implementation candidate: manifest `5fa86d71e1e4a6667ecb2f668fb730eea09010c6d2cc7cafaba21ac4d29e5530`; Bash evaluator `3e2430559547b6a06c27e19e70ac7003acb99924004c2a0ba259ef46e1c28b87`; PowerShell evaluator `6daae2e88a65ca7fd1b9f215f93e869215d21ee82380101cc69b5245229a1197`. These are **baseline**, not post-amendment hashes; the new gate must hash the exact amended bytes and every admitted layer spec anew.

## T-012 persisted state inconsistency

`reports/quality-gate/epic-195-a7-compatibility/T-012.md` says `VERDICT: PASS` and “T-012 is Done”; its implementation report also claims Done. Yet both current `tasks.md:1672` and the historical evidence-bundle commit `58ec3b88` say `Status: Implementation Complete`. The T-012 addition commit `cd208894` likewise has `Implementation Complete`; no observed commit moved this task to Done. The current bundle validator passes and confirms referenced artifact hashes, but warns its `git_commit` is not an ancestor of HEAD and `git_generated_dirty=true`; it does **not** reconcile the lifecycle field. Sample current log digests match the bundle (`structural-sh.log` `d15931aa35b2ad955db035bedd6ce1916286b665f0f83623b8e38149e75ab5f6`, `live-refresh-sh.log` `0c966d0a36f8904a4bc3e5ec139e655f6ded4d2644cb2b7768642fc498f2f2c9`). The issue is a report-to-task state contradiction, not demonstrated log corruption. Only the quality-gate owner may set Done after reconciling its provenance; do not silently flip the status or call the task Done now.

## Reproduced T-010 evaluator mismatch

Read-only commands against the same HEAD, path and literal:

```sh
rtk proxy bash tests/lib/skip-allowlist-evaluator.sh file-contains . HEAD specs/epic-195-a7-compatibility/requirements.md 'Spec-Review-Statu?'
rtk proxy pwsh -NoProfile -File tests/lib/skip-allowlist-evaluator.ps1 file-contains . HEAD specs/epic-195-a7-compatibility/requirements.md 'Spec-Review-Statu?'
```

Bash exited 1; PowerShell exited 0; both emitted no stdout/stderr. The
PowerShell implementation at `tests/lib/skip-allowlist-evaluator.ps1:80`
uses `-clike`, which interprets the supplied literal as a wildcard pattern,
unlike Bash's `grep -F` at `tests/lib/skip-allowlist-evaluator.sh:67`.
Use ordinal literal substring comparison and add the negative case to the
existing twin suites when implementation is admitted; documenting the
current implementation as literal would conceal this defect.

The PowerShell executable suffix check at line 92 also uses case-insensitive
`-notmatch`, unlike Bash's case-sensitive suffix list. That second finding
is source inspection, not an executed uppercase-suffix regression.
T-010 remains Approved/Planned, high-risk TDD, blocked by T-003, T-004,
T-006, T-007 and T-008. No implementation, new gate or dependency bypass
was performed in this investigation.
