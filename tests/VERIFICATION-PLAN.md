# Cross-platform / E2E / hook-enforcement verification plan

Status: approved (scope = full A–E; B2 = required CI job) — 2026-06-14

## Why

CI proves each deterministic gate script is correct **in isolation on 3 OS**, but does
not prove the **integrated system** behaves identically across Windows / macOS / Linux
and across the three CLI runtimes (Claude Code, Codex CLI, GitHub Copilot CLI). The
gaps below were found by an evidence-based audit (gate scripts, hook configs, `test.yml`,
and the existing `eval.tests.sh` / `guards.tests.sh` / `scripts.tests.ps1` suites read
line-by-line; high-impact claims adversarially re-verified).

What already exists and is **not** re-built here:

- `tests/eval.tests.sh` — outcome-based suite; `make_clean_project` builds a real SDD
  tree and runs the real gates. Scenario 6 runs `sdd-hook-guard.sh --emit exit` with a
  real self-approval Edit payload (asserts exit 2). Scenario 9 runs check-risk +
  check-traceability (pass + adversarial). **bash-only; skipped on Windows.**
- `tests/gates.tests.sh` (bash) / `tests/scripts.tests.ps1` (pwsh, all 3 OS) — unit-level
  gate behavior.
- `tests/guards.tests.sh` (bash) / `tests/hooks.tests.ps1` (pwsh, all 3 OS) — guard logic
  via stdin payload injection.

## Confirmed gaps → planned work

| ID | Gap | Work | Files |
|----|-----|------|-------|
| A | No single project that holds low+high+critical tasks run through **all six gates chained in lifecycle order** | `scenario` suite: one project, walk Draft→Approved→In Progress→Impl Complete→Done; assert blocked-until-approved, critical blocked-until-2-distinct-approvers+signature | `tests/scenario.tests.sh` + `tests/scenario.tests.ps1` (new) |
| B1 | Hook contract tested only via POSIX `.sh --emit exit`; the Claude Code `.js` form and Copilot `--emit copilot` JSON form are **not** exercised, and the configured command lines in the hook JSON are not asserted to match what's tested | Drive the guard exactly as each CLI config specifies; assert deny on self-approval + allow on benign edit; assert the JSON config command lines resolve to the tested invocations | `tests/scenario.tests.{sh,ps1}` |
| B2 | **No real CLI is launched** in CI — "the guard logic is correct" is proven, "each CLI actually fires the hook" is not | Required CI job: install each CLI; run a scripted self-approval attempt; assert it is blocked. Degrade explicitly (fail loud, never silent-skip) where a CLI cannot be installed/authenticated on the runner | `.github/workflows/test.yml` (new job) |
| C | bash awk gates strip trailing `[ \t]` but **not** `\r`; a CRLF tasks.md/contract.json fed to a bash gate before git normalization can flip a verdict | Harden line parsing to tolerate `\r`; add a CRLF-parity regression (same input → same verdict on `.sh` and `.ps1`) | gate `*.sh` (edit) + `tests/scenario.tests.{sh,ps1}` |
| D | install tests check file **presence** only; installed gates are never executed | After install, run one installed gate against a fixture; assert exit 0 and exit 1 paths | `tests/install.tests.{sh,ps1}` (edit) |
| E | No critical **signing round-trip** in CI (release.yml only builds tarball+SBOM) | With an **ephemeral** `SDD_EVIDENCE_KEY` (CI-generated, never in repo): generate critical bundle → sign → verify (pass) → tamper → verify (fail) | `tests/scenario.tests.{sh,ps1}` + `test.yml` env |

## Invariants (must hold for every added test)

- **No fabricated evidence.** Tests assert real gate exit codes / real signatures; they do
  not hand-author "VERDICT: PASS" or stamp approvals. Self-approval and two-person controls
  are exercised by *attempting* the blocked action and asserting the block.
- **No secrets in the repo.** The signing key is an ephemeral value minted inside the CI
  job (or a throwaway in the local test's temp dir), never committed, never printed.
- **Deterministic core, honest degradation.** A/B1/C/D/E are deterministic and gate the
  build. B2 (real CLI) is required; if a runner genuinely cannot install/authenticate a
  CLI, the job must **fail loudly** with a clear message rather than skip silently — so the
  "required" status stays meaningful. (Open question flagged to the maintainer: whether to
  keep B2 hard-required on fork PRs, where CLI auth secrets are unavailable.)
- **Cross-runtime parity.** Every new bash scenario has a PowerShell mirror so the same
  assertions run on a real `windows-latest` runner.

## CI wiring

- `tests/scenario.tests.ps1` → `shell: pwsh` on all 3 OS (new step in `test` job).
- `tests/scenario.tests.sh` → `shell: bash`, `if: runner.os != 'Windows'`.
- Signing round-trip → ephemeral key exported in the step env on all 3 OS.
- B2 real-CLI job → added to `required-checks.needs`.
