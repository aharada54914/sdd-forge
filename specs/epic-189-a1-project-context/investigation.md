# Investigation: epic-189-a1-project-context

Source: Epic A1 (`docs/ai-dlc-foundation-decision-v2.md` §19), tracking issue
#187, Epic A0 issue #188, issue #189 ("Project Context + 承認防衛"). Read-only
survey of `main` lineage (worktree `feature/epic-189-a1-project-context`).
Paths cited relative to the repository root; line numbers verified against
the files as read during this investigation (2026-07-21).

## INV-001: Current track-selection contract (CLI-flag priority)

**File**: `PLUGIN-CONTRACTS.md:61-66`

```text
### Track Detection (priority order)

1. `--full` flag → FULL (verifies acceptance-tests.md + traceability.md exist)
2. `--lite` flag → LITE
3. `spec_profile: lite` in AGENTS.md → LITE
4. Default → FULL
```

This is the section ADR-0023 (Track Selection Contract Migration) targets for
revision: a CLI flag currently outranks any project-level declaration, which
conflicts with ADR-0016's rule that `project-context.yaml.workflow` becomes
the sole source of truth for `spec_profile` once a Project Context exists.

## INV-002: Track-selection consumers (current CLI-flag-first behavior)

- **`sdd-ship` (`plugins/sdd-ship/skills/ship/SKILL.md:76-117`)** implements
  the identical priority order as prose: `--full` flag (line 80) → risk-upgrade
  scan (lines 85-107, `--full` is the only bypass) → `--lite` flag (line 109)
  → `AGENTS.md` `spec_profile: lite` marker (lines 110-111) → default FULL
  (line 112). `plugins/sdd-ship/skills/ship/SKILL.md` is itself an
  R-10-protected file (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`,
  entry `'plugins/sdd-ship/skills/ship/SKILL.md'`), so any edit to its Track
  Detection section must go through the human-copy procedure (ADR-0011).
- **`sdd-bootstrap-interviewer`, via `sdd-bootstrap/bootstrap` (`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:80-132`)**
  selects the track once, before invoking the interviewer, with the same
  priority (`--lite` flag → `AGENTS.md` `spec_profile: lite` → full, lines
  84-86); `sdd-bootstrap-interviewer` itself reads `spec_profile: lite` three
  more times to decide whether to skip a review gate
  (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:147,159,199`).
  `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` and
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` are NOT
  present in `PROTECTED_GATE_SUFFIXES` (verified against
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` — a
  direct grep for both basenames returns no match), so both are
  agent-editable directly.
- **The lite-track family (`plugins/sdd-lite/`)**: `plugins/sdd-lite/skills/lite-spec/SKILL.md:48`
  states "`--lite` never overrides this decision" for its own risk-upgrade
  gate, i.e. it already treats a full-track signal as stricter-only —
  consistent with, but predating, ADR-0023's general rule.
  `plugins/sdd-lite/skills/lite-spec/SKILL.md` IS R-10-protected
  (`guard_invariants.py:4`, entry
  `'plugins/sdd-lite/skills/lite-spec/SKILL.md'`); `plugins/sdd-lite/skills/lite-gate/SKILL.md`
  is NOT in that list (verified: no `lite-gate` entry present) and is
  agent-editable directly.
- `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:61` also branches
  on `spec_profile: lite`, but that file is R-10-protected
  (`impl-review-loop/SKILL.md` in `guard_invariants.py:4`) and out of Epic
  A1's scope (it reads the profile, it does not implement track *selection*;
  no per-user Task 1 REQ names it as a migration target).

Summary: three consumer surfaces are named in scope (`ship`,
`bootstrap-interviewer`, "lite 系"); of the concrete files backing them,
`plugins/sdd-ship/skills/ship/SKILL.md` and
`plugins/sdd-lite/skills/lite-spec/SKILL.md` are protected and require
human-copy; `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`,
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`, and
`plugins/sdd-lite/skills/lite-gate/SKILL.md` are unprotected and
agent-editable directly.

## INV-003: Existing HMAC precedent #1 — `SDD_SUDO` (`sudo_active`)

**File**: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:330-486`

- `_parse_sudo_fields` (lines 330-338): parses `key: value` lines from the
  `SDD_SUDO` flag file into a dict.
- `_resolve_sudo_key` (lines 350-380): key-resolution priority — (1) env
  `SDD_SUDO_KEY`, (2) env `SDD_SUDO_KEY_FILE` (file read, BOM/whitespace
  stripped by `_strip_key_bytes`, lines 341-347), (3)
  `<HOME>/.sdd/sudo-key`, (4) `None` (no key ⇒ fail-closed).
- `_sudo_canonical` (lines 383-390): canonical preimage is five fields
  (`issuer`, `nonce`, `repo`, `issued-epoch`, `expires-epoch`) LF-joined, in a
  fixed order — a hand-rolled canonicalization, not YAML/JSON-based.
- `sudo_active` (lines 393-486): validates file-not-symlink (`O_NOFOLLOW`),
  required fields present, nonce format (`^[0-9a-fA-F]{32,}$`), issued/expiry
  epoch bounds (TTL ≤ 86400s, line 458), repo-binding via `os.path.realpath`
  equality (lines 461-471), then HMAC-SHA256 verification with
  `hmac.compare_digest` (lines 478-481).

This is the direct precedent decision-doc §9 cites for the approval sidecar's
external-key HMAC and TTL/cooldown mechanics (env-var → env-var-pointing-to-file
→ fixed home path → none; constant-time compare; repo-binding).

## INV-004: Existing HMAC precedent #2 — `SDD_EVIDENCE_KEY` (evidence bundle)

**File**: `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh:1-404`

- The `.sh` entry point (lines 1-35) is a POSIX dispatcher that, when
  `python3` is available, execs a single embedded Python heredoc
  (`python3 - <<'PYEOF' ... PYEOF`, line 35) containing the entire
  implementation — i.e. one canonical Python implementation, invoked from a
  thin shell wrapper. `generate-evidence-bundle.ps1` (separately checked, not
  a dispatcher — a full native PowerShell re-implementation) is the one
  precedent in this repository that does NOT follow the "single
  implementation + thin wrapper" shape; decision-doc §18.3 explicitly directs
  the *canonicalizer* to follow `sdd-hook-guard.sh`'s dispatcher shape
  instead (INV-005), not this script's.
- `resolve_evidence_key` (lines 314-338): identical four-step priority order
  to `_resolve_sudo_key` — env `SDD_EVIDENCE_KEY`, env
  `SDD_EVIDENCE_KEY_FILE`, `<HOME>/.sdd/evidence-key`, `None`.
- `evidence_canonical` (lines 340-367): builds a canonical preimage from a
  fixed, ordered list of bundle fields (`task_id`, `feature`, `risk`,
  `required_workflow`, `spec_revision`, `git_commit`,
  `git_generated_dirty`, `review_verdict.verdict`, and a
  sorted-and-rejoined `artifacts` digest) — again a hand-rolled, field-order
  canonicalization, not YAML 1.2/JCS.
- Signing (lines 389-399): only bundles with `contract_risk == "critical"`
  are HMAC-signed; the `hmac.new(key_bytes, canonical.encode("utf-8"),
  hashlib.sha256).hexdigest()` value is stored at `bundle["signature"]`,
  alongside `key_ref` recording which resolution step supplied the key.

Both precedents (INV-003, INV-004) independently resolve keys via the same
env-var → env-file → home-path → none order and sign with `hmac-sha256` +
constant-time compare; the approval-sidecar HMAC (REQ-004) follows the same
shape with its own env-var names, per the user's directive to use "the same
family" of resolution order.

## INV-005: `sdd-hook-guard.sh` dispatcher shape (canonicalizer precedent)

**File**: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh:1-53`

The POSIX entry point validates the generated provenance shim
(`generated/guard-invariants.generated.sh`, lines 28-32), reads stdin once
(line 34), then delegates to `python3 sdd-hook-guard.py "$@"` if `python3` is
on `PATH` (lines 36-38), else falls back through `pwsh` / `powershell.exe` /
`powershell` running `sdd-hook-guard.ps1` (lines 41-50), else denies
(`deny_unavailable`, lines 17-24). This is the "Python single implementation
+ thin `sh`/`ps1`/`js` wrapper" shape decision-doc §18.3 names explicitly
("`sdd-hook-guard.sh` 方式の踏襲") for the canonicalizer (REQ-003): unlike
`generate-evidence-bundle.ps1` (INV-004), there is exactly one behavioral
implementation (`sdd-hook-guard.py`), and every other runtime entry point
only locates and invokes it (or denies fail-closed if none is available).

## INV-006: `guard-invariants` generation flow and its exact-match validation

- **Canonical source**: `plugins/sdd-quality-loop/references/guard-invariants.json`
  (86 lines) — `protected_gate_suffixes` (37 entries), `protected_gate_plugin_json_suffixes`
  (3 entries), `shell` (regex/array constants for the hook's shell-command
  parser), `sudo_signature_hex_length: 64`, `phase2_human_copy_targets` (18
  entries).
- **Generator**: `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:1-296`.
  `load_and_validate` (lines 129-167) does not merely schema-check the JSON —
  it enforces an **exact-match** invariant against Python-hardcoded
  constants: `BASELINE_SUFFIXES` (lines 57-88, 27 entries — the pre-Phase-2
  protected set) and `PHASE2_TARGETS` (lines 37-56, 18 entries — the Phase-2
  self-protection additions), combined as
  `expected_protected = BASELINE_SUFFIXES + (v for v in PHASE2_TARGETS if v
  not in BASELINE_SUFFIXES)` (line 145); line 146-147 raises
  `"protected_gate_suffixes must be the exact baseline/inventory union"` if
  the live JSON's list does not equal this tuple exactly, in order. The same
  applies to `phase2_human_copy_targets` (lines 153-157) against the same
  `PHASE2_TARGETS` constant.
  **Consequence for Epic A1**: adding new protected paths (the approval
  sidecars, the approver registry, and the new canonicalizer/validator/
  weakening-detector scripts) requires editing `generate-guard-invariants.py`
  itself (to extend the constant `expected_protected` is checked against),
  in the SAME change as editing `guard-invariants.json` — a JSON-only edit
  would fail `load_and_validate` (and therefore `--check`, INV-007) even if
  every other file were internally consistent. Both files are themselves
  R-10-protected (`guard_invariants.py:4`, entries
  `'plugins/sdd-quality-loop/references/guard-invariants.json'` and
  `'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'`), so this
  edit must be staged and applied via human-copy, not written directly.
- **Generated outputs** (`expected_outputs`, lines 255-261, each protected):
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` (Python
  tuple module, sha256-headed, "This file is generated. Do not edit." —
  verified header format at
  `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-2`),
  `guard-invariants.generated.js` (frozen `module.exports` object),
  `guard-invariants.generated.ps1` (ordered hashtable), and
  `guard-invariants.generated.sh` (a "dispatcher provenance module" that
  intentionally exposes no decision constants, only a schema version and a
  source sha256 — consumed by `sdd-hook-guard.sh:28-32`, INV-005).
- **Matching semantics**: `_is_protected_gate_file`
  (`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:976-989`) does
  case-insensitive, `normpath`-normalized **suffix** (`str.endswith`)
  matching against `_PROTECTED_GATE_SUFFIXES` — a fixed repository-relative
  filename anywhere under the tree matches regardless of the invoking
  directory, which is why a stable filename convention (e.g.
  `sdd/project-context.approval.json`) is sufficient to protect the file
  without a full-path anchor.

## INV-007: CI wiring of the generator and workflow-state validators

**File**: `.github/workflows/test.yml`

- 3-OS matrix (`windows-latest`, `macos-latest`, `ubuntu-latest`; lines
  15-19).
- `generate-guard-invariants.py --check` runs on every OS (lines 27-35, split
  Windows/POSIX steps) — this is what fails if `guard-invariants.json`,
  `generate-guard-invariants.py`, or any of the four generated files drift
  from each other.
- `check-workflow-state.ps1`/`.sh` run on every OS (lines 48-55).
- `tests/validate-repository.ps1`/`.sh` run on every OS (lines 57-64).

## INV-008: `check-workflow-state.sh` — the Phase-2/`tasks.md` gating rule

**File**: `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:650-718`

For every non-`lite`, non-`legacy` registry entry (`profile: full`):
`requirements.md`, `design.md`, `acceptance-tests.md` must exist (lines
657-660); `spec`/`impl` are read from their `Spec-Review-Status`/
`Impl-Review-Status` headers and must each be `Pending` or `Passed` (lines
661-674). **Line 681-682 is unconditional on file existence, not on the
`Task-Review-Status` value inside the file**:
`[[ ! -f "$tasks" || ( "$spec" == Passed && "$impl" == Passed ) ]] ||
diagnostic ... "tasks.md requires Spec and Impl Passed"` — i.e. if
`tasks.md` exists at all, `Spec-Review-Status` and `Impl-Review-Status` must
already both read `Passed`, regardless of what `tasks.md`'s own
`Task-Review-Status` says. This mirrors the documented workflow: `tasks.md`
is a Phase 2 artifact, generated only "after `Impl-Review-Status: Passed`"
(`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md:88-112`, step 4: "Phase 2 —
... (after `Impl-Review-Status: Passed`). Outputs: `tasks.md` (Approval:
Draft)"), and epic-159-pillar-c's own Non-goals state the identical rule in
prose: "tasks.md and traceability.md (Phase 2 artifacts, authored after spec
approval)" (`specs/epic-159-pillar-c/requirements.md:423-424`).
`traceability.md` carries no equivalent existence check anywhere in
`check-workflow-state.sh` (verified: no `traceability` string appears in the
file), so its presence does not trigger this rule.

**Resolution (coordinator decision, 2026-07-22)**: this package originally
included a Draft `tasks.md`/`traceability.md` alongside
`Spec-Review-Status: Pending`/`Impl-Review-Status: Pending`, which made
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh` (and its `.ps1`
twin, and `tests/validate-repository.ps1`, which calls it) fail once
`epic-189-a1-project-context` was registered with `profile: full` in
`specs/workflow-state-registry.json` — exactly as this INV predicted. The
coordinator ruled to follow the repository's Phase model rather than work
around it: `tasks.md` and `traceability.md` were removed from this
package's committed content (their Draft content preserved outside the
repository, at
`/private/tmp/claude-501/-Users-jrmag-Setup/0097dba4-ac85-43c6-8e5c-271e593ecdeb/scratchpad/a1-tasks-draft.md`
and `a1-traceability-draft.md`, for reintroduction once
`spec-review-loop`/`impl-review-loop` actually reach `Passed` against this
package — a future implementation session's Phase 2 step). REQ↔Test
correspondence in the interim is carried by `acceptance-tests.md`'s own
Requirement/Test-ID columns, which needs no `tasks.md` to exist.

## INV-009: Task lifecycle field syntax `check-workflow-state.sh` enforces

**File**: `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:683-710`

- Valid `Approval:` values: `Draft`, `Approved`, or `Approved (...)` (line
  688) — `Pending` is not a valid `Approval:` value anywhere in this script.
- When `Task-Review-Status` is `Pending` (lines 701-710), every task's
  `Approval:` must be `Draft` and every `Status:` must be `Planned` — no
  other combination is legal for an unreviewed task plan.
- `approval_count` must equal `status_count` (line 698) — every task needs
  both fields present.

This fixes `tasks.md`'s required per-task fields for this package: `Approval:
Draft`, `Status: Planned`, for every `T-NNN` (never `Approved`, matching the
parent task's explicit prohibition).

## INV-010: `workflow-state-registry` entry shape and registration precedent

**Files**: `contracts/workflow-state-registry.schema.json`,
`specs/workflow-state-registry.json`

A non-legacy entry is `{"feature": "<slug>", "profile": "full" | "lite"}`
only (`contracts/workflow-state-registry.schema.json:459-497`, the first
`oneOf` branch requires exactly `feature` + `profile`, `additionalProperties:
false`). Recent full-profile epics
(`epic-159-pillar-a`, `epic-159-pillar-a2`, `epic-159-pillar-b`,
`epic-159-pillar-c`, `epic-159-pillar-d`) are appended at the end of the
`entries` array in landing order, not re-sorted alphabetically
(`specs/workflow-state-registry.json:337-355`) — the same convention this
package's registration follows.

## INV-011: Human-copy precedent — two distinct mechanisms

- **Per-spec staging (the mechanism this epic's tasks use)**:
  `specs/epic-159-pillar-c/human-copy/` stages corrected content for the four
  protected review-loop reviewer `.md` files and for
  `.github/workflows/test.yml`, each with a `MANIFEST.sha256` entry; a human
  maintainer runs `cp` and verifies the SHA-256 manually (no dedicated
  applier script in that directory — confirmed: `find
  specs/epic-159-pillar-c/human-copy -type f` lists only staged targets and
  `MANIFEST.sha256`, no `.ps1`/`.sh` applier).
  `specs/epic-136-phase2-gates/human-copy/` follows the identical staging
  shape for its own targets.
- **The one-time bootstrap installer**:
  `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` (653
  lines) is a separate, far more elaborate mechanism: an embedded C#
  `AnchoredCopySession` (ADR-0011) that opens the repository root via
  `NtCreateFile`, validates the staged canonical inventory against either a
  frozen `$BootstrapTargets` list (`-Bootstrap` mode) or the live
  `guard-invariants.json` (non-bootstrap mode), verifies manifest SHA-256s,
  and atomically renames temp files into place. This script is itself
  R-10-protected AND is one of the fixed `PHASE2_TARGETS`
  (`generate-guard-invariants.py:55`), i.e. it is pinned to the specific
  18-file Phase-2 bootstrap inventory (`$BootstrapTargets`,
  `apply-protected-files.ps1:11-30`) — it is not a generic per-PR human-copy
  applier and is out of this epic's edit scope.

**Revision (closes B6 — resolves the contradiction between this INV's prior
"Epic A1 uses the simpler per-spec staging shape" conclusion and REQ-007's
anchored-publisher requirement)**: Epic A1's own tasks do NOT use the first
bullet's bare-`cp`, per-spec staging shape for APPLYING staged candidates.
REQ-007 generalizes that precedent into an anchored-publisher-equivalent
tool, `apply-human-copy.{sh,ps1}` (ADR-0011-generalized — held handle,
handle-relative traversal, temp-rehash, atomic rename, no path-copy
fallback), which every human-copy application this epic's tasks stage
(guard-invariants registration, sidecar-signature publication,
`PLUGIN-CONTRACTS.md` consumers' skill-file edits, `.github/workflows/test.yml`
registration) is applied through — never a bare `cp`. The ONE exception is
`apply-human-copy` itself: since no anchored-publisher tool exists yet to
apply IT, its own FIRST installation is bootstrapped via a single,
human-verified plain `cp` + SHA-256 check (mirroring how
`apply-protected-files.ps1` was itself originally installed, this INV,
second bullet) — after that one-time bootstrap, `apply-human-copy` is
self-hosting, and every SUBSEQUENT human-copy application in this epic goes
through it, never reverting to a bare `cp`.

## INV-012: Test-suite pairing and registration convention

**File**: `tests/run-all.sh:1-64`

Every entry in the `tests=( ... )` array (lines 8-56) is a `.sh` suite; the
POSIX runner also separately invokes `tests/guard-r10-port.tests.ps1` under
`pwsh` if available (lines 59-65) as a cross-runtime guard-parity check. Each
`.sh` suite in this array has a same-named `.ps1` twin registered in
`tests/run-all.ps1` (not modified in this investigation, referenced by
convention — e.g. `agent-model-routing.tests.sh`/`.ps1`,
`render-agent-frontmatter.tests.sh`/`.ps1`, both present in the array) and a
corresponding step pair in `.github/workflows/test.yml`
(`Verify ... (Windows)` / `... (POSIX)` shape, INV-007). New suites this
epic adds follow the same `.sh`+`.ps1` pairing, registered directly in
`tests/run-all.sh`/`.ps1` (both unprotected), with their `.github/workflows/test.yml`
step additions staged via human-copy (INV-011) because that file is
R-10-protected (`guard_invariants.py:4`).

## INV-013: Risk classification precedent

**File**: `plugins/sdd-quality-loop/references/risk-classification-policy.md`

Four tiers (`low`/`medium`/`high`/`critical`) map to required workflows
(`test-after`/`acceptance-first`/`tdd`/`tdd`+two-person+signed-evidence,
lines 12-17). `high` explicitly names "authentication/authorization ...
secrets handling ... anything where a silent defect causes material harm" —
the classification this epic's HMAC-signing, hook-guard-extension, and
guard-invariants-registration tasks are evaluated against in tasks.md.

## INV-014: `.gitattributes` line-ending normalization (existing defense)

**File**: `.gitattributes:1-9`

`* text=auto eol=lf` plus explicit `eol=lf` rules for `.sh`/`.ps1`/`.js`/
`.py`/`.json`/`.md`/`.yml`/`.toml` are already in place. Decision-doc §18.3
treats this as an existing, sufficient defense against CRLF-induced hash
drift (a canonicalizing YAML/JSON parse plus NFC normalization removes
byte-level line-ending sensitivity regardless), so REQ-003 does not need to
add new `.gitattributes` rules.

## INV-015: `sdd-hook-guard.py`'s actual invocation contract (host-mediated
`PreToolUse`, not a subprocess-observable event)

**File**: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1401-1524`

`main()` reads a JSON payload from stdin (or the `PAYLOAD` env var,
`sdd-hook-guard.py:1413-1423`) shaped `{"tool_name": ..., "tool_input":
...}` — this payload describes a tool call the HOST RUNTIME's own
`PreToolUse` hook dispatch is about to execute on behalf of the AGENT
SESSION, not a description of anything a plain child process did. The
guard's decision reaches the host via one of two documented output modes
(`parse_args`, `sdd-hook-guard.py:34-36`): `--emit exit` (default; allow =
exit 0, deny = a reason on stderr + exit 2 — the shape a shell-mediated
`PreToolUse` hook script is expected to use) or `--emit copilot` (always
prints `{"permissionDecision": ...}` JSON to stdout and exits 0 — a shape
suited to a runtime that inspects structured output rather than an exit
code). **Consequence for Epic A1's hook-activation handshake (REQ-010)**:
a standalone script (`check-hook-activation-handshake.py`, run as an
ordinary subprocess via `python3 <script>.py`) performing its OWN file
write is never piped through this `PreToolUse` payload path at all — its
write succeeds or fails purely on OS-level file permissions, which are
unrelated to whether the host's hook is actually installed and wired to
invoke `sdd-hook-guard.py` before a REAL agent-proposed tool call. The only
way to observe genuine hook installation is for the AGENT SESSION ITSELF
to propose a real tool call (`Edit`/`Write`/`Bash`/`apply_patch`) that the
host's own dispatch intercepts and pipes to the guard — this is the fact
REQ-010's redesigned host-side canary challenge/response protocol (design.md
Design Decisions) is built on, and the reason a prior draft's
subprocess-file-I/O probe design could not have proven what it claimed to
prove.

**Defense-tier scope (closes B4)**: closing the standalone-script blind spot
above makes the challenge/response *verification logic* correct against a
synthetic, fixture-recorded evidence file (a footgun guard: it stops an
agent from trusting `HOOK_ACTIVE` on the strength of its own unmediated
subprocess I/O). It is NOT, by itself, proof that any given LIVE host
actually intercepts and denies a REAL agent-proposed tool call at runtime —
that is an empirical claim about the host's own `PreToolUse` wiring, which
this spec-authoring session has no live host to observe. Per decision doc
§9 v2's two-tier defense scope, that live-host, cross-runtime observation
is Epic A8's own mandatory Done condition (REQ-010, requirements.md,
Non-goals), not A1's — A1's Done condition is scoped to the verification
logic's correctness, never to "an actual hook fired," a claim this
investigation and REQ-010 no longer make unconditionally.

## Open Questions

- OQ-001 — Where should the "approver registry" (decision-doc §9: "approver
  registry に2名以上の実在identityが登録されている場合のみ"二者承認を必須化)
  live? No existing file or schema in this repository names it. REQ-006
  defines `sdd/approver-registry.yaml` (new, protected) as its home, since
  no earlier ADR or Foundation epic defines a candidate location and the
  policy-weakening detector cannot function without one — see design.md
  Design Decisions.
- OQ-002 — Should `distribution_channels`/`data_classification` be
  component-scalar strings or arrays? ADR-0020's DSL example uses
  `in`/`contains` operators against these fields (`operator: contains`,
  `operator: in`), which only make sense against array-valued fields
  (`contains`: "array ∋ scalar"; `in`: "scalar ∈ array literal" — a
  scalar field could only ever use `equals`/`not_equals`). REQ-001
  resolves this as arrays-of-string, to keep both operators meaningful — see
  design.md Design Decisions.
- OQ-003 — INV-008's tension (`tasks.md` vs. `check-workflow-state.sh`) —
  RESOLVED by coordinator decision (2026-07-22): follow the repository's
  Phase model exactly; `tasks.md`/`traceability.md` are deferred to Phase 2
  and removed from this package's committed content (Draft preserved
  outside the repository, INV-008 above).

## RT-20260909-002 human authorization record

Date: 2026-09-09. Source: explicit user messages in the current Codex
conversation; these quotations are preserved verbatim, not inferred from a
general instruction to finish the repository work.

> フック証跡契約の限定修正については承認する

> 今回の操作に対するSDDガードの実拒否の証明」で満たせるようにする判定契約の変更と、復旧専用レビュー経路の承認する

The authorized amendment is limited to the operation-bound Codex denial
criterion and its recovery-only review route. It is not authorization to
bypass protective enforcement, fabricate plugin flags, rewrite historical
PASS/Done evidence, waive independent review, or admit unrelated integration.
Cleanup behavior remains REQ-010 / AC-032's existing three-outcome contract;
the requirements amendment only disambiguates contradictory unconditional
summaries. This record does not itself establish a passing review or live
activation. The following amendment-context declaration must bind this
record and the amended documents to an actual commit before a new review.

## Amendment Re-Review Context

Declaration recorded 2026-09-09 for RT-20260909-002. Amendment snapshot commit:
`e1f343b44706fc2eb3d09744feed0e034225a0fc`. The human returned the full commit
identity and the following SHA-256 values after a successful `git diff
--exit-code` comparison of the three amended documents with that commit.
The subsequent multi-file hash collection reported one absent staged workflow;
it was NOT a successful whole-command verification. Its individually printed
hashes are human-collected evidence, not an agent claim of re-executing the
refused collector. The absent path is accounted for separately below.

Amended-document hashes AS OF that snapshot (the investigation hash precedes
this declaration; it is not asserted to hash its own appended bytes):

| Document relative to this feature | SHA-256 at amendment snapshot |
|---|---|
| requirements.md | c99ae8bafce9f17da9db189188e3f76337e540c40489e9f290981cf39e2e3434 |
| acceptance-tests.md | 079567e6ef2ec31c96c77d4e635f1097e06ae74757bb668dd56050620d90f11a |
| investigation.md | bbe500edca04b25089ee55daf81bf3c6110b156a49ecd3dae3e57a9bd623f75c |

Verbatim human approval, recorded 2026-09-09 in the authorization section of
the above committed investigation snapshot (SHA-256
`bbe500edca04b25089ee55daf81bf3c6110b156a49ecd3dae3e57a9bd623f75c`):

> フック証跡契約の限定修正については承認する

> 今回の操作に対するSDDガードの実拒否の証明」で満たせるようにする判定契約の変更と、復旧専用レビュー経路の承認する

The following existing later-phase and decision artifacts are disclosed as
human-collected content snapshots, not as new approvals, current PASS evidence
or authorization to implement unrelated work. Feature-relative paths resolve
under `specs/epic-189-a1-project-context/`; paths beginning `docs/` or `reports/`
are repository-relative. These SHA-256 pins identify the exact referenced
content independently of whether that content was part of the amendment commit.

| Referenced artifact | SHA-256 |
|---|---|
| design.md | c983abe8d80a3f1c38dd677156b6287e0e9791810bbed8a1e32fd9cce95c97f5 |
| tasks.md | bd66327f71f84f3d555fd4c01a9e2db4cfd0ce4debc18b7adb4e046e600cb044 |
| traceability.md | ed3166a5a468b075a5d48c7031dec000110cc657b4ac6b1bd76b2ba85b0b5a54 |
| ux-spec.md | 1ecac8ad0949029ff805f06e6da2aaa9c692eff32c8f099a394911de2354e8e7 |
| frontend-spec.md | 0c4c53dabe5ae5f98ad26c16df38b65fad6c6c4b45c27b985d6a8095e1c33771 |
| infra-spec.md | 2f6b17f7239ecf3ce4c395e9d1a1d59303680a0239fa7a2f1abef09d1e9ca489 |
| security-spec.md | d68fe78b0261420be876a8eaa3b2f02473f4f7a6801de10277e6b6fcfe77faec |
| human-copy/PROTECTED-MANIFEST.md | d1d94441adb5b5a0ec31d60299b69183eba900c5af657e52775bb586c21e0edb |
| human-copy/plugins/sdd-quality-loop/references/guard-invariants.json | e37af15bfa44cc04029e65f25602fe9bc617594e847b9af3bceeb450e31367f5 |
| human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py | 344e035ea9313d0d39a1972e9c1084d9cfaf8afa6e31802222fe9df44c3b1757 |
| docs/ai-dlc-foundation-decision-v2.md | c2957c535f355dd7ef11c8b5a08bc8b318c80b900b51d3ef537dbbb063d3ba11 |
| docs/adr/0011-phase2-handle-relative-protected-copy.md | a14070ac6a4461a2d73c8222c9d94a346d5dddb016a35f18755f5b6b1c0550eb |
| docs/adr/0016-workflow-axes-separation.md | c72452308fc5d40f422f748b729e86a1190e57fc06a178f2e807d8a17b4d144c |
| docs/adr/0018-provider-binding-separation.md | 26b70c330c3d42146c31381a09beca3df8b3b92e374359a9d141bbc2e115d597 |
| docs/adr/0019-approval-sidecar-protection.md | f958b79ec60013c2f5df30baf06bbbb85c8662d56371838565897b24d6953bf6 |
| docs/adr/0020-conditional-predicate-dsl.md | b3c0f05e44c9f56b540c41ecae0f55d3bb0f18ea2a561f93912567d5b16021ba |
| docs/adr/0021-context-projection-staleness.md | 39495d2a5343c0d0b8b8e8ae07529257dcbe7734ed9086e8ebff19db38a53064 |
| docs/adr/0023-track-selection-contract-migration.md | 54fbbc7f441cbfcc250125c009124c2879301b64d56ba25d53f90d5d449d573c |
| reports/verification/hook-recovery-entry-contract-20260909.md | 2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f |
| docs/review-tickets/RT-20260909-002.yml | 878942094199aa2ae34de1c91a5968cb3019a2c83672d0e762964be5fcd835ad |

Absent historical staged artifact: requirements AC-028 references
`human-copy/.github/workflows/test.yml`, but commit
`c8ac93a27e2f8fc351100fb8fa76958781532797` deleted that exact staged file
and its manifest entry to prevent stale per-feature snapshots from overwriting
shared CI. Read-only `git show --stat` identified this deletion and
`git merge-base --is-ancestor` returned zero against amendment snapshot
`e1f343b44706fc2eb3d09744feed0e034225a0fc`. This is a commit-bound absence
record, NOT a fabricated content hash or proof of AC-028 satisfaction. The
historical reference does not authorize restoring the removed snapshot or
substituting the live workflow's hash. Any remaining specification inconsistency
is disclosed for independent review, not silently waived by this declaration.

The dated cleanup precedence in the requirements snapshot above governs this
limited repair; older later-phase summaries are not silently rewritten or
promoted to current evidence. The referenced recovery contract still requires
formal predecessor reviews, retained regressions and fresh native activation
before ordinary work resumes. This declaration supplies provenance only and
does not change any review verdict, task Done state or implementation outcome.

### Authorized reference and shared-CI follow-up (2026-09-09)

Verbatim additional human authorizations, recorded 2026-09-09:

> RT002限定の設計3文書の改訂・正式再レビューの承認

> 14件のACと既存設計・テストの対応を精査し、根拠のある参照を補う範囲拡張を承認する

> その他の設計変更も承認する

The amendment commit above remains
`e1f343b44706fc2eb3d09744feed0e034225a0fc`. The following follow-up hashes are
measured working-tree snapshots on that base, NOT a claim that these later
bytes are committed or approved by a historical verdict. The original
declaration and all its commit-time hashes are retained unchanged.

| Follow-up artifact (repository-relative) | SHA-256 measured 2026-09-09 |
|---|---|
| specs/epic-189-a1-project-context/requirements.md (Pending) | d303c649816d525ba3be93a45f3ec0f5b1320da404a0850554125efa08ac5660 |
| specs/epic-189-a1-project-context/acceptance-tests.md | 45bd2ff352d22e43ef6511341016245ff85429560df62faffc33d4a4a4baf94b |
| specs/epic-189-a1-project-context/investigation.md (before this append) | abd35dd920fbb5935577659f65462ed2fb23ae3be138d6673944426f1484cf67 |
| specs/epic-189-a1-project-context/design.md | 7ff9e12e80a6bec6189548d2f2c06b3fa41068a59e3d3059094efdfb75c3a1a2 |
| specs/epic-189-a1-project-context/infra-spec.md | db2bb526bae5fec34b9cac4ff4fe2e89edfba124f3b1337c0bacd2594861c776 |
| specs/epic-189-a1-project-context/security-spec.md | d3acb853736e83808d3e13b0131b1ebc050f49742fe658e8ab6080df8ff233e9 |
| tests/guard-invariants-epic-a1.tests.sh | b4813794bc766e88962e1803dbd117abfa66b4b619291d5d7ace12d6ee4a2361 |
| tests/guard-invariants-epic-a1.tests.ps1 | a2a8c822570c14d3d201b99d7795e7fa63c9c2a6bfcbf6396926d4d0dd436039 |
| docs/review-tickets/RT-20260811-002.yml | fd1ec0daeaf737b8146e2de88550d547c560ce72275c630c71b238ee918143ad |

The test-script pins identify the existing absence assertions cited by the
Shared CI amendment, not execution results for its newly planned TEST-028
branches. The original absence record above remains historical; the newly
authorized requirements amendment supersedes its unresolved-contract wording
without restoring the retired workflow snapshot. Tasks, traceability and
unchanged layer/decision artifacts retain the earlier explicit pins; their
historical completion is not completion under the new contract.

This append addresses the missing test-artifact provenance without changing
any test, approval predicate, review calibration or historical FAIL. The next
review manifest binds the complete investigation including this append; its
hash is intentionally not asserted to be the pre-append hash in the table.
