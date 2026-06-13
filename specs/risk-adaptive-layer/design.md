# Design: risk-adaptive-layer

## Technical Summary

One new field — **`risk`** — becomes the spine. Set on a task, it deterministically
derives: the required check set (the *risk→gate matrix*), the TDD intensity
(`required_workflow`), the review escalation, the provenance requirements, and the
approval count. Deterministic gates enforce these as **non-downgradable minimums**
(fail-closed superset rule), consistent with the existing Default-FAIL philosophy.
A parallel **traceability spine** (`REQ → AC → TEST → evidence`) is given IDs and a
machine-readable `traceability.json` so a gate can prove the chain is complete.
Evidence bundles are extended with **provenance** (spec revision, risk verdict,
per-check command/exit/time, build env, builder, review verdict) and, for Critical,
a **signature**. All gates keep dual-runtime parity (py + PowerShell, with sh/js
dispatchers) and **backward compatibility** with pre-feature artifacts.

## Architecture

```
                    ┌─────────────── risk (low|medium|high|critical) ───────────────┐
                    │                          │                                     │
   tasks.md ──set──>│                          ▼                                     ▼
   (Risk:,          │              risk-gate-matrix.md (canonical)            required_workflow
    Required        │                          │                              (test-after|
    Workflow:,      │                          ▼                               acceptance-first|tdd)
    Requirements:)  │         verification-contract.json (risk, required[] derived)
                    │                          │
   check-risk ◄─────┘                          ▼
   (field valid?)            check-contract (enforce tier-minimum ⊆ contract.required;
                              tdd ⇒ red_evidence+green_evidence; spec_revision present)
                                               │
   acceptance-tests.md (AC-/TEST-) ──> traceability.json ──> check-traceability
   (REQ→AC→TEST→evidence complete?)             │
                                               ▼
                generate-evidence-bundle ──> evidence-bundle.json (+provenance, +signature?)
                                               │
                                               ▼
                check-evidence-bundle (hashes, git ancestry, provenance shape, signature?)
                                               │
                       independent evaluator (review_verdict) ──> quality-gate Done decision
                                               │
                                               ▼
                         release.yml (sigstore provenance, gated on CI required checks)
```

## Data Plan — schemas (the contract is the source of truth)

### 1. Task fields (tasks.template.md / ai-task.template.md)

Add three fields to each task, after `Status:`:

```
Risk: high            # low | medium | high | critical   (REQUIRED; agent proposes, human confirms)
Risk Rationale: touches authentication token verification (REQ-AUTH-004)
Required Workflow: tdd # test-after | acceptance-first | tdd   (derived from Risk; see matrix)
Requirements: REQ-001, REQ-004   # REQ-IDs this task implements (for traceability)
```

`Done When` gains risk-derived items (templated by `Required Workflow`), e.g. for
high/critical: `- [ ] Red→Green evidence captured`, `- [ ] Independent review verdict recorded`,
and critical: `- [ ] Second approver recorded`, `- [ ] Evidence bundle signed`.

### 2. Verification contract (verification-contract.template.json)

New top-level fields + per-check optional Red/Green + requirement mapping:

```json
{
  "task_id": "T-000",
  "feature": "<feature-slug>",
  "risk": "high",
  "required_workflow": "tdd",
  "spec_revision": "<sha256-of-spec-files | git-tree-sha>",
  "created": "<ISO-8601>",
  "checks": [
    {
      "id": "unit-tests", "required": true, "passes": false,
      "evidence": "", "waiver_reason": "",
      "requirement_ids": ["REQ-001"],
      "red_evidence": "",   "green_evidence": ""
    }
  ]
}
```

- `risk` absent ⇒ default tier = **medium-baseline** (the current fixed set) → no regression.
- `red_evidence`/`green_evidence` optional in schema; **required by the gate** only when `required_workflow == "tdd"` for checks of type test.
- `requirement_ids` optional in schema; **required by `check-traceability`** for high/critical.

### 3. Risk → gate matrix (canonical; lives in `references/risk-gate-matrix.md` + encoded in `check-contract`)

`required = TRUE` means the check MUST be `passes:true` with evidence; `—` means not mandated (may be present as optional with waiver). Each tier's required-set is a **superset** of the tier below.

| Check / control            | low | medium | high | critical |
|----------------------------|:---:|:------:|:----:|:--------:|
| lint                       |  ✓  |   ✓    |  ✓   |    ✓     |
| typecheck                  |  ✓  |   ✓    |  ✓   |    ✓     |
| build                      |  ✓  |   ✓    |  ✓   |    ✓     |
| placeholder-scan           |  ✓  |   ✓    |  ✓   |    ✓     |
| task-state-check           |  ✓  |   ✓    |  ✓   |    ✓     |
| unit-tests                 |  —¹ |   ✓    |  ✓   |    ✓     |
| acceptance-tests           |  —  |   ✓    |  ✓   |    ✓     |
| regression (related)       |  —  |   ✓    |  ✓   |    ✓     |
| red→green evidence (tdd)   |  —  |   —    |  ✓   |    ✓     |
| requirement-traceability   |  —  |   —    |  ✓   |    ✓     |
| independent-review verdict |  —  |   —    |  ✓   |    ✓     |
| provenance (spec_rev+env)  |  —  |   —    |  ✓   |    ✓     |
| evidence-bundle signature  |  —  |   —    |  —   |    ✓     |
| two-person approval        |  —  |   —    |  —   |    ✓     |

¹ low: `unit-tests` may be `required:false` with a `waiver_reason` (test-after allowed).

`required_workflow` derivation: low→`test-after`, medium→`acceptance-first`, high/critical→`tdd`.

### 4. Traceability (acceptance-tests.md + spec-id-rules.md + traceability.json)

- New ID prefixes in `spec-id-rules.md`: `AC-NNN` (acceptance criterion), `TEST-NNN` (test case).
- `acceptance-tests.md` table gains a `Requirement` and `Test ID` column: `| AC-001 | REQ-001 | TEST-001 | unit | tests/foo.test.ts | Planned |`.
- Machine-readable `specs/<feature>/traceability.json`:

```json
{
  "feature": "<slug>",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"],
      "evidence": ["specs/<slug>/verification/T-001.unit.log"] }
  ]
}
```

`check-traceability` rules: every REQ has ≥1 AC; every AC has ≥1 TEST; for high/critical
every TEST has ≥1 existing non-empty evidence file. Fail-closed; dual-runtime.

### 5. Evidence bundle provenance (evidence-bundle.template.json + generate/check)

Add to the bundle (generator-computed, never hand-authored — preserves STR-003):

```json
{
  "task_id": "T-000", "feature": "<slug>",
  "risk": "high", "required_workflow": "tdd",
  "spec_revision": "<sha256 of specs/<slug>/{requirements,design,acceptance-tests}.md>",
  "git_commit": "<40-hex>", "git_generated_dirty": false,
  "build_env": { "os": "linux", "python": "3.x", "git": "2.x", "lockfile_sha256": "<...|null>" },
  "builder": { "kind": "ci|local", "id": "<runner or agent id>", "runtime": "claude-code|codex|copilot" },
  "review_verdict": { "verdict": "PASS", "critical": 0, "major": 0, "minor": 1, "reviewer": "sdd-evaluator" },
  "checks": [ { "id": "unit-tests", "command": "npm test", "exit_code": 0,
               "started_at": "<ISO>", "finished_at": "<ISO>", "evidence_sha256": "<...>" } ],
  "artifacts": [ { "path": "...", "sha256": "..." } ],
  "signature": { "alg": "sigstore|hmac-sha256", "value": "<...>", "key_ref": "<...>" }
}
```

- `check-evidence-bundle` (extended): existing hash + git-ancestry checks PLUS, when `risk` ∈ {high,critical}: require `spec_revision`, `build_env`, `review_verdict.verdict == PASS`. When `risk == critical`: require and **verify** `signature`, and **reject `git_generated_dirty == true`** (fail-closed; today it is warning-only).
- Backward compat: bundles without the new fields validate as today **only when** `risk` is absent or ≤ medium.

### 6. Signature mechanism (OQ-1 resolved)

- **CI / release path**: reuse the existing sigstore keyless attestation (STR-006). Critical bundles produced in CI are attested via `actions/attest-build-provenance`.
- **Local path**: HMAC-SHA256 over the canonicalized bundle (sorted keys, excluding `signature`) using the **same external-key pattern as sudo tokens** (`$SDD_EVIDENCE_KEY` env or `~/.sdd/evidence-key`, never in-repo, never agent-readable). This mirrors STR-005 and needs no new crypto design. `check-evidence-bundle` verifies with constant-time compare.

### 7. Two-person approval (REQ-007)

Critical tasks record in tasks.md:
```
Approval: Approved (alice 2026-06-13T..Z)
Second Approval: Approved (bob 2026-06-13T..Z)
```
`check-task-state` (extended) requires a non-empty, **distinct** `Second Approval` for `Risk: critical` before `Done`. Sudo MUST NOT auto-pass `Second Approval` (extend `sdd-hook-guard` allow-list logic — second approval is *judgment*, like WFI).

## API / Contract Plan — gate CLIs

| Script (dual-runtime) | New / changed | Contract |
|---|---|---|
| `check-risk.{sh,ps1}` (+py inline) | NEW | exit 1 if task `Risk` missing/invalid/!rationale; 0 otherwise |
| `check-contract.{sh,ps1}` | CHANGE | read `risk`→matrix; fail if `contract.required` ⊉ tier-minimum; if `required_workflow==tdd`, fail unless test checks carry non-empty `red_evidence`+`green_evidence`; require `spec_revision` for high/critical. Keep ALL current rules. |
| `check-traceability.{sh,ps1}` (+py) | NEW | validate `traceability.json` chain per §4 |
| `generate-evidence-bundle.{sh,ps1}` | CHANGE | populate provenance §5; compute signature for critical |
| `check-evidence-bundle.{sh,ps1}` | CHANGE | validate provenance §5; verify signature + reject dirty for critical |
| `check-task-state.{sh,ps1}` | CHANGE | require distinct `Second Approval` for critical Done |

## Test Strategy

Tests-first for every gate change (these gate changes are themselves high-risk).
Extend the existing suites: `tests/gates.tests.sh` (+ `.ps1` equivalents in
`scripts.tests.ps1`), `tests/guards.tests.sh`, `tests/eval.tests.sh`. For each new
rule: a failing fixture (gate exits 1) and a passing fixture (gate exits 0), in
both runtimes. Regression: all pre-feature fixtures MUST still pass unchanged
(AC-010). Map every TEST-NNN to a fixture in `traceability.json`.

## Security Considerations

- Every gate stays fail-closed and runs out-of-process (cannot be flipped by agent memory).
- Signature keys are external-only (env / `~/.sdd/`), never in-repo, never agent-readable — reuses the audited sudo-key resolution.
- New approval field (`Second Approval`) is guarded like the existing `Approval`/WFI: agents cannot write it; sudo cannot auto-pass it.
- `risk` downgrade is a guarded judgment action (records spec-change with approver), not auto-passable.
- Threat model for these additions is captured in `docs/THREAT-MODEL.md` (REQ-009).

## Deployment / CI Plan

- `.github/rulesets/main.json` (GitHub ruleset: required status checks = test matrix, require PR, block force-push) + `scripts/apply-branch-protection.sh` (gh API; degrades to documented manual steps on free tier).
- `CODEOWNERS` at root.
- `test.yml`: add `merge_group:` trigger (merge queue) and a `required-checks` summary job.
- `release.yml`: add `needs`/gating on a successful test run (or `workflow_run` predicate) so release cannot ship on red.
- `.github/self-improvement.yml`: route generated PRs through required checks (no auto-merge without CI).

## Migration & backward compatibility (load-bearing)

1. **Default tier**: `risk` absent ⇒ medium-baseline = today's BASELINE_IDS. Existing contracts/tests pass unchanged.
2. **Additive schema**: all new fields optional in templates; gates only *require* them per risk tier.
3. **Phase order enforces safety**: expand tests FIRST (red), then change the gate (green). Never change a gate without its failing+passing fixtures landing in the same task.
4. **Dual-runtime parity**: a change is incomplete until py and PowerShell behave identically (verified by `scripts.tests.ps1` + `gates.tests.sh`).

## Per-file change map (for implementers)

- Templates: `tasks.template.md`, `ai-task.template.md`, `verification-contract.template.json`, `evidence-bundle.template.json`, `acceptance-tests.template.md`, `traceability.template.md`.
- References (new): `risk-classification-policy.md`, `risk-gate-matrix.md`. (changed): `spec-id-rules.md`, `test-policy.md`, `deterministic-check-policy.md`, `verification-policy.md`, `sudo-mode-policy.md`.
- Scripts (new): `check-risk.{sh,ps1}`, `check-traceability.{sh,ps1}`. (changed): `check-contract.{sh,ps1}`, `generate-evidence-bundle.{sh,ps1}`, `check-evidence-bundle.{sh,ps1}`, `check-task-state.{sh,ps1}`, `sdd-hook-guard.{py,sh,ps1,js}` (second-approval guard).
- Skills: `sdd-bootstrap-interviewer/SKILL.md` (+`references/phase-quality-gates.md`), `quality-gate/SKILL.md`, `implement-task/SKILL.md`.
- CI/docs: `.github/rulesets/main.json`, `CODEOWNERS`, `.github/workflows/{test,release,self-improvement}.yml`, `docs/THREAT-MODEL.md`, `docs/agent-capability-matrix.md`, `docs/workflow-guide.md`, `.codex/agents/*.toml` (model routing).
- Tests: `tests/gates.tests.sh`, `tests/scripts.tests.ps1`, `tests/guards.tests.sh`, `tests/hooks.tests.ps1`, `tests/eval.tests.sh`.

## Assumptions

- Existing dual-runtime dispatch pattern (py-preferred, PowerShell fallback) is reused verbatim for new scripts.
- `spec_revision` = sha256 over the concatenation of the feature's `requirements.md`, `design.md`, `acceptance-tests.md` (documented, reproducible) — avoids depending on git for the spec hash while staying deterministic.

## Open Questions

- OQ-3: Should `independent-review verdict` in the bundle be cross-checked against the markdown report automatically, or is structural presence enough for v1? (v1: structural presence + PASS; cross-check is a follow-up.)

## Risks

- Gate-engine regression (High) — mitigated by tests-first, default-tier fallback, dual-runtime parity gating.
- Matrix encoded in two places (doc + code) can drift — mitigation: a test asserts `risk-gate-matrix.md` table equals the code's tier-minimum sets.
