# Cross-Model Verification Policy

A critical task's semantic verdict depends on a single LLM evaluator — a real blind
spot. Multi-vendor verification adds an independent, orthogonal signal: **≥2 distinct
vendors** run the same verification question in parallel, blind and unaware of each
other or the primary evaluator, emit a structured verdict JSON, and a deterministic
gate aggregates them under a documented consensus policy.

The approach is **split into two layers**:

- **Collection layer** (non-deterministic, external, opt-in, **local only**):
  panelists run blindly and in parallel, each writing a `cross-model-verdict/v1` JSON.
- **Gate layer** (deterministic, CI-testable, no network): `check-cross-model` reads
  verdict JSONs, applies consensus, writes a `cross-model-aggregate/v1` JSON, exits 0/1/2.

The aggregate flows into the evidence bundle as a contract check evidence artifact —
**no bundle schema change**. The single `review_verdict` is never merged or overwritten.

## Panelist Selection & Composition

A **panelist** is an independent LLM evaluator from a distinct vendor. Panel composition
is **variable** and defined per-task; the one hard constraint:

- **≥2 distinct vendors** (diversity minimum).
- **≥1 non-Anthropic vendor** (always present baseline: Claude).
- **Every vendor's verdict is collected blind** — no cross-talk, no evaluator context.

If the non-Anthropic vendor's CLI is absent or errors, the gate evaluates only the
collected verdicts but still enforces the diversity minimum. If diversity is unmet
(e.g., all vendors are Anthropic), `check-cross-model` fails and blocks auto-Done
(unless the task is explicitly waived).

## Blind & Parallel Execution

Panelists must **never** see:
- Each other's verdicts or findings.
- The evaluator's verdict, confidence, or reasoning.
- Prior review tickets or feedback tied to this task.

This is enforced at the **input-preparation step**: `prepare-panelist-input` computes
a sanitized bundle (no secrets, no absolute paths, no `.env`, no private URLs — reused
from `check-placeholders` secret patterns), embeds an `input_digest` (SHA-256 hex),
and passes this sanitized form to each panelist independently. Panelists are invoked
in parallel (no ordering dependency) with read-only agent roles (`disallowedTools`
include Write, Edit, NotebookEdit).

## Data Contracts

### Panelist Verdict (`cross-model-verdict/v1`)

Written to `specs/<feature>/verification/T-NNN.panelist-<vendor>.verdict.json`:

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

**Field semantics:**

- `schema`: literal `"cross-model-verdict/v1"`.
- `task_id`: the SDD task identifier (e.g., `T-001`).
- `feature`: feature name from the specs directory (e.g., `cross-model-verification`).
- `vendor`: ∈ {`anthropic`, `openai`, `google`, …}; must be non-empty and distinct.
- `model`: the model identifier (e.g., `gpt-5.5`, `claude-opus-4.8`).
- `verdict`: ∈ {`PASS`, `NEEDS_WORK`}; the panelist's final determination.
- `findings[]`: array of structured issues found.
  - `severity`: ∈ {`Critical`, `Major`, `Minor`}; blocks consensus if any is `Critical`.
  - `ref`: human-readable location (e.g., `path:line` or `section name`).
  - `note`: descriptive text.
- `blind`: MUST be `true`; attests that the panelist ran blind.
- `input_digest`: **64-character lowercase hex** of the SHA-256 hash of the sanitized
  input bundle; used to verify that all panelists evaluated the same input.
- `consent`: object describing how external send consent was obtained.
  - `kind`: ∈ {`human-flag`, `sudo`}.
    - `human-flag`: the task has a `tasks.md` field `Cross-Model: enabled`.
    - `sudo`: a valid `SDD_SUDO` token was active at send time.
  - `ref`: descriptive location (e.g., `tasks.md T-001 Cross-Model: enabled` or `SDD_SUDO`).

**Validation:** All fields MUST be present and non-empty. `input_digest` MUST be exactly
64 lowercase hex characters. `verdict` MUST be one of the allowed values. `blind` MUST
be the boolean `true` (not a string).

### Aggregate (`cross-model-aggregate/v1`)

Written by `check-cross-model` to `specs/<feature>/verification/T-NNN.cross-model.json`:

```json
{
  "schema": "cross-model-aggregate/v1",
  "task_id": "T-001",
  "feature": "cross-model-verification",
  "panelists": [
    { "vendor": "anthropic", "model": "claude-opus-4.8", "verdict": "PASS" },
    { "vendor": "openai", "model": "gpt-5.5", "verdict": "PASS" }
  ],
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

**Field semantics:**

- `schema`: literal `"cross-model-aggregate/v1"`.
- `task_id`, `feature`: copied from panelist verdicts.
- `panelists[]`: array of collected panelist records (vendor, model, verdict) from
  the input verdicts, in collection order.
- `vendors_distinct`: count of unique vendors in `panelists[]`.
- `non_anthropic_count`: count of panelists with `vendor != "anthropic"`.
- `all_pass`: boolean; `true` iff all `panelists[].verdict == "PASS"`.
- `any_critical`: boolean; `true` iff any finding in any panelist has
  `severity == "Critical"`.
- `evaluator_verdict`: ∈ {`PASS`, `NEEDS_WORK`}; the single primary evaluator's
  verdict (if `--evaluator` flag is passed to the gate; else `null` or omitted).
- `divergence`: boolean; `true` iff `evaluator_verdict` is present and the consensus
  differs from it (panel PASS but evaluator NEEDS_WORK, or vice versa).
- `requires_human_decision`: boolean; `true` if `divergence == true` (blocks auto-Done).
- `result`: ∈ {`PASS`, `FAIL`, `NEEDS_HUMAN`}; the gate's final determination.

## Consensus Algorithm (`check-cross-model`)

The gate script reads verdict JSONs under `specs/<feature>/verification/` matching the
glob `T-<task_id>.panelist-*.verdict.json` and applies the following algorithm:

### Inputs

- `--task T-NNN`: task identifier.
- `--feature <f>`: feature name (e.g., `cross-model-verification`).
- `[--evaluator PASS|NEEDS_WORK]`: optional primary evaluator verdict for divergence detection.
- `[--expect-digest <hex>]`: optional expected SHA-256 of the sanitized input; all
  `input_digest` values MUST match.

### Steps

1. **Parse & Validate Schema**
   - Read all matching `T-NNN.panelist-*.verdict.json` files.
   - For each file, validate:
     - JSON is well-formed.
     - `schema == "cross-model-verdict/v1"`.
     - `blind == true`.
     - `input_digest` is exactly 64 lowercase hex characters.
     - `vendor` is non-empty.
     - `consent.kind` is present and in {`human-flag`, `sudo`}.
   - If any verdict is malformed or invalid, exit 2 (tool error).

2. **Compute Diversity Metrics**
   - Count unique vendors.
   - Count non-Anthropic vendors.

3. **Diversity Check**
   - Require `vendors_distinct >= 2` AND `non_anthropic_count >= 1`.
   - If unmet, write aggregate with `result: FAIL` and exit 1 (caller opens review ticket).

4. **Consent Check**
   - Every verdict MUST carry a valid `consent` object.
   - Missing or invalid consent ⇒ exit 1 (fail closed).

5. **Input Digest Check** (if `--expect-digest` is provided)
   - Every verdict's `input_digest` MUST equal the expected value.
   - Mismatch ⇒ write aggregate, exit 1 (indicates panelist ran on different input).

6. **Consensus Check**
   - Require all `verdict == "PASS"`.
   - Require no finding with `severity == "Critical"`.
   - Else write aggregate with `result: FAIL`, exit 1 (caller opens review ticket for any
     NEEDS_WORK or Critical finding).

7. **Divergence Check** (if `--evaluator` is provided)
   - Compare the consensus verdict (PASS if all pass, else FAIL) against `--evaluator`.
   - If they differ:
     - Set `divergence: true`, `requires_human_decision: true`, `result: NEEDS_HUMAN`.
     - Exit 1 (blocks auto-Done; caller must open review ticket with divergence mark).
   - Else set `divergence: false`.

8. **Success**
   - Write aggregate with `result: PASS`, `requires_human_decision: false`.
   - Exit 0.

### Exit Codes

- **0**: Consensus passed; aggregate `result: PASS`; gate passes.
- **1**: Consensus failed (diversity, consent, digest, consensus, or divergence issue);
  aggregate `result: FAIL` or `NEEDS_HUMAN`; gate fails and caller should open review ticket.
- **2**: Tool error (malformed JSON, schema mismatch, file I/O error); gate fails (cannot
  proceed reliably).

## Absence of Consensus: Fail-Closed Default

If no verdict JSONs are found for the task:
- Exit 1 (fail closed).
- Diversity requirement cannot be met; gate fails.
- Caller opens a review ticket.

This surfaces the silent-degradation failure mode of external fusion panels where a CLI
is absent or fails silently.

## Conflict Resolution

### Panelists Disagree With Each Other

If any panelist says NEEDS_WORK or Critical, consensus fails and the gate fails.
This is a conservative, unanimous-PASS policy: all panelists must agree before the
gate passes.

### Panelists Disagree With Evaluator

If the consensus (PASS or FAIL) differs from the primary evaluator's verdict, the
aggregate is written with:
- `divergence: true`
- `requires_human_decision: true`
- `result: NEEDS_HUMAN`
- Exit 1 (blocks auto-Done).

The quality-gate skill must then open a review ticket with the divergence flagged,
requiring a human to inspect both verdicts and make the final call.

### No Consensus Yet (Partial Collection)

If some panelist verdicts are missing (e.g., a vendor's CLI failed), the gate
evaluates only the collected verdicts. If diversity is still met, the gate may
pass. If diversity is unmet, the gate fails.

## Input Sanitization & `input_digest`

The `prepare-panelist-input` script runs **before** any external send:

1. Accept the task's specification (code, design, requirements).
2. Scan the input for secrets using the same patterns as `check-placeholders`:
   - Content of `.env` files.
   - SSH / AWS / GCP key material (patterns: `-----BEGIN`, `ssh-rsa`, `AKIA`, etc.).
   - Absolute filesystem paths (e.g., `/home/user/…`, `C:\Users\…`).
   - Private URLs (localhost, private IP ranges, internal hostnames).
3. **Redact** matching patterns with a placeholder (e.g., `<REDACTED_SECRET>`).
4. Output the **sanitized** bundle (markdown + code).
5. Compute SHA-256 hash of the UTF-8 bytes of the sanitized bundle.
6. Format as **64-character lowercase hex** string.
7. Embed as `input_digest` in each verdict JSON sent to panelists.

**Purpose:** Attests to reviewers and auditors that:
- No raw secrets were sent to any panelist.
- All panelists evaluated the same redacted input (digest match confirms no
  panelist received different, unredacted content).
- The digest is reproducible from the sanitized file on disk.

## Consent & External Send

The `prepare-panelist-input` script enforces **fail-closed consent** before any
external send to a panelist:

### Consent Sources

1. **Human Flag**: A field in `tasks.md` (same task as the contract):
   ```
   Cross-Model: enabled
   ```
   If present and non-empty, human has explicitly enabled external send for this task.

2. **SDD_SUDO Token**: A valid `SDD_SUDO` token (per `sudo-mode-policy.md`) is
   active at invocation time.
   - Resolved from env `SDD_SUDO` file or env var.
   - Token signature and expiry MUST be valid.
   - If valid, external send is authorized and consent is recorded as `kind: sudo`.

### Fail-Closed Behavior

- If neither source provides valid consent, `prepare-panelist-input` exits with error.
- **No panelist is contacted.**
- The gate layer continues (on fixtures or existing verdicts) but fails diversity
  and blocks auto-Done.

This prevents accidental external send and makes explicit human intent mandatory for
all cross-model verification on critical tasks.

## Contract Integration & Backward Compatibility

The gate check id `cross-model-verification` is added to the **contract checks** in a
task's `evidence_bundle` and referenced from the **`risk-gate-matrix.md`** as follows:

### Risk-Tier Enforcement

- **`critical`**: `cross-model-verification` is **required** (must be present,
  `required: true`, `passes: true`) **unless explicitly waived**.
- **`high`**: `cross-model-verification` is **optional** (present and passing if
  opted in via a contract check entry; if absent, no gate failure).
- **`medium`/`low`/legacy**: no enforcement.

### Waiver Path

A contract may set a `cross_model` descriptor to control enforcement:

- **Absent** / **`"legacy"`**: no enforcement (backward compatibility; old fixtures
  unaffected).
- **`"required"`**: the check MUST be present, `required: true`, and `passes: true`
  with valid aggregate JSON evidence.
- **`"waived"`**: the check may be `required: false` with a non-empty `waiver_reason`
  (e.g., air-gapped repo, secret-sensitive codebase, limited vendor access).

**Backward Compatibility:** Pre-existing contracts and bundles with no `cross_model`
field behave as if `cross_model: "legacy"` (no enforcement). New critical tasks MUST
either:
- Set `cross_model: "required"` and provide a passing aggregate JSON, OR
- Set `cross_model: "waived"` with a documented reason (audit trail).

### Evidence Binding

The aggregate JSON (`T-NNN.cross-model.json`) is registered as a contract check
`evidence` path. When `generate-evidence-bundle` runs:
- It reads the aggregate JSON.
- Computes its SHA-256 hash.
- Records the path and hash in `artifacts[]`.
- `check-evidence-bundle` validates that the hash matches the file on disk (byte
  integrity).

The single `review_verdict` block in the evidence bundle is **never** merged with or
overwritten by the panelist aggregate. The primary evaluator's verdict remains
canonical; the aggregate is supplementary, visible in the artifact chain.

## Security & Fail-Closed Defaults

### Never Invoked in CI

The **collection layer** (`prepare-panelist-input`, panelist runners) is **never
auto-invoked by any CI job**. Only the **gate layer** (`check-cross-model`) runs in
CI, reading pre-collected fixtures (no network, no external send). This is enforced
by the CI job configuration (AC-007) and documented in test plans.

**Rationale:**
- Prevents accidental external send from automated pipelines.
- Avoids unbounded cost exposure (panelist LLM API calls).
- Keeps CI deterministic and fast (gate runs on fixtures).

### Key Isolation

- `SDD_EVIDENCE_KEY` (for evidence signing) and `SDD_SUDO_KEY` (for sudo token
  verification) are **never passed to panelists** and never visible in verdict JSONs.
- Panelists cannot read or write keys; agent roles include `disallowedTools: Write,
  Edit, NotebookEdit`.

### Consent & Sanitization Auditable

Every verdict JSON carries:
- `input_digest`: Allows auditors to verify that the panelist received a sanitized,
  not raw-secret, version of the input.
- `consent.kind` and `consent.ref`: Records **how** (human flag vs. sudo token) and
  **where** (tasks.md field, SDD_SUDO file) consent was obtained; both are git-tracked
  or audit-logged.

### Panelist Verdicts Are Read-Only

Panelists cannot:
- Write code, edit the spec, or modify the repository.
- Approve, sign, or set task status.
- Access secondary approval or risk-classification controls.

Agent role enforcement (Codex `developer_instructions` validation) ensures panelists
are isolated to read-only verdict emission.

## Model Routing (Cost-Aware)

**Build time** (implementing this feature):
- T-001 (policy doc) = Haiku.
- T-004 (prepare-panelist-input) = Haiku.
- T-002 (check-cross-model gate) = Sonnet.
- T-005 (panelist orchestration, agent configs) = Sonnet.
- T-003 (contract integration) = Opus (main) + human.
- T-006 (dogfood tests & evidence) = Haiku.

**Run time**:
- `prepare-panelist-input` formatting = Haiku-class (lightweight, deterministic).
- Panelists = heterogeneous frontier models (Claude + GPT-5.5, variable per-task).
  Always ≥1 non-Anthropic.
- `check-cross-model` = no model (pure shell/PowerShell script, no LLM calls).

## Example: Workflow With Cross-Model Verification

1. **Task Setup**: Task marked `Critical`, contract has `cross_model: required`.
2. **Local Collection** (opt-in, developer's machine):
   - `sdd quality-gate` → collection orchestrator skill → `prepare-panelist-input` (consent check, sanitize).
   - If consent OK: invoke 2+ panelists in parallel (Claude + GPT-5.5), each writes verdict JSON.
   - If no consent: fail-closed, no external send.
3. **Gate (local or CI)**:
   - `check-cross-model --task T-XXX --feature <f> [--evaluator PASS|NEEDS_WORK]`.
   - Reads `T-XXX.panelist-*.verdict.json`, applies consensus algorithm.
   - Writes `T-XXX.cross-model.json` (aggregate).
   - Exits 0 (pass) or 1 (fail / divergence) or 2 (tool error).
4. **Evidence Bundle**:
   - `generate-evidence-bundle` reads the aggregate JSON.
   - Records its path and SHA-256 in `artifacts[]`.
   - `check-evidence-bundle` validates the artifact hash.
   - Bundle includes both the primary `review_verdict` and the cross-model aggregate.
5. **Quality Gate & Task Completion**:
   - `quality-gate` checks that `cross-model-verification` is `required: true`,
     `passes: true` with evidence.
   - If divergence (`requires_human_decision: true`), quality-gate opens a review
     ticket; task stays in `In Progress` pending human decision.
   - Else, task may proceed to `Done`.

## See Also

- `risk-gate-matrix.md` — canonical risk → required-control matrix; defines where
  `cross-model-verification` is required vs. optional.
- `design.md` § 1-7 — architecture, data contracts, algorithm, security, model routing.
- `requirements.md` — REQ-001..008 and acceptance criteria.
- `evidence-signing-policy.md` — HMAC signing and consent patterns (parallel structure).
- `sudo-mode-policy.md` — SDD_SUDO token format and resolution.
