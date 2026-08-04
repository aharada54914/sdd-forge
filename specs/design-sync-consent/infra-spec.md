# Infrastructure Specification: design-sync-consent

## Deployment Topology

**Nothing is deployed.** No service, container, IaC resource, region, endpoint, or environment is created or changed. There is no `## Scaling Strategy`, `## Service Level Objectives`, `## Data Residency and Retention`, `## Observability` or `## Cost Estimate` content to write, and no `## Environments` table beyond `local`.

The changed artifacts and how they reach a consumer:

| Artifact | Consumed by | Distribution |
|---|---|---|
| `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` | the `design-sync-loop` skill, invoked by `sdd-bootstrap-interviewer` or `lite-spec` | shipped inside the plugin; no build step |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` | the interviewer skill | same |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | the lite-spec skill | same — but **protected**, see below |
| `docs/workflow-guide.md` | humans | repository-only |
| test suites | a CI entry point (OQ-8) | repository-only |

`SDD_PANELIST_TIMEOUT`-style runtime configuration has no analogue here: this feature introduces no environment variable, no setting, and no file the runtime reads. The one configuration surface in the vicinity — `ds_upload_consent` in `AGENTS.md` — belongs to #140 and is explicitly out of scope.

**One egress dependency exists and is not infrastructure this repository owns.** The loop reaches claude.ai/design through the `DesignSync` tool, which is a Claude Code-only capability (INV-022). There is no endpoint to configure, no credential this repository holds, and no network policy it can set. On a host without the tool — Codex, notably — the loop falls to the manual path, which performs no upload at all (`claude-design-workflow.md:12`, `:70-71`), so the egress dependency simply does not exist there.

## CI/CD Sequence

### Protected-file staging — one round certain, a second conditional

`plugins/sdd-lite/skills/lite-spec/SKILL.md` is an R-10 protected enforcement-chain file (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`; also `PHASE2_HUMAN_COPY_TARGETS` at `:18`). It cannot be written by an agent, and neither can its staging destination: the guard's protected-suffix match is a case-insensitive `endswith()` on the normalized repository-relative path (`sdd-hook-guard.py:1001-1015`) with **no `human-copy/` carve-out**, so `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` is denied to an agent exactly as the live path is.

The staging is therefore three-path, following the shape `epic-136-phase3` established (`specs/epic-136-phase3/infra-spec.md:75-98`, and the header of `specs/epic-136-phase3/human-copy/MANIFEST.sha256`):

| Role | Path | Who creates it |
|---|---|---|
| agent-authored bytes | `specs/design-sync-consent/verification/T-NNN/staged-lite-spec-candidate.draft.md` | the agent |
| staging destination | `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` | **the human**, by copying the draft |
| checksum record | `specs/design-sync-consent/human-copy/MANIFEST.sha256` | the agent (records the draft's SHA-256 under the destination name) |

Only `MANIFEST.sha256` will be committed under `human-copy/` by the agent. Finding exactly that one file there is the **designed state, not a missing artifact** — the same state `find specs/epic-136-phase3/human-copy -type f` returns today.

Human steps, all human-performed:

1. copy the draft to `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`;
2. verify: `cd specs/design-sync-consent/human-copy && shasum -a 256 -c MANIFEST.sha256` must report OK;
3. apply the staged candidate to the live `plugins/sdd-lite/skills/lite-spec/SKILL.md`.

Until step 3 lands, TEST-017 (lite-profile record destination) is red against the live tree. **That red is the designed fail-closed behaviour, not a defect** — there is no staged-candidate fallback, by the same reasoning `epic-136-phase3` applied to TEST-019/TEST-020.

**A second round is conditional on OQ-8.** `.github/workflows/test.yml` is on the same protected list. If OQ-8 resolves toward registering the assertion suite in CI, this feature acquires a second protected target, a second staged candidate, and a second blocking human action mid-implementation. If it resolves otherwise, no CI file is touched. **The task decomposition cannot be finalised before OQ-8 is answered**, because the two answers produce different task counts, different dependencies, and different human checkpoints.

**Re-verification instruction (AGENTS.md "Author-time sweeps", item 3).** Protected-file membership is repository-wide, git-tracked, shared state this branch does not own, and it is regenerated from `plugins/sdd-quality-loop/references/guard-invariants.json`. Re-derive both claims — not from this document — at spec-review time and again at implementation start, by reading `guard_invariants.py:4` and testing each target with `endswith()` on its repository-relative path.

### The suite that would verify this feature is not currently run

`tests/design-system-contract.tests.{sh,ps1}` already asserts against `design-sync-loop/SKILL.md` (block `DS-006`, `tests/design-system-contract.tests.sh:60-68`), which makes it the natural home for this feature's assertions. It is **registered nowhere**:

| Registration surface | present? |
|---|---|
| `tests/run-all.sh` (63 entries, read in full) | no |
| `tests/run-all.ps1` (36 entries, read in full) | no |
| `.github/workflows/*.yml` | no — zero matches for `design-system` in any workflow |

And `tests/run-all.sh` is itself **not invoked by CI**: zero matches for `run-all` across `.github/workflows/`. The workflow enumerates each suite individually (87 `run:` steps, 54 distinct `./tests/…` paths). `tests/design-system-compliance.tests.{sh,ps1}` is orphaned the same way.

Consequences for sequencing:

1. An acceptance criterion asserted only in that suite is, today, **not a CI-enforced guard**.
2. BL-007 — "the seven `DS-006` literals survive the restructuring" — is currently protected by a suite nobody runs, at exactly the moment this feature restructures the file those literals live in. That is the sharpest argument for OQ-8 option (a).

**Newly-reachable branch declaration (AGENTS.md "Author-time sweeps", item 5).** Under option (a), the whole `DS-001`…`DS-017` block — which has never executed on a CI runner — becomes reachable for the first time, on every leg of the OS matrix. The implementation report must name that block and that environment explicitly and either exercise it in a matching environment before merge or flag it as "pending first real execution at CI time", so a resulting failure is traced to this class rather than read as an unrelated surprise. Note also that these assertions were authored against a tree that has since changed; a first-ever CI run may surface pre-existing failures unrelated to this feature, and those must be reported as discovered defects rather than silently fixed inside this change.

**Re-verify the three "no" answers above** from `.github/workflows/` and `tests/run-all.{sh,ps1}` at implementation start; the registration surface is shared state this branch does not own.

### Merge-time sequence

1. Deterministic gates: `check-sdd-structure`, `check-workflow-state` (see Prerequisites below).
2. The `test` job's existing enumerated suites — unchanged unless OQ-8 resolves to option (a).
3. No `dist/` rebuild step applies. Markdown, shell and PowerShell only; no esbuild bundle is in scope, so ADR-0003's same-commit rebuild obligation does not attach and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion.
4. No `npm audit` interaction. No package manifest or lockfile is touched.
5. The human-copy application commit(s) — blocking, and inside the implementation phase rather than after it.

Stack for the verification contract is `shell` (Markdown, shell and PowerShell), which makes `lint` / `typecheck` / `build` waivable with a reason per `risk-gate-matrix.md`'s Stack descriptor table.

## Environments

| Environment | URL | Auth | Trigger | Classification | Promotion rule |
|---|---|---|---|---|---|
| local | the operator's checkout | none | agent skill invocation | repository source | n/a |
| CI | GitHub Actions, 3-OS matrix | repository token | push / PR | repository source | required checks on `main` |
| production | **N/A** | — | — | — | plugins are consumed from the repository; there is no deployed environment |

## Prerequisites — deterministic gates for this spec directory

Two repository-level obligations attach to creating `specs/design-sync-consent/`, and neither was performed during Phase 1 authoring because the authoring instruction forbade editing files outside the new spec directory. Both are recorded here so they are executed rather than discovered.

1. **Registry entry (blocking, gate-visible).** `check-workflow-state.sh:130-134` iterates every directory under `specs/` and emits `registry-unregistered-directory` for any that has no entry in `specs/workflow-state-registry.json`. Without an entry the gate exits 1. The minimal entry accepted by `contracts/workflow-state-registry.schema.json` (`definitions.entry`, first `oneOf` branch) is:

   ```json
   { "feature": "design-sync-consent", "profile": "full" }
   ```

   With `profile: full`, the loop at `check-workflow-state.sh:671-741` then requires `requirements.md`, `design.md` and `acceptance-tests.md` to exist and both stage headers to read `Pending` or `Passed`; with both `Pending`, the provenance validation at `:736-738` is skipped. All three files exist and both headers read `Pending`, so the entry is the only missing piece.

2. **`AGENTS.md` Active Spec Directories (non-blocking, gate-invisible).** `sdd-bootstrap-interviewer/SKILL.md:234-236` requires appending `specs/design-sync-consent/` to the list at `AGENTS.md:79-99`. No gate enforces it, so it will not appear as a red check — which is exactly why it is recorded here.

## Rollback

Revert the commit. The change is additive to skill prose and additive to two test suites, so the revert is complete and carries no migration, no state, and no cache.

**A rollback here is a security improvement, not a neutral undo — the opposite of the usual case.** Reverting restores per-upload consent and mandatory local review, which is a *stricter* egress posture than the one this feature ships. Stated explicitly because the reflex, drawn from features like `epic-136-phase4-docs` where a revert reopened a denial-of-service hole, is to treat rollback as a regression. Here the trade runs the other way: reverting costs the workability the issue is about and buys back the per-payload human eye (`security-spec.md` L1).

Component-wise:

- **Skill and documentation reverts** restore the per-upload text in all four live sites. Nothing parses them, so nothing breaks mechanically.
- **A `Design-Source` record already written** by a run under the new model survives the revert as inert text. It is not read by any gate (INV-011), so a stale record is harmless — but it is also permanent, because it is git-tracked. An operator reverting for privacy reasons should know the record of a past consent does not disappear with the code that produced it.
- **The `lite-spec/SKILL.md` revert requires a human**, because the file is protected in both directions. An agent can neither apply nor un-apply it. Plan the rollback as a human action, not a `git revert`.
- **If OQ-8 resolved to option (a)**, reverting the CI registration is likewise a second human action, and reverting the suite content without reverting its registration would leave a registered suite asserting text that no longer exists.

Partial rollback is safe in one direction only. The documentation reconciliation (REQ-007) may be reverted independently of the loop change; reverting the loop change while keeping the reconciliation would leave four documents describing a per-feature consent model the skill no longer implements — the precise documentation-versus-behaviour drift that produces issues of this shape in the first place.

## Open Questions

- maintainers: **OQ-8** — where this feature's assertions run. Determines whether the plan carries one protected human-copy round or two. Blocks the task decomposition.
- maintainers: **OQ-10** — whether `docs/THREAT-MODEL.md` gains a design-sync egress boundary in this feature. Non-blocking; would add one unprotected documentation target.
