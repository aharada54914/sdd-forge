# Dispatch reference correction

Root identified that the first T-008 draft used `gh workflow run --ref "$W"`
while W means an immutable commit SHA. `gh workflow run --help` and the official
CLI manual describe --ref as a branch or tag name; the GitHub workflow_dispatch
API likewise accepts a branch/tag ref. Actual help and read-only official-page
retrieval hashes are adjacent. No workflow was dispatched.

Current guide commands now use operator-selected CONTROL_REF resolving to exact
W. The shipped protected Policy.ref is refs/heads/main, so main is the supported
example, not an invented tag policy. The Azure and AWS setup references and
release runbook distinguish dispatch selector from immutable admission pin.
A preflight ref-resolution check is not atomic: Policy.workflow_revision and
native workflow_sha must still equal W at admission. No relaxation of E/W pins.
Root's pre-version curated-tree workflow-state result is not final release CI.
