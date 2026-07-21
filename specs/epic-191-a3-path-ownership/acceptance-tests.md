# Acceptance Tests: epic-191-a3-path-ownership

TEST IDs (TEST-001..TEST-028) are namespaced to this feature
(`specs/epic-191-a3-path-ownership/`) and map 1:1 to AC-001..AC-028 in
requirements.md. All TEST IDs are `Status: Planned` — this feature's Phase
2 task decomposition (`tasks.md`, deferred per investigation.md INV-012)
has not yet been authored, so no task owns any TEST ID yet; that mapping
is `traceability.md`'s job once Phase 2 exists.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | glob semantics | `tests/component-path-resolver.tests.sh`/`.ps1`: `**` matches zero-or-more segments including crossing `/` | Planned |
| AC-002 | REQ-001 | TEST-002 | glob semantics | same suite: bare `*` matches within one segment only, never crosses `/` | Planned |
| AC-003 | REQ-001 | TEST-003 | normalization | same suite: `\`-separated pattern normalizes to `/` and matches its `/`-separated equivalent | Planned |
| AC-004 | REQ-001 | TEST-004 | normalization | same suite: NFD-encoded fixture path matches an NFC-encoded pattern after normalization | Planned |
| AC-005 | REQ-001 | TEST-005 | case sensitivity | same suite: a case-differing fixture path never matches, on every OS this suite runs on | Planned |
| AC-006 | REQ-002 | TEST-006 | classification | same suite: single-component `(include − exclude)` match → EXCLUSIVE | Planned |
| AC-007 | REQ-002 | TEST-007 | invariant (negative) | same suite: a path in component C's own `exclude`, also matching a C `include` pattern, is never classified EXCLUSIVE to C (Fail-5 invariant) | Planned |
| AC-008 | REQ-002 | TEST-008 | classification | same suite: zero-component match, no `shared_paths` match → UNOWNED (Fail-1) | Planned |
| AC-009 | REQ-002 | TEST-009 | classification | same suite: two-or-more-component match, no `shared_paths` match → OVERLAP (Fail-3) | Planned |
| AC-010 | REQ-002 | TEST-010 | precedence | same suite: a `shared_paths` match exempts a path from OVERLAP/UNOWNED regardless of component-include count | Planned |
| AC-011 | REQ-002 | TEST-011 | config-shape (negative) | same suite: a `shared_paths` entry with both `components` and `classification: cross-cutting`, or neither, is rejected fail-closed at load time | Planned |
| AC-012 | REQ-003 | TEST-012 | git-diff basis | `tests/component-path-diff-basis.tests.sh`/`.ps1`: baseline = `git merge-base <feature-branch> main`; an unrelated-histories fixture produces a fail-closed diagnostic, never an empty diff | Planned |
| AC-013 | REQ-003 | TEST-013 | git-diff basis | same suite: staged + unstaged + untracked are each counted exactly once, collected via git porcelain commands only (no raw filesystem walk) | Planned |
| AC-014 | REQ-003 | TEST-014 | rename-follow | same suite: both old and new path of a rename are independently classified; a cross-component rename is reported as a distinct case | Planned |
| AC-015 | REQ-003 | TEST-015 | reference-only boundary | same suite: a submodule (gitlink) entry and a symlink entry are each evaluated only for their own reference/pointer text, never expanded into referenced content | Planned |
| AC-016 | REQ-004 | TEST-016 | gate registration | `tests/check-component-coverage.tests.sh`/`.ps1`: runs as a `stage: implementation` check; a fully-declared, non-overlapping, fully-owned diff fixture passes cleanly in full mode | Planned |
| AC-017 | REQ-004 | TEST-017 | fail-condition coverage (6-way) | same suite: one dedicated fixture per Fail-1..Fail-6 deterministically triggers that condition in full mode (Fail-6's fixture includes a `sdd/provider-bindings.yaml`) | Planned |
| AC-018 | REQ-004 | TEST-018 | degraded-mode behavior | same suite: with no Facet Manifest supplied, Fail-1/3/5(/6 when applicable) still enforce, and Fail-2/4 are recorded as an explicit WARN, never a silent PASS | Planned |
| AC-019 | REQ-004 | TEST-019 | conditional N/A | same suite: with no `sdd/provider-bindings.yaml` present, Fail-6 is recorded N/A with a WARN, never silently omitted without a trace | Planned |
| AC-020 | REQ-004 | TEST-020 | protected-registration (3-part) | same suite: (a) staged candidates exist under `specs/epic-191-a3-path-ownership/human-copy/` with correct `MANIFEST.sha256` entries for `guard-invariants.json` + the four `generated/*` files; (b) the live files are byte-identical before/after this feature's own commits; (c) a post-human-copy self-registration grep confirms the three `check-component-coverage.*` entries are present | Planned |
| AC-021 | REQ-005 | TEST-021 | digest scope | `tests/ownership-digest.tests.sh`/`.ps1`: `ownership_digest` is computed only over the components'/`shared_paths` entries actually consumed for a given resolve, via Epic A1's canonicalizer; the task records a documented blocker if that canonicalizer does not exist at implementation time | Planned |
| AC-022 | REQ-005 | TEST-022 | staleness exclusion | same suite: `ownership_digest` populates `context_binding` per ADR-0021; a fixture where only `ownership_digest` changes (no resolved-component-set change) does not mark the Feature stale | Planned |
| AC-023 | REQ-006 | TEST-023 | document conformance | grep-based check: `plugins/sdd-quality-loop/references/default-shared-paths.md` lists at least `specs/**`, `reports/**`, `docs/adr/**`, `CHANGELOG.md`, `.github/**`, `tests/fixtures/**`, `contracts/**` | Planned |
| AC-024 | REQ-006 | TEST-024 | no-op proof | `tests/component-path-resolver.tests.sh`/`.ps1` (shared fixture): a diff confined to the default cross-cutting entries, with zero components declared to own them, never triggers Fail-1 | Planned |
| AC-025 | REQ-007 | TEST-025 | fixture shape | structural check over `tests/fixtures/component-path-ownership/`: at least two components with overlapping candidate owned paths, a nested excluded subtree, and a bounded `shared_paths` entry | Planned |
| AC-026 | REQ-007 | TEST-026 | suite registration + 6-case coverage | `tests/run-all.sh`/`.ps1` registration grep; `.github/workflows/test.yml` 3-part human-copy proof (mirrors AC-020's shape, scoped to the three new suites' own CI steps); each of overlap/unowned/rename/untracked/exclude-misuse/shared-undeclared has ≥1 positive case and ≥1 red/failing-then-fixed case across the three suites | Planned |
| AC-027 | REQ-008 | TEST-027 | document conformance | grep-based check: each Phase-2 task's own `CHANGELOG.md` `## Unreleased` entry cites #191; `docs/adr/00NN-component-path-ownership-resolver-semantics.md` exists and documents glob semantics, precedence, and the six Fail-condition definitions | Planned |
| AC-028 | REQ-008 | TEST-028 | version-bump conformance | grep-based self-check: no version string mutated anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation | Planned |

Notes:

- TEST-001..TEST-015 (REQ-001, REQ-002, REQ-003) are fully deterministic,
  fixture-driven, and require no LLM invocation, no network call, and no
  `gh` invocation — they exercise `resolve-component-paths` alone, with no
  Gate, Facet Manifest, or Provider Bindings dependency.
- TEST-016..TEST-020 (REQ-004) are the only cases that construct a Facet
  Manifest fixture (full mode) or deliberately omit one (degraded mode,
  TEST-018); none of them requires Epic A4's actual schema file to exist —
  each fixture is a standalone JSON/YAML object shaped to match
  `facet-manifest.affected_components`'s documented field (design.md Data
  Plan), consistent with this feature's own scope boundary against
  redefining that schema.
- TEST-021/TEST-022 (REQ-005) assume Epic A1's canonicalizer utility is
  available at the time these tests actually run; if it is not yet
  available when this feature's Phase 2 implementation begins, this is
  recorded as a blocker (requirements.md Dependencies), not a skipped or
  weakened test.
- TEST-020 and TEST-026's protected-registration proofs follow the same
  three-part shape `specs/epic-159-pillar-c/acceptance-tests.md`'s TEST-027
  established for a different protected file (`.github/workflows/test.yml`)
  — reused here for both the `guard-invariants.json` toolchain (TEST-020)
  and the CI step registration (TEST-026).
- No test in this feature writes a real repository path outside its own
  new/edited files, invokes `gh`, invokes `sdd-sudo`, or emits an approval
  string; every protected-path input (`guard-invariants.json` and its
  generated siblings, `.github/workflows/test.yml`) is read-only to every
  test, and a write target only via the `human-copy/` staging area.
- This is script/gate/test-infrastructure and reference-documentation work
  with no GUI entry point; the UI integration checklist and the four
  layer-spec files (`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/
  `security-spec.md`) are not applicable and are not authored for this
  feature (investigation.md INV-013; design.md Layer Specifications).
