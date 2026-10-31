# Frontend Specification: design-sync-consent

## Technology Stack

**N/A — no browser, no bundle, no build output.**

The technology in scope is Markdown (skill and documentation files) plus POSIX shell and PowerShell test assertions. There is no HTML, CSS, JavaScript, framework, router, state container, bundler, or asset pipeline in this change set, so `## Component Tree`, `## State Shape`, `## Routes and Components`, `## API Client Strategy`, `## Code Splitting and Size Budget` and `## Performance Budget` have no content to carry. Recorded as N/A rather than omitted, matching this repository's convention for non-frontend features.

Two clarifications, because the words "HTML" and "frontend" both appear in this feature's subject matter and could mislead a reader skimming the layer table.

**The HTML this feature governs is not this repository's frontend.** `design-sync-loop` generates semantic HTML mockups under `specs/<feature>/mockups/` in a *consuming* project (`design-sync-loop/SKILL.md:73-75`). Those files are disposable, non-canonical visual references produced by the loop when a downstream project runs it — never built, never served, never shipped, and never rendered by anything in `sdd-forge`. This feature changes the consent under which they are uploaded; it writes none of them and changes none of their content rules (`:76-80` is untouched). No such directory exists anywhere in this repository (INV-010).

**No `dist/` output is involved.** Unlike `epic-136-phase4-mcp`, which owned an esbuild Node/stdio bundle (`mcp/sdd-forge-mcp/dist/index.js`) and therefore inherited ADR-0003's same-commit rebuild obligation, this feature produces no build artifact. ADR-0003 does not attach, and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion. Stated in `infra-spec.md` under CI/CD Sequence as well, so the two layers agree.

## Dependencies

None added, none removed, none upgraded. No package manifest or lockfile is touched, so no `npm audit`, license-scan, or SBOM interaction follows.

## Testing

All verification is document conformance over Markdown files, executed by shell and PowerShell suites. The suite placement is the subject of OQ-8 and is specified in `infra-spec.md` and `acceptance-tests.md` (TEST-039); nothing about it is frontend-shaped.

One constraint does land here by association, because the assertions are written in two runtimes: **dual-runtime parity with documented carve-outs only** (BL-008). Where an ASCII-only `.ps1` source cannot carry a literal the `.sh` twin asserts, the reason is stated where the asymmetry is created, following the existing precedent comment at `tests/design-system-contract.tests.ps1:57`. Silently asserting a subset in one runtime is the failure mode.

## Open Questions

None specific to this layer.
