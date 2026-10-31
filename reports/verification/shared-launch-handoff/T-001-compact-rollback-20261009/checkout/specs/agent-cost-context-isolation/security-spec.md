# Security Spec

Task, reviewer, and evaluator manifests are allowlists. Paths must be canonical
repository-relative paths, traversal, backslashes, absolute paths, symlinks,
duplicates, and undeclared output roots are rejected, SHA-256 is recomputed,
and unknown JSON properties fail closed. Mutable task inputs are copied into an
atomically published read-only snapshot after no-follow identity and mutation
checks.

Every independent reviewer and evaluator uses a fresh read-only session and a
persisted path/SHA manifest. Missing manifests, unlisted files, hash mismatch,
chat-only input, and session reuse fail closed; no review/evaluation fallback
exists. Chat logs, compacted summaries, secrets, and unlisted files are
forbidden inputs.

Terminal strong-tier recurrence remains blocked until the human task-approval
authority records a diagnosis, revises the affected task contract, and
explicitly reapproves it. Risk classification is validated from structured
impact, reversibility, and surface fields before routing.
