# Frontend Specification: design-sync-standing-consent

## Technology Stack

**N/A — no browser, no bundle, no build output.**

The technology in scope is Markdown (`AGENTS.md`, a skill file, a reference document) plus POSIX shell and PowerShell test assertions. There is no HTML, CSS, JavaScript, framework, router, state container, bundler, or asset pipeline in this change set, so `## Component Tree`, `## State Shape`, `## Routes and Components`, `## API Client Strategy`, `## Code Splitting and Size Budget` and `## Performance Budget` have no content to carry. Recorded as N/A rather than omitted, matching this repository's convention for non-frontend features and DS-29's own stub (`specs/design-sync-consent/frontend-spec.md`).

**No `dist/` output is involved**, for the same reason DS-29 recorded: this feature produces no build artifact, so ADR-0003's same-commit rebuild obligation does not attach, and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion. Stated in `infra-spec.md` under CI/CD Sequence as well, so the two layers agree.

## Dependencies

None added, none removed, none upgraded. No package manifest or lockfile is touched.

## Testing

All verification is document conformance over Markdown files, executed by shell and PowerShell suites (`acceptance-tests.md`). The suite is new to this feature (`tests/design-sync-standing-consent.tests.{sh,ps1}`), not an extension of DS-29's own `design-system-contract` suite (`design.md` → "The verification surface, again"); nothing about its placement is frontend-shaped.

One constraint lands here by association, because the assertions are written in two runtimes: **dual-runtime parity with documented carve-outs only**, following the existing precedent comment at `tests/design-system-contract.tests.ps1:57`.

## Open Questions

None specific to this layer.
