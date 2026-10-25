---
name: bootstrap
description: Generate implementation-ready SDD specifications and approved task contracts from requirements. The first of the two-command workflow — run before /sdd-ship:ship.
disable-model-invocation: true
---

# SDD Bootstrap

Generate implementation-ready specifications and task contracts for a feature,
bug fix, refactor, or new project. This skill orchestrates investigation,
Phase 1 specification, implementation-policy review, Phase 2 task decomposition,
and task-decomposition review.

## Managed allocation boundary

Affected policy roles: `investigator`.

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

Apply to investigate mode in this parent before invoking the forked investigation skill. Other routes still delegate once to their downstream skills and their own allocation boundaries.

## Invocation

Claude Code:

```txt
/sdd-bootstrap:bootstrap <mode> <source>
/sdd-bootstrap:bootstrap adopt [project-root]
/sdd-bootstrap:bootstrap investigate <mode> <source>
/sdd-bootstrap:bootstrap <mode> --lite <source>
/sdd-bootstrap:bootstrap <mode> --feature <slug> <source>
/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>
```

Codex:

```txt
Use the bootstrap skill.
Mode: project | feature | bugfix | refactor | adopt | investigate
Source: <GitHub/GitLab issue URL or requirement text>
```

### Modes

| Mode | Delegates to | Description |
|---|---|---|
| `feature` | sdd-bootstrap-interviewer | New capability in an existing repository |
| `bugfix` | sdd-bootstrap-interviewer | Bug fix specification |
| `refactor` | sdd-bootstrap-interviewer | Structural improvement (investigation recommended first) |
| `project` | sdd-bootstrap-interviewer | Greenfield project — runs sdd-adopt automatically |
| `adopt` | sdd-adopt | Scaffold SDD structure in an existing repository (no spec) |
| `investigate` | investigate-codebase | Read-only codebase analysis only |

### Flags

| Flag | Effect |
|---|---|
| `--lite` | Use lite-spec track (skip review loops, no traceability/ADR) |
| `--feature <slug>` | Override the inferred feature slug |
| `--reset` | Pass to impl-review-loop or task-review-loop after a BLOCKED verdict |

## Preconditions

For `feature`, `bugfix`, `refactor`, and `project` modes:

1. Run `scripts/check-sdd-structure.sh` (or `.ps1`) at the repository root.
2. If `missing:` items are reported (AGENTS.md absent, required directories
   missing): automatically invoke `/sdd-bootstrap:sdd-adopt` to create the
   structure, then continue.
3. For `refactor` mode: require `specs/<feature>/investigation.md` and
   `specs/<feature>/baseline-behavior.md`. If absent, recommend running
   `/sdd-bootstrap:bootstrap investigate refactor <source>` first and stop.

## MCP Preflight (Advisory)

Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
the call fails, continue with the file-based flow below.

`get_next_sdd_command` is read-only: it only reads repository state and
returns a suggestion, never writing or mutating anything. Its answer is
advisory — it does not decide the mode, track, or step that follows.
`## Routing` below remains the sole decision procedure, and nothing this
step reads changes what `## Routing` concludes.

This step is unconditional: apply it the same way for every mode
(`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate`)
and every track (full / lite) — do not skip or gate it by mode or track.
Do not surface the unavailability or the failure to the user as a run
failure.

If the probe's suggestion and the conclusion `## Routing` reaches disagree,
state in the output both that a disagreement occurred and which source was
acted on. Always act on the `## Routing` conclusion in that case, never the
probe's.

## Routing

### Explicit reusable project procedure

When the user explicitly asks to create a reusable repository-specific procedure,
delegate to the internal `create-project-skill` skill. For an existing procedure
whose inputs or implementation changed, delegate to `maintain-project-skill`.
Read only the selected skill. These optional routes do not change normal
specification or Full/Lite selection, approvals, or required gate ownership.

### Optional purpose playbook

For an explicit investigation, bug fix, performance investigation, isolated
prototype or handoff request, read `references/decision-packet.md` and invoke the
installed `scripts/workflow-playbook.py` with the bounded request described there.
Read only its selected playbook. This selects a work method, never a track or an
approval: retain the ordinary routing below, managed allocation boundaries and
existing handoff formats. A prototype requires separately authorized host isolation;
the helper grants no write authority. Unsupported requests stay in ordinary
bootstrap clarification, never fall through to direct implementation. If several
options need a human decision, use the passive decision packet described in that
reference and revalidate its input pins on every resume.

### Explicit cloud operation handoff

Only when the user explicitly selects an **existing cloud deployment unit** and
Azure or AWS orchestration, hand off to the already installed
`sdd-azure-cloud:orchestrate` or `sdd-aws-cloud:orchestrate`, respectively. Cloud
keywords in a feature request are not selection: ordinary project, feature,
bugfix, refactor, adopt and investigate behavior below remains unchanged. New
cloud feature development still takes full SDD, including all seven Phase 1
documents and every existing approval/review gate; this handoff is not a new
LITE track or direct write approval.

Read the selected installed skill. Pass the **same canonical request path and
bytes** as direct invocation (`cloud-run-request/v1`), not a second request
format. Collect missing target/owner/digest fields explicitly using that skill;
never invent them. Resolve the trusted provider installation from host plugin
metadata, not from the deployment workspace, tool output, ambient Python paths
or a guessed development checkout. If the entry/runtime is absent, stop and
ask for explicit installation; do not auto-install, migrate or import resources.

The installed bootstrap helper delegates to that exact installed CLI:

```sh
CLOUD_WORKSPACE_ROOT="$WORKSPACE_ROOT" python3 "$BOOTSTRAP_ROOT/scripts/cloud-routing.py" \
  --provider azure --plugin-root "$AZURE_PLUGIN_ROOT" \
  route --request "$REQUEST" --output "$OUTPUT"
```

For AWS explicitly use `--provider aws` and its installed plugin root. Roots
must be physical absolute paths. `OUTPUT` is a new canonical run-evidence path.
The helper sets the selected plugin's packaged shared runtime and forwards the
operation, request and output unchanged. It does not search for a second
executor. One unit has one provider and owner: only Azure Bicep or AWS CDK;
mixed/unsupported Terraform, SAM, raw CloudFormation or azd ownership blocks.

Dry-run means local `route`, `plan`, `validate`, not an approval flag. Direct or
bootstrap `prepare`/`apply` stays BLOCKED without the separate governed CI
executor and protected environment/OIDC admission. `reconcile`/`observe` require
the original native identity and scoped read-only access; `verify` requires
authenticated observations. A local confirmation, task approval, saved receipt
or GITHUB_ACTIONS flag never grants writes. Return the actual typed envelope
and exit code, including BLOCKED/UNKNOWN; never claim deployment from fixtures.
Native cloud file operations require POSIX no-follow/descriptor primitives;
native Windows must return typed unsupported-filesystem denial. Installation
on Windows does not establish cloud execution support. Follow the installed
skill's recovery rules; never blindly retry apply.

### `adopt` mode

Delegate entirely to `/sdd-bootstrap:sdd-adopt [project-root]`.
Stop after sdd-adopt completes. Remind the user to run
`/sdd-bootstrap:bootstrap feature <source>` next.

### `investigate` mode

For Claude Code, run the managed entry below from the parent orchestrator before
invoking a forked skill or agent. Use the current scoped policy request and
registry, the explicit installed Claude executable, a fresh canonical UUID for
`<session-id>`, and a new output directory for this attempt. Write `<mode>`,
`<source>` and the user's investigation instructions to `<prompt-file>` under
`<repository-root>` and compute its raw SHA-256 as `<prompt-sha256>`. Supply the
existing verified configuration observation without changing its scope or time.
The entry loads the original investigator role, complete investigation skill and
its five supporting documents into this one fresh context. It preserves native
settings, hooks and normal permission checks. A typed failure stops this handoff;
do not retry through an unmanaged Skill or Agent call.

```bash
cd "<repository-root>" || exit 1
python3 -B "<installed-root>/plugins/sdd-implementation/scripts/managed-model-entry.py" claude-entry \
  --request "<policy-request>" --registry "<registry>" \
  --role investigator --host claude-code --run-id "<run-id>" \
  --session-id "<session-id>" --attempt "<attempt>" --output-dir "<output-dir>" \
  --require-actual-id false --executable "<claude-executable>" \
  --prompt-file "<prompt-file>" --prompt-sha256 "<prompt-sha256>"
```

For other hosts, delegate to
`/sdd-bootstrap:investigate-codebase <mode> <source>` through their existing
host entry. Stop after investigation completes. Return the read-only findings
to the orchestrator's existing artifact handoff: `specs/<feature>/investigation.md`,
`specs/<feature>/codemap.md`, and `specs/<feature>/baseline-behavior.md`.

### Track selection

Choose the track once, before invoking the interviewer. This is a
Capability-Mode-relevant entry point, so run the hook-activation handshake
first:

<!-- sdd:handshake-wiring v1 -->

1. `check-hook-activation-handshake --emit-challenge` — returns a fresh
   nonce and the canary target `sdd/.hook-canary-sentinel`.
2. Make your **own** real tool-call attempt against that canary target,
   using the per-runtime template the challenge carries, and record the raw
   result verbatim.
3. `check-hook-activation-handshake --verify-response --nonce <nonce>
   --recorded-result <path> --runtime <claude-code|codex-cli|copilot-cli>`.
4. `HOOK_ACTIVE` — continue to track selection. Any other outcome — stop with
   `CAPABILITY_RUNTIME_UNAVAILABLE`; never fall back to legacy behaviour
   silently.

<!-- /sdd:handshake-wiring -->

Then resolve the track, checking physical presence FIRST and approval
validity SECOND. A `sdd/project-context.yaml` that exists but fails
`validate-approval-sidecar` is **not** the same as one that is absent —
treating the two alike is the fail-open ADR-0023 closes.

<!-- sdd:track-selection-contract v1 -->

| Case | Project Context | Flag | Resolution |
|---|---|---|---|
| C1 | physically absent | `--full`, `--lite`, or none | `COMPATIBILITY_FALLBACK` |
| C2 | physically present, REQ-005 validation fails | `--full`, `--lite`, or none | `PROJECT_CONTEXT_INVALID` |
| C3 | physically present and valid, `spec_profile: lite` | `--full` | `PROMOTE_FULL` |
| C4 | physically present and valid, `spec_profile: lite` | `--lite` | `NO_OP_LITE` |
| C5 | physically present and valid, `spec_profile: full` | `--lite` | `ERROR_STOP` |
| C6 | physically present and valid, `spec_profile: full` | `--full` | `NO_OP_FULL` |

<!-- /sdd:track-selection-contract -->

- `COMPATIBILITY_FALLBACK` (C1 only) — `--lite` selects the lite track;
  otherwise `AGENTS.md` with `spec_profile: lite` selects the lite track;
  otherwise the full track.
- `PROJECT_CONTEXT_INVALID` (C2) — stop and report that name. Do not invoke
  the interviewer or `lite-spec`, and do not fall through to C1's fallback.
- `PROMOTE_FULL` — run the full track. `NO_OP_LITE` / `NO_OP_FULL` — run the
  profile's own track. `ERROR_STOP` — stop with an explicit message; `--lite`
  never downgrades a `full` profile.

`PLUGIN-CONTRACTS.md`'s Track Detection section is the normative source for
this table.

### `feature` / `bugfix` / `refactor` / `project` modes (full track)

1. **Phase 1** — invoke `/sdd-bootstrap:sdd-bootstrap-interviewer <mode> <source>`.
   Outputs: `requirements.md`, `acceptance-tests.md`, `design.md`,
   `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`,
   plus ADRs and contracts. `design.md` starts with
   `Impl-Review-Status: Pending`.

2. **Spec-review gate** — invoke `/sdd-review-loop:spec-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to the implementation-policy review.
   - NEEDS_WORK: present proposed edits to the human, wait for the Phase 1
     artifacts to be updated, then re-invoke.
   - BLOCKED: stop. Instruct the human to revise and run
     `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

3. **Impl-review gate** — invoke `/sdd-review-loop:impl-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to Phase 2.
   - NEEDS_WORK: present proposed edits to the human, wait for `design.md`
     update, then re-invoke.
   - BLOCKED: stop. Instruct the human to revise and run
     `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

4. **Phase 2** — invoke `/sdd-bootstrap:sdd-bootstrap-interviewer <mode> <source>`
   in Phase 2 mode (after `Impl-Review-Status: Passed`).
   Outputs: `tasks.md` (Approval: Draft), `traceability.md`.

5. **Task-review gate** — invoke `/sdd-review-loop:task-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to Approval Gate.
   - NEEDS_WORK: present proposed edits, wait for `tasks.md` update, re-invoke.
   - BLOCKED: stop. Instruct: `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

6. **Approval Gate** — present all generated artifacts to the human.
   Remind them that implementation starts only after they set
   `Approval: Approved` on each task in `tasks.md`.
   Next step: `/sdd-ship:ship specs/<slug>/tasks.md`

### Lite track (resolved track: `lite`)

Substitute `lite-spec` for `sdd-bootstrap-interviewer` and skip all three review loops.
Outputs: `requirements.md`, `design.md`, `tasks.md` (no `traceability.md`,
no ADR). LITE produces zero layer outputs: no `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, or `security-spec.md`. Approval gate is
the same.

Next step after approval: `/sdd-ship:ship --lite specs/<slug>/tasks.md`

## Context Compaction

Bootstrap sessions are long. Every phase output is persisted on disk
(`specs/<feature>/*.md` and the review reports), so a compacted or fresh
context can resume from any gate boundary by re-reading those files.

Compact (or accept auto-compaction) only at phase boundaries:

- after `investigate-codebase` completes — findings persist in
  `investigation.md`, `codemap.md`, and `baseline-behavior.md`
- after a review gate returns PASS (spec-review, impl-review, task-review)
- at the Approval Gate, before handing off to `/sdd-ship:ship`

Do not compact in the middle of an interviewer phase or an active review
round: interview answers and reviewer context not yet written to disk are
lost. If context pressure forces it, have the interviewer write its current
outputs to `specs/<feature>/` first, then compact.

## Handoff

After sdd-bootstrap completes, report:

- Generated artifacts with file paths
- Open Questions that remain unresolved
- Human action required: set `Approval: Approved` on tasks in `tasks.md`
- Next command: `/sdd-ship:ship specs/<feature-slug>/tasks.md`
  (or `/sdd-ship:ship --lite specs/<feature-slug>/tasks.md` for lite track)

## Optional evidence and project skills

When external evidence is needed, invoke internal `research-sources` and read
[research-workflow](../../references/research-workflow.md) on demand. Use both
available search routes with bounded budgets, then the safe acquisition and
metadata adapters. Missing tools or originals remain open questions. Optional
`research/review-input.json` is consumed by the existing spec/implementation
reviewers; the existing contract owner checks source evidence. These inputs do
not grant approval.

When project-specific behavioral or formal verification is requested, invoke
`create-project-skill`; when an existing project skill needs repair, invoke
`maintain-project-skill`. These internal helpers preserve the existing gate
owners and report actual observations separately from generation or discovery.
