# RT-20260908-002 local verification — 2026-09-08

Status: repair implemented; integration blocked pending native Windows evidence,
independent quality verification and mandatory CI. This is not a quality-gate PASS.

## Scope and authorization

The user explicitly approved the production repair ticket on 2026-09-08.
The approval is recorded in the main workspace ticket
`/Users/jrmag/sdd-forge/docs/review-tickets/RT-20260908-002.yml`.
Base: `4366438f3b243210a4ece5a17f873ca2d920600a`, detached recovery worktree.
Existing collection test changes from earlier tickets were preserved.
No frozen specifications, task statuses, CI configuration or protection settings
were changed. No commit, push, merge or issue closure was performed.

## Repair

`run-panelist-gemini.ps1` now scans balanced objects respecting strings and
escapes, selects the last exact schema match, and emits candidate-specific
rejection diagnostics. Launch, stdin, timeout, downstream blind/digest/verdict
validation and Google output identity remain unchanged.

Twelve Gemini-specific CL-024 cases exercise the actual runner through an offline
synthetic CLI: single, distractor, last, fenced, malformed, wrong schema,
schema case, blind false, digest case, invalid verdict, last invalid, no object.
Positive cases assert the emitted payload including escaped nested finding text.
Negative cases assert nonzero exit, a diagnostic and absence of verdict output.
The last-invalid case proves no fallback to an earlier acceptable verdict.
No external model invocation was used.

## Actual executions

Commands below ran in this worktree using `rtk proxy`.

| Command | Actual result | Evidence |
| --- | --- | --- |
| `pwsh -NoProfile -File tests/collection-layer.tests.ps1` before production repair | 50 passed, 5 failed; exit 1 | Session 34298, tool chunks 2f355d and 6d0bba; RED, not acceptance |
| Same command after repair and 12 cases | 59 passed, 0 failed; exit 0 | `rt-20260908-002-collection-ps1-green.log`; session 48688, terminal chunk 173399 |
| `bash tests/collection-layer.tests.sh` | 52 passed, 0 failed; exit 0 | session 54529, terminal chunk 8b3841 |
| `bash tests/run-panelist-effort.tests.sh` | 28 passed, 0 failed; exit 0 | c2a7e5 |
| `pwsh -NoProfile -File tests/run-panelist-effort.tests.ps1` | 28 passed, 0 failed; exit 0 | 675886 |
| `bash tests/effort-policy-flip.tests.sh` | 10 passed, 2 failed, 1 skipped; exit 1 | c7c050 |
| `pwsh -NoProfile -File tests/effort-policy-flip.tests.ps1` | exit 1 at line 168, null `.Trim()` | f71219; no completed summary |
| `git diff --check` | exit 0 | fff06f |

Only the final PowerShell collection stdout/stderr tool stream is persisted in
full here. Earlier results above reference observed terminal output; do not
represent those references as saved full-output files or gate-ready evidence.
All these executions used macOS; PowerShell on macOS is not Windows evidence.

## Primary review and case-sensitivity sweep

No Critical finding in this scoped primary review; this is not an independent
evaluator result. Scanner character comparisons use `-ceq`/`-cne`; depth/count
comparisons are numeric. Schema selection uses ordinal `String.Equals` and the
mis-cased-schema negative fixture passes. The preserved digest `-cnotmatch`
rejects uppercase hex (digest-case fixture). Regex fence matching explicitly
lists upper/lower ASCII letters; substring operations use numeric bounds.
No new Select-String, wildcard file selection, sorting, split, or switch appears
in the repair. The pre-existing downstream `-notin` verdict comparison remains
case-insensitive; full shell/PowerShell validation parity is NOT claimed by this
candidate. Changing that downstream contract was not part of this repair.

## Broader suite failure diagnosis

Three hypotheses considered: parser regression; detached checkout/environment;
historical task-specific expectation. The failing code does not call Gemini:
`effort-policy-flip.tests.sh:270-289` demands a T-007 branch and an Unreleased
heading in the first five changelog lines. This checkout is detached and
`CHANGELOG.md:3` is `## v1.17.0 (2026-08-27)`. The PowerShell twin calls
`.Trim()` on the empty branch result at line 168 before emitting its summary.
These observations explain the failures directly. No branch rename, changelog
rewrite, test deletion or assertion relaxation was used to manufacture a pass.
The real Codex smoke remained explicitly skipped, not passed.

## Source hashes

| Path | SHA-256 |
| --- | --- |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1` | `4b73e21e30ae79dc8786d325dbc3425a0492a6c638090eeb9cec25c0f54d5b27` |
| `tests/collection-layer.tests.ps1` | `b9119bd81b2443113cc1fb6c3fb369c8d312bce2bc3620d08184a7a6b2f8dfc4` |
| `tests/collection-layer.tests.sh` | `f1b0e10596f75a21c50fbeb16541137def98306b44b6438de40918256402faeb` |

## Remaining requirements

1. Run Windows-specific fixtures on native Windows against these same bytes.
2. Preserve failed broader-suite results and resolve their task/environment
   applicability explicitly; do not report all verification green.
3. Prepare the sanctioned post-fix declaration and independent quality-gate
   precheck. The installed quality-gate skill requires an Implementation Complete
   target and isolated, manifest-bound evaluation; it cannot accept this primary
   review in place of the evaluator. Historical T-005 Done evidence is not proof
   for these new bytes.
4. Complete mandatory CI before main integration and Issue #359 closure.

The review ticket remains open. No task was newly set to Done.
