# Frontend Specification: design-sync-scan

## Technology Stack

**N/A — no browser, no bundle, no build output.**

The technology in scope is POSIX shell and PowerShell (the scanner and its tests) plus Markdown (the skill and documentation edits). There is no HTML, CSS, JavaScript, framework, router, state container, bundler, or asset pipeline in this change set, so `## Component Tree`, `## State Shape`, `## Routes and Components`, `## API Client Strategy`, `## Code Splitting and Size Budget`, and `## Performance Budget` have no content to carry. Recorded as N/A rather than omitted, matching this repository's convention for non-frontend features, including `specs/design-sync-consent/frontend-spec.md` for the loop this feature attaches to.

Two clarifications, because this feature's subject matter is unusually likely to be misread as frontend work by a reader skimming the layer table.

**The HTML this feature scans is not this repository's frontend, and this feature does not modify it.** `design-sync-loop` generates semantic HTML mockups under `specs/<feature>/mockups/` in a *consuming* project (`design-sync-loop/SKILL.md:73-80`, unchanged by this feature). Those files are disposable, non-canonical visual references produced when a downstream project runs the loop — never built, never served, never shipped, and never rendered by anything in `sdd-forge`. This feature reads them; it never writes to them (`design.md`'s Data Plan). No such directory exists anywhere in this repository (`design-sync-consent/frontend-spec.md` records the same absence, unchanged here).

**No `dist/` output is involved, and no build step is added.** The scanner ships as source — a `.sh` file and a `.ps1` file under `plugins/sdd-bootstrap/scripts/`, invoked directly, exactly as `plugins/sdd-quality-loop/scripts/check-placeholders.sh`/`.ps1` already are. ADR-0003's same-commit rebuild obligation does not attach, and `git diff --exit-code -- dist/` is not a leg of any acceptance criterion. Stated in `infra-spec.md` under CI/CD Sequence as well, so the two layers agree.

## Dependencies

None added, none removed, none upgraded. No package manifest or lockfile is touched, so no `npm audit`, license-scan, or SBOM interaction follows. The scanner uses only POSIX shell builtins and `grep`/`sed` (mirroring `check-placeholders.sh`'s own toolset) on the `.sh` side, and only PowerShell 5.1-compatible cmdlets (mirroring `check-placeholders.ps1`) on the `.ps1` side — no external module, no `Install-Module`, no third-party binary.

## Testing

Two verification techniques, not one, unlike a typical frontend layer:

- **Executable unit tests against the scripts themselves.** `tests/design-sync-scan.tests.{sh,ps1}` runs the actual `design-sync-scan.sh` / `.ps1` against `mktemp`-created fixtures and asserts on exit codes and report content — the shape `tests/check-placeholders.tests.sh` already establishes, not a frontend-testing shape (no DOM, no component harness, no snapshot testing; there is nothing here for those tools to attach to).
- **Document conformance over the `SKILL.md` wiring**, in the manner `specs/design-sync-consent/acceptance-tests.md` established, since the wiring itself has no executable code path.

One constraint lands here by association because the scanner's assertions exist in two runtimes: **dual-runtime parity with documented carve-outs only** (mirroring `design-sync-consent`'s BL-008, extended here to genuinely executable code rather than only document assertions). Where an ASCII-only `.ps1` source cannot carry a literal the `.sh` twin asserts, the reason is stated where the asymmetry is created, following the precedent comment at `tests/design-system-contract.tests.ps1:57`. This feature additionally carries a **cross-runtime comparison test** (`requirements.md` AC-031/AC-032, `acceptance-tests.md` TEST-049/TEST-050) that runs both scripts against one shared fixture corpus and diffs their verdicts directly — a stronger claim than either suite passing independently, and a testing shape `design-sync-consent` did not need because it had no executable code to compare.

The case-sensitivity sweep (AGENTS.md "Author-time sweeps", item 1) applies at full strength to this port, unlike `design-sync-consent`'s narrow applicability, since this feature is a genuine `.sh`→`.ps1` translation of new regex-bearing logic (`design.md`'s Test Strategy; `acceptance-tests.md` TEST-051).

## Open Questions

None specific to this layer.
