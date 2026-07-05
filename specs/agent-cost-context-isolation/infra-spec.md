# Infrastructure Spec

GitHub Actions runs the paired Bash and PowerShell selectors, snapshot
builders, task-manifest validators, rollback fixtures, and repository
validators across the supported matrix. Seven required jobs must pass before
release. A missing deterministic runtime fails closed as
`deterministic-runtime-unavailable`; no model may replace parsing, validation,
hashing, or state-transition scripts.

Release 1.5.0 synchronizes all host manifests and marketplaces. Rollback uses
the pinned `7df7318` baseline, exact baseline/release hashes, an isolated
temporary worktree, pre-apply validation, and verified backup restoration.
No new service, secret, network dependency, database, or deployment topology
is introduced.
