# Acceptance Tests: design-sync-scan

Two verification techniques coexist in this feature, and each Test Matrix row uses the one that actually proves its claim. The scanner (`design-sync-scan.sh` / `.ps1`) has real executable behaviour, so criteria about it are verified by **running the script against fixtures and asserting on exit codes and report content** — the style `tests/check-placeholders.tests.sh` already establishes in this repository. The `SKILL.md` wiring has no executable code path of its own — it is instructions an agent follows — so criteria about it are verified by **document conformance**, the technique `specs/design-sync-consent/acceptance-tests.md` uses throughout. A row's Test Type column says which applies; neither technique is used where the other would be weaker for that claim.

Where a criterion's own language enumerates branches or quantifies over conditions, it is expanded below into individual branches, each with its own TEST row and its own concrete assertion, per AGENTS.md `## Rules` → "Author-time sweeps that replace case-by-case vigilance", item 4.

## Test Matrix

| Test ID | AC | REQ | Test Type | Target | Assertion in one line |
|---|---|---|---|---|---|
| TEST-001 | AC-001 | REQ-001 | unit | `design-sync-scan.sh`, `.ps1` | both scripts exist, are directly invocable, and error on zero arguments |
| TEST-002 | AC-002 | REQ-001 | unit (fixture) | same | a finding inside a nested subdirectory's `.html` file is detected |
| TEST-003 | AC-003 | REQ-001 | unit (fixture) | same | one invocation flags findings from more than one category; no flag selects a subset |
| TEST-004 | AC-004 | REQ-001 | unit (fixture) | same | a target directory with zero `.html` files exits 0 |
| TEST-005 | AC-005 | REQ-002 | unit (fixture) | same | a fully clean fixture set exits 0 |
| TEST-006 | AC-006 | REQ-002 | unit (fixture) | same | a **placeholder-only** fixture exits 1 |
| TEST-007 | AC-006 | REQ-002 | unit (fixture) | same | a **secret-only** fixture exits 1 |
| TEST-008 | AC-006 | REQ-002 | unit (fixture) | same | a **PII-only** fixture exits 1 |
| TEST-009 | AC-006 | REQ-002 | unit (fixture) | same | a **mixed-category** fixture exits 1 and the report names every category present |
| TEST-010 | AC-007 | REQ-002 | unit (fixture) | same | a missing/invalid argument exits **2** with a usage diagnostic |
| TEST-011 | AC-007 | REQ-002 | unit (fixture) | same | a nonexistent target directory exits **2**, diagnostic names the missing path |
| TEST-012 | AC-007 | REQ-002 | unit (fixture) | same | an unreadable `.html` file exits **2**, diagnostic names the file; the rest of the set is not silently reported clean |
| TEST-013 | AC-008 | REQ-002 | regression | same | the usage-error branch exits 2, never 1 — contrasted explicitly with `check-placeholders.sh`'s own exit-1 usage-error convention |
| TEST-014 | AC-009 | REQ-003 | unit (fixture) | same | placeholder detection reproduces `check-placeholders.sh:18-19`'s own verdicts against the same corpus |
| TEST-015 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S1** (PEM private-key header) triggers a `secret` finding |
| TEST-016 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S2** (`AKIA[0-9A-Z]{16}`) triggers a `secret` finding |
| TEST-017 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S3** (`ghp_...`) triggers a `secret` finding |
| TEST-018 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S4** (`github_pat_...`) triggers a `secret` finding |
| TEST-019 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S5** (`sk-...`) triggers a `secret` finding |
| TEST-020 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S6** (`xox[baprs]-...`) triggers a `secret` finding |
| TEST-021 | AC-010 | REQ-003 | unit (fixture) | same | secret pattern **S7** (generic keyword `:`/`=` quoted value) triggers on a substantive value and does **not** trigger on a bare or empty value |
| TEST-022 | AC-011 | REQ-003 | unit (fixture) | same | PII pattern **P1** (email-shaped, non-reserved domain) triggers a `PII` finding |
| TEST-023 | AC-011 | REQ-003 | unit (fixture) | same | PII pattern **P2** (E.164-shaped phone) triggers a `PII` finding |
| TEST-024 | AC-011 | REQ-003 | unit (fixture) | same | an email at an RFC 2606 reserved domain/TLD (`example.com`, `.test`, …) does **not** trigger a finding |
| TEST-025 | AC-012 | REQ-003 | unit (fixture) | same | a mixed-category fixture's report labels every finding with its correct category |
| TEST-026 | AC-013 | REQ-004 | unit (fixture) | same | a multi-file fixture's report gives correct, distinct file:line per finding |
| TEST-027 | AC-014 | REQ-004 | unit (fixture) | same | a **secret** finding's report line does not contain the matched value |
| TEST-028 | AC-014 | REQ-004 | unit (fixture) | same | a **PII** finding's report line does not contain the matched value |
| TEST-029 | AC-014 | REQ-004 | unit (fixture) | same | a **placeholder** finding's report line contains the matched marker text in full |
| TEST-030 | AC-015 | REQ-004 | unit | same | the script completes with stdin closed/redirected from `/dev/null` — no interactive read, no prompt |
| TEST-031 | AC-016 | REQ-004 | document conformance | `design-sync-loop/SKILL.md` | step 5 states the invocation, the target directory, and that findings are presented before any push on exit 1 |
| TEST-032 | AC-017 | REQ-005 | document conformance | same | the exit-0 branch states direct continuation to step 6 with no additional prompt |
| TEST-033 | AC-018 | REQ-005 | document conformance | same | the skill text states the check is egress-hygiene-only and makes no quality judgment |
| TEST-034 | AC-018 | REQ-005 | document conformance | `design-sync-scan.sh` / `.ps1` header comment | the script's own header states the same egress-hygiene-only scope |
| TEST-035 | AC-019 | REQ-005 | document conformance (structural) | `design-sync-loop/SKILL.md` | the Loop's step order is structurally unchanged (generate → consent → check point → push → review) |
| TEST-036 | AC-020 | REQ-006 | document conformance | same | the override affordance is stated; absent explicit approval, no push occurs |
| TEST-037 | AC-021 | REQ-006 | document conformance | same | a fresh scan after regeneration is stated to require its own override decision |
| TEST-038 | AC-021 | REQ-006 | document conformance | same | this holds even when the new scan reproduces **identical** findings |
| TEST-039 | AC-022 | REQ-006 | document conformance | same | an override is stated to record `Egress-Scan: overridden` |
| TEST-040 | AC-022 | REQ-006 | document conformance | same | a clean scan is stated to record `Egress-Scan: clean` |
| TEST-041 | AC-023 | REQ-006 | document conformance | same | `Egress-Scan-At` (ISO-8601) is stated for **both** the `clean` and `overridden` values |
| TEST-042 | AC-024 | REQ-006 | regression | same | the five existing `Egress-Consent*` field names are present, unrenamed, and unredefined |
| TEST-043 | AC-025 | REQ-006 | document conformance | same | the decline outcome (no push, no override record, remediate-then-rescan) is stated and distinguished from `Egress-Consent`'s decline/withdrawal |
| TEST-044 | AC-026 | REQ-007 | document conformance | same | step 5 remains the single named point — not duplicated, not relocated |
| TEST-045 | AC-027 | REQ-007 | document conformance (structural) | same | no upload path in the Loop bypasses the check point |
| TEST-046 | AC-028 | REQ-007 | regression | `tests/design-system-contract.tests.{sh,ps1}` | the full existing suite passes unmodified after the `SKILL.md` edit |
| TEST-047 | AC-029 | REQ-008 | document conformance | `claude-design-workflow.md` (or its referring section) | standalone scan usage is documented at the manual-fallback description point |
| TEST-048 | AC-030 | REQ-008 | static | `design-sync-scan.sh` / `.ps1` source | no host- or runtime-conditional branch exists in either script's source |
| TEST-049 | AC-031 | REQ-009 | cross-runtime parity | `design-sync-scan.sh` vs `.ps1` | same exit code on every fixture in the shared corpus |
| TEST-050 | AC-032 | REQ-009 | cross-runtime parity | same | same category and file:line classification on the shared corpus |
| TEST-051 | AC-033 | REQ-009 | case-sensitivity sweep | `design-sync-scan.ps1` | a mis-cased negative fixture per case-sensitive pattern group is rejected identically to the `.sh` original |
| TEST-052 | AC-034 | REQ-010 | suite existence | `tests/design-sync-scan.tests.{sh,ps1}` | both files exist and together cover REQ-001 through REQ-009 |
| TEST-053 | AC-035 | REQ-010 | registration conformance | `tests/run-all.{sh,ps1}` | the new suite is registered in both |
| TEST-054 | AC-036 | REQ-010 | CI-registration conformance | `.github/workflows/test.yml` | the staged patch is tracked; this row stays red against the live tree until a human applies it |

## Test Details

### TEST-001 – TEST-004 (AC-001 – AC-004) — the script contract's basic shape

- **TEST-001** — both runtimes exist at `plugins/sdd-bootstrap/scripts/` and error when invoked with no arguments (the specific error code is TEST-010's claim, not this one — this row only asserts an argument is required).
- **TEST-002** — mockups are organised per view and per state, so a scan that only reads the top level of the target directory would silently miss most real mockup sets; the fixture nests a flagged file at least two directories deep.
- **TEST-003** — asserts the absence of a category-selecting flag by using a fixture with findings in two categories and confirming both appear in one run with no extra argument.
- **TEST-004** — the non-blocking invariant the Loop already states ("absence of mockups... never blocks specification review") must hold for this check specifically: an existing, empty-of-HTML directory is not an error.

### TEST-005 – TEST-009 (AC-005, AC-006) — the detection branches, one row per category and one for the mix

Each category must independently reach exit 1, and the mix must not let one category's finding mask another's absence from the report. Five fixtures: clean, placeholder-only, secret-only, PII-only, and one file carrying a finding from two categories at once — TEST-009 additionally asserts the report names both.

### TEST-010 – TEST-013 (AC-007, AC-008) — the tool-error branch, and its exit code is not 1

Three tool-error causes, each its own row because a caller triaging a red run needs to know which one occurred without reading the diagnostic first:

- **TEST-010** — no argument, or an unrecognised extra argument.
- **TEST-011** — the argument is well-formed but the path does not exist.
- **TEST-012** — the path exists but a file under it cannot be read (permissions, or a fixture removed mid-scan); the assertion requires the *rest* of the set still gets a diagnostic-bearing exit 2, not a partial clean report — the same fail-closed discipline `check-placeholders.sh`/`.ps1` established for issue #127 applies here on first principles, not by inheritance, since this is a different script.
- **TEST-013** — a regression row specifically contrasting this script's exit 2 with `check-placeholders.sh`'s exit 1 for the same class of error (`check-placeholders.sh:6-9`), so a future edit that "fixes" this script to match that convention is caught rather than silently accepted.

### TEST-014 (AC-009) — placeholder detection is the same detection, not a lookalike

Runs `design-sync-scan`'s placeholder path against the same corpus `tests/check-placeholders.tests.sh` uses (or an equivalent corpus built from the same two pattern strings) and asserts the same verdicts. A reimplementation that "looks like" `check-placeholders.sh:18-19` but drifts in one character is exactly the failure this row exists to catch — AC-009 requires the source be cited, not retyped, and this test is the check that the citation was honoured rather than merely claimed.

### TEST-015 – TEST-021 (AC-010) — one row per secret pattern

Each of S1–S7 gets its own fixture and its own row, because a secret scanner that silently drops one vendor format is a scanner with an undocumented gap — the same reasoning `design-sync-consent`'s TEST-033–036 applied to reconciliation sites, applied here to pattern coverage. TEST-021 is the one row with two assertions in the same fixture family: S7's value-length-and-quoting requirement must both catch a real assignment and *not* catch a bare keyword or an empty value, since both halves are load-bearing (a pattern that only ever fires is as broken as one that never does).

### TEST-022 – TEST-024 (AC-011) — PII, and the exclusion that keeps it usable

**TEST-022** and **TEST-023** are the positive cases for the two PII patterns. **TEST-024** is the negative case that makes P1 usable at all: without it, every mockup's conventional `user@example.com` placeholder would flag, and `design.md`'s Design Decisions section states plainly what that does to an operator's attention — they learn to override reflexively, which defeats the signal. This row is therefore not a nice-to-have; a P1 implementation that omits the RFC 2606 exclusion fails this row even though it correctly implements the "positive" half of AC-011.

### TEST-025 (AC-012) — findings are labelled, not just counted

Reuses TEST-009's mixed-category fixture and asserts the report's per-finding labels are correct for all three categories present in the one run — a single fixture suffices because the property under test (correct labelling) is falsifiable by any one mislabelled finding in a mixed set; testing categories in isolation again here would not strengthen the claim.

### TEST-026 – TEST-030 (AC-013 – AC-015) — the report is actionable and not itself a new disclosure surface

- **TEST-026** — a fixture spanning three files with findings in different files and different lines; the report's location data must not collapse or misattribute across files.
- **TEST-027 / TEST-028** — the failing shape for both is a report line that reproduces the exact matched substring for a secret or a PII string; the assertion greps the *matched value itself*, not merely the word "REDACTED", against the report output and requires it absent.
- **TEST-029** — the mirror-image assertion: a placeholder marker must appear in full, so a masking implementation applied indiscriminately to all three categories (over-broad, easier to write, wrong) is caught here rather than passing by accident.
- **TEST-030** — runs the script with stdin explicitly closed and asserts it still completes and produces a verdict; a script that blocks waiting for input would hang a caller that does not expect an interactive step, exactly the failure AC-015 exists to prevent.

### TEST-031 – TEST-035 (AC-016 – AC-019) — the skill text states what the script does, in the right place and the right order

- **TEST-031 / TEST-032** — the two halves of step 5's branching (exit 1 presents before pushing; exit 0 proceeds without a prompt) are asserted as separate rows because a text could state one half correctly while getting the other wrong, and a combined check would hide that.
- **TEST-033 / TEST-034** — the egress-hygiene-only scope statement is required in *both* the skill and the script's own header comment, so either artifact read alone still carries the boundary; two rows because either one going stale independently of the other is a plausible drift (an editor updating the skill's wording without touching the script header, or vice versa).
- **TEST-035** — reuses the structural, position-comparing technique `design-sync-consent`'s TEST-010/TEST-014 established: parse the Loop's numbered list and assert step 5 (the check point) still falls between step 4 (consent) and step 6 (push), and that the cycle at step 7 still returns to step 2, none of which is disturbed by this feature's edit.

### TEST-036 – TEST-043 (AC-020 – AC-025) — the override procedure, in full

- **TEST-036** — the affordance itself, and the negative half in the same row: absent an explicit "yes," the text must not permit a push.
- **TEST-037 / TEST-038** — the no-persistence rule, split because "a fresh scan needs its own decision" and "this holds even for identical findings" are different claims a text could satisfy one of while failing the other; an implementation that special-cases "the findings are the same as last time" to skip re-presentation passes TEST-037 and fails TEST-038, which is exactly the failure mode Edge Case 3 in `requirements.md` names.
- **TEST-039 / TEST-040** — the two possible values of `Egress-Scan`, each its own row for the same reason `design-sync-consent`'s AC-022-equivalent field-value checks were split: a record that only ever writes one value cannot be distinguished from a record that never runs the other branch.
- **TEST-041** — the timestamp requirement applies to both values, not only the exceptional one; the assertion checks the skill states `Egress-Scan-At` accompanies `Egress-Scan: clean` as well as `Egress-Scan: overridden`.
- **TEST-042** — a regression row: greps the skill's field table for the five `design-sync-consent` field names and asserts each is present with its original meaning, unchanged by this feature's addition of two more rows to the same table.
- **TEST-043** — the decline outcome and its distinction from `Egress-Consent`'s vocabulary are asserted together because the distinction is the substantive half — the same pattern `design-sync-consent`'s TEST-043 used for AC-026's decline/not-permitted distinction, applied here to a different pair of concepts that are equally easy to conflate in prose.

### TEST-044 – TEST-046 (AC-026 – AC-028) — the point is not duplicated, not bypassed, and the old lock still holds

- **TEST-044** — asserts step 5 appears exactly once in the Loop's numbered list and that steps 4 and 6 retain their adjacency to it.
- **TEST-045** — the same no-bypass structural technique `design-sync-consent`'s TEST-026 used, re-run against the file after this feature's edit: enumerate every path that reaches the push step and confirm each passes step 5 first.
- **TEST-046** — runs the entire existing `tests/design-system-contract.tests.{sh,ps1}` suite unmodified and requires every assertion in it — the `DS-006` block and `design-sync-consent`'s own structural rows — to still pass. A failure here is proof this feature broke a locked invariant; the fix is to correct this feature's edit, never to edit the suite to accommodate it.

### TEST-047 – TEST-048 (AC-029, AC-030) — the manual/Codex path

- **TEST-047** — the manual-fallback documentation must name the scan and how to run it standalone, at the point a Codex operator (or anyone on a host without `DesignSync`) would actually be reading when deciding what to do before falling back.
- **TEST-048** — a static source check: grep both scripts for anything that branches on an environment marker, a tool-name string, or a caller identity, and require no match. This is what makes "runtime-neutral" a property of the artifact and not merely an intention stated in prose.

### TEST-049 – TEST-051 (AC-031 – AC-033) — the two runtimes agree with each other, not just with their own suites

- **TEST-049 / TEST-050** — run both `design-sync-scan.sh` and `design-sync-scan.ps1` against one shared fixture corpus (every category, the clean case, and each AC-007 tool-error branch) and diff exit codes (TEST-049) and per-finding category/location (TEST-050). This is a stronger claim than "each runtime's own suite passes," and it is the row that would catch a translation error that happens to satisfy both suites independently while disagreeing with each other on the same input.
- **TEST-051** — the case-sensitivity sweep's own row (AGENTS.md item 1): a lower-cased mutation of each case-sensitive pattern group's fixture (the reused placeholder markers, and the S1/S2/S3/S4/S5/S6 vendor-prefix group) must be rejected by both runtimes identically. Unlike `design-sync-consent`, which recorded this sweep as narrowly applicable (no real port existed there), this feature is a real `.sh`→`.ps1` translation and the sweep applies at full strength.

### TEST-052 – TEST-054 (AC-034 – AC-036) — the verification surface itself

- **TEST-052** — the new suite exists and its coverage is traceable to REQ-001 through REQ-009 (not REQ-010 itself, which this row and the two below cover).
- **TEST-053** — both `tests/run-all.sh` and `tests/run-all.ps1` list the new suite; neither file is protected (`guard_invariants.py:4`), so this is agent-applicable directly, unlike a protected-file change would be.
- **TEST-054** — mirrors `design-sync-consent`'s AC-024/TEST-039 exactly: `.github/workflows/test.yml` is protected, its registration is a separately staged, human-applied patch, and this row is **designed to stay red** against the live tree until that patch lands — not a defect, and not something a task in this feature's own decomposition can close.

## UI Integration Checklist

**N/A — no user-facing entry point.** This feature adds no view, dialog, menu item, or context action. Its only human-perceivable surfaces are a terminal/agent-session finding report and an override decision point inside an existing skill flow, neither of which has a shell location to be reachable from. Recorded as N/A rather than omitted, matching `specs/design-sync-consent/acceptance-tests.md`'s own treatment of the same question for the same loop.

## Notes

- **Test type vocabulary.** `unit` and `unit (fixture)` rows execute the actual scripts against files created for the test; `document conformance` and `document conformance (structural)` rows read and parse `SKILL.md` text without executing anything; `cross-runtime parity` rows execute both scripts against the same input and diff their output; `regression` rows assert something already true stays true; `static` and `case-sensitivity sweep` rows inspect source without executing the scanned-for behaviour; `registration conformance`, `suite existence`, and `CI-registration conformance` rows are about the verification surface itself, mirroring `design-sync-consent`'s TEST-038/TEST-039 vocabulary for the same class of claim.
- **Dual-runtime parity, with the same carve-out discipline `design-sync-consent`'s BL-008 established.** Every `.sh`-suite assertion in TEST-001–TEST-048 has a `.ps1` counterpart; where an ASCII-only `.ps1` source cannot carry a literal the `.sh` twin asserts, the reason is stated where the asymmetry is created. TEST-049–TEST-051 are the additional, stronger cross-runtime rows described above and are not a substitute for this per-suite parity.
- **Case-sensitivity sweep (AGENTS.md item 1) applies at full strength here**, unlike in `design-sync-consent`. This is a genuine `.sh`→`.ps1` port of new regex-bearing logic; TEST-051 is its dedicated row, but the sweep itself — both the operator-level and the cmdlet-level passes AGENTS.md describes — must be performed across the whole `.ps1` script, not only at the one row that names it.
- **Re-verify every `file:line` in this document at implementation start**, per the same recurring-defect discipline `requirements.md` → Assumptions states (WFI-011).
- **This suite proves detection and wiring; it cannot prove an agent runs the scan.** Precisely as `design-sync-consent/acceptance-tests.md` states for its own document-conformance tests: these rows prove the script detects correctly and that `SKILL.md` describes the right procedure. They cannot prove an agent actually invokes step 5 before pushing on a given real run — REQ-007's no-bypass assertion (TEST-045) is the strongest structural guarantee this specification can offer, and it is a claim about the text, not about runtime behaviour no mockup generation has ever produced in this repository to observe.
