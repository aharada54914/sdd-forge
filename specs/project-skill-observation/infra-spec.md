# Infra spec: Project skill execution methods and verification observations (#594)

DRAFT. REQ-001, REQ-007, REQ-011, REQ-012, REQ-013, NFR-002, NFR-003.

## Files (planned, not created by this draft)

- **Contracts:**
  - `contracts/project-skill-manifest.schema.json`
  - `contracts/project-verification-observation.schema.json`
  - Each `$id` is `https://github.com/aharada54914/sdd-forge/contracts/<file>`.
  - Both are vendored byte-identically under `plugins/sdd-quality-loop/contracts/`.
- **Validator:** `plugins/sdd-quality-loop/scripts/validate-project-skill.{py,sh,ps1}`.
- **Tests:**
  - `tests/project-skill-observation.tests.py`.
  - Small text fixtures under `tests/fixtures/project-skill-observation/`.
  - Execution roots (and the one Git checkout in TEST-056) are created in
    temporary directories at test time and are not committed.
- **Catalog entry** in `tests/verification-catalog.json`, using the existing
  `suites` shape (`path`, `runtime`, `ci_jobs`). CI job names are picked from
  the current catalog at implementation time, which is a routine choice.
- **Docs:**
  - A section in `PLUGIN-CONTRACTS.md`, plus `CHANGELOG.md`.
  - README, USERGUIDE and skill-reference counts change only if a counted
    surface changes. Scripts are not skills; re-check the counts at
    implementation.
- **Evidence boundary:** `reports/project-skill-observations/<task_id>/<run_id>/`
  per run (trial: `trial/<skill>/`), admitted via `allowed_outputs`, for consumers;
  #594 creates no files there.

## Runtime

- Python 3 standard library plus in-repo helpers (G-6).
- No Git dependency: the validator hashes only declared paths in the execution
  root. A `run_id` containing `:` cannot be a Windows directory name; that path
  fails closed and Windows remains unverified.
- No network, no install, no new dependency.

## Platform status

- Bash/pwsh wrapper parity on Linux is **planned** verification (TEST-085 and
  TEST-086). It has not been executed.
- macOS and Windows execution, and use on the Claude/Codex/Copilot hosts, remain
  unverified until actually observed.

## Compatibility

No existing file changes behaviour. #594 leaves existing schemas, the
evaluator, the contract checker, hooks, events and MCP tools untouched.
