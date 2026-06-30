# Independent Implementation Review: T-002 Round 3

Reviewer: T-002-independent-reviewer-round-3

Result: PASS

## Remediation

1. Original Critical: `check-terminal-tier-resume.ps1` validated repository containment
   lexically and checks only the final item for `LinkType`. A repository-local
   parent-directory symlink can therefore resolve outside the repository while
   PowerShell still accepts the diagnosis (and the same helper also protects
   blocked-state paths). An independent fixture using
   `diagnostics -> /tmp/.../outside` produced:
   `bash_status=1` with `TERMINAL_RESUME_PATH: diagnosis reference escapes repository`,
   but `pwsh_status=0` with `TERMINAL_RESUME_OK`.
   Resolve the effective target and every path component, reject any symlink
   component, and compare the resolved target against the resolved repository
   root with ordinal semantics in both validators.
   Resolved: PowerShell now resolves `RepoRoot`, walks and rejects every
   symlink path component, and applies ordinal containment. The independent
   reproduction now returns nonzero from both runtimes.
2. Original Major: `verification/T-002/green.log` no longer identified the reviewed
   outputs. It records selector/test hashes beginning `76b6010`, `dc44982`,
   and `abc19ee`, while the reviewed files hash to `fa5b8df`, `ab5605f`, and
   `c9fb836` respectively. Regenerate the green evidence after the containment
   fix and rerun the scoped suite so the durable evidence is hash-bound to the
   final implementation.
   Resolved: the regenerated evidence matches all seven current output hashes,
   including resume validator `eef6c10` and routing test `09ec1ad`.

## Verified Resolutions

- Both selectors reject scalar candidate roots and boolean, numeric, and
  exponent-form costs.
- PowerShell selects `provider/Z` under `sv-SE`, matching ordinal Bash
  tie-breaking.
- JSON and non-JSON recurrence output contains all REQ-004 escalation fields.
- Trusted blocked-state binding, forged-hash rejection, strict timestamp
  parity, and deterministic-runtime fail-closed behavior pass the scoped suite.
- Commit `c0ccc0f06546d2324e47d62ad24b432a704a5fbd` contains the failing test
  before the routing implementation; the committed failure is reproducible
  from the recorded missing selector.

## Test Evidence

- `bash tests/agent-model-routing.tests.sh`: PASS, including the
  parent-directory symlink regression for both runtimes.
- Independent parent-symlink containment reproduction: Bash exit 1 with
  `diagnosis reference escapes repository`; PowerShell exit 1.
- SHA-256 comparison against `verification/T-002/green.log`: PASS for all
  listed outputs.

Remaining Critical, Major, or Warning findings: none.

Gate: PASS. T-002 may proceed to Implementation Complete and its independent
quality gate.
