# Acceptance Tests: epic-191-a3-path-ownership

TEST IDs (TEST-001..TEST-055) are namespaced to this feature
(`specs/epic-191-a3-path-ownership/`) and map 1:1 to AC-001..AC-055 in
requirements.md. **Amended 2026-08-11** (following requirements.md's
human-directed conditional-activation supersession, which made a
predicate load-bearing that this file previously never exercised —
measured: zero occurrences of `sdd/project-context.yaml` existed here
before this amendment): AC-035 is now additionally covered by three
sub-ID rows — TEST-035a/TEST-035b/TEST-035c, the conditional-activation
three-way fixture — so the mapping remains 1:1 by acceptance criterion
(AC-035 ↔ the TEST-035 family); no pre-existing TEST ID changed meaning
and none was deleted. **Amended again 2026-08-11** (following the
same-day human-directed ruling that added REQ-004's
present-but-malformed Gate-side contract): a fourth sub-ID row,
TEST-035d, adds the Gate-side half of the same activation boundary —
`check-component-coverage`'s own recordless non-zero exit on a
present-but-malformed config — deliberately distinct from TEST-035c,
which asserts `check-contract`'s behaviour on the same fixture class;
the mapping remains 1:1 by acceptance criterion (AC-035 ↔ the TEST-035
family), and again no pre-existing TEST ID changed meaning and none was
deleted. All TEST IDs are `Status: Planned` — this feature's Phase
2 task decomposition (`tasks.md`, deferred per investigation.md INV-012)
has not yet been authored, so no task owns any TEST ID yet; that mapping
is `traceability.md`'s job once Phase 2 exists.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | glob semantics | `tests/component-path-resolver.tests.sh`/`.ps1`: `**` matches zero-or-more segments including crossing `/` | Planned |
| AC-002 | REQ-001 | TEST-002 | glob semantics | same suite: bare `*` matches within one segment only, never crosses `/` | Planned |
| AC-003 | REQ-001 | TEST-003 | normalization | same suite: `\`-separated pattern normalizes to `/` and matches its `/`-separated equivalent | Planned |
| AC-004 | REQ-001 | TEST-004 | normalization | same suite: NFD-encoded fixture path matches an NFC-encoded pattern after normalization (matching only) | Planned |
| AC-005 | REQ-001 | TEST-005 | case sensitivity | same suite: a case-differing fixture path never matches, on every OS this suite runs on | Planned |
| AC-006 | REQ-001 | TEST-006 | glob clause (negative): unsupported metacharacters | same suite: a pattern containing `?` or `[...]` is rejected as a fail-closed config error at load time | Planned |
| AC-007 | REQ-001 | TEST-007 | glob clause: `**` zero-segment | same suite: `a/**/b` matches literal `a/b` (zero intervening segments) | Planned |
| AC-008 | REQ-001 | TEST-008 | glob clause: empty sets | same suite: an empty changed-paths diff resolves vacuously; an empty `include` list is a config-load-time error, never UNOWNED | Planned |
| AC-009 | REQ-001 | TEST-009 | glob clause: shared zero-match | same suite: a `shared_paths` entry matching zero changed paths triggers no Fail-4 check for that resolve (classification-level fact only); the entry remains part of the full ownership input REQ-005 always binds into `ownership_digest` regardless (AC-037) | Planned |
| AC-010 | REQ-001 | TEST-010 | NFC collision + raw identity | same suite: two raw paths differing only in NFD/NFC form and colliding under normalization is a fail-closed error; every record preserves raw-path identity and output is a stable sort over raw path bytes | Planned |
| AC-011 | REQ-001 | TEST-011 | schema conformance (FAIL-closed on absence) | same suite: a dedicated fixture FAILS (non-zero, red) if Epic A1's canonical schema artifact is absent from its fixed, documented path — never a skip or conditional pass; when present, it validates the config parser against that schema and fails on any divergence | Planned |
| AC-012 | REQ-002 | TEST-012 | classification | same suite: single-component `(include − exclude)` match → EXCLUSIVE | Planned |
| AC-013 | REQ-002 | TEST-013 | invariant (negative) | same suite: a path in component C's own `exclude`, also matching a C `include` pattern, is never classified EXCLUSIVE to C (Fail-5 invariant) | Planned |
| AC-014 | REQ-002 | TEST-014 | evidence emission | same suite: an UNOWNED path caused entirely by exclude-as-include (AC-013) carries an explicit `EXCLUDED_MATCH` evidence tag, distinct from an ordinary UNOWNED record | Planned |
| AC-015 | REQ-002 | TEST-015 | classification | same suite: zero-component match, no `shared_paths` match → UNOWNED (Fail-1) | Planned |
| AC-016 | REQ-002 | TEST-016 | classification | same suite: two-or-more-component match, no `shared_paths` match → OVERLAP (Fail-3) | Planned |
| AC-017 | REQ-002 | TEST-017 | precedence | same suite: a `shared_paths` match exempts a path from OVERLAP/UNOWNED regardless of component-include count | Planned |
| AC-018 | REQ-002 | TEST-018 | config-shape (negative) | same suite: a `shared_paths` entry with both `components` and `classification: cross-cutting`, or neither, is rejected fail-closed at load time | Planned |
| AC-019 | REQ-003 | TEST-019 | git-diff basis | `tests/component-path-diff-basis.tests.sh`/`.ps1`: source defaults to `HEAD`/`--source-rev`, target is a complete ref/OID via `--target-rev`, both resolved with `rev-parse --verify <rev>^{commit}` before `merge-base`; an unresolvable rev or unrelated-histories fixture produces a fail-closed diagnostic, never an empty diff | Planned |
| AC-020 | REQ-003 | TEST-020 | git-diff basis | same suite: staged + unstaged + untracked are each counted exactly once, collected via git porcelain commands only (no raw filesystem walk) | Planned |
| AC-021 | REQ-003 | TEST-021 | NUL-safe framing | same suite: every path-enumerating git invocation uses `-z` and parses raw bytes; a TAB/LF-containing path round-trips correctly, an invalid-UTF-8 path fails closed with a diagnostic | Planned |
| AC-022 | REQ-003 | TEST-022 | rename-follow | same suite: both old and new path of a rename are independently classified; a cross-component rename is reported as a distinct case | Planned |
| AC-023 | REQ-003 | TEST-023 | rename contract | same suite: pinned similarity threshold + `diff.renameLimit` + `--no-ext-diff`; the followed-rename vs. limit-exceeded-fallback output contract is fixed; a limit-exceeding fixture is fail-closed, never a silent `D`+`A` reinterpretation | Planned |
| AC-024 | REQ-003 | TEST-024 | reference-only boundary (4 fixtures) | same suite: (a) dirty-only submodule not reported; (b) gitlink OID change reported as the submodule path only; (c) symlink target-text change reported for the symlink path only; (d) referent-only content change not reported | Planned |
| AC-025 | REQ-003 | TEST-025 | single-writer / TOCTOU | same suite: HEAD OID + index/worktree fingerprint captured at start and end; a mid-sequence mutation triggers one retry then a fail-closed diagnostic | Planned |
| AC-026 | REQ-004 | TEST-026 | applicability derivation | `tests/check-component-coverage.tests.sh`/`.ps1`: derived state (`disabled-legacy`/`advisory`/`required`) is derived solely from `workflow.capability_enforcement`; a fixture with a present manifest file but `disabled-legacy` state still records `disabled-legacy` (no evaluation of that manifest), proving file presence is not a selector even though the script itself still runs | Planned |
| AC-027 | REQ-004 | TEST-027 | `disabled-legacy` truthful non-evaluation | same suite: in `disabled-legacy`, the Gate still runs to completion and emits a real evidence record with `state: "not-applicable (disabled-legacy)"` — no Fail conditions evaluated, no WARN recorded, exit 0; the record is genuine, not a placeholder, giving `check-contract`'s required-check-set real evidence to validate | Planned |
| AC-028 | REQ-004 | TEST-028 | manifest-required hard error | same suite: in either `advisory` or `required`, a missing/unreadable `--facet-manifest` path is a hard error with a distinct exit code, never WARN + exit 0 | Planned |
| AC-029 | REQ-004 | TEST-029 | resolver-only diagnostics separated | same suite (+ `resolve-component-paths --diagnose` invocation): the Fail-1/3/5/6-conditional checks exist only outside the Gate; `quality-gate`'s `## Process` never invokes them and their exit code never affects the Implementation Gate | Planned |
| AC-030 | REQ-004 | TEST-030 | fail-condition coverage (6-way) | same suite: one dedicated fixture per Fail-1..Fail-6 deterministically triggers that condition when the Gate is invoked with a present, readable Facet Manifest, identically in both `advisory` and `required` (only exit code/blocking differs, TEST-052/053) (Fail-6's fixture includes `sdd/provider-bindings.yaml` with `adapter_paths`) | Planned |
| AC-031 | REQ-004 | TEST-031 | Fail-2/Fail-4 mutual exclusivity | same suite: a bounded-shared shortfall fixture triggers Fail-4 only; an EXCLUSIVE-owner-missing fixture triggers Fail-2 only; neither fixture double-fires the other condition | Planned |
| AC-032 | REQ-004 | TEST-032 | Fail-5 Gate-level reachability | same suite: a dedicated fixture drives Fail-5 as an ordinary runtime path via `EXCLUDED_MATCH` evidence against real Facet Manifest data, distinguished from a same-fixture UNOWNED trigger | Planned |
| AC-033 | REQ-004 | TEST-033 | Fail-6 adapter-path rule | same suite: a binding declaring `adapter_paths` whose glob matches an EXCLUSIVE-owned path triggers Fail-6 (the glob match is the sole trigger condition); a fixture whose declared `adapter_paths` glob does not match any EXCLUSIVE-owned changed path does not trigger Fail-6; a binding lacking `adapter_paths` records WARN "evaluation not possible" | Planned |
| AC-034 | REQ-004 | TEST-034 | conditional N/A | same suite: with no `sdd/provider-bindings.yaml` present, Fail-6 is recorded N/A with a WARN, never silently omitted without a trace | Planned |
| AC-035 | REQ-004 | TEST-035 | reachability (two-tier defense scope) | same suite: a fixture deletes/renames the `quality-gate/SKILL.md` invocation, or substitutes an unregistered replacement script paired with a same-id, mismatched-digest `passes:true` evidence entry; the `high`/`critical` Gate still fails via `check-contract`'s protected required-check-set + producer-digest verification, scoped to footgun-prevention/tamper-evidence, not unconditional adversarial-agent reachability (external boundary: protected files, HMAC evidence bundle, branch protection, human review); amended 2026-08-11: this fixture pins `sdd/project-context.yaml` present and schema-valid in its fixture tree, because under the conditional-activation supersession the required-check-set half it exercises is active only in that state (the activation boundary itself is TEST-035a/b/c) | Planned |
| AC-035 | REQ-004 | TEST-035a | conditional activation — file absent (added 2026-08-11) | same suite (+ direct invocation of the staged `check-contract.{sh,ps1,py}` candidate against a disposable fixture tree, never the live repository): with no `sdd/project-context.yaml` in the fixture tree, a `high`/`critical` contract carrying no `check-component-coverage` evidence entry passes `check-contract` — the tier-minimum membership is inactive (the state of every pre-existing contract); guards against a stuck-shut regression that would re-break the 94 pre-existing `high`/`critical` contracts (requirements.md Problems) | Planned |
| AC-035 | REQ-004 | TEST-035b | conditional activation — present and valid (added 2026-08-11) | same suite: with a schema-valid `sdd/project-context.yaml` present in the fixture tree, the otherwise-identical `high`/`critical` contract lacking the entry FAILS `check-contract` — the membership is active; guards against a stuck-open regression where the minimum never arms once the file lands | Planned |
| AC-035 | REQ-004 | TEST-035c | conditional activation — present but malformed, fail-closed (added 2026-08-11) | same suite: with a present but malformed `sdd/project-context.yaml` (one unparseable-YAML variant and one schema-divergent variant), the contract lacking the entry still FAILS — check still required — proving the predicate is plain file presence with no YAML parser participating; catches an implementation whose caught parse exception silently concludes `disabled-legacy` and turns the minimum off forever, the exact regression requirements.md's Problems paragraph warns against | Planned |
| AC-035 | REQ-004 | TEST-035d | Gate-side present-but-malformed fail-closed crash (added 2026-08-11, human-directed ruling) | `tests/check-component-coverage.tests.sh`/`.ps1`: with a present but malformed (unparseable) `sdd/project-context.yaml` supplied as `--config` in a disposable fixture tree, `check-component-coverage` ITSELF — both runtimes — exits non-zero with a diagnostic naming the parse failure and emits NO evidence record (no record at all, so no `passes:true` entry can exist for the activated tier minimum to accept); this row asserts the GATE's behaviour, not `check-contract`'s — TEST-035c asserts that `check-contract` still requires the check on the same fixture class, and the two rows must never be merged: 035c pins the requirement side (check still demanded), 035d pins the producer side (no record produced), and only both together keep the pipeline red until the config is fixed (requirements.md REQ-004's present-but-malformed sub-bullet; AC-035); catches an implementation that catches the Gate's own parse exception and reuses the file-absence `disabled-legacy` fallback, which would emit a genuine, producer-digest-valid record satisfying the activated minimum while the config is broken | Planned |
| AC-036 | REQ-004 | TEST-036 | protected-registration + generator-inventory parity | same suite: (a) staged six-file candidate set (`guard-invariants.json`, `generate-guard-invariants.py`, four `generated/*` files) exists with correct `MANIFEST.sha256` entries; (b) `generate-guard-invariants.py --check` exits 0 against the staged tree; (c) the live files are byte-identical before/after this feature's own commits; (d) a post-human-copy self-registration grep confirms the three `check-component-coverage.*` entries are present | Planned |
| AC-037 | REQ-005 | TEST-037 | digest scope (full input, unconditional) | `tests/ownership-digest.tests.sh`/`.ps1`: `ownership_digest` is computed over the **entire** declared ownership input — every component/`shared_paths` entry, unconditionally, never a per-resolve-scoped subset — plus the matcher-semantics-version, via Epic A1's canonicalizer; the task records a documented blocker if that canonicalizer does not exist at implementation time | Planned |
| AC-038 | REQ-005 | TEST-038 | staleness exclusion | same suite: `ownership_digest` populates `context_binding` per ADR-0021; a fixture where only `ownership_digest` changes (no resolved-component-set change) does not mark the Feature stale | Planned |
| AC-039 | REQ-005 | TEST-039 | non-match stale regression (instance of AC-037) | same suite: a component/`shared_paths` entry that did not match a given Feature's changed-path set is edited to now match — even against the identical changed paths — changes `ownership_digest`, confirming the full-input guarantee observably | Planned |
| AC-040 | REQ-005 | TEST-040 | selective-stale positive/negative matrix (full-input premise) | same suite: owner added, owner removed, non-match→match unrelated to this Feature's diff, bounded-shared-entry change unrelated to this diff, an edit disjoint from this diff that also changes every other Feature's identical digest simultaneously, and a matcher-semantics-version bump — each verified against ADR-0021 semantic-output comparison and `context_binding`/`resolver` metadata update behavior, since selectivity now lives entirely in that comparison, never in the digest's own scope | Planned |
| AC-041 | REQ-005 | TEST-041 | suite-wiring self-test | same suite: a self-check confirms `tests/ownership-digest.tests.sh`/`.ps1` is present in `tests/run-all.sh`/`.ps1`, `.github/workflows/test.yml`'s staged candidate, and design.md's own Components table | Planned |
| AC-042 | REQ-006 | TEST-042 | cross-epic inventory conformance (single source of truth) | cross-epic fixture: reads Epic A1's shipped `contracts/project-context.template.yaml` directly and asserts its `shared_paths` cross-cutting entries are **exactly** `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`, `CHANGELOG.md` — no more, no fewer, no differently classified — and that `contracts/**` does **not** appear; FAILS closed (never skips) on a missing artifact or any divergence, since A3 authors no competing list | Planned |
| AC-043 | REQ-006 | TEST-043 | no-op proof | `tests/component-path-resolver.tests.sh`/`.ps1` (shared fixture): a diff confined to the six-entry set above, with zero components declared to own them, never triggers Fail-1 | Planned |
| AC-044 | REQ-006 | TEST-044 | day-one cross-epic integration proof | `tests/component-path-resolver.tests.sh`/`.ps1` (cross-epic fixture, combined with `component-path-diff-basis`'s collector): a `project-context.yaml` shaped exactly like Epic A1's `contracts/project-context.template.yaml` (read directly once it lands; FAILS closed/block while absent, never a stand-in) prevents Fail-1 on an ordinary day-one `specs/**`/`reports/**` change immediately after Gate introduction — proven against A1's own artifact, not an A3-maintained copy | Planned |
| AC-045 | REQ-007 | TEST-045 | fixture shape | structural check over `tests/fixtures/component-path-ownership/`: at least two components with overlapping candidate owned paths, a nested excluded subtree, and a bounded `shared_paths` entry | Planned |
| AC-046 | REQ-007 | TEST-046 | contracts bounded-shared enforcement | `tests/check-component-coverage.tests.sh`/`.ps1` (shared fixture): a `contracts/**`-shaped bounded `shared_paths` entry (`components: [...]` enumerated) with a fixture where an out-of-enumeration component's artifact under `contracts/**` triggers Fail-4, not a silent pass | Planned |
| AC-047 | REQ-007 | TEST-047 | suite registration + 6-case + expanded fixtures | `tests/run-all.sh`/`.ps1` registration grep; `.github/workflows/test.yml` human-copy proof for the five new suites' CI steps; each of overlap/unowned/rename/untracked/exclude-misuse/shared-undeclared has ≥1 positive case and ≥1 red/failing-then-fixed case; the fixture tree carries the 4 submodule/symlink fixtures, the NFC-collision fixture, and one fixture per glob clause id | Planned |
| AC-048 | REQ-008 | TEST-048 | document conformance | grep-based check: each Phase-2 task's own `CHANGELOG.md` `## Unreleased` entry cites #191; `docs/adr/00NN-component-path-ownership-resolver-semantics.md` exists and documents glob semantics, precedence, and the six Fail-condition definitions | Planned |
| AC-049 | REQ-008 | TEST-049 | version-bump conformance | grep-based self-check: no version string mutated anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation | Planned |
| AC-050 | REQ-009 | TEST-050 | dual-runtime parity (product wrapper direct) | `tests/component-path-ownership-parity.tests.sh`/`.ps1`: identical fixture+argv fed **directly to each product wrapper pair** (`resolve-component-paths.{sh,ps1}`, `check-component-coverage.{sh,ps1}` — the only two wrapper pairs this feature ships); canonical normalized stdout JSON (design.md), exit code, WARN/error category, and argv pass-through (incl. `$LASTEXITCODE`) are diffed directly between each wrapper's two runtimes — never a suite-twin comparison; a `.ps1`-only argument-drop or `$LASTEXITCODE` defect fails this test even when both wrapper runtimes independently pass | Planned |
| AC-051 | REQ-009 | TEST-051 | parity harness registration | same suite: registered in `tests/run-all.sh`/`.ps1` and staged into `.github/workflows/test.yml` via human-copy, alongside the suite pairs | Planned |
| AC-052 | REQ-004 | TEST-052 | `advisory` non-blocking | `tests/check-component-coverage.tests.sh`/`.ps1`: in `advisory`, a fixture where at least one Fail condition triggers still exits 0; the trigger is recorded in the evidence output, never silently dropped | Planned |
| AC-053 | REQ-004 | TEST-053 | `required` blocking | same suite: in `required`, a fixture where at least one Fail condition triggers exits non-zero; a fixture where none trigger exits 0 | Planned |
| AC-054 | REQ-004 | TEST-054 | evidence producer binding + `emit-run-record` conformance | same suite: every evidence record, in all three derived states, carries `schema: "check-component-coverage-verdict/v1"`, `check_id`, and a `producer.sha256` computed over the actual invoked `check-component-coverage.py`; a fixture with a mismatched or missing `producer.sha256` is rejected | Planned |
| AC-055 | REQ-004 | TEST-055 | `check-contract` producer-digest verification | same suite (+ direct `check-contract` invocation): the staged `check-contract.{sh,ps1,py}` candidate recomputes `check-component-coverage.py`'s live sha256 and fails a `passes:true` evidence entry whose recorded `producer.sha256` does not match; a substituted-script fixture paired with a stale/unrelated evidence file fails this check | Planned |

Notes:

- TEST-001..TEST-018 (REQ-001, REQ-002) are fully deterministic,
  fixture-driven, and require no LLM invocation, no network call, and no
  `gh` invocation — they exercise `resolve-component-paths` alone, with no
  Gate, Facet Manifest, or Provider Bindings dependency. TEST-010's
  NFC-collision fixture requires no external precondition. TEST-011's
  schema-conformance fixture is the one exception with an external
  dependency (Epic A1's landed schema) — but it is not precondition-gated
  the way a skip would be: it runs unconditionally and **FAILS closed**
  whenever that schema artifact is absent, rather than skipping.
- TEST-019..TEST-025 (REQ-003) exercise the git-diff collector alone
  against real, disposable fixture git repositories (never this
  repository's own history) — deterministic, no network call.
- TEST-026..TEST-036, TEST-052..TEST-055 (REQ-004) are the only cases that
  construct a Facet Manifest fixture (`advisory`/`required` states) or
  deliberately test the `disabled-legacy`/hard-error boundary conditions;
  none of them requires Epic A4's actual schema file to exist — each
  fixture is a standalone JSON/YAML object shaped to match
  `facet-manifest.affected_components`'s documented field (design.md Data
  Plan), consistent with this feature's own scope boundary against
  redefining that schema. TEST-035a/b/c (added 2026-08-11) and
  TEST-035d (added 2026-08-11, Gate-side ruling) construct
  their `sdd/project-context.yaml` presence/validity/malformation
  variants inside a disposable fixture tree only — this repository has
  no live `sdd/project-context.yaml`, and no test creates one at the
  live path (doing so would flip the repository's own derived
  capability state). TEST-035d invokes only
  `check-component-coverage.{sh,ps1}` (both runtimes) against its
  malformed fixture config; unlike TEST-035a/b/c it never invokes
  `check-contract`. TEST-035 (with its 2026-08-11 sub-IDs
  TEST-035a/b/c)/TEST-036/TEST-055 additionally read
  (never write) `check-contract.{sh,ps1,py}`, `risk-gate-matrix.md`,
  `guard-invariants.json`, and `generate-guard-invariants.py` to construct
  their reachability/registration/producer-digest fixtures, and invoke
  `generate-guard-invariants.py --check` against a staged copy of the
  tree, never the live repository paths. TEST-054/TEST-055 are the only
  cases that inspect the `emit-run-record`-conformant evidence schema and
  its `producer.sha256` binding directly (NEW-001).
- TEST-037/TEST-041 (REQ-005) assume Epic A1's canonicalizer utility is
  available at the time these tests actually run; if it is not yet
  available when this feature's Phase 2 implementation begins, this is
  recorded as a blocker (requirements.md Dependencies), not a skipped or
  weakened test. TEST-037/TEST-039/TEST-040 additionally assert
  `ownership_digest` binds the **entire** declared ownership input,
  identically across every Feature sharing a config — never a
  per-resolve-scoped subset.
- TEST-036 and TEST-047's protected-registration proofs follow the same
  multi-part shape `specs/epic-159-pillar-c/acceptance-tests.md`'s
  TEST-027 established for a different protected file
  (`.github/workflows/test.yml`) — reused here for the
  `guard-invariants.json`/generator toolchain (TEST-036) and the CI step
  registration (TEST-047); TEST-035 (and its 2026-08-11 sub-IDs
  TEST-035a/b/c)/TEST-055 additionally reuse the
  pattern for `check-contract`'s protected required-check-set and its
  producer-digest verification pass (a family TEST-027 itself did not
  need to cover).
- TEST-042/TEST-044 (REQ-006) are cross-epic tests: they read Epic A1's
  shipped `contracts/project-context.template.yaml` directly once it
  lands, never an A3-authored competing seed-list document — consistent
  with the single-canonical-source consolidation (Dependencies). Like
  TEST-011, these FAIL closed (never skip) on a missing artifact or any
  inventory divergence.
- TEST-050/TEST-051 (REQ-009) are the only cases that invoke both
  runtimes of a **product wrapper** (`resolve-component-paths.{sh,ps1}` or
  `check-component-coverage.{sh,ps1}`) from within a single test process
  to diff their output directly — never a comparison between each other
  suite's own separately-authored `.sh`/`.ps1` twin processes; every other
  suite's `.sh`/`.ps1` pair is still run independently (once per OS lane)
  as before; the parity harness is an additional, not a replacement,
  layer.
- No test in this feature writes a real repository path outside its own
  new/edited files, invokes `gh`, invokes `sdd-sudo`, or emits an approval
  string; every protected-path input (`guard-invariants.json` and its
  generated siblings, `generate-guard-invariants.py`,
  `check-contract.{sh,ps1,py}`, `.github/workflows/test.yml`) is read-only
  to every test, and a write target only via the `human-copy/` staging
  area.
- This is script/gate/test-infrastructure and reference-documentation work
  with no GUI entry point; the UI integration checklist and the four
  layer-spec files (`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/
  `security-spec.md`) are not applicable and are not authored for this
  feature (investigation.md INV-013; design.md Layer Specifications).
