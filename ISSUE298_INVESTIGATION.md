# Investigation: model-freshness false positives (#298)

Mode: bugfix investigation. Date: 2026-09-05. Baseline: `3749a252af31c504387c4cb8855342261c41dbbd`. Investigator: inexpensive explorer plus primary-agent verification. No implementation or registry changes.

## Findings

| ID | Finding | Evidence |
|---|---|---|
| INV-001 | Raw fetched model-documentation text is split on whitespace; a token is admitted if its charset is alphanumeric/dot/hyphen and it contains any digit. Markup is not parsed first. | `.github/scripts/check-model-freshness.sh:106`, `:129`, `:158` |
| INV-002 | Consequently `123.5`, `M0.5`, and `bg-gray-75` pass exactly like the synthetic model `gpt-99`. Primary ran the actual `extract_candidate_tokens` function after sourcing definitions with only the final main invocation removed; all four appeared. No fetch or gh action ran. | `.github/scripts/check-model-freshness.sh:158` |
| INV-003 | Fixtures lock fail-soft, divergence, dedup, no-diff and injection filtering, but use synthetic plain-text model names rather than HTML-heavy vendor fixtures. | `tests/model-freshness-check.tests.sh:156`, `:183`, `:252`, `:308`, `:362`, `:386`; twin `tests/model-freshness-check.tests.ps1` |
| INV-004 | Registry mutation is expressly excluded; automatic issue text requires human triage. The production script intentionally has no PowerShell twin; tests do have a twin. | `.github/scripts/check-model-freshness.sh:21`, `:45`, `:250`; `tests/model-freshness-check.tests.sh:531` |

All 31 pinned remote heads were checked with `git diff --name-only <pinned-main>...<head> --` the script, possible ps1 script, both test suites, workflow, and registry paths. Every diff was empty. This is evidence of no branch-side committed patch on those exact paths, NOT proof of ownership release or no work elsewhere. Exact heads are in the inventory JSON. Owner local-only/uncommitted states remain outside that proof.

## Codemap

| Surface | Responsibility |
|---|---|
| `.github/workflows/model-freshness-check.yml:41` | Scheduled/manual Ubuntu execution; supplies GitHub token to script |
| `.github/scripts/check-model-freshness.sh:86` | Fixture-injectable curl fetch |
| `.github/scripts/check-model-freshness.sh:129` | Registry-versus-candidate divergence |
| `.github/scripts/check-model-freshness.sh:158` | Candidate filter — defect boundary |
| `.github/scripts/check-model-freshness.sh:170` | Read-only registry-name and basename extraction |
| `.github/scripts/check-model-freshness.sh:211` | Dedicated markers, gh issue create/comment/dedup |
| `tests/model-freshness-check.tests.sh:74` | Temporary fixtures and fake gh; no live credentials |

Dependencies: Bash, curl, grep/sed/tr/sort, gh; registry `contracts/agent-model-capabilities.v2.json`. Scope excludes capability selection, registry model recommendations and unrelated workflow repairs.

## Baseline behavior

| ID | Trigger | Preserve? | Observable result / evidence |
|---|---|---|---|
| BL-001 | Either fetch fails | Yes | Dedicated unavailable issue path; exit 0 (`check-model-freshness.sh:258`) |
| BL-002 | Genuine missing model token | Yes | Divergence issue or dedup, fixed marker (`:224`) |
| BL-003 | All candidate models already known | Yes | No gh side effects (`:272`) |
| BL-004 | Malicious markup/instructions | Yes | Never execute content or write registry; issue tokens restricted (`:158`, tests `:386`) |
| BL-005 | Numeric CSS/SVG token | No | False candidate admitted (INV-002) |

## Proposed specification work — not Approved

Define the recognition contract before coding: vendor-aware model ID recognition versus markup parsing; expected treatment of human display names and punctuation; empty/changed vendor pages; dedup behavior when a stale noisy issue remains open. Preserve fail-soft, no-registry-write and injection boundaries. Add realistic offline HTML/CSS/SVG fixtures plus genuine-model positive controls, mixed-case and malformed negatives in both test harnesses. Never use model recommendations guessed from the noisy issue body.

Next SDD transition: bootstrap Phase 1, independent spec/design reviews, Draft task decomposition and independent task review, then explicit human approval of the selected task. No existing Approved task for this fix has been established. Do not retrofit frozen epic-159-pillar-d artifacts or mark #298 resolved from this investigation.

## Historical validation limit — superseded for suite execution below

The direct token-function reproduction succeeded. `rtk proxy bash tests/model-freshness-check.tests.sh` produced no output for over two minutes and was terminated by exact known test-process PIDs. No suite pass is claimed; the local startup/hang cause is undiagnosed. The test suite's documented behavior above is source evidence, not a successful full run in this turn.

## Baseline suite verification — 2026-09-06

The unchanged suites completed in detached worktree
`/private/tmp/model-freshness-verify.FTfm7p/worktree`, at
`9dd531f94882eb18fe7f783de395cd1c7a8ee208`. Primary independently checked
that exact HEAD, empty git status, and the raw log summaries:

- System `/bin/bash`: 40 passed, 0 failed;
  `/tmp/model-freshness-check-9dd531f9.log`.
- PowerShell twin: 29 passed, 0 failed;
  `/tmp/model-freshness-check-9dd531f9.ps1.log`.

These are existing fixture-suite results, not acceptance of a fix for #298.
The candidate filter still admits any allowlisted whitespace token containing
a digit (`.github/scripts/check-model-freshness.sh:158-163`); baseline success
does not establish model-ID recognition or realistic markup coverage. No
production script, registry, test, or issue state was changed. The previous
interrupted run remains historical evidence, not a diagnosed failure cause.
