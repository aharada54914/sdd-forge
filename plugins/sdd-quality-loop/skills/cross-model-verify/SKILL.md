---
name: cross-model-verify
description: Orchestrate blind parallel cross-model panelist verification for a critical SDD task. Runs prepare-panelist-input (consent + sanitize), invokes panelists blind in parallel (Claude via Agent tool; GPT/Gemini via CLI runners), collects verdict JSONs, then prompts the user to run check-cross-model to gate the result.
disable-model-invocation: false
user-invocable: false
---

# Cross-Model Verify

Use this skill when a task's contract has `cross_model: required` and you need
to collect panelist verdicts before running the deterministic gate.

**Never run this skill in CI.** Collection is local-only and opt-in (design.md §6).

## Managed allocation boundary

Affected policy roles: `evaluator`.

Apply in the allocating parent before an unbound forked Skill/Agent, native role,
or fresh context receives work, and before any identity reservation. This
boundary takes precedence over later native/default launch guidance for these
roles. It does not add an availability or authority gate.

Keep an already admitted managed entry with its validated selection/controls and
matching role, host, run/session and workload. Keep a concretely known matching
batch startup and fixed generated Codex configuration under their original
contracts. An already bound worker continues its original procedure: do not
select again, allocate again, or run this refusal inside that same worker.
A bound parent does not bind a new child, role or session: each new allocation
needs its own admitted selection/carrier binding or takes the refusal below.

When this operation has no admitted binding of the selected model and effort to
its actual native carrier, substitute the next affected policy role and actual
host (`claude-code`, `codex-cli`, `copilot-cli`, or `gemini-cli`) and execute:

```bash
python3 -I -B "<installed-root>"/plugins/sdd-implementation/scripts/managed-model-entry.py unsupported-entry \
  --role "<policy-role>" --host "<host>"
```

Exit 2 with `model-policy-error/v1` / `model-unavailable` stops that allocation
before work or reservation. Do not fall through to an old model hint, alias,
unbound native default or another parent session; do not count allocation alone
as selection proof. This refusal does not assert host incapability and never
authorizes same-session reload. Original host-incapable-only implementation
fallback evidence and all review isolation requirements remain unchanged.

This boundary applies only to the Anthropic blind Agent panelist slot, represented by evaluator policy role. No dedicated managed blind transport is admitted for that slot; ordinary evaluator controls alone do not admit a different workload. Stop that slot before Agent and retain the original panelist-unavailable/graceful-degrade decision. Existing GPT/Gemini consented CLI and native/default routes remain unchanged; do not invent an Anthropic verdict or retry an alias Agent.

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
  --input specs/<feature>/verification/<T-NNN>/ \
  --spec-root specs \
  --max-bytes 1048576

# pwsh
pwsh plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1 \
  --task <T-NNN> --feature <feature> \
  --input specs/<feature>/verification/<T-NNN>/ \
  --spec-root specs \
  --max-bytes 1048576
```

The bundle is composed for the ONE task under review, not discovered by
walking `specs/<feature>/`. It contains:
- the feature's spec documents (requirements/design/acceptance-tests/tasks/
  traceability/investigation + layer specs when present);
- `<T-NNN>`'s own verification contract, `evidence.json`, and
  `verification/<T-NNN>/` evidence directory (`--input` above is this same
  directory — a literal directory-walk of --input no longer happens; it is
  read explicitly by task ID);
- `<T-NNN>`'s own implementation report;
- the CURRENT content of every path `<T-NNN>`'s own report `## Outputs`
  table declares (this is what makes code-level Done When items reviewable
  — not just the implementer's own `ok:` labels).

Other tasks' evidence, quality-gate logs, and mutation transcripts are
never read. The panel's own prior artifacts (`*.panelist-input.txt`,
`*.verdict.json`, `*.cross-model.json`) remain excluded.

`--max-bytes` (optional) is a fail-closed size guard on the FINAL sanitized
bundle — pass the target vendor's known input cap (e.g. `1048576` for
`codex exec`'s character limit). If exceeded, the script writes NO file and
exits nonzero with a byte breakdown on stderr rather than silently
truncating; a panelist that cannot tell its input was cut would report
confident conclusions about material it never saw.

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

The orchestrator must supply current, admitted `<policy-request>` and `<registry>`
paths, a fresh `<run-id>` and `<session-id>`, and an absent, role-specific
`<output-dir>` under the execution-input project. The request must name the
matching role and host below and carry current verified configuration evidence.
Do not reuse another panelist's controls, fabricate discovery, or continue when
these inputs are unavailable. Controlled-adoption requirements still apply;
fixture evidence does not authorize production adoption. Resolve script paths
against the installed package; execute these commands from the input project.

Prepare each vendor independently, then start eligible panelists in parallel.
Preparation failure stops that vendor before its runner. The controls hash comes
from the successful preparation validation, rather than a new hash of possibly
changed controls. Consent kind and digest come from the sanitized bundle;
the original runner rechecks actual consent and bundle bytes before sending.

**GPT panelist** (OpenAI vendor — if `gpt` slug in detect-panel output):

```sh
output='<output-dir>'
bundle='specs/<feature>/verification/<T-NNN>.panelist-input.txt'
python3 plugins/sdd-implementation/scripts/managed-model-entry.py prepare \
  --request '<policy-request>' --registry '<registry>' \
  --role panelist-gpt --host codex-cli --run-id '<run-id>' --session-id '<session-id>' \
  --attempt 1 --output-dir "$output" --require-actual-id false || exit $?
controls_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["controls"]["sha256"])' "$output/validation.json") || exit $?
bundle_meta=$(python3 - "$bundle" <<'META'
from pathlib import Path
import re, sys
header = Path(sys.argv[1]).read_bytes().split(b'\n\n', 1)[0].decode('utf-8')
kind = re.findall(r'^# consent: (human-flag|sudo)$', header, re.M)
digest = re.findall(r'^# input_digest: ([0-9a-f]{64})$', header, re.M)
if len(kind) != 1 or len(digest) != 1:
    raise SystemExit('Invalid sanitized bundle consent or digest')
print(kind[0] + ' ' + digest[0])
META
) || exit $?
consent=${bundle_meta%% *}
digest=${bundle_meta#* }
bash plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh \
  --task <T-NNN> --feature <feature> --input "$bundle" --spec-root specs \
  --consent "$consent" --digest "$digest" \
  --model-controls "$output/controls.json" --model-controls-sha256 "$controls_sha" \
  --run-id '<run-id>' --session-id '<session-id>'
```

```powershell
$ErrorActionPreference = 'Stop'
$output = '<output-dir>'
$bundle = 'specs/<feature>/verification/<T-NNN>.panelist-input.txt'
python3 plugins/sdd-implementation/scripts/managed-model-entry.py prepare `
  --request '<policy-request>' --registry '<registry>' `
  --role panelist-gpt --host codex-cli --run-id '<run-id>' --session-id '<session-id>' `
  --attempt 1 --output-dir "$output" --require-actual-id false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$validation = Get-Content -Raw -LiteralPath "$output/validation.json" | ConvertFrom-Json
$controlsSha = $validation.controls.sha256
$header = ([IO.File]::ReadAllText((Join-Path (Get-Location) $bundle)) -split "`n`n", 2)[0]
$kind = [regex]::Matches($header, '(?m)^# consent: (human-flag|sudo)$')
$digest = [regex]::Matches($header, '(?m)^# input_digest: ([0-9a-f]{64})$')
if ($kind.Count -ne 1 -or $digest.Count -ne 1) { throw 'Invalid sanitized bundle consent or digest' }
$consent = $kind[0].Groups[1].Value
$inputDigest = $digest[0].Groups[1].Value
& plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1 `
  --task <T-NNN> --feature <feature> --input "$bundle" --spec-root specs `
  --consent "$consent" --digest "$inputDigest" `
  --model-controls "$output/controls.json" --model-controls-sha256 "$controlsSha" `
  --run-id '<run-id>' --session-id '<session-id>'
exit $LASTEXITCODE
```

**Gemini panelist** (Google vendor — if `gemini` slug in detect-panel output):

```sh
output='<output-dir>'
bundle='specs/<feature>/verification/<T-NNN>.panelist-input.txt'
python3 plugins/sdd-implementation/scripts/managed-model-entry.py prepare \
  --request '<policy-request>' --registry '<registry>' \
  --role panelist-gemini --host gemini-cli --run-id '<run-id>' --session-id '<session-id>' \
  --attempt 1 --output-dir "$output" --require-actual-id false || exit $?
controls_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["controls"]["sha256"])' "$output/validation.json") || exit $?
bundle_meta=$(python3 - "$bundle" <<'META'
from pathlib import Path
import re, sys
header = Path(sys.argv[1]).read_bytes().split(b'\n\n', 1)[0].decode('utf-8')
kind = re.findall(r'^# consent: (human-flag|sudo)$', header, re.M)
digest = re.findall(r'^# input_digest: ([0-9a-f]{64})$', header, re.M)
if len(kind) != 1 or len(digest) != 1:
    raise SystemExit('Invalid sanitized bundle consent or digest')
print(kind[0] + ' ' + digest[0])
META
) || exit $?
consent=${bundle_meta%% *}
digest=${bundle_meta#* }
bash plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh \
  --task <T-NNN> --feature <feature> --input "$bundle" --spec-root specs \
  --consent "$consent" --digest "$digest" \
  --model-controls "$output/controls.json" --model-controls-sha256 "$controls_sha" \
  --run-id '<run-id>' --session-id '<session-id>'
```

```powershell
$ErrorActionPreference = 'Stop'
$output = '<output-dir>'
$bundle = 'specs/<feature>/verification/<T-NNN>.panelist-input.txt'
python3 plugins/sdd-implementation/scripts/managed-model-entry.py prepare `
  --request '<policy-request>' --registry '<registry>' `
  --role panelist-gemini --host gemini-cli --run-id '<run-id>' --session-id '<session-id>' `
  --attempt 1 --output-dir "$output" --require-actual-id false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$validation = Get-Content -Raw -LiteralPath "$output/validation.json" | ConvertFrom-Json
$controlsSha = $validation.controls.sha256
$header = ([IO.File]::ReadAllText((Join-Path (Get-Location) $bundle)) -split "`n`n", 2)[0]
$kind = [regex]::Matches($header, '(?m)^# consent: (human-flag|sudo)$')
$digest = [regex]::Matches($header, '(?m)^# input_digest: ([0-9a-f]{64})$')
if ($kind.Count -ne 1 -or $digest.Count -ne 1) { throw 'Invalid sanitized bundle consent or digest' }
$consent = $kind[0].Groups[1].Value
$inputDigest = $digest[0].Groups[1].Value
& plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1 `
  --task <T-NNN> --feature <feature> --input "$bundle" --spec-root specs `
  --consent "$consent" --digest "$inputDigest" `
  --model-controls "$output/controls.json" --model-controls-sha256 "$controlsSha" `
  --run-id '<run-id>' --session-id '<session-id>'
exit $LASTEXITCODE
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
