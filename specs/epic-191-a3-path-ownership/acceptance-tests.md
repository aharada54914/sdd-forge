# Acceptance Tests: epic-191-a3-path-ownership

TEST IDs (TEST-001..TEST-051) are namespaced to this feature
(`specs/epic-191-a3-path-ownership/`) and map 1:1 to AC-001..AC-051 in
requirements.md. All TEST IDs are `Status: Planned` — this feature's Phase
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
| AC-009 | REQ-001 | TEST-009 | glob clause: shared zero-match | same suite: a `shared_paths` entry matching zero changed paths is not evaluated for that resolve (no Fail-4 check fires) | Planned |
| AC-010 | REQ-001 | TEST-010 | NFC collision + raw identity | same suite: two raw paths differing only in NFD/NFC form and colliding under normalization is a fail-closed error; every record preserves raw-path identity and output is a stable sort over raw path bytes | Planned |
| AC-011 | REQ-001 | TEST-011 | schema conformance (hard dependency) | same suite: a dedicated fixture validates the config parser against Epic A1's landed canonical schema once it exists; divergence is a documented blocker, not a silent pass | Planned |
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
| AC-026 | REQ-004 | TEST-026 | applicability derivation | `tests/check-component-coverage.tests.sh`/`.ps1`: applicability is derived solely from `workflow.capability_enforcement`/`disabled-legacy`; a fixture with a present manifest file but `disabled-legacy` state still results in no invocation | Planned |
| AC-027 | REQ-004 | TEST-027 | capability-disabled no-op | same suite: in `disabled-legacy`, the Gate is not invoked at all — no Fail conditions evaluated, no WARN recorded, skip is logged not silent | Planned |
| AC-028 | REQ-004 | TEST-028 | manifest-required hard error | same suite: in the capability-active state, a missing/unreadable `--facet-manifest` path is a hard error with a distinct exit code, never WARN + exit 0 | Planned |
| AC-029 | REQ-004 | TEST-029 | resolver-only diagnostics separated | same suite (+ `resolve-component-paths --diagnose` invocation): the Fail-1/3/5/6-conditional checks exist only outside the Gate; `quality-gate`'s `## Process` never invokes them and their exit code never affects the Implementation Gate | Planned |
| AC-030 | REQ-004 | TEST-030 | fail-condition coverage (6-way) | same suite: one dedicated fixture per Fail-1..Fail-6 deterministically triggers that condition when the Gate is invoked with a present, readable Facet Manifest (Fail-6's fixture includes `sdd/provider-bindings.yaml` with `adapter_paths`) | Planned |
| AC-031 | REQ-004 | TEST-031 | Fail-2/Fail-4 mutual exclusivity | same suite: a bounded-shared shortfall fixture triggers Fail-4 only; an EXCLUSIVE-owner-missing fixture triggers Fail-2 only; neither fixture double-fires the other condition | Planned |
| AC-032 | REQ-004 | TEST-032 | Fail-5 Gate-level reachability | same suite: a dedicated fixture drives Fail-5 as an ordinary runtime path via `EXCLUDED_MATCH` evidence against real Facet Manifest data, distinguished from a same-fixture UNOWNED trigger | Planned |
| AC-033 | REQ-004 | TEST-033 | Fail-6 adapter-path rule | same suite: a binding declaring `adapter_paths` whose glob matches an EXCLUSIVE-owned path without the corresponding binding facet/revision in the diff triggers Fail-6; a binding lacking `adapter_paths` records WARN "evaluation not possible" | Planned |
| AC-034 | REQ-004 | TEST-034 | conditional N/A | same suite: with no `sdd/provider-bindings.yaml` present, Fail-6 is recorded N/A with a WARN, never silently omitted without a trace | Planned |
| AC-035 | REQ-004 | TEST-035 | reachability (required-check-set) | same suite: a fixture deletes/renames the `quality-gate/SKILL.md` invocation, or substitutes an unregistered replacement script; the `high`/`critical` Gate still fails via `check-contract`'s protected required-check-set enforcement, independent of SKILL.md's text | Planned |
| AC-036 | REQ-004 | TEST-036 | protected-registration + generator-inventory parity | same suite: (a) staged six-file candidate set (`guard-invariants.json`, `generate-guard-invariants.py`, four `generated/*` files) exists with correct `MANIFEST.sha256` entries; (b) `generate-guard-invariants.py --check` exits 0 against the staged tree; (c) the live files are byte-identical before/after this feature's own commits; (d) a post-human-copy self-registration grep confirms the three `check-component-coverage.*` entries are present | Planned |
| AC-037 | REQ-005 | TEST-037 | digest scope (full input) | `tests/ownership-digest.tests.sh`/`.ps1`: `ownership_digest` is computed over every component/`shared_paths` entry actually evaluated — matched or not — plus the matcher-semantics-version, via Epic A1's canonicalizer; the task records a documented blocker if that canonicalizer does not exist at implementation time | Planned |
| AC-038 | REQ-005 | TEST-038 | staleness exclusion | same suite: `ownership_digest` populates `context_binding` per ADR-0021; a fixture where only `ownership_digest` changes (no resolved-component-set change) does not mark the Feature stale | Planned |
| AC-039 | REQ-005 | TEST-039 | non-match stale regression | same suite: a previously non-matching component/`shared_paths` entry (evaluated, not matched) changing to now match the same changed-path set changes `ownership_digest` | Planned |
| AC-040 | REQ-005 | TEST-040 | selective-stale positive/negative matrix | same suite: owner added, owner removed, non-match→match, bounded-shared-entry change, consumed-input change, non-consumed-input change — each verified against ADR-0021 semantic-output comparison and `context_binding`/`resolver` metadata update behavior | Planned |
| AC-041 | REQ-005 | TEST-041 | suite-wiring self-test | same suite: a self-check confirms `tests/ownership-digest.tests.sh`/`.ps1` is present in `tests/run-all.sh`/`.ps1`, `.github/workflows/test.yml`'s staged candidate, and design.md's own Components table | Planned |
| AC-042 | REQ-006 | TEST-042 | document conformance | grep-based check: `plugins/sdd-quality-loop/references/default-shared-paths.md` lists at least `specs/**`, `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`, `tests/fixtures/**`, and does **not** list `contracts/**` | Planned |
| AC-043 | REQ-006 | TEST-043 | no-op proof | `tests/component-path-resolver.tests.sh`/`.ps1` (shared fixture): a diff confined to the default cross-cutting entries, with zero components declared to own them, never triggers Fail-1 | Planned |
| AC-044 | REQ-006 | TEST-044 | bootstrap integration proof | `tests/component-path-resolver.tests.sh`/`.ps1` (bootstrap-integration fixture, combined with `component-path-diff-basis`'s collector): the default seed list applied to a fixture day-one `project-context.yaml` prevents Fail-1 on an ordinary `specs/**`/`reports/**` change immediately after Gate introduction | Planned |
| AC-045 | REQ-007 | TEST-045 | fixture shape | structural check over `tests/fixtures/component-path-ownership/`: at least two components with overlapping candidate owned paths, a nested excluded subtree, and a bounded `shared_paths` entry | Planned |
| AC-046 | REQ-007 | TEST-046 | contracts bounded-shared enforcement | `tests/check-component-coverage.tests.sh`/`.ps1` (shared fixture): a `contracts/**`-shaped bounded `shared_paths` entry (`components: [...]` enumerated) with a fixture where an out-of-enumeration component's artifact under `contracts/**` triggers Fail-4, not a silent pass | Planned |
| AC-047 | REQ-007 | TEST-047 | suite registration + 6-case + expanded fixtures | `tests/run-all.sh`/`.ps1` registration grep; `.github/workflows/test.yml` human-copy proof for the five new suites' CI steps; each of overlap/unowned/rename/untracked/exclude-misuse/shared-undeclared has ≥1 positive case and ≥1 red/failing-then-fixed case; the fixture tree carries the 4 submodule/symlink fixtures, the NFC-collision fixture, and one fixture per glob clause id | Planned |
| AC-048 | REQ-008 | TEST-048 | document conformance | grep-based check: each Phase-2 task's own `CHANGELOG.md` `## Unreleased` entry cites #191; `docs/adr/00NN-component-path-ownership-resolver-semantics.md` exists and documents glob semantics, precedence, and the six Fail-condition definitions | Planned |
| AC-049 | REQ-008 | TEST-049 | version-bump conformance | grep-based self-check: no version string mutated anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation | Planned |
| AC-050 | REQ-009 | TEST-050 | dual-runtime parity | `tests/component-path-ownership-parity.tests.sh`/`.ps1`: identical fixture+argv fed to every `.sh`/`.ps1` twin across all four other suites; normalized stdout JSON, exit code, WARN/error category, and argv pass-through are diffed directly; a `.ps1`-only argument-drop or `$LASTEXITCODE` defect fails this test even when both twins independently pass | Planned |
| AC-051 | REQ-009 | TEST-051 | parity harness registration | same suite: registered in `tests/run-all.sh`/`.ps1` and staged into `.github/workflows/test.yml` via human-copy, alongside the other four suite pairs | Planned |

Notes:

- TEST-001..TEST-018 (REQ-001, REQ-002) are fully deterministic,
  fixture-driven, and require no LLM invocation, no network call, and no
  `gh` invocation — they exercise `resolve-component-paths` alone, with no
  Gate, Facet Manifest, or Provider Bindings dependency. TEST-010's
  NFC-collision fixture and TEST-011's schema-conformance fixture are the
  two exceptions requiring an external precondition (a landed Epic A1
  schema for TEST-011; both are self-contained fixtures otherwise).
- TEST-019..TEST-025 (REQ-003) exercise the git-diff collector alone
  against real, disposable fixture git repositories (never this
  repository's own history) — deterministic, no network call.
- TEST-026..TEST-036 (REQ-004) are the only cases that construct a Facet
  Manifest fixture (capability-active state) or deliberately test the
  `disabled-legacy`/hard-error boundary conditions; none of them requires
  Epic A4's actual schema file to exist — each fixture is a standalone
  JSON/YAML object shaped to match `facet-manifest.affected_components`'s
  documented field (design.md Data Plan), consistent with this feature's
  own scope boundary against redefining that schema. TEST-035/TEST-036
  additionally read (never write) `check-contract.{sh,ps1,py}`,
  `risk-gate-matrix.md`, `guard-invariants.json`, and
  `generate-guard-invariants.py` to construct their reachability/
  registration fixtures, and invoke `generate-guard-invariants.py --check`
  against a staged copy of the tree, never the live repository paths.
- TEST-037/TEST-041 (REQ-005) assume Epic A1's canonicalizer utility is
  available at the time these tests actually run; if it is not yet
  available when this feature's Phase 2 implementation begins, this is
  recorded as a blocker (requirements.md Dependencies), not a skipped or
  weakened test.
- TEST-036 and TEST-047's protected-registration proofs follow the same
  multi-part shape `specs/epic-159-pillar-c/acceptance-tests.md`'s
  TEST-027 established for a different protected file
  (`.github/workflows/test.yml`) — reused here for the
  `guard-invariants.json`/generator toolchain (TEST-036) and the CI step
  registration (TEST-047); TEST-035 additionally reuses the pattern for
  `check-contract`'s protected required-check-set (a family TEST-027
  itself did not need to cover).
- TEST-050/TEST-051 (REQ-009) are the only cases that invoke both a `.sh`
  and its `.ps1` twin from within a single test process to diff their
  output directly — every other suite's `.sh`/`.ps1` pair is still run
  independently (once per OS lane) as before; the parity harness is an
  additional, not a replacement, layer.
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
