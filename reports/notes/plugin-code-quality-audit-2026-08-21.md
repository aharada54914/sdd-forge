# Plugin Code Quality Audit — scattered validation & non-recursive deep loops (2026-08-21)

## Scope and method

Three sweeps over `plugins/*/scripts/` (135 scripts, ~39k lines; `tests/`
excluded):

1. Duplicated value-check/validation logic across Bash scripts.
2. Duplicated validation logic across Python and across PowerShell scripts
   (deliberate `.sh`↔`.ps1` cross-language twins excluded by design).
3. Deeply nested, non-recursive loops with complex exit conditions, and
   iteratively-written traversals that obscure a recursive structure.

Each finding was hand-verified with file:line evidence. This report records
what was **fixed in this change**, what was found and **deferred with a
reason**, and how the findings connect to the failure pattern the
2026-08-21 WFI why-why review identified ("two-surface contract drift with
no parity control" — see `docs/workflow-improvements/wfi-why-why-review-2026-08-21.md`).

## Fixed in this change

### 1. Task dependency-graph cycle detection unified as recursive DFS (twin-divergent algorithms)

`plugins/sdd-review-loop/scripts/task-review-precheck.sh` used a recursive
three-colour DFS whose visit state was a pair of parallel arrays scanned
linearly with an `echo`-in-subshell accessor (~O(n·e), a subshell per node
visit); `task-review-precheck.ps1` used a **different algorithm entirely**
(Kahn's queue-based topological count). Two implementations of the same
gate can disagree; only DFS can ever report the cycle path.

- `.sh`: visit state and adjacency now live in derived-name variables
  (`graph_visit_T_001`, `graph_adj_T_001` via `printf -v` + `${!var}`)
  — bash-3.2 compatible (the plugin tree deliberately avoids `declare -A`),
  O(1) lookups, no subshells; the unknown-task check now also runs in one
  pass. The DFS stays recursive; depth is bounded by the task count.
- `.ps1`: Kahn's algorithm replaced with the same recursive three-colour
  DFS (`Test-GraphHasCycleFrom`), so the twins now mirror each other
  structurally, not just in verdict.

Tests: `tests/downstream-review-precheck.tests.sh` (incl. the cycle
fixture), `tests/task-review-precheck.tests.sh` — pass. (`pwsh` is not
available in this environment; the `.ps1` side must be confirmed by the
next CI run's `tests/downstream-review-precheck.tests.ps1` /
`downstream-review-precheck-parity.tests.sh`.)

### 2. Panelist runner duplication collapsed into `lib/panelist-common.sh`

`run-panelist-gpt.sh` and `run-panelist-gemini.sh` each carried a
byte-identical 66-line `_sdd_run_bounded` (process-group watchdog with the
2-term grace-wait exit condition) — the gemini copy even said "See the GPT
twin for the rationale" — plus identical `SDD_PANELIST_TIMEOUT` validation
and required-arg guards. A timeout bug had to be fixed twice.

New `plugins/sdd-quality-loop/scripts/lib/panelist-common.sh` (sourced the
same way `sdd-hook-guard.sh` sources its generated invariants) now owns
`_sdd_run_bounded`, `sdd_panelist_validate_timeout`, and
`sdd_panelist_require_args`; both runners source it fail-closed. ~130
duplicated lines removed; the `<&0` stdin hazard and deadline rationale are
documented once, in the library.

Tests: `tests/collection-layer.tests.sh` (51), `tests/cross-model.tests.sh`
(70), `tests/run-panelist-effort.tests.sh` (28) — all pass.

### 3. Approval-sidecar draft-07 engine: three fail-open holes closed

`validate-approval-sidecar.py` carries its own standalone draft-07 subset
engine (independence from the generator is a recorded design rationale).
Unlike the shared-shape engines (`validate-facet-manifest.py` et al.), it
failed **open** in three ways:

1. `_schema_type_ok` ended `return True` — a typo'd or array-form `"type"`
   silently validated every instance. Now: union lists recurse, unknown
   names fail closed.
2. `pattern` used bare `re.match`, so Python's `$`-before-trailing-newline
   leniency admitted `"sha256:<64hex>\n"` against `^sha256:[0-9a-f]{64}$` —
   exactly the hole the schema's digest/hmac patterns exist to close, and
   exactly the bug the sibling engines document and fix (`_ecma_anchor`).
   Now: ECMA-262 `$`→`\Z` rewrite + draft-07 search semantics.
3. `additionalProperties` given as a schema (not a boolean) was silently
   ignored. Now enforced.

The engine remains standalone (no sibling import), per the file's recorded
independence rationale; the hardening is documented in its header.

Tests: `tests/validate-approval-sidecar.tests.sh` (50),
`tests/generate-approval-sidecar.tests.sh` (69),
`tests/project-context-schema.tests.sh` (44),
`tests/approver-registry-schema.tests.sh` (8),
`tests/plugin-contracts-track-selection.tests.sh` (106),
`tests/ship-track-selection-migration.tests.sh` (139) — all pass.

Note: `tests/apply-human-copy.tests.sh` shows 4 pre-existing failures in
this environment, all `[chmod000/*]` cases — the suite runs as root here
and root bypasses mode bits. Unrelated to this change (the script is
untouched); they will pass on a non-root runner.

## Found and deferred — needs a semantic decision (WFI candidates)

These are drifted duplicates where the two copies **disagree about
behaviour**; unifying them means deciding which behaviour is correct, which
is a gate-semantics decision, not a mechanical refactor. Each is an
instance of the WFI-038 "two surfaces must agree and nothing asserts it"
pattern and belongs in the retrospective→WFI pipeline:

1. **`require_persisted_pass` (~176 lines) duplicated between
   `impl-review-precheck.sh:93-268` and `task-review-precheck.sh:54-237`,
   with 3 substantive drifts** (mirrored in the `.ps1` twins):
   - `assert_contract_reviewer_agreement` exists only in the impl copy
     (`impl-review-precheck.sh:254`), though the incident it guards
     (contract hash recorded that neither reviewer saw,
     epic-136-phase4-docs attempt 2 round 2) applies to both.
   - The `$stage == "task"` allowed-manifest-path list differs
     (impl copy: `tasks.md`,`traceability.md`; task copy adds `design.md`
     and the four layer specs) — the same predicate, two allowlists.
   - Layer-input manifest verification exists only in the task copy
     (`task-review-precheck.sh:205-210`).
   Proposed shape: extract to
   `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh` (+ a
   `.ps1` counterpart), with each drift resolved deliberately.
2. **Approval-line grammar split**: `check-task-state.sh:87` accepts
   `Approved (<anything>)` while `check-task-state-lite.sh:58` requires
   `Approved (<id> <ISO8601>)`; the strict regex also lives inside the full
   gate's `approver_id()`. One field, two grammars. The shared
   `Status:` lifecycle enum is duplicated in 4+ places
   (`check-task-state.sh:93`, `check-task-state-lite.sh:63`,
   `check-workflow-state.sh:857-874`, `check-workflow-state.ps1:1069`).
3. **Gate-report task-identity predicate divergence**:
   `emit-run-record.sh:129` greps `Task: <tid>` (unanchored, unescaped,
   GNU-only `\b`) while `check-quality-gate-cycle-limit.sh:96-97` matches
   the three anchored forms incl. `Task ID:` measured against all 220
   committed reports. The emitter under-counts 219/220 reports — the same
   wrong-predicate class WFI-035 fixed in the cycle-limit counter. This is
   a `measurement` / Meta-Change fix (run-record definitions) and should go
   through a WFI with its own verification metric.
4. **Signing-key resolution drift (PowerShell)**:
   `prepare-panelist-input.ps1:186-200` falls back to `~/.sdd/sudo-key`
   when `SDD_SUDO_KEY_FILE` points at a missing file — silent key
   substitution where `sdd-hook-guard.ps1:392-424` fails closed with
   `$null`. Four `.ps1` copies, three behaviours; needs one dot-sourced
   helper and one decided semantic (fail-closed).
5. **Repo-path validator drift**: `prepare-task-snapshot.{sh,ps1}` vs
   `validate-task-input-manifest.{sh,ps1}` disagree on trailing slashes —
   `"src/"` passes validation and then fails snapshot preparation.
6. **SHA-256 shape validation**: three incompatible dialects
   (case-insensitive `-match`, `-cnotmatch`, `[0-9a-fA-F]`) across ~20
   sites; `sha256()` shell helpers in 8 files with 5 error behaviours —
   the majority silently produce an empty hash when both `sha256sum` and
   `shasum` are absent (empty == empty passes); only
   `validate-review-context-set.sh:31-35` and `apply-human-copy.sh:205-230`
   fail closed. Propagate the fail-closed shape; pick lowercase-only.
7. **Python-dispatch wrappers**: 14 `.sh` wrappers in 4 dialects (missing
   runtime → exit 3, 1, or 127 — four have no guard at all) and 14 `.ps1`
   wrappers in 3 variants whose byte-exactness rationales contradict each
   other (`canonicalize-sdd-yaml.ps1:14-24` vs `validate-facet-manifest.ps1:4-8`).
   Consolidation should follow the generated-file precedent
   (`generate-guard-invariants.py`) or one sourced dispatcher; exit-code
   unification will require updating the tests that pin codes.

## Found and deferred — blocked on a recorded design constraint

The draft-07 engine is triplicated verbatim (~205 lines × 3) across
`validate-facet-manifest.py:169-373`, `validate-capability-summary.py:182-386`,
`validate-context-projection.py:137-343`, and the discovery/git-root
resolution is quadruplicated — but `validate-capability-summary.py:20-27`
records a design.md decision: "four standalone validator scripts, none of
which import from a sibling script". That claim is already false in
practice (`compare-facet-manifest-staleness.py:311-338` imports
validate-facet-manifest via importlib, citing `check-component-coverage.py`
as the same-directory-import precedent; `validate-capability-registry.py:27-28`
imports `registry_discovery`). Resolving the contradiction — either amend
design.md and consolidate into `schema_engine.py`, or keep the copies and
add an executable identity/parity check — is a human design decision.
A fifth, weaker engine variant in `resolve-component-paths.py:715-734`
(unknown type names fail open there too) has a `.ps1` twin bound by parity
tests, so its fix must land in both and be verified where `pwsh` runs.

## Loop audit — verdicts

The tree is largely disciplined about recursion already:
`canonicalize-sdd-yaml.py`, `resolve-component-paths.py/.ps1` and
`validate-domain-contract.sh`'s embedded Python are proper recursive-descent
parsers with depth governors, and `validate-domain-contract.ps1`'s
explicit-stack JSON scanner is deliberately iterative (documented
stack-exhaustion rationale) — none of these should be "fixed". Remaining
genuine findings, in value order:

1. **Fixed here**: `task-review-precheck` cycle detection (above).
2. `apply-human-copy.sh:1082-1227` — 4-deep hand-nested awk JSON parser
   with a 6-term exit condition and 3-global return channel; the `.ps1`
   twin just uses `ConvertFrom-Json`, a structural JSON-acceptance
   divergence in the crash-recovery path. Either delete the parser in
   favour of `python3 -c 'import json…'` (verify the recovery path may
   depend on python3 first) or decompose into named awk helpers with the
   file's established extra-parameter local idiom. POSIX-awk portability
   and the no-subshell `recover_all` constraint (`:1234-1240`) must hold.
3. `apply-human-copy.sh:1233-1394` `recover_all` (+ `.ps1:816-905`) — three
   ~85%-identical passes, a 3-state machine encoded in two booleans, and
   `rm -f "$targets_tmp"` repeated 11 times. Decompose into
   `classify_batch` / `revert_mixed_batch` / `confirm_all_at_pre` /
   `probe_or_die`; classification must not be `$(...)`-captured (die/exit
   semantics), and the `< file` redirection (not `cmd | while`) must stay.
4. `check-component-coverage.ps1:207-243` / `resolve-component-paths.py:1155-1180`
   / `.ps1:1238-1250` — Fail-6 4-way cartesian loop with `catch { continue }`
   silently swallowing malformed adapter-path patterns in all three copies,
   plus per-iteration re-normalization. Hoist pattern validation once per
   binding and surface a warning for unusable patterns.
5. `check-workflow-state.ps1:193-230` — 4-deep root-derivation with two
   early returns buried three levels in; extract `Get-CandidateRootsForPath`
   (beware PowerShell collection-unrolling on return: `,$set`).
6. `design-sync-scan.{sh,ps1}` — six copy-pasted depth-3 scan blocks;
   table-driven rules collapse them (the `.sh` side must keep writing to a
   temp file: `grep | while` subshell, documented at `:127`).

## Suggested follow-up order

1. WFI for the `require_persisted_pass` extraction + drift resolution
   (correctness: the missing reviewer-agreement assertion is a documented
   incident class).
2. WFI (`measurement`, Meta-Change) for the `emit-run-record.sh` task
   predicate — aligns with the WFI review's follow-up #1 (deterministic
   authored-report/identity enforcement).
3. Fail-closed sweep: sha256 helpers + key-resolution `.ps1` copies.
4. design.md decision on the standalone-validator clause; then either
   `schema_engine.py` consolidation or an executable parity check.
5. `apply-human-copy` recover_all/awk decomposition (both twins together).
6. Python-dispatch wrapper unification (with test exit-code updates).
