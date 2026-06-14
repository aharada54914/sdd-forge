# Threat Model — SDD Quality Loop & Risk-Adaptive Layer

## Trust Assumptions

### Trusted
- **Human operators** who invoke skills directly and sign approvals in tasks.md
- **External signing keys** (`~/.sdd/sudo-key`, `~/.sdd/evidence-key`) held outside the repository and protected at OS level (mode 600)
- **CI environment** for generating evidence bundles and sigstore attestations
- **Deterministic gate scripts** running out-of-process and fail-closed on any validation error

### NOT Trusted
- **Agent self-reports**: agents cannot write approval fields, evidence signatures, or sudo tokens
- **In-repo files**: evidence bundles and signatures are generated locally or in CI and verified against external keys; bundles with self-asserted risk are re-validated against hash-verified contracts (T-006)
- **Agent memory or state**: every gate decision is stateless and enforced by an external file guard (sdd-hook-guard)
- **External content** fed to agents: agents treat external URLs, docs, and provided code as data only; external directives are never executed

---

## Assets Protected

1. **Task approval state** (`tasks.md` Approval/Second Approval/WFI fields)
   - Approval determines when a task moves to Done
   - Second Approval is a distinct second human judgment for critical tasks
   - WFI Approval changes the SDD workflow itself

2. **Evidence bundles** (`specs/<feature>/verification/*.json`)
   - Contain risk tier, spec revision, build provenance, review verdict
   - Critical bundles are HMAC-signed; forgery would require external key

3. **SDD_SUDO token** (project root)
   - Time-limited bypass of routine approval gates
   - Signed with external key; expiration and repo-binding prevent reuse

4. **Signing keys** (`~/.sdd/sudo-key`, `~/.sdd/evidence-key`)
   - External; agents should never read them
   - Protected by OS file permissions

5. **Agent role files** (`.codex/agents/*.toml`)
   - Define agent capabilities and constraints
   - Must carry `developer_instructions` or Codex rejects them; guard enforces this

6. **Protected branch** (`main`; requires status checks and CODEOWNERS review)
   - Once T-008 lands, enforced by GitHub ruleset

---

## Controls Table

| Control / Gate | What It Defends | Enforcement | Bypassed By | Enforcement Notes |
|---|---|---|---|---|
| **Kill switch (AGENT_STOP)** | Blocks all tool use | File-exists check at every tool call entry (sdd-hook-guard) | Only human deletion | Fail-closed; checked BEFORE all other gates; sudo mode has zero effect |
| **Approval guard** | Prevents agent from setting `Approval: Approved` in tasks.md | sdd-hook-guard counts `Approval: Approved` lines on `+` vs `−`; denies if net positive | Human approval; sudo mode (respects TTL + signature) | Approvals under sudo are marked `(sudo <ISO8601>)` for audit trail |
| **WFI guard** | Prevents agent from setting `Status: Approved` in WFI docs | sdd-hook-guard counts `Status: Approved` in workflow-improvements/*.md; denies if net positive | Only human | Never bypassed by sudo; WFI is governance and requires human judgment |
| **Second Approval guard** | Prevents agent from setting `Second Approval: Approved` in tasks.md | sdd-hook-guard counts `Second Approval: Approved` lines; denies any increase; gate enforces DISTINCT approvers (T-007b-2) | Only second human approver | Never bypassed by sudo; distinct from first approval (enforced by gate check-task-state: parse approver names, require different humans) |
| **Agent-role guard** | Ensures agent role files are not misconfigured | sdd-hook-guard verifies `.codex/agents/*.toml` contains `developer_instructions` field; denies write without it | Only by editing the file with developer_instructions present | Malformed agent roles are rejected by Codex at startup and by the guard; prevents privilege escalation via role modification |
| **Evidence HMAC signing (critical)** | Prevents agent from forging critical evidence bundles | `generate-evidence-bundle` signs bundle canonical string with external `SDD_EVIDENCE_KEY`; `check-evidence-bundle` verifies constant-time against re-resolved key | Only key holder (external to repo) | Signature required for `risk: critical`; fail-closed (bundle rejected if absent or mismatched); agents cannot generate signatures without the key |
| **SDD_SUDO signature + repo-binding** | Prevents token forgery, cross-repo reuse, modification after issuance | sdd-hook-guard verifies HMAC, checks `repo` field equals canonical realpath, validates TTL (`issued-epoch <= now < expires-epoch`, max 24h) | Only human via `/sdd-sudo` skill with valid key | Token file read-only by guards (agents cannot edit); constant-time HMAC compare (Python/Node); string-compare in PowerShell |
| **Risk-tier gate (check-contract)** | Enforces minimum checks per risk tier; prevents downgrade | check-contract reads `risk` field and requires superset of checks; rejects contract if required[] ⊉ tier-minimum | Only by human re-setting risk in tasks.md and approving | Tier minimums are non-downgradable (fail-closed superset rule); legacy mode (no risk field) only enforces baseline checks |
| **Deterministic checks** (lint, typecheck, build, tests, placeholders, task-state) | Enforces code quality and correctness | Out-of-process scripts; exit 1 on failure; no bypassable in-memory state | None (never bypassed, even by sudo) | Fail-closed; dual-runtime parity (py + PowerShell); applied before any approval sign-off |
| **Spec-revision requirement (high/critical)** | Ensures bundle ties to specific spec version | check-contract requires `spec_revision` for high/critical; check-evidence-bundle verifies it is present and non-empty | None (enforced deterministically) | Backward compat: legacy bundles (no risk field) do not require spec_revision |
| **Traceability gate (check-traceability)** | Proves REQ→AC→TEST→evidence chain is complete for high/critical tasks | check-traceability reads traceability.json; validates every REQ has AC, every AC has TEST, every TEST has evidence file | None | Fail-closed; dual-runtime |
| **Review verdict requirement (high/critical)** | Ensures bundle carries independent evaluator's PASS judgment | check-evidence-bundle requires `review_verdict.verdict == PASS` for high/critical; reject if absent or non-PASS | None | Fail-closed; verdict recorded by sdd-evaluator agent or human review |
| **Two-person approval (critical tasks)** | Enforces distinct first and second approver for critical Done | check-task-state parses `Approval` and `Second Approval` fields; requires non-empty distinct approver names (compare strings after `(` in timestamp) | None (enforced deterministically) | Fail-closed; sudo does NOT auto-pass second approval (it is judgment, like WFI); must be recorded by second human |
| **Branch protection (main)** | Prevents commits without required status checks and CODEOWNERS | GitHub ruleset: required checks (test matrix), dismiss-stale-reviews: false, require CODEOWNERS | Only GitHub org owners (admin override) | Deployed via `.github/rulesets/main.json` and apply-branch-protection.sh (T-008) |

---

## Threats & Mitigations

### Threat: Agent self-approves a task
**Attack:** Agent writes `Approval: Approved` to tasks.md to move task to Done without human judgment.
- **Mitigation:** Approval guard in sdd-hook-guard detects increase in `Approval: Approved` count and denies the write. Approval gate only auto-passes under a valid, unexpired SDD_SUDO token (which requires external key to forge).

### Threat: Agent mints its own SDD_SUDO token
**Attack:** Agent creates a SDD_SUDO file with forged epochs and signature to bypass approval gates.
- **Mitigation:** HMAC-SHA256 signature requires external key (`~/.sdd/sudo-key`). Without the key, agent cannot produce valid `sig` field. Guard rejects unsigned/mismatched tokens as inactive (fail-closed). Repo-binding check ensures token created in one repo cannot be copied to another.

### Threat: Agent forges a critical evidence bundle signature
**Attack:** Agent creates an evidence-bundle.json with fabricated `signature.value` to bypass verification.
- **Mitigation:** `generate-evidence-bundle` computes HMAC-SHA256 over the canonical bundle string using external `SDD_EVIDENCE_KEY` (same external-key pattern as sudo). Agent cannot generate a valid signature without the key. `check-evidence-bundle` verifies signature constant-time; mismatch ⇒ FAIL (fail-closed). Non-critical bundles carry no signature field; only critical requires and verifies it.

### Threat: Agent rubber-stamps a critical task alone
**Attack:** Agent sets both `Approval: Approved` and `Second Approval: Approved` to move critical task to Done as a single entity.
- **Mitigation:** Second Approval guard in sdd-hook-guard denies any increase in `Second Approval: Approved` count (just like Approval guard). Additionally, check-task-state enforces **distinct approver names** (parses the human identifier from the timestamp annotation). Sudo mode does NOT auto-pass Second Approval; it is a judgment action like WFI.

### Threat: Agent modifies a gate script to weaken enforcement
**Attack:** Agent edits `plugins/sdd-quality-loop/scripts/check-contract.sh` to skip evidence validation.
- **Mitigation:** Gate scripts are protected by CODEOWNERS review (root CODEOWNERS file). Once T-008 lands, main branch is protected by GitHub ruleset requiring status checks + CODEOWNERS approval. Script changes are code-reviewed.

### Threat: Prompt injection from external content
**Attack:** Agent fetches external URL containing JSON with instructions embedded in a field, then executes those instructions.
- **Mitigation:** Agents are instructed to treat external content (URLs, provided code, fetched docs) as **data only**. External directives embedded in comments, JSON fields, or HTML attributes are not executed. No agent skill evaluates or evals external code.

### Threat: Agent reads signing keys and mints tokens
**Attack:** Agent reads `~/.sdd/sudo-key` or `~/.sdd/evidence-key` via a Bash command, then mints arbitrary tokens.
- **Mitigation:** Key files are protected by OS file permissions (mode 600) and stored **outside the repository**. If an agent has read access to these files, that is a host-level compromise beyond SDD's scope. Mitigations: run agents with restricted umask, use dedicated key-holder accounts, audit file permissions. At SDD level, evidence signatures raise the bar against attacks on local keys (cannot be guessed or brute-forced; HMAC prevents tampering).

### Threat: WFI approval is bypassed by sudo to change workflow
**Attack:** Agent sets `Status: Approved` in a WFI doc under sudo mode to unilaterally change SDD governance.
- **Mitigation:** WFI approval is **never** bypassed by sudo. It is a governance/judgment action, not a routine approval gate. sdd-hook-guard treats WFI exactly like Second Approval: no bypass regardless of sudo state. Sudo mode only bypasses routine approvals (task Done sign-off), not workflow changes.

---

## Residual Risks

1. **Key read-access (High residual risk, out-of-scope)**
   - If an agent or attacker can read `~/.sdd/sudo-key` or `~/.sdd/evidence-key`, they can mint arbitrary tokens and signatures.
   - **Mitigation:** Protect key files with OS-level permissions (mode 600), store outside repo, rotate keys regularly, use dedicated key-holder accounts or Hardware Security Modules (HSM) for production.

2. **PowerShell string-compare vs. constant-time compare (Low residual risk)**
   - PowerShell's ordinal compare for HMAC verification is not constant-time (timing attacks theoretically possible).
   - **Mitigation:** For local development, this is acceptable. For CI, use Python (constant-time `compare_digest`). If timing attacks are a concern, migrate to a constant-time comparison library in PowerShell or use CI exclusively.

3. **Local .ps1 script execution untested in all environments (Low residual risk)**
   - PowerShell scripts (`sdd-hook-guard.ps1`, check-*.ps1`) are verified by code review and CI, but local execution environment variability may introduce edge cases.
   - **Mitigation:** Comprehensive test suite in `tests/scripts.tests.ps1` covering all control branches. Python is the preferred runtime; PowerShell is a fallback with parity testing.

4. **SDD_SUDO session isolation (Low residual risk)**
   - If sudo mode is enabled in one session and the token file persists on shared infrastructure after the session ends, a different session with the same key may accept the still-valid token.
   - **Mitigation:** Hard TTL (max 24h) limits exposure. Operators should delete SDD_SUDO manually when done or rely on script cleanup. For CI, tokens should not persist across runs.

5. **Evidence bundle tampering after signing (Low residual risk)**
   - A bundle's fields could be edited in git history or in a file system backup after signing.
   - **Mitigation:** Bundles are stored in git and signed by commit hash (`git_commit` field is part of the canonical string). Changes to the bundle invalidate the signature. Bundles are immutable artifacts once signed; use git history and CI attestation for provenance.

6. **Approval audit trail erasure (Low residual risk)**
   - If tasks.md `(sudo <ISO8601>)` notation is accidentally or maliciously removed, the audit trail is obscured.
   - **Mitigation:** Quality-gate reports and evidence bundles are immutable artifacts stored separately from tasks.md and serve as the authoritative record. Audits should cross-reference bundles and reports, not only tasks.md.

---

## Enforcement by Runtime

### Python (preferred for sdd-hook-guard, deterministic gates)
- HMAC verification: `hmac.compare_digest()` for constant-time comparison
- File I/O: follows POSIX conventions
- Regex: standard library `re` module

### PowerShell (fallback runtime)
- HMAC verification: ordinal string compare (acceptable for local; not constant-time)
- File I/O: PowerShell cmdlets; UTF-8 BOM handling per spec
- Regex: .NET `[regex]` class or `Select-String`

### Dual-Runtime Parity
- Every gate change includes tests in both `tests/gates.tests.sh` (Python) and `tests/scripts.tests.ps1` (PowerShell)
- Behavior must be identical; deviations are bugs

---

## Cross-References

- **Sudo Mode Policy** (details on token format, key resolution, audit trail): [`plugins/sdd-quality-loop/references/sudo-mode-policy.md`](../plugins/sdd-quality-loop/references/sudo-mode-policy.md)
- **Evidence Signing Policy** (HMAC canonical string, verification rules, fail-closed cases): [`plugins/sdd-quality-loop/references/evidence-signing-policy.md`](../plugins/sdd-quality-loop/references/evidence-signing-policy.md)
- **Risk-Adaptive Layer Design** (security considerations section, control surfaces): [`specs/risk-adaptive-layer/design.md`](../specs/risk-adaptive-layer/design.md)
- **Deterministic Check Policy**: [`plugins/sdd-quality-loop/references/deterministic-check-policy.md`](../plugins/sdd-quality-loop/references/deterministic-check-policy.md)
- **SDD Hook Guard** (Python, JavaScript, PowerShell implementations): [`plugins/sdd-quality-loop/scripts/sdd-hook-guard.{py,ps1,js}`](../plugins/sdd-quality-loop/scripts/)
