# Design: cross-model-verification

Source of truth for implementation. Implements `requirements.md`; verified by
`acceptance-tests.md`. Provenance: derived from the comparative review of the
external `duolahypercho/fusion-fable` panel→judge harness vs. this repo
(2026-06-14); see memory `cross-model-verification-design`.

## 1. Architecture — two-layer separation

The non-deterministic external work and the deterministic gate are split so the
gate stays CI-testable and CI never auto-sends code.

- **Collection layer** (non-deterministic, external, opt-in, **local only**):
  `cross-model-verify` skill → `prepare-panelist-input` (consent + sanitize) →
  blind parallel panelists (Claude via Agent tool; GPT/Gemini via CLI runners) →
  one `T-NNN.panelist-<vendor>.verdict.json` per panelist under
  `specs/<feature>/verification/`.
- **Gate layer** (deterministic, no network, CI-testable):
  `check-cross-model.{sh,ps1}` reads the verdict JSONs, applies the consensus
  policy, writes the aggregate `T-NNN.cross-model.json`, exits 0/1/2.

The aggregate is referenced as a contract `checks[].evidence` path, so it flows
into the evidence bundle `artifacts[]` (SHA-256 bound) through the existing
`generate-evidence-bundle` path — **no bundle schema change**.

## 2. Data contracts

### 2.1 Panelist verdict (`cross-model-verdict/v1`)
`specs/<feature>/verification/T-NNN.panelist-<vendor>.verdict.json`
```json
{
  "schema": "cross-model-verdict/v1",
  "task_id": "T-001",
  "feature": "cross-model-verification",
  "vendor": "openai",
  "model": "gpt-5.5",
  "verdict": "PASS",
  "findings": [{ "severity": "Minor", "ref": "path:line", "note": "..." }],
  "blind": true,
  "input_digest": "<64-hex sha256 of sanitized input>",
  "consent": { "kind": "human-flag", "ref": "tasks.md T-001 Cross-Model: enabled" }
}
```
- `vendor` ∈ {anthropic, openai, google, …}; `verdict` ∈ {PASS, NEEDS_WORK}.
- `findings[].severity` ∈ {Critical, Major, Minor}.
- `blind` MUST be `true`; `input_digest` MUST be 64-hex; `consent.kind` ∈ {human-flag, sudo}.

### 2.2 Aggregate (`cross-model-aggregate/v1`) — emitted by `check-cross-model`
`specs/<feature>/verification/T-NNN.cross-model.json`
```json
{
  "schema": "cross-model-aggregate/v1",
  "task_id": "T-001",
  "feature": "cross-model-verification",
  "panelists": [{ "vendor": "anthropic", "model": "claude-opus-4.8", "verdict": "PASS" }],
  "vendors_distinct": 2,
  "non_anthropic_count": 1,
  "all_pass": true,
  "any_critical": false,
  "evaluator_verdict": "PASS",
  "divergence": false,
  "requires_human_decision": false,
  "result": "PASS"
}
```
- `result` ∈ {PASS, FAIL, NEEDS_HUMAN}.

## 3. Consensus algorithm (`check-cross-model`)

Inputs: `--task T-NNN --feature <f> [--evaluator PASS|NEEDS_WORK] [--expect-digest <hex>]`.
Reads all `T-NNN.panelist-*.verdict.json` under the feature's `verification/`.

1. Parse + schema-validate each verdict (`blind==true`, 64-hex `input_digest`,
   `vendor` non-empty, `consent.kind` present). Malformed ⇒ exit 2.
2. Compute `vendors_distinct`, `non_anthropic_count`.
3. **Diversity**: require `vendors_distinct >= 2` AND `non_anthropic_count >= 1`. Else exit 1.
4. **Consent**: every verdict carries `consent`. Missing ⇒ exit 1.
5. **Digest** (if `--expect-digest`): every `input_digest` equals it. Mismatch ⇒ exit 1.
6. **Consensus**: every `verdict == PASS` AND no `findings[].severity == Critical`.
   Else write aggregate `result:FAIL`, exit 1 (caller opens a review ticket).
7. **Divergence** (if `--evaluator`): panel-consensus != evaluator ⇒ `result:NEEDS_HUMAN`,
   `requires_human_decision:true`, exit 1 (blocks auto-Done).
8. Else write aggregate `result:PASS`, exit 0.

Exit codes mirror existing gates: 0 pass / 1 fail / 2 tool error.

## 4. Contract integration & backward compatibility

- Add check id `cross-model-verification` to `risk-gate-matrix.md`: **required at
  critical**, **opt-in at high**, n/a below.
- `check-contract` enforces `cross-model-verification` via a **dedicated conditional
  pass (Pass 6)**, gated by the contract `cross_model` descriptor. It is
  deliberately **NOT** added to the machine-form `RISK_TIERS` set — exactly like
  `signature` and `two-person approval`, which are conditional controls listed in
  the matrix table but enforced outside the tier-minimum set. This preserves the
  matrix↔encoding parity invariant and full backward compatibility (mirrors the
  `risk`-absent⇒legacy precedent in risk-adaptive-layer):
  - `cross_model` absent / `"legacy"` ⇒ no enforcement (old fixtures unaffected).
  - `cross_model: "required"` ⇒ the check must be present, `required:true`,
    `passes:true` with evidence (the aggregate JSON).
  - `cross_model: "waived"` ⇒ the check may be `required:false` with non-empty
    `waiver_reason` (air-gapped / secret-sensitive repos).
- The check's `evidence` path is the aggregate JSON, which `generate-evidence-bundle`
  hashes into `artifacts[]`. `review_verdict` (single evaluator) is untouched.

## 5. File inventory

| File | Layer | Task |
|---|---|---|
| `references/cross-model-verification-policy.md` | docs | T-001 |
| `scripts/check-cross-model.{sh,ps1}` | gate | T-002 |
| `tests/cross-model.tests.{sh,ps1}` + fixtures | gate tests | T-002 |
| `check-contract.{sh,ps1}` + `risk-gate-matrix.md` (wiring) | gate engine | T-003 |
| `scripts/prepare-panelist-input.{sh,ps1}` | collection | T-004 |
| `scripts/detect-panel.{sh,ps1}`, `run-panelist-gpt.{sh,ps1}`, `run-panelist-gemini.{sh,ps1}` | collection | T-005 |
| `skills/cross-model-verify/SKILL.md`; `agents/panelist-*.md`; `.codex/agents/sdd-panelist-*.toml` | collection | T-005 |
| `.github/workflows/test.yml` (gate-layer job) | CI | T-003 |
| `specs/cross-model-verification/verification/*` + `traceability.json` | dogfood | T-006 |

## 6. Security

- **Consent**: `prepare-panelist-input` fails closed unless a `tasks.md`
  `Cross-Model: enabled` flag OR a valid `SDD_SUDO` token is present. The chosen
  consent is stamped into each verdict's `consent` field.
- **Sanitization**: before any external send, strip `.env` content, key material,
  absolute paths, and private URLs (reuse `check-placeholders` secret patterns).
  Output is the sanitized bundle; its sha256 is the `input_digest`.
- **Key isolation**: `SDD_EVIDENCE_KEY` / sudo key are never passed to panelists.
- **CI**: the collection layer is never invoked by any CI job; only the gate layer
  runs (on fixtures, offline). Enforced by AC-007.
- Panelists are read-only; they cannot write code, approve, or sign (agent role
  `disallowedTools: Write, Edit, NotebookEdit`; `.codex` toml carries `developer_instructions`).

## 7. Model routing (cost-aware)

- **Build-time** (implementing this feature): T-001/T-004-docs/T-006 = Haiku;
  T-002/T-005 logic = Sonnet; T-003 gate-engine + governance = main (Opus) + human.
- **Run-time**: `prepare-panelist-input` formatting = Haiku-class; panelists =
  heterogeneous frontier (Claude + GPT-5.5 [+ Gemini]), variable, ≥1 non-Anthropic;
  `check-cross-model` = no model (pure script).

## 8. Migration

Additive. Pre-existing contracts/bundles validate unchanged (`cross_model` absent
⇒ legacy). New critical tasks set `cross_model: required` (or `waived` + reason).
The `quality-gate` skill defaults critical to `required` going forward; existing
merged critical work is not retroactively re-gated.
