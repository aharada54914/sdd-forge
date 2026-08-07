# Requirements: design-sync-scan

Spec-Review-Status: Pending

Source issue: [#139](https://github.com/aharada54914/sdd-forge/issues/139) (`enhancement`, `security`; key `DS-30`, epic #136). Depends on: [#138](https://github.com/aharada54914/sdd-forge/issues/138) (`DS-29`), specified in `specs/design-sync-consent/`. Sibling: [#140](https://github.com/aharada54914/sdd-forge/issues/140) (`DS-31`), not addressed here.

## Overview

`design-sync-loop` pushes generated HTML mockups from the operator's machine to a claude.ai/design project (`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`). DS-29 (`design-sync-consent`) changed the egress gate's unit from per-upload to per-feature-and-session consent, and in doing so demoted local human review from a mandatory precondition to an optional offer (`SKILL.md`'s Loop, step 4 "Local review is OPTIONAL and non-blocking"). That demotion is deliberate and already shipped; `design-sync-consent/security-spec.md`'s Residual Risk **R1** names its consequence plainly: *"Demoting local review removes the only step at which a human necessarily sees the payload before it leaves... This feature adds no compensating mechanical control; #139 is that control."*

This feature is that control. It adds a runtime-neutral, mechanical pre-upload scan for three egress-hygiene categories — placeholder/stub markers, secret-shaped tokens, and PII-shaped strings — over the HTML files under `specs/<feature>/mockups/`, and attaches it to the single named point `SKILL.md`'s Loop already reserves for exactly this purpose: step 5, "Pre-upload check point" (`:128-135`), which today performs no check and states in its own text that DS-30 attaches here.

Three things about the shape of this change need saying plainly, because scope discipline here is what keeps this feature from silently becoming DS-29 v2 or a general-purpose secret scanner.

**This is egress hygiene, not quality review.** The issue's own Rationale is explicit: "品質の良し悪しは判定しない" (this does not judge quality). Nothing in this feature assesses mockup design, UX, accessibility, or fidelity to `design-system/`. Those are `design-system-contract`'s and human review's job. This feature only asks: does the payload about to leave contain a stub marker, a secret-shaped token, or a PII-shaped string. A scan that grows opinions about anything else is out of scope by construction.

**This is a compensating control for R1, not a replacement for it.** Pattern matching over HTML text cannot catch a secret that matches no known shape, a PII string in a format this feature does not enumerate, or a confidential business fact with no distinguishing lexical signature (an unreleased product name is exactly this — `design-sync-consent/security-spec.md` E2 names it as the substantive egress risk, and no regex catches it). This feature narrows R1; it does not close it. `security-spec.md` records the gap as a residual risk rather than implying completeness.

**The gate is mechanical, and its override is human, not automatic.** The issue's three acceptance boxes are: detection blocks the upload and shows the human what was found; a clean scan does not slow down DS-29's flow; and a false positive has a documented way past the gate. All three are binary behaviours a script and a short skill-text addition can state precisely, which is why this feature — unlike DS-29 — has an executable artifact at its centre rather than being pure document conformance.

## Requirements

### REQ-001 — a runtime-neutral script pair exists and scans a target directory's HTML files for all three categories in one pass

`plugins/sdd-bootstrap/scripts/design-sync-scan.sh` and `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1` (both new) each take the scan target directory as a required first positional argument and scan every `*.html` file found recursively under it. The two runtimes are twins in behaviour, not merely in name (REQ-009).

No default directory is baked into the script: the conventional caller — `design-sync-loop/SKILL.md` step 5, and the documented manual/Codex usage (REQ-008) — supplies `specs/<feature>/mockups/` explicitly as that argument. A script with no knowledge of "the current feature" cannot supply that path itself; making the argument required, mirroring `check-placeholders.sh`'s own `<file-or-dir> [<file-or-dir> ...]` convention, keeps the contract honest about where the value comes from.

#### AC-001

Both `design-sync-scan.sh` and `design-sync-scan.ps1` exist at `plugins/sdd-bootstrap/scripts/`, are directly invocable (`bash design-sync-scan.sh <dir>` / `pwsh design-sync-scan.ps1 <dir>`), and require the scan target directory as their first positional argument — no invocation with zero arguments succeeds.

#### AC-002

The scan covers `*.html` files recursively under the target directory, including files in subdirectories (mockups are organised per view and per state, so a single flat scan would miss nested files).

#### AC-003

All three detection categories (REQ-003) run in a single invocation. No flag selects a subset; a clean run and a run with findings differ only in what was found, never in what was looked for.

#### AC-004

A target directory that exists but contains zero `.html` files exits 0 and is not treated as an error — consistent with `SKILL.md`'s non-blocking invariant ("absence of mockups... never blocks specification review"). A feature with no mockups yet has nothing to scan, and that is not a failure of the scan.

### REQ-002 — the exit-code contract is exactly three-valued, and it is fail-closed

The contract is decided, not left to the implementation: **0** = no detection, upload may proceed; **1** = at least one detection, upload must not proceed without an explicit human override (REQ-006); **2** = the tool itself could not complete the scan, treated identically to a detection for gating purposes (fail-closed) but distinguished in wording from a genuine finding, so an operator debugging a missing script or a permissions error is not misdirected into hunting for a secret that was never found.

#### AC-005

Exit code is 0 if and only if no pattern in any of the three categories matched anywhere in the scanned set.

#### AC-006

Exit code is 1 if and only if at least one pattern matched, in one or more of the three categories. Each category independently reaching exit 1 is verified on its own, and a mixed-category case is verified separately again, so a category that only ever triggers detection while riding alongside another category's finding does not go unnoticed:

1. a placeholder-only fixture exits 1;
2. a secret-only fixture exits 1;
3. a PII-only fixture exits 1;
4. a fixture with findings in more than one category exits 1, and the finding report (REQ-004) still names every category present, not only the first one matched.

#### AC-007

Exit code is 2 for a tool error, enumerated exhaustively rather than left open-ended: a missing or invalid positional argument; a target directory that does not exist; and a file under the target directory that cannot be read. Each is its own branch because each is a different failure a caller must be able to tell apart from the others when triaging a red run:

1. no argument, or more arguments than the contract defines, exits 2 with a usage diagnostic;
2. a nonexistent target directory exits 2 with a diagnostic naming the missing path;
3. an unreadable `.html` file under an otherwise valid target directory exits 2 with a diagnostic naming the file — the scan does not silently skip a file it could not read and report the rest as clean, mirroring the fail-closed discipline `check-placeholders.sh`/`.ps1` already established for issue #127 (grep exit ≥2, or a PowerShell path/read failure).

#### AC-008

The usage/argument-error branch of AC-007 exits 2, not 1 — stated because it is a deliberate divergence from `check-placeholders.sh`, whose own missing-argument branch exits 1 (conflating "bad usage" with "markers found" under one code, `check-placeholders.sh:6-9`). This script's two failure codes carry different caller-facing meanings and must not be collapsed into one: a caller that branches on exit code to decide whether to show "here is what was found" versus "the tool did not run" would show the wrong message on any invocation-error path if the two were conflated.

### REQ-003 — the three detection categories are named, and their exact pattern sets are enumerated in `design.md`, not deferred to the implementer

The issue names three categories and licenses reuse of `check-placeholders.sh`'s patterns for one of them; it does not enumerate the secret or PII pattern sets, and deliberately leaves their exact composition to be settled in this specification (`design.md`) rather than guessed at implementation time.

#### AC-009

The placeholder category reuses `plugins/sdd-quality-loop/scripts/check-placeholders.sh:18-19`'s two patterns — the case-sensitive stub-marker set and the case-insensitive phrase set — verbatim. Not re-derived, not narrowed, not embellished; cited by source and re-read at implementation time (Assumptions).

#### AC-010

The secret category's pattern set is enumerated by name in `design.md`, each member with a stated rationale, and split into a case-sensitive group (fixed vendor-format prefixes, whose casing is part of the format) and a case-insensitive group (generic keyword-plus-assignment shapes, whose casing varies in the wild) — mirroring the same case-sensitive/case-insensitive split `check-placeholders.sh` already uses and for the same reason: a naive single case-insensitive sweep over generic keywords produces false positives on ordinary prose, while a vendor-format prefix is exactly as case-fixed as `TODO` is.

#### AC-011

The PII category is exactly two patterns, both named and both justified for their false-positive/false-negative trade-off in `design.md`: a conservative email-shaped pattern that excludes RFC 2606 reserved placeholder domains and TLDs (`example.com`/`.net`/`.org`/`.edu`, and the `.test`/`.example`/`.invalid`/`.localhost` TLDs), and a conservative E.164-shaped phone pattern. Neither category grows a third pattern without a design.md amendment — an unbounded, ad hoc PII pattern list is exactly the scope creep this feature must not become.

#### AC-012

Every reported finding is labelled with its category (`placeholder`, `secret`, or `PII`). A report that aggregates "N finding(s)" without saying which category each belongs to fails this criterion, because REQ-004's presentation to the human depends on the human being able to triage by category.

### REQ-004 — a detection blocks the upload, and the findings are presented to the human without re-exposing the sensitive value itself

The issue's first acceptance box: "secret/PII/placeholder 検出時に upload がブロックされ内容が人間に提示される" (on detection, upload is blocked and the content is presented to a human). "内容が提示される" is read here as *the finding's location and kind*, not as *the literal matched bytes reproduced in a terminal or a log* — printing a genuine secret to stdout for triage purposes would make the scanner itself a new place that secret is exposed, on the exact class of surface (terminal scrollback, CI logs, a captured session transcript) this repository already treats carefully elsewhere (`cross-model-verification-policy.md`'s redaction-before-send).

#### AC-013

On exit 1, the report enumerates every finding with a file path and a line number sufficient for a human to open the right file at the right place, across a fixture spanning multiple files.

#### AC-014

The secret and PII categories mask the matched value in the report rather than reproducing it; the placeholder category does not, because a stub marker (`TODO`, `PLACEHOLDER`) carries no sensitivity and showing it in full is what makes the finding actionable. Three branches, because the masking rule is category-differentiated and each direction fails independently:

1. a secret finding's report line does not contain the matched secret value;
2. a PII finding's report line does not contain the matched email address or phone number;
3. a placeholder finding's report line contains the matched marker text in full.

#### AC-015

The script itself presumes no interactive human at its own invocation — it reads no stdin, prompts for nothing, and completes deterministically from its arguments and the filesystem alone. Its exit code plus its finding report are sufficient for a caller to gate on. This is the same hedge `design-sync-consent`'s AC-018 states for the pre-upload check point generally (`design-sync-loop/SKILL.md:133-134`, "does not presume an interactive human is present"), restated here as a property this feature's own artifact must hold, not only a property the point that hosts it must hold.

#### AC-016

`design-sync-loop/SKILL.md` step 5 states the invocation — the script, and `specs/<feature>/mockups/` as its target — and states that on exit 1 the findings are presented to the human before any push is attempted; no push occurs without that presentation having happened.

### REQ-005 — a clean scan does not impede the DS-29 flow, and the check makes no quality judgment

The issue's second acceptance box: "検出なしなら DS-29 のフローを妨げない（egress hygiene に限定、品質判断はしない）" (if nothing is detected, the DS-29 flow is not impeded; scoped to egress hygiene, no quality judgment).

#### AC-017

On exit 0, `SKILL.md` step 5 states the loop proceeds directly to step 6 (push) with no additional prompt and no delay beyond the scan's own run time.

#### AC-018

Both `SKILL.md` (at the point the check is described) and the script's own header comment state explicitly that the check is limited to egress hygiene — placeholder, secret, and PII detection — and performs no assessment of mockup quality, design fidelity, accessibility, or adherence to `design-system/`. Two TEST rows, one per artifact, because a scope statement that lives only in the skill and not in the script (or vice versa) leaves the other artifact's reader without the boundary that keeps a future edit from quietly growing a quality opinion into the check.

#### AC-019

The Loop's step order — generate → consent → **check point** → push → review, cycling back to generate — is unchanged in its relative positions by this feature's edit. Verified structurally, by parsing the numbered list and comparing positions, not by presence, mirroring the technique `design-sync-consent`'s TEST-010 used for the same reason: a presence-only check passes against a file where the right steps exist in the wrong order.

### REQ-006 — the false-positive override is an explicit, human-gated, single-scan-scoped procedure, and its outcome is recorded

The issue's third acceptance box: "誤検知時の override 手順が明記されている" (the override procedure for a false positive is documented). This requirement fixes both the procedure and its scope, because an override that silently persists across a regenerated mockup set would quietly recreate the gap this feature exists to close — a human approves *this* scan's findings, not a standing exemption for the feature.

#### AC-020

`SKILL.md` states an explicit override affordance: after being presented with findings, a human may explicitly approve continuing despite them. Absent that explicit approval, the push does not occur — silence, a non-response, or an agent's own judgment is not an override.

#### AC-021

The override is scoped to the specific scan result it was granted against. Two TEST rows, because the scoping rule and its survival under re-scanning are two different claims:

1. the skill states that a fresh scan (after any regeneration) requires its own override decision — a prior override does not carry forward;
2. this holds even when the new scan reproduces the *same* findings as before — recurrence is not evidence the human need not be asked again, and stating this closes the reading under which "we already saw this one" would license silently skipping the presentation step.

#### AC-022

On override, the layer file's `Design-Source` section gains `Egress-Scan: overridden`. On a clean scan, it gains `Egress-Scan: clean`. Two TEST rows, one per value, because a record that only ever writes `overridden` (never distinguishing a clean run) would make every later reader unable to tell "nothing was found" from "something was found and excused."

#### AC-023

`Egress-Scan-At` records an ISO-8601 timestamp alongside `Egress-Scan`, for both the `clean` and `overridden` values — not only the exceptional one. An audit trail that timestamps only overrides cannot show when the scan last ran clean either.

#### AC-024

The `Design-Source` record shape gains exactly two new fields — `Egress-Scan`, `Egress-Scan-At` — additively, per the extensibility rule `design-sync-consent/design.md:180` already establishes ("unknown fields are ignored by a reader, and absent optional fields do not make a record non-conforming"). None of `design-sync-consent`'s five existing fields — `Egress-Consent`, `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`, `Egress-Consent-Expiry` — is renamed, removed, or redefined by this feature.

#### AC-025

On decline — findings presented, no override given — `SKILL.md` states the outcome in full: no push occurs; nothing is written to `Design-Source` as an override; and the agent is directed to remediate the mockups (remove or replace the flagged content) before the next scan attempt. The skill explicitly distinguishes this from `Egress-Consent`'s own decline/withdrawal vocabulary (`design-sync-consent`'s AC-026/AC-028): a content-hygiene decline is not a consent-scope decline, and the two must not be conflated in the record or in the prose, because they answer different questions — one is "may this destination receive this feature's mockups at all," the other is "does this specific payload contain something that should not go out."

### REQ-007 — the pre-upload check point stays the single named point every upload path passes through, and existing `design-system-contract` invariants survive unmodified

`SKILL.md` step 5 already exists as a defined, no-op point precisely so a control could attach here without restructuring the loop (`design-sync-consent/design.md`'s "Pre-Upload Check Point... deliberately distinct from consent"). This feature activates that point; it does not add a second one, move it, or fold it into the consent step.

#### AC-026

`SKILL.md` step 5 remains the single named point — not duplicated elsewhere in the Loop, not relocated relative to steps 4 (consent) and 6 (push).

#### AC-027

No upload path in the loop bypasses the now-active check point. Verified structurally, by enumerating every path in the Loop that reaches the push step and asserting each passes through step 5 first — the same no-bypass assertion technique `design-sync-consent`'s TEST-026 used against the point when it was still a no-op, re-run against the edited file now that the point does something.

#### AC-028

The existing `tests/design-system-contract.tests.{sh,ps1}` suite — its `DS-006` block, and `design-sync-consent`'s own structural assertions covering step order, the `Egress-Consent*` field names, and the no-bypass property — passes unmodified after this feature's `SKILL.md` edit. No test in that suite requires a source change; a failure there is evidence this feature broke a locked invariant, not something to accommodate by editing the lock.

### REQ-008 — the scan is independently runnable as a manual pre-fallback check on a host without `DesignSync`

The issue's 2026-07-10 addendum: on a host without the `DesignSync` tool (Codex, per `design-sync-consent/infra-spec.md`'s note that the tool is a Claude Code-only capability), the operator can still run the same scan by hand, ahead of the manual `claude-design-workflow.md` fallback, which itself performs no upload at all.

#### AC-029

A host without `DesignSync` can invoke `design-sync-scan.sh` / `.ps1` directly and standalone — no Claude Code-specific tool, deferred-tool search, or DesignSync capability is a precondition for running the script itself. This usage is documented at the point `claude-design-workflow.md` or its referring text describes the manual fallback, so an operator following that path is told the check exists and how to run it, not left to discover the script by reading source.

#### AC-030

The standalone invocation uses the identical script, the identical pattern set, and the identical exit-code contract as the `DesignSync`-driven path. The script source contains no runtime-specific branch — no conditional keyed on being invoked from Claude Code versus Codex versus a bare terminal — so the same command against the same input produces the same verdict regardless of who or what is calling it. This is what "runtime-neutral" means operationally, not only what runtimes it is written in.

### REQ-009 — both runtimes return identical verdicts on identical input

The issue's 2026-07-10 addendum, stated as its own acceptance criterion: "両ランタイム（bash / PowerShell）でスキャンが同一判定を返すこと" (both runtimes return the same verdict). This is a stronger claim than "the `.ps1` port has its own passing tests" — it requires the two scripts to agree with each other on the same input, not merely to each pass their own suite.

#### AC-031

For a shared fixture corpus spanning all three categories, a clean case, and each tool-error branch from AC-007, `design-sync-scan.sh` and `design-sync-scan.ps1` return the same exit code on every fixture in the corpus.

#### AC-032

For the same corpus, both runtimes classify every finding under the same category and report the same file and line number — not necessarily byte-identical prose, but the same location and the same kind.

#### AC-033

The case-sensitivity sweep (AGENTS.md "Author-time sweeps that replace case-by-case vigilance", item 1) is performed for every `.ps1` site implementing a pattern the `.sh` original compares case-sensitively — concretely, the reused placeholder case-sensitive pattern (AC-009) and the secret category's case-sensitive vendor-prefix group (AC-010) — with a mis-cased negative fixture per such site, before this feature is reported Implementation Complete. This is a real full-parity port, unlike `design-sync-consent`, which had none; the sweep applies at full strength here rather than the narrow applicability that feature recorded.

### REQ-010 — the feature's tests are a new suite, registered for local execution; CI registration is staged separately

#### AC-034

`tests/design-sync-scan.tests.sh` and `tests/design-sync-scan.tests.ps1` (both new) exist and together cover REQ-001 through REQ-009's criteria.

#### AC-035

Both are registered in `tests/run-all.sh` and `tests/run-all.ps1`. Neither file is a member of `PROTECTED_GATE_SUFFIXES` (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`), so registering the new suite there is agent-applicable, following the same read `design-sync-consent`'s R-OQ-8 relied on for the same two files.

#### AC-036

CI registration of the new suite in `.github/workflows/test.yml` is **not** inside this feature's blocking task decomposition. `.github/workflows/test.yml` is a member of `PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`) and of `PHASE2_HUMAN_COPY_TARGETS` (`:18`); it cannot be written by an agent. CI registration is tracked as a separately staged, human-applied patch, following the precedent `design-sync-consent` established at R-OQ-8/BL-005. An acceptance criterion asserting CI-reachability stays red against the live tree until a human applies that patch — the designed fail-closed state, not a defect (mirrors `design-sync-consent`'s AC-024/TEST-039).

## Non-goals

- **A comprehensive, entropy-based secret scanner.** This is a bounded, documented pattern-matching gate reusing `check-placeholders.sh`'s markers plus the named secret/PII set in `design.md` — not a `trufflehog`/`gitleaks`-class engine with entropy heuristics, vendor-API verification, or a continuously updated signature database. `security-spec.md` records the coverage gap this leaves as a residual risk rather than implying completeness.
- **Redacting or rewriting the mockup HTML in place.** The scan detects and reports; it never edits, strips, or replaces content in the scanned files. Remediation is a human/agent action outside this script's scope.
- **A machine-checkable, cryptographically-bound override object** (on the model of `prepare-panelist-input`'s `input_digest`, `cross-model-verification-policy.md:270-318`). The override is recorded as agent-written prose in `Design-Source`, at the same trust posture as `design-sync-consent`'s `Egress-Consent*` fields — an audit trace, not an enforcement point (`security-spec.md` carries the full treatment, mirroring `design-sync-consent/security-spec.md`'s B3 treatment).
- **Scanning non-HTML files under `specs/<feature>/mockups/`.** The issue's own text scopes the scan to "の HTML"; a JSON fixture, an image, or a README dropped into that directory is not scanned by this feature. Recorded as a known gap (Edge Case 4), not a silent omission.
- **Remediating git history.** This feature gates the *next* upload attempt. It does not scan, flag, or purge any commit already in history, including one written before this feature existed or one an operator chose to override.
- **Changing anything `design-sync-consent` (DS-29) specified.** `Egress-Consent`, `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`, `Egress-Consent-Expiry`, the consent-scope rules, and the push-failure rule are unmodified (BL-002). This feature is additive to the `Design-Source` record and to step 5's prose only.
- **Implementing DS-31 (#140, `ds_upload_consent`).** Out of scope here, as it is for DS-29.
- **CI registration of the new test suite.** Staged separately per REQ-010/AC-036; not a blocker on this feature's task decomposition.

## Edge Cases

1. **No mockups exist yet.** The scan is invoked (or invocable) before `specs/<feature>/mockups/` has any content, or before the directory exists at all. Resolved by AC-004 and AC-007 branch 2 respectively: an existing-but-empty directory is clean (exit 0); a genuinely nonexistent directory is a tool error (exit 2) distinct from "nothing to scan" — the Loop only ever invokes the scan after step 2 (Generate mockups) has run, so a nonexistent directory at that point is itself informative (something upstream did not do what the Loop assumes), not a condition the scan should paper over as clean.
2. **A regenerated mockup set after an override.** `SKILL.md`'s cycle returns to step 2 (generate) after every review (`design-sync-consent`'s step 7), so a scan granted an override on revision *n* faces revision *n+1* fresh. Resolved by AC-021: the override does not carry forward; every scan invocation is evaluated on its own, including one that reproduces identical findings.
3. **A legitimate string repeatedly resembling a false positive.** A mockup that genuinely, correctly contains something matching a PII or secret shape (a support contact's real email address in a "Contact Us" mockup; a field labelled "API Key" in a settings-page mockup with no real value present) triggers a finding on every regeneration and requires override every time under Edge Case 2's no-persistence rule. This is a stated usability cost, not an oversight: the alternative — letting a prior override apply to new content — is exactly the standing-exemption gap this feature exists to prevent (`security-spec.md`'s R1 discussion). The RFC 2606 exclusion (AC-011) and value masking (AC-014) reduce friction and disclosure risk respectively; they do not eliminate the cost.
4. **A non-HTML file under the target directory.** A JSON data fixture, an image, or stray notes placed inside `specs/<feature>/mockups/` are not scanned (Non-goals). A secret or PII string inside such a file is a gap this feature does not close.
5. **Divergent regex-engine behaviour between POSIX ERE (`grep -E`) and .NET regex (PowerShell).** Patterns in this feature are restricted to a common, boring subset — literal prefixes, character classes, `{n}`/`{n,}` interval quantifiers, and the case-sensitive/case-insensitive split already used by `check-placeholders.sh` — deliberately avoiding constructs such as inline `(?i)` flags (a .NET-regex idiom with no POSIX ERE equivalent) that would otherwise force the two runtimes to diverge structurally rather than merely require careful porting. AC-033's case-sensitivity sweep is the mechanical check that this restriction was actually honoured.
6. **A `.ps1` invocation against a path with characters POSIX and PowerShell path handling treat differently** (embedded spaces, mixed `/`/`\`, non-ASCII path segments). Not resolved here; re-verify at implementation time against the shared fixture corpus (REQ-009), following the same "re-verify before relying on it" discipline the Assumptions section states for shared repository state.
7. **A finding on a line so long that printing it in full would flood the report** (a minified or single-line mockup, plausible for generated HTML). Not resolved here as a fixed truncation width; recorded as an implementation-time decision that must preserve AC-013's "sufficient to locate" property and AC-014's masking property together — truncation must not itself become a way to accidentally show more of a masked value than the masking rule intends.

## Assumptions

- **Re-verify every `file:line` in this document at implementation start.** Citations accurate when written and stale when used are a recorded, recurring defect class in this repository (WFI-011); `design-sync-consent/requirements.md` records one instance found in its own source issue.
- **`design-sync-loop/SKILL.md`'s current text is shared state this branch does not own.** Step 5's line numbers (`:128-135` as read at authoring time) and its exact prose are `design-sync-consent`'s output, live on `main` as of this writing; re-read the file at implementation start rather than trusting the citations above, in case an intervening change has shifted them (AGENTS.md "Author-time sweeps", item 3).
- **Protected-file membership is shared, git-tracked state this branch does not own.** The claim that `.github/workflows/test.yml` is protected and that `tests/run-all.{sh,ps1}` and `design-sync-loop/SKILL.md` are not must be re-derived, not re-read from this document, at spec-review time (it gates a reviewer's conclusion about the task plan's shape) and again at implementation start, by reading `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` and `:18` and testing each target with `endswith()` on its repository-relative path (AGENTS.md "Author-time sweeps", item 3).
- **`check-placeholders.sh:18-19`'s exact pattern strings are shared state.** Re-read them at implementation time rather than transcribing this document's copy, in case the source has changed since authoring.
- **`tests/design-system-contract.tests.{sh,ps1}`'s exact block boundaries (`DS-006`, and `design-sync-consent`'s TEST-010/TEST-015/TEST-026/TEST-040-equivalent assertions) are shared state.** Re-derive the current line ranges at implementation time before claiming REQ-007's regression criterion (AC-028) is satisfied.
- **Whether `tests/run-all.sh` is itself invoked by any CI workflow may have changed since `design-sync-consent` recorded it as "no" (INV-016/INV-017 there).** Re-check `grep -rn "run-all" .github/` at implementation time; if a workflow now invokes `run-all`, REQ-010's CI-registration analysis (AC-036) may need revisiting rather than assumed unchanged.
- **`plugins/sdd-lite/skills/lite-spec/SKILL.md` does not restate the pre-upload check point and is not a target of this feature**, confirmed by direct read at authoring time (it references `design-sync-loop` by name only, at `:62`, without restating Loop internals). Re-verify this at implementation time in case an intervening edit changed that.

## Baseline Constraints

- **BL-001 — the pre-upload check point is not duplicated or relocated.** `SKILL.md` step 5 remains the single named point every upload path passes through (AC-026, AC-027).
- **BL-002 — `design-sync-consent`'s consent model is unmodified.** `Egress-Consent`, `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`, `Egress-Consent-Expiry`, the feature∧session scope rule, expiry, withdrawal, the transient-decline rule, and the push-failure rule are all untouched by this feature (AC-024, AC-025).
- **BL-003 — the existing `tests/design-system-contract.tests.{sh,ps1}` suite passes unmodified.** No source change to that suite is required by this feature (AC-028).
- **BL-004 — `.github/workflows/test.yml` is protected and is not written by this feature's tasks.** CI registration of the new suite is a separately staged, human-applied patch (AC-036). Re-verify per Assumptions before relying on this.
- **BL-005 — `specs/workflow-state-registry.json` needs an entry for this feature**, per `check-workflow-state.sh:130-134`.

## Open Questions

None of the five below blocks implementation. Each is a genuine product/security judgment call this document declines to make by fiat, distinct from the engineering-level decisions (exact pattern sets, exit-code semantics, masking behaviour, override scope) that `design.md` settles directly, per `sdd-bootstrap-interviewer/SKILL.md:53` ("Record unknown product decisions under Open Questions; do not invent them").

| OQ | Question | Owner | Blocks | Notes |
|---|---|---|---|---|
| OQ-1 | Should the secret pattern set be extended beyond the vendor formats enumerated in `design.md` (e.g. Stripe, Twilio, JWT bearer tokens, SSH keypair formats beyond the generic PEM header) in a later revision? | security | no | The enumerated set is a stated v1 baseline, not exhaustive by design (`design.md`, Design Decisions). |
| OQ-2 | Should the override in REQ-006 support per-finding granularity (approve some findings, keep others blocking) rather than the all-or-nothing scope this document specifies? | product | no | All-or-nothing is chosen here as the simpler, more conservative default matching the issue's binary framing ("block... present... override"); finer granularity is a possible future refinement, not required now. |
| OQ-3 | Should the `Design-Source` scan record carry a content-derived identifier (a hash of the finding set, in the spirit of the panelist path's `input_digest`) so an audit can distinguish "the same findings, overridden again" from "different findings, overridden"? | security | no | Deliberately out of scope here (Non-goals: no machine-checkable consent/audit object); flagged as a possible follow-up rather than decided. |
| OQ-4 | Does `docs/THREAT-MODEL.md` gain an entry for this control, given it is the compensating mechanism for `design-sync-consent`'s Residual Risk R1? | maintainers | no | Mirrors `design-sync-consent`'s own unresolved OQ-10; `security-spec.md` records this feature's presence as narrowing, not closing, R1. |
| OQ-5 | Should this feature's staged CI-registration patch (AC-036) be batched into the same human action as `design-sync-consent`'s still-pending equivalent patch for `tests/design-system-contract.tests.{sh,ps1}`? | maintainers | no | Informational sequencing question; both are separately staged and neither blocks its own feature's decomposition. |
