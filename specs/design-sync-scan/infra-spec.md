# Infrastructure Specification: design-sync-scan

## Deployment Topology

**Nothing is deployed.** No service, container, IaC resource, region, endpoint, or environment is created or changed. There is no `## Scaling Strategy`, `## Service Level Objectives`, `## Data Residency and Retention`, `## Observability`, or `## Cost Estimate` content to write.

The changed artifacts and how they reach a consumer:

| Artifact | Consumed by | Distribution |
|---|---|---|
| `plugins/sdd-bootstrap/scripts/design-sync-scan.sh` | `design-sync-loop/SKILL.md` step 5, and any operator/agent running it standalone (REQ-008) | shipped inside the plugin; no build step |
| `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1` | same, on hosts running PowerShell | same |
| `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` | the `design-sync-loop` skill | same — **not protected**, unlike `design-sync-consent`'s `lite-spec/SKILL.md` target |
| `claude-design-workflow.md` (or its referring section) | operators on a host without `DesignSync` | repository-only |
| test suites | `tests/run-all.{sh,ps1}` locally; CI registration is a separate staged patch | repository-only |

No environment variable, no setting, and no file the runtime reads is introduced by this feature — the scanner's only input is its positional argument and the filesystem under it. `ds_upload_consent` (`design-sync-consent`'s sibling issue #140) remains out of scope and untouched.

**No egress dependency exists.** Unlike `design-sync-consent`, which reaches claude.ai/design through the `DesignSync` tool, this feature performs no network call, contacts no external service, and requires no credential. It is a local, read-only filesystem scan. This is the basis for REQ-008: nothing about the scanner depends on which host or tool ecosystem invokes it.

## CI/CD Sequence

### No protected-file staging round — a materially simpler shape than `design-sync-consent`

`design-sync-loop/SKILL.md`, `claude-design-workflow.md` (or its referring section), and `tests/run-all.{sh,ps1}` are all confirmed absent from `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, read in full at authoring time) and from `PHASE2_HUMAN_COPY_TARGETS` (`:18`). Every live edit this feature makes is therefore agent-applicable directly, with no `human-copy/` staging round anywhere in this decomposition — unlike `design-sync-consent`, which carried one certain round for `plugins/sdd-lite/skills/lite-spec/SKILL.md`.

**Re-verification instruction (AGENTS.md "Author-time sweeps", item 3).** Protected-file membership is repository-wide, git-tracked, shared state this branch does not own. Re-derive this claim — not from this document — at spec-review time and again at implementation start, by reading `guard_invariants.py:4` and `:18` and testing each of `design-sync-loop/SKILL.md`, the manual-fallback reference file, and `tests/run-all.{sh,ps1}` with `endswith()` on its repository-relative path.

### One protected target remains: CI registration of the new suite

`.github/workflows/test.yml` is a member of both `PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS`. Registering `tests/design-sync-scan.tests.{sh,ps1}` there cannot be done by an agent. Following the precedent `design-sync-consent` established at R-OQ-8 for its own suite:

1. The new suite is authored directly (unprotected files).
2. It is registered in `tests/run-all.sh` and `tests/run-all.ps1` (also unprotected — agent-applicable).
3. CI registration in `.github/workflows/test.yml` is a **separate staged patch**: tracked, human-applied, and explicitly **not** a blocker on this feature's task decomposition.

The consequence, stated rather than glossed, mirrors `design-sync-consent/infra-spec.md`'s own finding exactly: `tests/run-all.sh` is itself not invoked by any workflow as of the last check recorded in that document (`grep -rn "run-all" .github/` returned nothing). Re-verify this at implementation time (`requirements.md` → Assumptions, and → Open Questions OQ-5, which asks whether this feature's staged patch should be batched with `design-sync-consent`'s own still-pending one). Until a human applies the staged patch, `tests/design-sync-scan.tests.{sh,ps1}` runs locally under `run-all` but not in CI. The acceptance criterion asserting CI-reachability (AC-036, TEST-054) is **not** part of `acceptance-tests.md`'s blocking Test Matrix for exactly this reason — it lives in that file's Deferred (non-blocking verification) section, following the adversarial-review correction (Ruling C) of the fail-closed-but-still-nominally-blocking treatment `design-sync-consent`'s AC-024/TEST-039 originally used.

**Newly-reachable branch declaration (AGENTS.md "Author-time sweeps", item 5).** When the staged CI patch lands, `tests/design-sync-scan.tests.{sh,ps1}` executes on a CI runner for the first time, on every leg of the 3-OS matrix (`.github/workflows/test.yml:22-27`). The implementation report must name this suite and that environment explicitly and either exercise it in a matching environment before merge or flag it as "pending first real execution at CI time." The cross-runtime parity comparison (`acceptance-tests.md` TEST-049/TEST-050) is separately environment-conditional — it requires both `bash` and `pwsh` present on the same host to run at all — and that SKIP condition must be named the same way wherever it is not exercised.

### Merge-time sequence

1. Deterministic gates: `check-sdd-structure`, `check-workflow-state` (see Prerequisites below).
2. The `test` job's existing enumerated suites — unchanged inside this feature's decomposition, plus the new suite once the staged CI patch (above) is applied by a human.
3. No `dist/` rebuild step applies. Shell, PowerShell, and Markdown only; ADR-0003's same-commit rebuild obligation does not attach, and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion.
4. No `npm audit` interaction. No package manifest or lockfile is touched.
5. No human-copy application commit is required by this feature (contrast with `design-sync-consent`, which required one inside its implementation phase).

Stack for the verification contract is `shell` (POSIX shell, PowerShell, Markdown), which makes `lint` / `typecheck` / `build` waivable with a reason per `risk-gate-matrix.md`'s Stack descriptor table.

## Environments

| Environment | URL | Auth | Trigger | Classification | Promotion rule |
|---|---|---|---|---|---|
| local | the operator's checkout, or an agent session's working tree | none | `design-sync-loop` invocation, or a standalone manual run (REQ-008) | repository source | n/a |
| CI | GitHub Actions, 3-OS matrix | repository token | push / PR | repository source | required checks on `main`, once the staged CI patch lands |
| production | **N/A** | — | — | — | plugins are consumed from the repository; there is no deployed environment |

## Prerequisites — deterministic gates for this spec directory

One repository-level obligation attaches to creating `specs/design-sync-scan/`, not performed during Phase 1 authoring because the authoring instruction forbade editing files outside the new spec directory except this registry.

**Registry entry (blocking, gate-visible).** `check-workflow-state.sh:130-134` iterates every directory under `specs/` and emits `registry-unregistered-directory` for any that has no entry in `specs/workflow-state-registry.json`. Without an entry the gate exits 1. The minimal entry accepted by `contracts/workflow-state-registry.schema.json` (`definitions.entry`, first `oneOf` branch) is:

```json
{ "feature": "design-sync-scan", "profile": "full" }
```

With `profile: full`, the loop at `check-workflow-state.sh:671-741` then requires `requirements.md`, `design.md`, and `acceptance-tests.md` to exist and both stage headers to read `Pending` or `Passed`; with both `Pending` (as they are here), provenance validation is skipped. All three files exist and both headers read `Pending`, so the entry itself — added by this same task — is the only missing piece once this spec directory is created.

`AGENTS.md`'s Active Spec Directories list (`sdd-bootstrap-interviewer/SKILL.md:234-236`'s obligation) is a separate, non-blocking, gate-invisible action; not performed by this task per its instructions (only `specs/design-sync-scan/` and the registry are in scope), and recorded here so it is not silently forgotten.

## Rollback

Revert the commit. The change is additive to skill prose, additive to one Design-Source field pair, and additive to a new, independently-invocable script pair and test suite — the revert is complete and carries no migration, no state, and no cache.

**A rollback here is a security regression, not a neutral undo — the same asymmetry `design-sync-consent/infra-spec.md` names for itself, but pointed the other way.** Reverting this feature removes the compensating mechanical control `design-sync-consent/security-spec.md`'s Residual Risk R1 called for, re-widening that gap back to its pre-#139 state: local human review is still optional under `design-sync-consent` regardless of this feature's presence, and without this feature nothing mechanical stands between an ungated mockup set and the first push. Stated explicitly so a rollback decision made for an unrelated reason (a regression this feature is wrongly blamed for, a script bug) is made with that cost visible, not discovered afterward.

Component-wise:

- **The script pair and its tests** revert cleanly; nothing else in the repository calls them except the one `SKILL.md` step this feature edits.
- **The `SKILL.md` and `claude-design-workflow.md` reverts** restore step 5's no-op text and remove the manual-usage documentation. Nothing parses them, so nothing breaks mechanically.
- **An `Egress-Scan` record already written** by a run under this feature survives the revert as inert text, exactly as `design-sync-consent/infra-spec.md` notes for its own `Egress-Consent*` fields: not read by any gate, permanent because git-tracked, harmless as a stale record but not erased by reverting the code that produced it.
- **The staged CI patch, if already applied**, is a separate human action to revert; reverting the suite's source without reverting its CI registration would leave a registered suite asserting against a script that no longer exists in that form.

Partial rollback is safe in one direction only: reverting the manual-fallback documentation edit (REQ-008) independently of the scanner itself is safe (the documentation simply stops mentioning a capability that still exists). Reverting the scanner and the `SKILL.md` wiring while keeping the documentation edit would leave the manual-fallback text describing a check that no longer runs — the same documentation-versus-behaviour drift `design-sync-consent/infra-spec.md` warns against for its own partial-rollback case.

## Open Questions

- maintainers: **OQ-5** (from `requirements.md`) — should this feature's staged CI-registration patch be batched with `design-sync-consent`'s still-pending equivalent patch for `tests/design-system-contract.tests.{sh,ps1}`? Non-blocking; both are independently staged and neither blocks its own feature's decomposition.
