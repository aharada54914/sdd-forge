# Candidate-only repair scope

Issue #195 / A7 attempt-18 launch recovery, owner a7-t005-intake.
The existing owner worktree is dirty; no existing changes are discarded.
Risk: high (review input completeness). No protected source, identity ledger,
review verdict or task status is changed by this candidate work.

Persisted delivery claims must match a complete deterministic prompt built
from invocation path/hash, role and the exact independently validated receipt.
Regression: identical truncation of both prompt file and native transcript
must fail, although the previous comparison accepts it. Existing transport
negatives remain required. Fixtures do not establish live admission.
