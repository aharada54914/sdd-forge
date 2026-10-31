# Infrastructure Specification: design-sync-standing-consent

## Deployment Topology

**Nothing is deployed.** No service, container, IaC resource, region, endpoint, or environment is created or changed. There is no `## Scaling Strategy`, `## Service Level Objectives`, `## Data Residency and Retention`, `## Observability` or `## Cost Estimate` content to write, and no `## Environments` table beyond `local`.

The changed artifacts and how they reach a consumer:

| Artifact | Consumed by | Distribution |
|---|---|---|
| `AGENTS.md` | every agent operating in this repository, and — once a consuming project copies the convention — every agent operating there | repository-only, read at the start of `sdd-bootstrap-interviewer` / `lite-spec` / `design-sync-loop` invocations |
| `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` | the `design-sync-loop` skill | shipped inside the plugin; no build step |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` | the manual fallback path | same |
| test suites | `tests/run-all.{sh,ps1}` locally; CI registration is a separate staged patch | repository-only |

**One property is new relative to DS-29, and belongs in this document rather than in `security-spec.md` alone: the configuration surface this feature introduces has no runtime analogue anywhere else in the repository's infrastructure.** Every other project-level knob this repository ships (`SDD_DESIGN_SYSTEM_ENFORCE`, `SDD_PANELIST_TIMEOUT`-style environment variables) is read by a script this repository controls the execution of. `ds_upload_consent` is read by an agent following prose — there is no process boundary, no environment variable, and no script that validates the value before an agent acts on it. A typo (`stading`, `Off`, an unsupported fourth value) has no defined failure mode beyond "the agent does whatever it makes of the text," which this document does not specify further (out of scope: this feature defines the three valid values and the default for their absence, not a validator for an invalid one).

**The egress dependency itself is unchanged from DS-29.** The loop reaches claude.ai/design through the `DesignSync` tool, a Claude Code-only capability (INV-022, carried). There is no endpoint to configure, no credential this repository holds, and no network policy it can set — true under every one of this feature's three regimes.

## CI/CD Sequence

### No protected-file staging — a contrast with DS-29, stated because it is unusual

Every file this feature edits live — `AGENTS.md`, `design-sync-loop/SKILL.md`, `claude-design-workflow.md` — is absent from `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, 42 entries, re-verified at drafting time). Unlike DS-29, which required a three-path human-copy round for `plugins/sdd-lite/skills/lite-spec/SKILL.md`, this decomposition has **no blocking human action inside the implementation phase**. The only human action this feature's own scope requires is the staged CI-registration patch below, which — as with DS-29's equivalent — does not block task decomposition or `Done` status for any task inside this feature.

**Re-verification instruction** (`AGENTS.md` "Author-time sweeps" item 3): protected-file membership is repository-wide, git-tracked, shared state this branch does not own. Re-derive at spec-review time and again at implementation start, by reading `guard_invariants.py:4` and testing each of `AGENTS.md`, `design-sync-loop/SKILL.md`, and `claude-design-workflow.md` with `endswith()` on its repository-relative path.

### The suite that would verify this feature is new, and is not yet registered anywhere

`tests/design-sync-standing-consent.tests.{sh,ps1}` does not exist yet (this feature's own implementation output). Its registration surface, checked at drafting time:

| Registration surface | present? |
|---|---|
| `tests/run-all.sh` | no — file does not exist yet |
| `tests/run-all.ps1` | no — same |
| `.github/workflows/*.yml` | no — zero matches for `design-sync-standing-consent` in any workflow |

Both `tests/run-all.sh` and `tests/run-all.ps1` are themselves unprotected, so registering the new suite there is agent-applicable, with no staging round.

**`tests/run-all.sh` is itself not invoked by CI** — re-verified at drafting time: zero matches for `run-all` across `.github/workflows/`, the identical fact DS-29's own `infra-spec.md` recorded and that remains true today, because DS-29's own equivalent staged patch has not yet been applied either (`requirements.md` → Assumptions). Consequence: registering this feature's suite in `run-all` (agent-applicable) makes it runnable **locally**, but not CI-enforced, until a human applies the staged workflow patch below — the same two-step gap DS-29 already lives with.

### Merge-time sequence

1. Deterministic gates: `check-sdd-structure`, `check-workflow-state` (see Prerequisites below).
2. The `test` job's existing enumerated suites — unchanged inside this feature's decomposition. This feature's own suite is not among them until the staged CI patch lands.
3. No `dist/` rebuild step applies (`frontend-spec.md`).
4. No `npm audit` interaction. No package manifest or lockfile is touched.
5. **No human-copy application commit is required inside this decomposition** — a contrast with DS-29's own step 5, which was blocking.

Stack for the verification contract is `shell` (Markdown, shell and PowerShell), making `lint` / `typecheck` / `build` waivable with a reason per `risk-gate-matrix.md`'s Stack descriptor table.

### Staged patch — `.github/workflows/test.yml`

`.github/workflows/test.yml` is protected (`guard_invariants.py:4`, and `PHASE2_HUMAN_COPY_TARGETS` at `:18`); an agent cannot write it, live or staged, and its staging destination would be equally denied (no `human-copy/` carve-out, `sdd-hook-guard.py:1001-1015`). CI registration of `tests/design-sync-standing-consent.tests.{sh,ps1}` is therefore a **separately staged, human-applied patch**, following the shape DS-29 established for its own still-outstanding equivalent (`specs/design-sync-consent/infra-spec.md`, "A second protected target is acquired"): a draft candidate at a non-protected path plus a `MANIFEST.sha256` recording its hash, both agent-authored; the human copies the draft to the live path and verifies the checksum before applying it.

**This feature does not itself produce that draft during Phase 1 authoring.** The draft belongs to the implementation phase, once the new suite's actual content exists to register. This document records the obligation and its shape so the task plan can schedule it as a non-blocking, staged action rather than discover it during implementation.

**Bundling with DS-29's own outstanding patch (OQ-5).** DS-29's `tests/design-system-contract.tests.{sh,ps1}` registration is, at drafting time, still not applied to `.github/workflows/test.yml` either. Both patches touch the same file; whichever human applies either should consider applying both in the same edit, though this document does not require it — `requirements.md` OQ-5.

## Environments

| Environment | URL | Auth | Trigger | Classification | Promotion rule |
|---|---|---|---|---|---|
| local | the operator's checkout | none | agent skill invocation | repository source | n/a |
| CI | GitHub Actions, 3-OS matrix | repository token | push / PR | repository source | required checks on `main` |
| production | **N/A** | — | — | — | plugins are consumed from the repository; there is no deployed environment |

## Prerequisites — deterministic gates for this spec directory

Two repository-level obligations attach to creating `specs/design-sync-standing-consent/`, mirroring DS-29's own Prerequisites section — one performed by this authoring session, one deliberately deferred.

1. **Registry entry (blocking, gate-visible) — performed by this authoring session.** `check-workflow-state.sh:130-134` iterates every directory under `specs/` and emits `registry-unregistered-directory` for any that has no entry in `specs/workflow-state-registry.json`. Unlike DS-29, which deferred this to a later phase, the task authorizing this document's creation explicitly permits editing `specs/workflow-state-registry.json` alongside this spec directory, so the minimal entry is added directly:

   ```json
   { "feature": "design-sync-standing-consent", "profile": "full" }
   ```

   With `profile: full`, `check-workflow-state.sh:671-741` requires `requirements.md`, `design.md`, and `acceptance-tests.md` to exist and both stage headers to read `Pending` or `Passed`; with both `Pending` (as authored), provenance validation at `:736-738` is skipped. All three files exist and both headers read `Pending` at authoring time, so the entry is the only piece this feature's own gate visibility depends on.

2. **`AGENTS.md` Active Spec Directories (non-blocking, gate-invisible) — deferred, not performed by this authoring session.** `sdd-bootstrap-interviewer/SKILL.md:234-236` requires appending `specs/design-sync-standing-consent/` to the list at `AGENTS.md:79-99`. This authoring session's scope is limited to this spec directory and the registry file (per the instruction that produced this document), and `AGENTS.md` is neither — so this bookkeeping item is recorded here, not performed, exactly as DS-29 recorded its own equivalent item without performing it during Phase 1.

## Rollback

Revert the commit. The change is additive to prose (one new `AGENTS.md` section, an outer branch in one skill file, one bullet in a reference document) and additive to one new test suite, so the revert is complete and carries no migration, no state, and no cache.

**A rollback here is a security improvement for `standing`-configured projects, and a availability regression for `off`-configured ones — the trade runs in different directions depending on which regime was in force, which is itself worth stating rather than assuming one direction.** Reverting removes the `ds_upload_consent` key entirely, which is observably identical to every project defaulting back to `per-feature` (`requirements.md` AC-003's backward-compatibility guarantee, exercised in reverse):

- **A project that had `standing` configured** regains DS-29's per-feature-and-session confirmation — a stricter posture, the same direction DS-29's own rollback note describes for reverting DS-29 itself.
- **A project that had `off` configured** loses the forbiddance entirely and reverts to `per-feature`'s ask-once behaviour — a project that specifically wanted uploads blocked outright (an organisation whose claude.ai use is not approved, the issue's own stated case for `off`) would need to know this before rolling back, because a plain revert silently re-permits what `off` was configured to forbid.

Component-wise:

- **`AGENTS.md` and `SKILL.md` reverts** restore DS-29's own behaviour for every project. Nothing parses the removed section mechanically, so nothing breaks.
- **A `Design-Source` record already written** under any of the three regimes survives the revert as inert text, exactly as DS-29's own rollback note describes for its records — it is not read by any gate, so a stale record referencing a setting that no longer exists in the skill's own text is harmless but permanent (git-tracked).
- **No protected-file revert is needed** — a further contrast with DS-29, whose `lite-spec/SKILL.md` revert required a human in both directions.
- **The staged CI patch, once applied, requires a second human action to revert**, exactly as DS-29's own equivalent does; reverting the suite's content without reverting its CI registration would leave a registered CI check asserting text that no longer exists.

## Open Questions

- maintainers: **OQ-5** — are the two staged CI-registration patches (DS-29's own outstanding one, and this feature's) applied to `.github/workflows/test.yml` together or separately? Non-blocking; either satisfies this feature's own `AC-028`.
