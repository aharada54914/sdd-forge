# RT002 dependency inventory policy boundary — 2026-10-05

Scope: read-only continuation checks and this non-frozen observation record. This is not an implementation report, formal verdict, policy change, or permission to repeat a refused operation.

- Task: epic-189-a1-rt002-repair T-001; owner `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`.
- HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`; branch `codex/rt002-host-denial-repair`.
- Existing dirty tracked paths: workflow test.yml, AGENTS.md, both validate-review-context-set wrappers, quality-gate skill, review-context-boundary reference, workflow-state-registry, four review/scratch tests and run-all.sh. Existing untracked RT002 evidence and tests were preserved.
- Risk: this record changes no enforcement or evidence-acceptance contract; the underlying proposed guard change remains protected/high-risk.
- Required validation for this record: current owner/status, preserved evidence hashes, and inspection of the existing candidate's documented scope. No suite rerun is needed to record an unchanged pre-execution blocker.

## Current evidence

`git rev-parse HEAD`, `git status --short --branch`, and task status inspection executed through `rtk proxy`. T-001 remains Approved / Implementation Complete / high; T-002 remains Draft / Planned. No lifecycle field was changed.

Read-only `rtk proxy shasum -a 256` returned exit 0 and independently reconfirmed:

| Artifact | SHA-256 |
|---|---|
| `reports/implementation/epic-189-a1-rt002-repair/T-001.md` | `f3c151a105a1d0b1d0c90fb050f63a8b81005596d9484d95e158cb0490067533` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004/canonical-report-before-recovery.md` | `f3c151a105a1d0b1d0c90fb050f63a8b81005596d9484d95e158cb0490067533` |
| stopped run `task-input-manifest.json` | `affe26456f270f2fdf79552076f39ec1c43f18605569f52efaab4072fee7cfa5` |
| stopped run `implementation-revalidation-observations.md` | `80e2b77897e2f35573b833f444d7359c752cb0b97167a2c577f596a0b7d6f496` |

The last two paths are under `reports/implementation-scratch/epic-189-a1-rt002-repair/T-001/RUN-RT002-T001-REVALIDATION-20261005T043106Z-497150f9-9afe-4686-9f8a-9619f4014c6d/`. These checks reconfirm preservation only, not validity/completeness of that stopped 67-input snapshot.

## Concrete guard candidate and remaining mismatch

The relevant candidate checkout is `/private/tmp/sdd-guard-main.3JEj4I/repo`. Its existing `reports/verification/read-policy-pure-read-candidate-result-20261005.md` says that the classifier is inert, not applied, and requires formal reviews and an Approved implementation task. It accepts `rg` only with both `--no-config` and `-n`. The later `read-policy-audit-fix-record-20261005.md` additionally rejects parentheses, including quoted search-pattern parentheses. The independent limited re-audit confirms these candidate repairs while excluding actual guard execution, refused-operation retry, protected application and native activation.

The latest patch `reports/verification/read-policy-three-runtime-integration-20261005.patch` was hashed here with `rtk proxy shasum -a 256`, exit 0: `51bfdaa8a325899b2b63e01783026ef6e6e9325db7d49b58ba63c2e705e44f91`. Its recorded 298-case three-runtime candidate results and order checks are not installed-host proof.

The refused RT002 command preserved in `rt002-fresh-revalidation-stop-and-hook-diagnostic-20261005.md` uses `rg -n` without `--no-config`, and its quoted pattern starts `(^|[[:space:]])`. Therefore the documented candidate does not establish permission for that exact command even if later applied. This conclusion is a comparison of existing records; no classifier/guard probe and no retry of the refused command was executed. Adding options or changing the pattern as a workaround would not resolve the preserved refusal boundary.

These two mismatches have different meanings. The common matrix explicitly explains U07 (`rg -n` without `--no-config`): external configuration can request execution and the hook must not infer the eventual shell environment (`read-policy-regression-inputs-20261004.json:48`). The locally installed ripgrep help confirms that `--no-config` prevents reading configuration and ignores `RIPGREP_CONFIG_PATH`. Retain that conservative denial; making this original form pass is not a recovery requirement. By contrast, `specs/guard-role-read-regression/design.md` requires preserving quote provenance and treating literal pattern data separately from executable verbs; its acceptance amendment says punctuation alone is not grounds for denial, and retained TEST-017 explicitly permits quoted parentheses (`acceptance-tests.md:7-8,46`). The candidate's all-parentheses exclusion is a documented conservative limitation, not evidence that a single-quoted regex is executable. Resolving that candidate/spec discrepancy belongs to its owner and formal review, not an RT002 scope expansion.

## Bounded restart condition

The known missing dispatcher inputs remain `plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh` and `.ps1`; they are not a complete closure. The smallest currently documented path is a human-provided complete dependency inventory: a bounded list of repository-relative regular-file paths for both original suites, wrappers, verifier, dispatchers and recursively referenced helpers/fixture inputs, with caller-to-dependency edges and an explicit statement that dynamic references were resolved or none remain. It must identify the owner HEAD/current bytes; the owner can then hash-pin those listed bytes using the already sanctioned manifest procedure before a new run. A newly authorized fixed inspector could produce the same artifact without executing inspected sources, but no such existing closure-producing interface has been established here. The existing manifest validator cannot substitute: it returned TASK_INPUT_OK on the preserved manifest that lacked both dispatchers, demonstrating that that successful invocation did not certify this closure.

A separately managed guard/inventory repair may also supply an explicitly authorized safe operation after sanctioned application and actual read/deny verification. That operation should use configuration-independent inspection and preserve protected-write denial; it need not and should not authorize the original configuration-loading form. Merely respelling the refused scan within this continuation remains disallowed. This RT002 record does not authorize widening the candidate grammar or adding an inspector.

Only after that condition may the owner create a distinct implementation run/session and dependency-complete pinned manifest, run both original functional suites, produce/adopt fresh evidence through the recovery contract and prepare the independent evaluator. No replacement manifest, reservation, canonical adoption, original functional suite, native activation, formal gate, CI, merge or Done decision was performed in this continuation. The previously recorded 230 shared-launch regressions remain a separate historical local result.
