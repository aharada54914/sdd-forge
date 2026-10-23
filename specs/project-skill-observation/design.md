# Design: Project skill execution methods and verification observations (#594)

Impl-Review-Status: Pending

DRAFT. Normative decision record: `docs/adr/0040-project-skill-observation-ownership.md`
(Proposed). Grounding ids G-n refer to requirements.md. Revised 2026-10-22 after
an informal content review (`/workspace/issue594-content-review.md`, findings
1–5); not a formal review.

## Technical Summary

Two new strict, versioned JSON contracts and one **passive** validator. A
project skill is a directory `sdd/skills/<name>/` whose manifest names the check
ids it can run, a runtime, a closure entrypoint and every file it contains. A
runner that executes it writes an observation bound to the run, the supplied
task input manifest, the skill bytes and the admitted inputs plus produced outputs in the execution
root. The validator checks
identity and consistency only: it never executes anything and cannot prove
what a run actually loaded or that a run was approved. Results and verdicts stay
with the existing evaluator. Nothing existing is modified in #594.

## Ownership (REQ-001)

| Concern | Owner | Mechanism (existing unless marked new) |
|---|---|---|
| Protected required set | `check-contract.py` tiers, capability Registry gates, approved contract `required: true` | G-2; unchanged |
| Task/run admission, immutable snapshot, output-root check, execution-root composition (#596) | existing implement-tasks orchestration (`plugins/sdd-implementation/skills/implement-tasks/SKILL.md:223-244`) and `validate-task-input-manifest.{sh,ps1}` | G-5; unchanged, upstream precondition |
| Execution method | Project, in `sdd/skills/<name>/` | new `project-skill-manifest/v1` |
| Execution and dynamic-access enforcement | future runner (#595 trial, #596 task) | not in #594 |
| Runner observation | the runner that executed the command | new `project-verification-observation/v1` |
| Identity/consistency validity | `sdd-quality-loop` | new `validate-project-skill` |
| Result + final verdict | `evaluate-selected-plan.py` / `quality-gate` | G-1, G-3; unchanged |

Contracts live in `contracts/` and are vendored byte-identically into
`plugins/sdd-quality-loop/contracts/` (packaged-first lookup, G-6). No new
plugin, no MCP tool, no new status/approval field.

## Contracts

All objects `additionalProperties: false`; all listed keys required unless the
row says otherwise.

### `project-skill-manifest/v1` — `sdd/skills/<name>/skill-manifest.json`

| Field | Type / rule | Semantics |
|---|---|---|
| `schema` | const `project-skill-manifest/v1` | version |
| `name` | `^[a-z0-9][a-z0-9-]{0,62}$`, equals directory name | identity |
| `checks` | array ≥1, unique, items `^[a-z0-9][a-z0-9-]*$` | check ids this skill can execute; confers no obligation |
| `runtime` | `^[a-z][a-z0-9.+-]*$` (bare program name, no path separator) | trusted toolchain program resolved by the runner from PATH (e.g. `python3`, `bash`, `node`, `pwsh`) |
| `entry` | non-empty string; semantically a member of `files[].path` | project entrypoint in the closure |
| `args` | array of strings, each `^[A-Za-z0-9=:,._+-]*$` and not containing `..` | literal trailing arguments; no paths, no shell text |
| `requires` | array, unique, items `^[A-Za-z0-9._-]+$` | other programs the runner must find; any absent ⇒ `unavailable` |
| `files` | array ≥1, sorted by `path`, unique `path` | closure |
| `files[].path` | non-empty string; semantic path grammar below | file in skill dir, may be nested |
| `files[].sha256` | `^[0-9a-f]{64}$` | sha256 of raw bytes |

Executed argv is always exactly
`[runtime, "sdd/skills/<name>/" + entry, *args]` with working directory = the
execution root (§Execution root and handoff). There is no free-form argv, so
`sh -c …` or an outside helper operand cannot be expressed. The validator binds
the entrypoint to the closure; it cannot prove which further files the
entrypoint reads or executes at run time. Keeping helpers inside the closure
and enforcing that at run time is the runner's responsibility (#595/#596),
stated as a limit, not a #594 guarantee.

Path grammar (semantic, so violations report `closure-escape`, not
`manifest-invalid`): POSIX relative, segments non-empty and not `.`/`..`, no
leading `/`, no `\`, no NUL.

Closure rule: ordinary directories may nest. The set of `files[].path` equals
the set of regular files anywhere under the skill directory excluding
`skill-manifest.json`; any symlink (file or directory, including the skill
directory itself) or special entry (FIFO, socket, device) is rejected.
`skill_manifest_sha256` = sha256 of the manifest's raw bytes, so it pins the
whole closure.

### `project-verification-observation/v1`

Stored only at the per-run evidence path below (§Evidence output); the
subtree `reports/project-skill-observations/` is evidence-only (G-10).

| Field | Type / rule | Semantics |
|---|---|---|
| `schema` | const `project-verification-observation/v1` | version |
| `mode` | `task` \| `trial` | `trial` = no task/run (REQ-010) |
| `skill` | manifest name pattern | executed skill |
| `check_id` | ∈ manifest `checks` | target check this observation answers |
| `skill_manifest_sha256` | 64 hex | raw manifest bytes at execution |
| `task_id` | `^T-[0-9]{3}$` | `task` mode only (same pattern as `contracts/task-input-manifest.schema.json:29-31`) |
| `run_id` | non-empty string | `task` mode only; equals task input manifest `run_id` |
| `task_input_manifest_sha256` | 64 hex | `task` mode only; raw bytes of the supplied manifest |
| `source.commit` | `^[0-9a-f]{40}$` or `null` | runner's provenance claim (the commit the admitted inputs were taken from, if any); never compared, never approval or provenance proof |
| `source.tree_sha256` | 64 hex | source-set digest, below |
| `environment.os` | `linux` \| `darwin` \| `windows` | runner context, unverified |
| `environment.host` | non-empty string | runner context, unverified |
| `environment.runtime_path` | non-empty string or `null` | runner claim (unverified) of the absolute path the runtime resolved to. Required non-null when `outcome` ∈ {passed, failed}, and when `outcome` = `unavailable` with `runtime` ∉ `missing`. Must be `null` when `runtime` ∈ `missing` or `outcome` = `not-run` |
| `environment.missing` | array ⊆ manifest `requires` ∪ {`runtime`}, unique | non-empty iff `outcome` = `unavailable` |
| `outcome` | `passed` \| `failed` \| `unavailable` \| `not-run` | runner observation |
| `started_at`, `finished_at` | `YYYY-MM-DDTHH:MM:SSZ`, start ≤ finish | present iff outcome ∈ {passed, failed} |
| `exit_code` | integer | present iff outcome ∈ {passed, failed}; `passed` ⇔ `exit_code == 0` |

The argv is derived from the manifest, not stored. No captured-output field:
the issue requires run/check/source correspondence, not log attestation;
runner claims stay unverified and quality-gate re-execution is unchanged.

## Execution root and handoff (REQ-006, REQ-007)

#594 adds no runner, no Git executor and no wider snapshot access. It fixes the
contract the existing orchestration hands to the validator:

- **Who materializes inputs.** The existing implement-tasks orchestrator
  builds the immutable, read-only snapshot. That snapshot contains exactly the
  `allowed_inputs` bytes, which are verified against their pins
  (`prepare-task-snapshot.sh:168-229`, `implement-tasks/SKILL.md:223-244`). The
  worker receives only that snapshot, the manifest and its declared output
  roots (`SKILL.md:239-244`, `:280-283`). #596 composes the **execution root**:
  a directory holding the snapshot inputs and the run's output roots at their
  repository-relative paths. It is not the parent repository and not a Git
  work tree. The snapshot itself stays read-only and unchanged.
- **Who executes and observes.** The runner (#595 trial, #596 task) executes
  in the execution root and computes `source.tree_sha256` there. It writes the
  observation to the per-run evidence path.
- **Where the validator reads.** The validator reads only under
  `--execution-root`, and only these paths:
  - `sdd/skills/` discovery;
  - `allowed_inputs` paths;
  - regular files under `allowed_outputs` entries;
  - the observation.

  Nothing else in the parent repository is read.
- **When validation and publication happen.**
  1. The worker validates after execution and before return.
  2. Step 13 of the existing workflow checks that every produced file is
     inside `allowed_outputs` (`SKILL.md:300-302`). This is publication to the
     repository.
  3. Any later consumer (quality-gate, #596) re-validates against the
     published tree. There, a changed input or output fails closed.

### Task-mode source set and digest

- **Records.** One record per `allowed_inputs` path. The file must exist and
  rehash to its pinned sha256, regardless of Git ignore status or location;
  otherwise `input-unbound`. Add one record per regular file currently present
  under any `allowed_outputs` entry (file or directory form), except files
  under the run's evidence directory.
- **Digest.** sha256 over the bytewise-sorted records
  `<path> NUL <sha256> LF`.
  - Absent paths produce no record. Membership is the files actually present,
    so there are no tombstones and no index dependence.
  - A symlink or special entry under an output root is `source-mismatch`.
  - Git is not used.
- **Stale.** A digest different from `source.tree_sha256` is
  `source-mismatch`. Each of these changes the digest:
  - an output file added, deleted or changed after the observation;
  - an input changed after the observation (which is also caught first by the
    pin rehash).
- **Not bound.** Files that are neither admitted inputs nor under output roots
  are not in the binding, for example unrelated dependency caches. This is a
  stated limit: they are runtime environment and remain unverified. An
  explicit input is never treated as such a cache.

### Evidence output

- **Path.** The observation path is exactly
  `reports/project-skill-observations/<task_id>/<run_id>/<check_id>.json`
  (task mode) or `reports/project-skill-observations/trial/<skill>/<check_id>.json`
  (trial). `<task_id>/<run_id>/` is the run's evidence directory.
- **Admission.** In task mode, an `allowed_outputs` entry must cover the
  observation path, using the existing directory semantics
  (`validate-task-input-manifest.sh:84-97`). That entry is declared before
  launch, so the destination is admitted per run. No new field or approval is
  involved. An uncovered destination is `input-unbound`.
- **Evidence-only.** Any `allowed_inputs` path under
  `reports/project-skill-observations/` is `input-unbound`. Evidence can never
  be executable or source input.
- **Task evidence is immutable.** Membership in the subtree does not authorise
  writes. Existing task evidence is never overwritten: a new task run uses a
  new `run_id` directory.
- **Trial observations are mutable.** A repeated local trial may replace only
  its own `trial/<skill>/<check_id>.json` observation with the new result. Trial
  observations remain inadmissible for task gates; this replacement permission
  does not extend to task evidence or any other path.

## Task mode binding (REQ-006)

Admission is upstream. The caller must supply a task input manifest that the
existing workflow admitted for the current run: built and validated by
`validate-task-input-manifest.{sh,ps1}`, including batch mode over the persisted
set (`implement-tasks/SKILL.md:223-244`). That validator already rejects:

- duplicate input paths (`validate-task-input-manifest.sh:257-266`);
- input/output overlap (`:290-298`);
- fallback evidence defects (`:278-288`).

#594 does not re-implement admission, and a schema-valid manifest is not proof
of human approval. VALID in task mode means only "consistent with these
manifest bytes". To keep its own lookups unambiguous, the validator also
rejects the following, each as `input-unbound`:

- a supplied manifest that fails `contracts/task-input-manifest.schema.json`;
- a path that appears more than once in `allowed_inputs`;
- an `allowed_inputs` path equal to or under an `allowed_outputs` entry;
- an `allowed_inputs` path under the evidence subtree;
- an observation destination that no `allowed_outputs` entry covers;
- any admitted input missing, or not matching its pin.

It then requires:

- the manifest bytes to match `task_input_manifest_sha256`;
- `task_id` and `run_id` to match;
- `sdd/skills/<name>/skill-manifest.json` and every closure path to each appear
  exactly once in `allowed_inputs`.

In task mode, discovery and collision checks consider only skill manifests
listed in `allowed_inputs`.

## Trial mode (REQ-010)

Trial mode has no task manifest, task id, run id or Project Context, and the
skill may be new and untracked. The execution root is the author's working
directory. Git is not required.

The source set is the skill closure only. Trial mode binds no project source,
which is a stated limit, and trial results are never admissible as evidence.

Validity requires:
- discovery over `sdd/skills/` in the execution root;
- the closure and digest checks;
- the trial evidence path;
- a digest equal to the closure digest.

The only valid states are `trial-*`, and they are never projected.

## Discovery and collision (REQ-004)

1. Adopter test is physical presence of `<execution-root>/sdd/skills/` (G-7 style).
   Absent ⇒ non-adopter; no existing path calls the validator.
2. Entries of `sdd/skills/` are sorted bytewise by name. Each must be a real
   directory (not a symlink) containing `skill-manifest.json`.
3. Each manifest is schema-validated, and `name` must equal its directory name.
4. A check id that appears in two manifests produces `check-collision`. The
   whole discovery is invalid, and there is no precedence rule. Same-name
   collisions cannot exist on one case-sensitive file system. Host projections
   (#602) are not scanned.

## Validator (REQ-012)

`plugins/sdd-quality-loop/scripts/validate-project-skill.py` with argument-
transparent `.sh` / `.ps1` wrappers (existing trio convention, e.g.
`validate-facet-manifest.{py,sh,ps1}`). It reuses G-6 helpers. The existing
schema helper does not implement `allOf` (G-6 note), so mode- and
outcome-conditional rules are coded checks reported as `observation-invalid`.
argparse rejects unknown flags.

```
validate-project-skill --execution-root DIR --skill NAME
                       [--observation FILE [--task-input-manifest FILE]]
```

- **Success:** exit 0. stdout is exactly `project-skill: VALID <name> <state>`, where `<state>` is one of:
  - `manifest-only`
  - `passed`, `failed`, `unavailable`, `not-run`
  - `trial-passed`, `trial-failed`, `trial-unavailable`, `trial-not-run`
- **Contract failure:** exit 1. stderr is exactly `project-skill: INVALID: <code>` and stdout is empty. The first failing code in the table order is reported.
- **Usage error:** exit 2 (argparse). This covers a missing or unknown flag, and `--task-input-manifest` without `--observation`.

| # | Code | Condition |
|---|---|---|
| 1 | `manifest-missing` | `sdd/skills/<name>/skill-manifest.json` absent, or a discovered entry lacks one |
| 2 | `manifest-invalid` | unreadable/non-JSON/schema failure, incl. unknown field such as `required`, bad `runtime`/`args` pattern |
| 3 | `name-mismatch` | `name` ≠ directory name |
| 4 | `check-collision` | a check id offered by two discovered skills |
| 5 | `closure-escape` | path-grammar violation, symlink or special entry, or `entry` not a listed file |
| 6 | `closure-missing` | listed file absent |
| 7 | `closure-incomplete` | regular file present but not listed |
| 8 | `digest-mismatch` | file bytes ≠ listed sha256 |
| 9 | `observation-invalid` | schema failure, unknown field, mode/outcome field inconsistency, `missing`/`runtime_path` rule, or observation not at its exact evidence path |
| 10 | `skill-mismatch` | `skill` ≠ `--skill`, or `check_id` ∉ `checks` |
| 11 | `manifest-digest-mismatch` | `skill_manifest_sha256` ≠ current manifest bytes |
| 12 | `input-required` | `task` mode without `--task-input-manifest`, or `trial` mode with it |
| 13 | `input-unbound` | any Task-mode binding failure above |
| 14 | `run-mismatch` | `task_id`/`run_id` ≠ manifest |
| 15 | `source-mismatch` | `tree_sha256` ≠ recomputed (stale), or symlink/special entry under an output root |

## Projection onto the existing evaluator (normative for #596)

#594 does not change the evaluator or the verification-contract schema. The
projection only rewrites the **execution fields** of a check that already
exists in the approved verification contract. The execution fields are
`command`, `started_at`, `finished_at`, `exit_code`, `passes` and `evidence`.

The projection never adds a check and never touches `id`, `required`,
`waiver_reason` or any other key, so obligations, waivers and all evaluator
precedence are preserved. A check id absent from the contract receives
nothing.

| Validator state | Execution fields written |
|---|---|
| `passed` / `failed` | `command` (compact JSON text of the derived argv), `started_at`, `finished_at`, `exit_code`, `passes` (= outcome is `passed`), `evidence` (observation path) |
| every other state: `unavailable`, `not-run`, `manifest-only`, any `trial-*`, any `INVALID`, skill missing | all six removed, including any stale values from an earlier projection; the reason for invalidity is kept only in validator output |

There is one fallback rule: remove all execution fields. The evaluator then
applies its unchanged order (`evaluate-selected-plan.py:140-163`):

1. A tier-required id without `required: true` gives `unknown` /
   `migration-pending-required`, whatever the execution fields say.
2. An unselected, unregistered `required: false` check gives `not-applicable` /
   `legacy-optional-not-selected`, even with execution fields present.
3. A selected Registry gate whose verifier file is missing gives `unavailable` /
   `verifier-missing`.
4. Missing execution fields give `not-run` / `not-executed`.
5. Otherwise the result is `passed` or `failed`.
6. For legacy-required ids, `unavailable`, `not-run` and `unknown` reasons are
   overwritten to `migration-pending-required`.

A required check is therefore PASS only from a valid `passed` projection and
the existing branches. An invalid or trial observation can never leave a
previous `passes: true` behind.

## Alternatives considered

- **Add fields to `verification-contract` or the plan schema.** Rejected: this
  breaks strict schemas and non-adopter bytes (REQ-011).
- **Let the evaluator or validator run skills.** Rejected: this contradicts G-1
  and the executor boundary.
- **Free argv, sandbox or shell parser.** Rejected: unneeded. Fixed argv shape
  plus a stated runner responsibility is sufficient for #594.
- **Hash Git diff output or Git membership.** Rejected: it depends on Git
  configuration or index state, and the immutable snapshot is not a Git tree
  (content-review finding 1, recheck findings 2–3).

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | CLI output lines only | ux-spec.md | sdd-quality-loop | Draft |
| Frontend | none | frontend-spec.md | — | Draft |
| Infra | files, catalog, platforms | infra-spec.md | sdd-quality-loop | Draft |
| Security | trust boundary, tampering | security-spec.md | sdd-quality-loop | Draft |

## Shared-state re-verification

- **ADR number.** 0040 was chosen because concurrent draft PR #631 (#614)
  uses 0039. At integration and in every review round, re-run `ls docs/adr/`,
  check the ADR README index and confirm who owns 0039 and 0040. If a number
  is taken, renumber only this feature's files.
- **Other shared-state claims.** Re-run G-8, G-9 and G-10.
