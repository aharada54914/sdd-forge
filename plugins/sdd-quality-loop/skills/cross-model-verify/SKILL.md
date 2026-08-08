---
name: cross-model-verify
description: Orchestrate blind parallel cross-model panelist verification for a critical SDD task. Runs prepare-panelist-input (consent + sanitize), invokes panelists blind in parallel (Claude via Agent tool; GPT/Gemini via CLI runners), collects verdict JSONs, then prompts the user to run check-cross-model to gate the result.
disable-model-invocation: true
user-invocable: false
---

# Cross-Model Verify

Use this skill when a task's contract has `cross_model: required` and you need
to collect panelist verdicts before running the deterministic gate.

**Never run this skill in CI.** Collection is local-only and opt-in (design.md §6).

## Prerequisites

- Task has `Cross-Model: enabled` in `specs/<feature>/tasks.md` (or a valid
  `SDD_SUDO` token exists).
- `prepare-panelist-input.{sh,ps1}` has been run and produced a sanitized
  bundle at `specs/<feature>/verification/<task>.panelist-input.txt`.
- At least one non-Anthropic panelist CLI is available (`codex` or `gemini`),
  OR you will provide a manual verdict JSON after running this skill.

## Blind & Parallel Isolation Rules

Panelists MUST be invoked blind. Before calling any panelist:

1. Do NOT share any other panelist's verdict, findings, or model with the next
   panelist.
2. Do NOT share the primary evaluator's verdict, confidence, or reasoning.
3. Do NOT pass prior review-ticket content, `Implementation Complete` reports,
   or any `specs/<feature>/verification/T-NNN.cross-model.json` to panelists.
4. Each panelist receives ONLY the sanitized input bundle
   (`T-NNN.panelist-input.txt`) — nothing else from the repository context.

These rules are enforced structurally: Claude panelist runs via Agent tool in a
fresh context; GPT/Gemini panelists run via isolated CLI runners with key
isolation (see `run-panelist-gpt.{sh,ps1}` and `run-panelist-gemini.{sh,ps1}`).

## Steps

### Step 1 — Consent + Sanitize

Run `prepare-panelist-input` if not already done:

```sh
# bash
bash plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh \
  --task <T-NNN> --feature <feature> \
  --input specs/<feature>/ \
  --spec-root specs

# pwsh
pwsh plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1 \
  --task <T-NNN> --feature <feature> \
  --input specs/<feature>/ \
  --spec-root specs
```

This will:
- Fail closed if `Cross-Model: enabled` is absent and no `SDD_SUDO` token exists.
- Strip secrets, absolute paths, and private URLs.
- Write `specs/<feature>/verification/<T-NNN>.panelist-input.txt`.
- Print the `input_digest` (64-hex SHA-256) to stdout.

Record the `input_digest` for the `--expect-digest` gate check later.

### Step 1.5 — Pre-Panel Readiness (deterministic, fail-closed)

If the task's specification flags an enumerable coverage requirement
(e.g. "every jq -r site", "every protected-suffix entry", "every declared
output" — a REQ/AC that enumerates or quantifies), the sanitized bundle
MUST include a machine-checkable coverage manifest mapping each required
element to the fixture/artifact that exercises it. Before invoking ANY
panelist:

- If no such flag exists on this task, skip this step — proceed to Step 2
  unchanged (no-op for ordinary tasks).
- If the flag exists and the manifest is present with every element
  mapped, proceed to Step 2.
- If the flag exists and any element is unmapped (or the manifest is
  absent), STOP. Do not invoke any panelist. Report the unmapped elements
  to the user and require the bundle to be corrected before retrying this
  skill.

### Step 2 — Detect available panelists

```sh
bash plugins/sdd-quality-loop/scripts/detect-panel.sh
# or
pwsh plugins/sdd-quality-loop/scripts/detect-panel.ps1
```

- Exit 0 + slug list → proceed.
- Exit 1 (no non-Anthropic CLIs) → warn user; they must provide a manual
  verdict JSON for at least one non-Anthropic vendor, or install a CLI.

### Step 3 — Invoke panelists blind in parallel

Run ALL panelists simultaneously. Do not wait for one before starting another.

**Claude panelist** (Anthropic vendor — always included):

Use the Agent tool to invoke `sdd-panelist-gpt` or `sdd-panelist-gemini` roles
— actually, Claude itself is the Anthropic panelist. Invoke a fresh Agent with
ONLY the sanitized bundle as input. The agent role is in
`plugins/sdd-quality-loop/agents/panelist-gpt.md` (for GPT) or
`panelist-gemini.md` (for Gemini-style structured review).

For the Anthropic (Claude) panelist: create a new Agent tool call with the
sanitized bundle path and the instruction to return a `cross-model-verdict/v1`
JSON, writing it to
`specs/<feature>/verification/<T-NNN>.panelist-anthropic.verdict.json`.

**GPT panelist** (OpenAI vendor — if `gpt` slug in detect-panel output):

```sh
bash plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh \
  --task <T-NNN> --feature <feature> \
  --input specs/<feature>/verification/<T-NNN>.panelist-input.txt \
  --spec-root specs
```

**Gemini panelist** (Google vendor — if `gemini` slug in detect-panel output):

```sh
bash plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh \
  --task <T-NNN> --feature <feature> \
  --input specs/<feature>/verification/<T-NNN>.panelist-input.txt \
  --spec-root specs
```

Each runner writes its verdict to
`specs/<feature>/verification/<T-NNN>.panelist-<vendor>.verdict.json`.

### Step 4 — Verify verdict files present

After all panelists complete, confirm verdict files exist:

```sh
ls specs/<feature>/verification/<T-NNN>.panelist-*.verdict.json
```

Minimum required: one `anthropic` + one non-Anthropic (openai or google).
If a runner exited non-zero (graceful degrade), that vendor is absent — the
gate will fail diversity unless a manual verdict is provided.

### Step 5 — Prompt user to run the gate

Tell the user to run `check-cross-model` to apply the deterministic consensus:

```sh
bash plugins/sdd-quality-loop/scripts/check-cross-model.sh \
  --task <T-NNN> --feature <feature> \
  --evaluator <PASS|NEEDS_WORK> \
  --expect-digest <input_digest_from_step1>

# or pwsh
pwsh plugins/sdd-quality-loop/scripts/check-cross-model.ps1 \
  --task <T-NNN> --feature <feature> \
  --evaluator <PASS|NEEDS_WORK> \
  --expect-digest <input_digest_from_step1>
```

The gate writes `specs/<feature>/verification/<T-NNN>.cross-model.json` and
exits 0 (PASS), 1 (FAIL/NEEDS_HUMAN), or 2 (tool error).

## Graceful Degrade

If `detect-panel` exits 1 (no non-Anthropic CLIs):
- Inform the user: "No non-Anthropic panelist CLIs found. The cross-model gate
  will fail diversity unless you provide a manual verdict JSON."
- Instruct them to manually create
  `specs/<feature>/verification/<T-NNN>.panelist-openai.verdict.json` (or
  google) following the `cross-model-verdict/v1` schema in
  `references/cross-model-verification-policy.md`.

Do NOT crash or block — the user may still proceed to manually provide verdicts.

## Security Reminders

- The sanitized bundle in `panelist-input.txt` must be the ONLY input to each
  panelist. Do not add repo context, agent memory, or prior verdicts.
- `SDD_EVIDENCE_KEY` and `SDD_SUDO_KEY` are never passed to panelists.
- The collection layer never runs in CI (enforced by AC-007).
