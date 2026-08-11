# Implementation Report Addendum: T-005 Remedy 1

- Task ID: T-005
- Model: Claude Sonnet 5
- Effort: high

Report Schema: implementation-report/v2 (remedy addendum)

This is a remedy addendum, not a revision of
`reports/implementation/epic-191-a3-path-ownership/T-005.md`, per
`quality-gate/SKILL.md`'s own guidance not to edit a frozen implementation
report to reconcile post-gate findings. The original report's narrative
stands as the record of that authoring run; this addendum records the
remedy work done in response to the quality-gate's findings.

## Source Finding

`reports/quality-gate/epic-191-a3-path-ownership/T-005.md` (Verdict:
NEEDS_WORK, Done Decision: Blocked), Major finding 1: `check_inventory_conformance`
(bash) / `Test-InventoryConformance` (PowerShell) performed only a
fixed-string/regex-escaped substring match, which caught a missing entry
and the one specific extra `contracts/**` case, but did not reject (a) an
arbitrary extra cross-cutting entry ("no more") or (b) a canonical entry
wrongly classified as bounded instead of cross-cutting ("no differently
classified") — both explicitly required by AC-042. This gap is independent
of Epic A1's template landing and was actionable immediately.

## Remedy

Rewrote both check functions to parse the actual `shared_paths` entry
structure and assert **set equality** between the template's cross-cutting
patterns and the canonical six-entry set — one assertion that catches
missing, extra, AND misclassified entries simultaneously (a canonical
pattern declared bounded is neither absent from `shared_paths` nor
cross-cutting, so it fails the same equality check either way).

- **Bash** (`tests/component-path-resolver.tests.sh`): reuses
  `resolve-component-paths.py`'s own restricted-YAML parser
  (`parse_minimal_yaml`) via a `python3 -` invocation, rather than a
  second, potentially-diverging parser implementation.
- **PowerShell** (`tests/component-path-resolver.tests.ps1`): originally a
  small, purpose-built line-based parser scoped to exactly the
  `shared_paths` entry shape (dot-sourcing `resolve-component-paths.ps1`
  was rejected as an approach — its CLI dispatch/`exit` logic sat at
  script scope, so dot-sourcing it with no bound parameters would execute
  that logic and terminate the calling test script too).

  **Correction (T-005 quality-gate cycle 2, 2026-08-09)**: this
  description no longer matches the code and is left here struck through
  in substance rather than silently rewritten, per the finding at
  `reports/quality-gate/20260809T081500Z-epic-191-a3-path-ownership-T-005.md`
  (Minor). The line-based parser above was itself structure-UNAWARE in
  three ways that gate cycle proved by mutation against the real landed
  `contracts/project-context.template.yaml`: case-insensitive
  `-eq`/`-ne` classification comparison, no `shared_paths:` block
  tracking (entries under an unrelated top-level key still counted), and
  block-form-only `components:` detection (an inline `components: [x]`
  combined with `classification: cross-cutting` went unseen). All three
  produced a false-conformant verdict on a template shape the resolver
  itself rejects fail-closed. Separately, `resolve-component-paths.ps1`
  gained a `$MyInvocation.InvocationName -ne '.'` guard around its CLI
  dispatch (for T-004's `check-component-coverage.ps1`, which already
  dot-sources it this same way), so the original rejection reason no
  longer holds: a bare `. resolve-component-paths.ps1` with no bound
  parameters now only defines its functions/classes and never runs that
  CLI body. `Test-InventoryConformance` was rewritten to dot-source that
  script for its own `ConvertFrom-MinimalYaml` restricted-YAML parser and
  read `$data["shared_paths"]` structurally, with case-sensitive
  (`-ceq`/`-cne`/`-ccontains`) comparisons throughout — the same
  structural delegation the bash twin already had via
  `parse_minimal_yaml`, not a second, potentially-diverging
  implementation. See that script's `Test-InventoryConformance` header
  comment for the full account.

Added two new `TEST-042-negative` sub-cases the quality-gate specifically
named as unexercised: `.2` (all six canonical entries present and
correctly classified, PLUS one arbitrary extra `vendor/**` entry — a pure
"no more" violation) and `.3` (a canonical entry, `specs/**`, declared
bounded via `components:` instead of `classification: cross-cutting` — a
pure "no differently classified" violation). Verified both new sub-cases
are rejected as expected on both runtimes, and re-verified a genuinely
conformant fixture is still accepted (no regression toward over-rejection).

## Outputs

Population: this addendum's own commit (`347f2f70`). The hashes below are
refreshed to the current on-disk value — the file was edited again after
this addendum's own authoring run, by T-001's unblock commit (`01df4cbd`),
by T-001's quality-gate remediation pass (adding TEST-002.3-.5 and
extending TEST-010.3's stable-sort fixture), and most recently by T-005's
own SECOND quality-gate remediation pass (2026-08-09, cycle 2 — see the
Correction note under Remedy above, and `T-005.md`'s own "Quality-gate
remediation addendum (2026-08-09, cycle 2)" section for the full account:
`Test-InventoryConformance` was rewritten again, from the hand-rolled line
parser this addendum introduced to a structural delegation via dot-sourcing
`resolve-component-paths.ps1`, and six new `TEST-042-negative` sub-cases
were added). Same current hash as declared in `T-005.md`'s own Outputs
table (both reports declare the same shared file), restricted via `git
diff --name-only` to this remediation's own changes (concurrent, unrelated
working-tree changes from other tasks' sessions sharing this worktree —
`plugins/sdd-quality-loop/scripts/resolve-component-paths.{ps1,py}` and
`tests/component-path-diff-basis.tests.{sh,ps1}` — are excluded as not
this task's output). Refreshed again below (2026-08-10): T-005's own
cycle-4 remediation reworded the `TEST-042-negative.6` assertion messages
in this same shared file (message text only — see `T-005.md`'s Cycle-4
remediation addendum), per RT-20260809-001's convention that a shared file
is declared at its CURRENT on-disk hash. Excluded as not-an-implementation-output:
`reports/quality-gate/epic-191-a3-path-ownership/T-005.md` (the finding this
addendum responds to — a review artifact) and
`specs/epic-191-a3-path-ownership/verification/T-005/*` (evidence logs,
regenerated by the cycle-2 remediation at the current 66/0 state but still
excluded under this same rationale) and this report itself;
`specs/epic-191-a3-path-ownership/tasks.md` (Approval/Status only) is
excluded as hash-bound.

| Path | SHA-256 |
|---|---|
| `tests/component-path-resolver.tests.ps1` | `bcf37072eeef43b892e357c5f94d4507b96d10a8f0009972c356adae4b32eb3a` |
| `tests/component-path-resolver.tests.sh` | `e8ebe2658a154bcfa6d867af7cd0517eca8d31adb009d9aad944a49600541030` |

> Refreshed 2026-08-11: T-001's RT-20260811-001 remediation edited this same
> shared pair (TEST-045.5 repointed to the human-copy staged candidate,
> TEST-045.6 replaced by a commit-attribution check, TEST-056 and an AC-049
> self-check added — none of it touches the T-005-owned TEST-042/043/044
> assertion groups, and both twins were re-verified green at 73/0 after the
> edit). Declared at the current on-disk hash per RT-20260809-001's
> shared-file convention; T-005's Status and Approval are untouched.
>
> Refreshed again 2026-08-11 (same convention): the seq0682 gate found the
> new TEST-045.6/AC-049 guards fail closed in a depth-1 CI checkout; both
> are now two-form (strict commit-attribution with full history, content-
> level fallback when shallow), the pinned set gains three commits, and
> the twins were re-verified green at 73/0. T-005-owned assertions are
> untouched.

## Test Evidence

- **Test Command**: `bash tests/component-path-resolver.tests.sh` and
  `pwsh -NoProfile -File tests/component-path-resolver.tests.ps1`
- **Test Result**: 40 passed / 3 failed on both runtimes (up from 38/3 —
  the two new TEST-042-negative sub-cases both pass; the three pre-existing
  failures, TEST-011.3/TEST-042/TEST-044, remain the same documented,
  designed Epic A1 external-dependency red state, unaffected by this
  remedy).
- **Test Evidence Path**:
  `specs/epic-191-a3-path-ownership/verification/T-005/component-path-resolver.GREEN.log`
  and
  `specs/epic-191-a3-path-ownership/verification/T-005/component-path-resolver-ps1.GREEN.log`
  (both refreshed to reflect this remedy's 40/3 state)

## Status After Remedy

Task remains `Blocked` — this remedy closes the one actionable-now Major
finding, but the task's Done state is still gated on Epic A1 shipping
`contracts/project-context.template.yaml` matching the six-entry set
(TEST-042/TEST-044), per the second Major finding and `tasks.md` T-005's
own Blockers note. Not resubmitted for quality-gate re-review in this
session (task is not being moved toward Done); recorded here for the next
quality-gate pass once Epic A1's artifact lands.
