# Bounded normalization prototype

Issue #423, owner issue423-approved-recovery/sdd-forge, HEAD
3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9. Existing dirty implementation,
validators, ledger, reports and tests are preserved. This directory alone is new.

Risk: high (evidence admission). This is NOT an admitted validator or a formal
review result. No original source, report, reservation or task status is changed.
Prototype scope: one pinned report and raw declaration plus pinned contemporaneous
owner observation, using the existing canonical/safe_path/overlap functions.
No cwd fallback, history rewrite, generic mapping list or claimed execution proof.

The approved limited recovery needs a formal contract extension before this input
can be consumed by either original validator. Normal allowed_inputs binding must
cover both receipt and observation. The observation is a transcription, NOT a
signature; independent admission must inspect the native tool observations cited
in issue423-t002-sandbox-scratch-diagnosis-20261006.md. No native transcript is
copied here. The prototype cannot itself authenticate that observation.

Validation must retain Bash/PowerShell parity, all existing feature-history cases,
and rejection of modified/unbound evidence, identity mismatch, malformed paths,
symlinks, and equal/ancestor/descendant roots. Historical directory absence is not
execution evidence and must not be repaired by creating a historical directory.
