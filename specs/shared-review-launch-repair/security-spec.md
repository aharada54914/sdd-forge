# Security Specification: shared-review-launch-repair

## Trust boundaries

Untrusted invocation paths and preflight proof outputs are checked before the canonical ledger is changed. The existing `review-context-invocation/v2` manifest and stage/role allowed-input rules govern input admission (`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:37-77`; `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:709,924,985-997`). The native CLI's effective Read/Bash permissions are independently probed before reservation (`plugins/sdd-review-loop/scripts/probe-nontty-review.py:154-250`). Formal review outputs are checked after launch, not before reservation.

## Threats and authorization

- Spoofed path, case alias, symlink, changed raw digest, or changed preview: reject before reservation; TEST-005. If the actual receipt mismatches after append, stop launch and retain the consumed ledger record without retry; TEST-005h.
- Excess command/read permission or wrong model: reject with exact negative fixtures; TEST-002/003.
- Unprotected shared entrypoint or stale generated guard: canonical/generated check and six-path write-denial/read-allowance fixtures; TEST-011/012.
- False evidence promotion: delivery, diagnostic, local fixture, reviewer verdict, and final CI are distinct; formal stage reviewers remain independent.

No general permission expansion, egress channel, secret handling change, ledger reconstruction, or installer trust change is authorized. If a protected write is refused, stop and report it; do not retry through another executor.

## Data protection and security tests

Use copied fixture ledgers and isolated host sessions; never store secrets in a review artifact. TEST-002/003/005/011/012 cover negative admission and guard behavior. Actual native host and Windows checks must be evidenced separately from mock or POSIX-only tests.

## Open questions

None in the bounded security contract. The final protection inventory and permitted application path must be re-verified immediately before protected change or merge.
