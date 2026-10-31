# Frontend Spec: review-cross-critique

## Technology Stack

**N/A — no browser, no frontend bundle, no client-side code.**

The technology in scope is POSIX shell, PowerShell, Markdown (agent skill and
role definitions), and JSON (round artifacts and schema validation). There is no
HTML, CSS, or JavaScript in this change set, no build tooling, and no bundled
asset.

One adjacent fact worth stating so it is not rediscovered: this repository does
ship a JavaScript artifact in the guard chain
(`plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` and
`plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`, both
on `PROTECTED_GATE_SUFFIXES` at
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`). That is a
Node-executed hook implementation, not a frontend bundle, and this feature does
not touch it — it would only come into scope if a *new file* needed protecting,
which is the contingent row in `design.md`'s Components table.

Because no `dist/` output exists in this change set, ADR-0003's same-commit
rebuild obligation does not attach; this is stated in `infra-spec.md` under
CI/CD Sequence.

Recorded as N/A rather than omitted, matching this repository's convention for
non-frontend features (`specs/epic-136-phase4-docs/frontend-spec.md`,
`specs/epic-136-phase3/`).
