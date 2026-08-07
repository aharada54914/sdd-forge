# Infrastructure Spec: mcp-readonly-preflight

## CI/CD Sequence

**No new CI step, and no CI file is edited.** `.github/workflows/test.yml` is on `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`) and is untouched by this feature.

The existing `test` job is authoritative. Sequence at merge time:

1. **`test` job, 3-OS matrix** — runs `tests/run-all.sh`. `tests/workflow-documentation.tests.sh` is already registered and already covers `README.md` (its `DOCS` array at `:6-13`) and asserts structure inside `bootstrap/SKILL.md` (`:65-68`). No registration change is needed for this suite to see the change.
2. **AC-027 requires that suite pass *unmodified*.** Needing to edit it is evidence that a documented structural assumption broke — most plausibly the `sed` range at `:65-68`, bounded by the literal headings ``### `feature` … full track)`` and `### Lite track` — and must be reported rather than accommodated by adjusting the suite to fit the change.
3. **No `dist/` rebuild step applies.** No file under `mcp/` changes (BL-001), so ADR-0003's same-commit rebuild obligation does not attach.
4. **No `npm audit` interaction.** No package manifest or lockfile is touched.

**Whether this feature adds a suite of its own is OQ-009 and is not decided here.** The issue states no test obligation. If one is added, it must self-register in `tests/run-all.sh` following the convention demonstrated by `tests/quality-gate-cycle-limit.tests.sh` (case `QGCL-016`, which positively asserts its own registration in `run-all.sh` and its absence from `run-all.ps1`).

### A CI-relevant consequence of AC-017 … AC-020

Four acceptance criteria require the probe and fallback paths be exercised under **both** Claude Code and Codex. Neither runtime is available inside the `test` job — the suites run shell and PowerShell, not agent sessions.

So these four cannot be satisfied by the standard CI leg regardless of how OQ-009 resolves. They need either an out-of-CI runtime exercise or an explicitly recorded manual verification naming the runtime and the observed path. This is stated here, in the infrastructure layer, because it is an infrastructure fact — the capability does not exist in the job — and not a testing preference.

## Deployment Topology

**Nothing is deployed.** No service, no container, no IaC resource, no external endpoint, no scheduled job.

| Artifact | Consumed by | Distribution |
|---|---|---|
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | agent skill runtime | shipped inside the plugin, no build step |
| `plugins/sdd-ship/skills/ship/SKILL.md` | agent skill runtime | same — but **protected**; see below |
| `USERGUIDE.md` | humans | repository-only |
| `README.md` | humans | repository-only |
| `specs/mcp-readonly-preflight/human-copy/**` | a human applying a patch | repository-only, never shipped |

The MCP servers this feature *calls* are already deployed by the installer as stdio child processes (`install.sh:355-357` for Claude Code; `install.sh:374-391` for the Codex marker block). **This feature adds a caller, not a server**, so it introduces no new process, no new port, and no new runtime dependency. `sdd-forge-mcp` needs no provisioning it does not already have.

## The protected-file staging leg

`plugins/sdd-ship/skills/ship/SKILL.md` is on `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`) and additionally in `PHASE2_HUMAN_COPY_TARGETS` (`:18`). An agent cannot write it. This makes the change a **two-commit deployment**, which is an infrastructure property of the change, not an implementation detail:

| Commit | Author | Contents | Gate state |
|---|---|---|---|
| 1 | agent | the three writable targets, plus `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md` and `MANIFEST.sha256` | TEST-025 green; **TEST-026 expected red** |
| 2 | human | the staged candidate applied to the live protected path | TEST-026 green |

**The red between the two commits is the correct state, not a blocker.** `tests/quality-gate-cycle-limit.tests.sh:390-392` records the identical expectation for its own protected leg, calling a red result there "the correct pre-human-copy state … NOT a suite defect". Any task decomposition must carry this note, or a correct red will be escalated as a failure.

`MANIFEST.sha256` uses the two-space-separated `<sha256>  <repo-relative-path>` form, as in `specs/quality-loop-fixes/human-copy/MANIFEST.sha256`.

This whole leg is conditional on **OQ-007**. If ship is descoped, commit 2 does not exist and the feature is single-commit.

## Registry registration — a merge-blocking prerequisite

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:130-135` walks every directory under `specs/` and fails the repository-wide gate with `registry-unregistered-directory` for any that has no entry in `specs/workflow-state-registry.json`. The diagnostic exits 1 immediately.

Creating `specs/mcp-readonly-preflight/` therefore turns the gate red until the entry exists. The entry must land in the **same change** as the directory, not as a follow-up:

```json
{ "feature": "mcp-readonly-preflight", "profile": "full" }
```

Exactly those two keys — the bounded schema at `contracts/workflow-state-registry.schema.json` requires `(keys | sort) == ["feature","profile"]` for a full-profile entry. `tests/workflow-state-registry.tests.sh:150` states that full/lite membership is deliberately not pinned, so adding an entry does not break that suite.

This is BL-005, and it is an infrastructure concern because it affects **every concurrent agent in the repository**, not only this feature: the gate is repository-wide, so an unregistered directory turns it red for work that has nothing to do with #129.

## Rollback

Revert the commit. The change is additive prose in four documents plus one registry entry, so the revert is complete and carries no migration, no state, and no cache.

- Reverting the skills restores the current file-based-only flow. **No security or availability regression** — the probe is advisory and changes no outcome by construction (AC-012/AC-013), so removing it removes information, not a control.
- Reverting the documents removes the two policy claims. The five pre-existing read-only statements (`README.md:108,114,118,130`; `USERGUIDE.md:40,135,213,229`) are untouched by this feature (BL-003) and therefore survive a revert intact.
- Reverting the registry entry must happen **together with** removing the spec directory. Reverting one without the other reproduces the `registry-unregistered-directory` failure — or, in the other direction, a `registry-dangling-entry` failure (`check-workflow-state.sh:120-121`). This is the one ordering hazard in the rollback.

**Partial rollback is safe in one direction only.** Stream B (the policy documents) may be reverted independently of Stream A. Reverting Stream A while keeping Stream B would leave `USERGUIDE.md` and `README.md` describing an advisory probe layer that no skill invokes — documentation-versus-behaviour drift, which is the exact defect class issue #129 was filed about. If Stream A is reverted, Stream B must be reverted with it.

If commit 2 (the human-applied protected file) has landed, its revert is also a human action: an agent cannot revert a protected path any more than it can write one.
