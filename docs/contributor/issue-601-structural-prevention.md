# #601: bounded structural-prevention preparation

Read-only preparation, not a review verdict or implementation. Baseline inspected: repository HEAD `8818e33e4ab283c00efcc79b23e2570d164aba21`; citations below are repository-relative `file:line` in that tree unless explicitly marked **issue619 branch**. Issue scope/corrections come from #601, #619, #620 and #600 (2026-10-22 snapshot). No tests, model calls, GitHub reads/writes, approvals or repository edits were performed.

Exactly three recurring-error classes are selected. Historical records establish recurrence; they do not establish present defect prevalence or a successful fix. Existing implementation, proposed branch work and remaining work are distinguished below.

## 1. One contract is copied into multiple independently maintained representations

**Historical source and recurrence.** WFI-039 records three successive CI failures in PR #305 as different mirrors surfaced, and an earlier occurrence (`docs/workflow-improvements/WFI-039.md:84`, `:115`). WFI-043 records the follow-on ambiguity twice: after a first branch sync, a second edit looked like pending human work (`docs/workflow-improvements/WFI-043.md:55`, `:84`). The same divergence mechanism affected report grammar: the corpus ratchet records 124 of 208 previously committed reports becoming invalid after contract changes (`tests/implementation-report-corpus.tests.sh:5`). These are recorded incidents, not inferred from duplicate files alone.

**Existing prevention → smallest remaining change.** Keep the canonical guard JSON and its four generated runtime projections (`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:431`, `:447`); CI already invokes generator `--check` (`.github/workflows/test.yml:355`). Mirror enumeration/classification is already shared by the sync tool and both freshness wrappers (`scripts/human_copy_mirrors.py:10`; `scripts/sync-human-copy-mirrors.py:34`; `tests/human-copy-mirror-freshness.tests.sh:54`; `.ps1:45`). Do not add another classifier or duplicate rule prose across skills. A concrete small integration candidate is registering or explicitly delegating the **existing focused classifier mutation suite**: it is currently excluded at `tests/verification-catalog.json:1078`. A call-site search over `.github/`, `scripts/`, `tests/` and `plugins/` found no reference to that suite outside its catalog entry; the freshness twins execute the classifier itself, not its mutation tests. Catalog discovery checks registration, not automatic execution (`tests/verification.py:79`, `:144`). This is a focused-fixture coverage gap, not absence of all mirror checking.

**Negative/control fixtures.** Reuse the existing bad-pin cases, including missing/duplicate pins and changed bytes (`tests/human-copy-mirrors-classification.tests.py:130`), the independently wrong manifest digest (`:233`), and legitimate new pending file versus missing published file (`:250`). Retain generator mutation checks that reject dropped protections/stale projections while permitting approved additive evolution (`tests/guard-invariants-epic-a1.tests.sh:253`). For WFI-043, preserve a synthetic second-edit ambiguity as a diagnostic/control case: do not claim automatic safe resync is solved by the current three-way comparison.

**Human judgment retained.** Whether a divergent bundle is already applied, is pending reviewed work, or needs an authorized successor cannot be inferred from inequality alone. New manifest membership is also a review decision (`docs/contributor/shared-file-mirrors.md:47`, `:65`). Preserve frozen historical bytes and pending human-copy; this preparation authorizes no sync or amendment.

## 2. Runtime defaults silently change a shared producer/consumer contract

**Historical source and recurrence.** The port rule at `AGENTS.md:254` distinguishes operator and cmdlet case defaults. WFI-044 documents three concrete mismatches across full/lite approval checkers and task-review precheck, including non-port changes missed by that trigger (`docs/workflow-improvements/WFI-044.md:57`, `:68`). #619 supplies a different runtime-dependent serialization example, with an essential correction: Windows PowerShell 5.1 `UTF8` emits a BOM; PowerShell 7 `utf8` does not. Existing BOM artifacts are not proof that current Core generated them, and the issue's original all-version explanation must not become the fixture oracle.

**Existing prevention → smallest remaining change.** Favor one explicit producer contract tested by independent consumers over a new blanket grep of all PowerShell operators. The inspected baseline still writes the aggregate with `Set-Content -Encoding Utf8` (`plugins/sdd-quality-loop/scripts/check-cross-model.ps1:75`). **issue619 branch only** ([PR #629](https://github.com/aharada54914/sdd-forge/pull/629), inspected through descendant commit `232e940f03b50b5611dd9b36f9bb5bb25e3bc1d1`) changes that producer to explicit BOM-free UTF-8 (`plugins/sdd-quality-loop/scripts/check-cross-model.ps1:75`) and delegates its new encoding fixture through the existing cross-model suite (`tests/verification-catalog.json:621`; `tests/cross-model.tests.ps1:523`). Reuse that work if integrated; do not implement a competing #601 writer fix or claim it is in the baseline.

**Negative/control fixtures.** Existing branch fixture runs the named producer, records edition/version, inspects actual prefix bytes, and uses strict Python/Node consumers preserving non-ASCII content (**issue619 branch**, `tests/cross-model-encoding.tests.ps1:28`, `:53`, `:110`). It covers PASS/FAIL and relative/in-session path controls (`:63`, `:83`). Remaining retention proof should retain a deliberately BOM-prefixed negative that both strict consumers reject, and compare old/new producer behavior on the actually supported editions: old 5.1 is the expected encoding negative; old 7 is a legitimate passing control. Keep case-mismatch negatives separate from canonical-case legitimate approvals; they test different runtime defaults. None of these cases was executed in this preparation.

**Human judgment retained.** Supported runtime versions, intended case-sensitive versus intentionally insensitive values, causal attribution for historical files, and treatment of frozen BOM evidence remain explicit judgments. Record `$PSVersionTable` and unexecuted platforms as unverified. Correct the cause through an addendum linked to #619; do not rewrite historical evidence or infer recurrence reduction from a locally passing branch test.

## 3. Missing or ambiguous measurement evidence is promoted into a substantive conclusion

**Historical source and recurrence.** WFI-055 records suites repeatedly added locally but omitted from CI, including two prior batches and a registration checker itself omitted (`docs/workflow-improvements/WFI-055.md:55`, `:70`, `:98`). WFI-051 documents a diagnostic saying “hash is stale” for missing committed history, which sent the investigation toward a wrong cause (`docs/workflow-improvements/WFI-051.md:55`, `:89`). #620 reports missing/partial/invalid/incomplete audit completion. It establishes an **audit process failure**, not a confirmed product defect, zero findings, or a specific root cause. #619 is also a useful counterexample to accepting an untested cause explanation.

**Existing prevention → smallest remaining change.** Reuse the executable catalog and its callers: local wrappers select profiles (`tests/run-all.sh:7`; `.ps1:9`), CI consumes the same runner (`.github/workflows/test.yml:207`), and missing required runtimes produce failure rather than success (`tests/verification.py:138`). The weekly workflow already validates current run/attempt/HEAD, exact check names and integer zero exits before declaring completion (`.github/workflows/self-improvement.yml:263`). It explicitly calls the record a **session assertion, not independent execution proof**. Keep that boundary. The smallest #601 addition is a paired retention/grading case over these existing artifacts: process completion and product findings must be recorded separately, with unknown cause allowed. Do not introduce another audit state machine or equate a well-shaped completion assertion with proof of all commands running.

**Negative/control fixtures.** Existing tests cover unregistered suites, excluded/delegated execution, failed-suite continuation and missing-runtime handling (`tests/verification-catalog.tests.py:42`, `:63`, `:91`, `:100`). Completion mutations cover missing/failed/unrun/boolean checks and stale identity, against a valid current record (`tests/self-improvement-guard.tests.sh:258`, `:277`). For #600 integration, pair (a) an incomplete audit whose report contains a real finding—must remain incomplete and retain the finding, with unknown root cause—with (b) a completed audit with genuine execution evidence and zero findings—must not be rejected merely for zero findings. A fake complete claim with absent execution artifacts must fail the behavior grader even if the current session-assertion validator alone accepts its shape.

**Human judgment retained.** The why-why process already requires evidence per link and labels uncorroborated links hypotheses (`plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md:414`). Horizon/Retention requires subsequent measurements and checking underlying reports before attribution (`:203`, `:221`, `:229`). Causal truth, support-policy decisions and improvement attribution remain review judgments; a schema can require links/statuses but cannot make a hypothesis true. Changes to graders, thresholds or approval rules use the existing Meta-Change lane (`:390`; `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md:364`), rather than promotion from higher PASS counts.

## Duplicate-validator reduction candidates, with actual consumers

| Candidate | Actual consumers and smallest safe direction |
|---|---|
| Repeated implementation-report output parsing | Authoring validator parses strict table rows (`plugins/sdd-implementation/scripts/validate-implementation-report.sh:199`); evaluator admission independently extracts table/legacy declarations (`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:207`, `:244`, `:412`, plus its PowerShell twin); panel preparation has a deliberately more tolerant historical parser (`plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:1115`). Candidate: a shared parsed declaration representation with explicit strict-current/historical compatibility modes, keeping each consumer's path/hash/admission checks. First reuse template parity and corpus ratchet (`tests/template-validator-parity.tests.sh:2`; `tests/implementation-report-corpus.tests.sh:13`). Do not transplant the tolerant parser into admission or delete validators because their headings resemble one another. |
| Repeated approval annotation grammar | Full and Lite repeat the same annotated-approval regex (`plugins/sdd-quality-loop/scripts/check-task-state.sh:89`; `plugins/sdd-lite/scripts/check-task-state-lite.sh:57`). Candidate: one authoritative grammar or generated constants for the syntax, with both native consumers tested. Full's critical two-person approval checks (`check-task-state.sh:185`) and Lite's different lifecycle/evidence responsibilities remain separate. This is prospective deduplication, not a finding that current syntax differs or permission to relax approval. |

The shared mirror classifier is already a successful deduplication boundary. Its native entrypoints and historical bundle-specific safety checks are not redundant merely because they inspect some of the same files.

## Remaining #600 handoff

Use the existing golden layout (`tests/golden/README.md:20`), presently documented as scaffold (`:43`). Supply these three classes as source-backed candidates within #600's five-case scope, with negative and legitimate-operation controls, origin references, grader mutations, and artifact/tool-trace assertions. #600 still owns tuning/held-out separation, concealed rubrics, matched model/configuration/budget, initial three repetitions and reporting n/k and time without causal overclaim. Deterministic fixtures must enter the existing catalog/CI profiles or an actual executed delegation; model runs stay opt-in. No held-out cases, graders, CI registration or behavior results were produced here.

For every selected class, the future correction record should link observed symptom → exact source/runtime → reproduction and counterexample → hypothesis or confirmed cause → structural change → retention fixture. Reuse existing WFI sections and addenda; do not add a rulebook, rewrite frozen records, change WFI/task approvals, or claim these proposals are already enforced.

## 2026-10-25 implementation addendum

The development session implements these Issue requirements directly; the
plugin's own workflow approval and model-adoption records are product data, not
prerequisites for editing the plugin. Existing product approval/enforcement
semantics remain unchanged.

- C1: the focused mirror suite now explicitly recreates the WFI-043 second-edit
  state and checks both `PENDING` classification and byte-for-byte no-write
  behavior. All 33 focused assertions pass on Linux. This is safe refusal, not
  an automatic resolution of the human ambiguity. The suite's catalog
  registration is part of the integrating change.
- C2: the already delegated encoding helper now prefixes a temporary copy with
  EF BB BF and separately requires rejection by unchanged strict Python and
  Node consumers. The original unprefixed producer controls still pass. Linux
  PowerShell Core completed 25 assertions. This synthetic negative is not an
  old-producer Red and does not establish historical origin or Windows Desktop
  behavior. Windows PowerShell 5.1 `UTF8` writes a BOM; PowerShell 7 `utf8` does
  not ([versioned runtime discussion](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding)).
- C3: `tests/golden/unrun-pass` preserves a finding while classifying incomplete
  process evidence and an unknown cause. Its bad-artifact and fake-PASS controls
  fail the grader. The comparison harness preserves failed/unrun/interrupted
  cells and refuses omitted trials, stale inputs, changed artifacts and missing
  metric observations; this does not authenticate an external collector's claims.

The three classes are now represented in the five-case golden portfolio:
C1 → `stale-skill`, C2 remains the existing cross-model encoding fixture,
C3 → `unrun-pass`; the other golden cases cover documented routing, cleanup and
an overbroad proposed scan. Exact runtime serialization remains a real producer/
consumer test rather than an LLM's JSON explanation. Golden `origin.md` files
link source records and distinguish reduced controls from exact historical
reproduction. Nineteen offline harness tests pass, including bad-output controls.

The two duplicate-validator candidates above remain deliberately unextracted:
strict current-authoring validation, historical parsing and review admission
have different trust responsibilities; Full and Lite approval policy likewise
must remain distinct. Existing shared mirror classification is reused.
No old reports, human-copy artifacts, task approvals or frozen specs were
rewritten. Retention: **Not evaluated**. Actual model/held-out trials, human
UX/adoption decisions and subsequent Horizon observations remain unperformed;
fixture pass counts do not demonstrate a reduction in recurring mistakes.
