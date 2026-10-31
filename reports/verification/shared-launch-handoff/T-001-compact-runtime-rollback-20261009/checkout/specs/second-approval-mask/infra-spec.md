# Infra Spec: second-approval-mask

## Deployment Topology

No topology change. Two existing validator scripts are modified in place via
the human-copy procedure; no services, jobs, or workflows are added or
reconfigured.

## CI/CD Sequence

- `tests/second-approval-mask.tests.sh` joins `tests/run-all.sh`, so the new
  corpus (including parity and CRLF cases) runs wherever the aggregate suite
  runs. The suite skips ps1 cases only if `pwsh` is absent, mirroring the
  existing parity suite's behavior, and must say so explicitly rather than
  silently passing.
- No workflow permission changes; no new CI secrets.

## Operational Notes

- Rollback: re-copy the previous `check-workflow-state.{sh,ps1}` from git
  history (live paths are tracked) and revert the test commit.
- Observability: unchanged diagnostic format (`workflow-state: <feature>:
  <rule>: <detail>`); the fix only changes when the stale-hash rule fires.
