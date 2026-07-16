# T-005 Security Decision Addendum

Decision Date: 2026-07-14

Decision: The human selected option A and authorized a sanctioned amendment of
the frozen T-005 specification. The immutable human-copy runner will replace
path-based copying with a Windows PowerShell 5.1-compatible, repository-root-
handle-relative no-follow design. It will hash and copy each source through the
same held handle, hold destination parents against namespace substitution,
verify every same-parent temporary before publication, and atomically replace
each target directory entry without following hard-link aliases.

Review Requirement: The amended requirements, acceptance tests, design, layer
specifications, task wording, traceability, and ADR must pass the applicable
specification, implementation-policy, and post-implementation provenance
reviews before T-005 can return to Implementation Complete. Sudo does not waive
those reviews.

Authority Boundary: The agent may stage and verify the protected batch only.
A human must execute the reviewed immutable runner to place the protected live
targets.
