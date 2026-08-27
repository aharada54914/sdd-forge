# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-046 |
| Category | plugin-improvement |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | NEEDS_REVISION |
| Critical Findings | 0 |
| Major Findings | 3 |
| Minor Findings (Advisory) | 1 |
| Generated | 2026-08-23T14:05:00Z |

## Verdict: NEEDS_REVISION

The bypass is real, reproduced on both runtimes, and the fix is the right one. But the
Node twin is cited at the wrong line, and the line named belongs to the sibling
approval exemption that already carries this fix -- an implementer following the
document literally would find the disqualifier present, conclude the work was done,
and leave the actual Node bypass open. That single citation is the difference between
a fix and the appearance of one. The why-chain also skips the mechanical level that
explains why the guard's fail-closed analysis never runs.

---

## Check Results

| Check | Result | Severity |
|---|---|---|
| EVIDENCE-CITED | **FAIL** | Major |
| ROOT-CAUSE-PLAUSIBLE | PASS | Major |
| WHY-CHAIN-VALID | **FAIL** | Major |
| CATEGORY-LANGUAGE-MATCH | PASS | Critical |
| CHANGE-CONCRETE | **FAIL** | Major |
| EFFECT-MEASURABLE | PASS | Major |
| VERIFICATION-METRIC-DEFINED | PASS | Major |
| VERIFICATION-PLAN-SPECIFIC | PASS | Major |
| NO-PLUGIN-SCOPE-CREEP | PASS | Critical |

## Findings

### EVIDENCE-CITED — Major

One severe mis-citation, plus one correct-but-imprecise cite. THE NODE TWIN IS NAMED WRONG, AND THE NAMED LINE IS THE ALREADY-FIXED SIBLING. The WFI cites the Node write-protection short-circuit at sdd-hook-guard.js:1161. Line 1161 is not in that function at all: it is inside wfiApprovalIncreases (def :1139), the APPROVAL-FIELD exemption -- a different gate governing a different decision -- and that exemption ALREADY carries the executing-syntax disqualifier at :1163, added by 918c6831. An implementer following the WFI literally would open :1161, find the disqualifier already present, and either conclude the work was done or add a redundant second copy; either way the actual Node bypass stays open while the WFI reads as applied. The real twin is sdd-hook-guard.js:617, inside shellTargetsProtectedGateFile (def :598): `if (!SHELL_COMPOUND_RE.test(cmd) && SHELL_SUDO_READ_ONLY_RE.test(cmd) && !hasWrite) return false;` -- the exact three-clause shape the py site at :1462 has. The two functions are roughly 700 lines apart and share only that shape, which is precisely how the confusion arises and why the WFI must disambiguate them explicitly. Secondary: the ps1 cite :966-967 spans the isReadOnlyStart assignment and the short-circuit; the short-circuit itself is :967, in Test-ShellTargetsProtectedGateFile (def :947). The py cite :1462 is correct. The three measured probe rows are accepted: the command-substitution and backtick bypasses reproduce, and the control is denied.

### WHY-CHAIN-VALID — Major

The link from level 3 to level 4 is broken. Level 3 explains why the clauses cannot see inside a substitution (the write vocabulary is a text denylist). Level 4 then asks why the class was fixed in the sibling exemption but not here -- a question about review scope, not a consequence of level 3. A why-chain must descend; this one changes subject. The missing level is the mechanical one that makes the bypass reachable: the short-circuit RETURNS at the clause test, so control never reaches the fail-closed write-target analysis sitting three lines below it (_shell_write_targets_are_safe at py:1466, shellWriteTargetsAreSafe at js:621, Test-ShellWriteTargetsAreSafe at ps1:969). Without that level the chain never explains why a guard that fails closed on unmodelled writes nonetheless allows this one. Separately, level 3's evidence cell is prose ('the write-vocabulary matcher over the whole command string') where every other cell carries a citation; the vocabulary is defined as sudo_write_re at plugins/sdd-quality-loop/references/guard-invariants.json:182 and tested at py:1461.

### CHANGE-CONCRETE — Major

Rows 2 and 3 inherit the mis-citation charged under EVIDENCE-CITED: the js row instructs 'the identical change at :1161' and the ps1 row ':966-967'. As Target File cells these name real files, but the Change Description points the implementer at the wrong line in the Node guard -- the one place where following the instruction literally produces a change that looks complete and leaves the bypass open. Row 1 (py) is concrete and correct. Rows 4-5 (the regression cases and the cross-exemption drift invariant) are specific and testable as written. The 'Not proposed' paragraph correctly rejects the tempting non-fix of adding tar to the vocabulary, on the right grounds: the bypass does not depend on tar.

## Proposed Revisions

Applied verbatim by the orchestrator, which is the only entity that writes WFI
content during an audit cycle.

**1. [Major] ## Problem Evidence**

Correct the Node twin from sdd-hook-guard.js:1161 to :617, naming the enclosing function shellTargetsProtectedGateFile (def :598), and tighten the ps1 cite to :967 in Test-ShellTargetsProtectedGateFile (def :947). Add an explicit paragraph distinguishing this exemption from the approval-field exemption in wfiApprovalIncreases (def :1139, disqualifier already at :1163), since the two share a clause shape and confusing them is what produced the error.

**2. [Major] ## Proposed Change (js and ps1 rows)**

Apply the same line corrections in the js and ps1 rows, and state in the js row that :1163 is NOT the target so the mistake cannot be reintroduced.

**3. [Major] ## Why-Why Analysis**

Insert a new level 4 between the current 3 and 4: the short-circuit returns at the clause test, so control never reaches the fail-closed write-target analysis below it (py:1466 / js:621 / ps1:969). Renumber the review-scope question to level 5.

**4. [Minor] ## Why-Why Analysis (level 3)**

Replace the prose evidence cell with a citation: sudo_write_re at plugins/sdd-quality-loop/references/guard-invariants.json:182, generated into each runtime and tested against the whole command at py:1461.

**5. [Minor] ## Proposed Change (py row)**

Note that WFI_EXEMPTION_UNSAFE_RE is no longer WFI-specific once a second gate uses it, and rename it in the same change, updating both use sites.

---

## Bridge to Cycle 2

`WFI-046-integrated-summary.json` carries counts and check IDs only. The Cycle-2
auditor (`wfi-auditor-b`) is a fresh isolated agent and does not read this report
or the raw Cycle-1 output.
