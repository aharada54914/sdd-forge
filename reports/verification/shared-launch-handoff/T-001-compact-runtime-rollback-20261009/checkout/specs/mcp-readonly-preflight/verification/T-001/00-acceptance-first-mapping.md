# T-001 — Acceptance-first Done-When ↔ TEST mapping

Authored before editing `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`,
per `Required Workflow: acceptance-first` (`tasks.md` T-001).

## INV-013 fresh re-verification (done now, before edit)

Re-read at implementation start, not trusted from `tasks.md`'s own line
numbers:

- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`: `## Preconditions` is at
  line 54, `## Routing` is at line 66 (confirmed via
  `grep -n '^## Preconditions$\|^## Routing$'`).
- `tests/workflow-documentation.tests.sh:66` extracts the range
  `sed -n '/^### `feature` .*full track)/,/^### Lite track/p'`. Those two
  bounding headings are at `bootstrap/SKILL.md:88` and `:124` — both well
  inside `## Routing`'s body (`:66` onward).
- The insertion point (immediately after line 65's trailing blank line,
  immediately before line 66's `## Routing`) is therefore confirmed, fresh,
  today, to fall entirely outside the extracted range. `tasks.md`'s own
  citation of this fact (`:60-70`) is accurate as of this re-check; no
  re-derivation is needed.

Full command transcript: `01-inv-013-range-recheck.md` in this directory.

## Done-When ↔ TEST mapping and verification method

| Done-When bullet | TEST/AC | Verification method used |
|---|---|---|
| 1. Insertion point + 3 required elements (tool identifier, "read-only", advisory/non-deciding) | AC-001, TEST-001 | Integration (real file read): grep the final file for the exact identifier `get_next_sdd_command`, the literal word `read-only`, and the advisory/non-deciding statement, each independently; confirm placement between `## Preconditions` and `## Routing` by line-number read. |
| 2. Attempt-and-degrade phrasing, not detect-then-branch; unconditional across mode/track | D-001, OQ-004 | Text inspection: confirm the added prose contains the "attempt `<tool>`; if unavailable or fails, continue with the file-based flow" shape and contains no "check whether ... registered" detect-then-branch instruction; confirm no mode-name or track-name gating conditional wraps the paragraph. |
| 3. Four absence assertions (TEST-004…007, bootstrap leg) | AC-004…007 | Unit (literal-absence): grep the final file for `claude mcp`, `~/.codex/config.toml`, the installer marker-block comment prefix, and `mcp.json`; each must be absent. Valid only jointly with item 1's presence check (acceptance-tests.md Notes). |
| 4. Fallback completes normal flow, no error surfaced (TEST-008/009) | AC-008, AC-009 | Structural + partial live: (a) confirm the wording textually instructs continuing to the unmodified `## Routing` flow without surfacing an error, for both the "unavailable" and "call fails" conditions; (b) record genuine first-hand environmental evidence where available — this coding session itself has no `get_next_sdd_command` MCP tool registered, which is a real, unfabricated instance of the TEST-008 condition; (c) disclose that a full live `/sdd-bootstrap:bootstrap` run under the TEST-009 (registered-but-failing) condition was not performed within this single-file documentation task's scope — recorded as an open item, not fabricated as a pass, matching the repository's OQ-009 disclosure convention. |
| 5. Differential outcome equality (TEST-012) | AC-012 | Structural: diff the final file against the pre-edit version and confirm `## Routing`'s existing body (`:66` onward, pre-edit) is byte-for-byte unchanged and contains no new conditional that reads the probe's result. Because `## Routing` cannot see the probe's output at all, the routing conclusion is identical with or without the probe, by construction — not by trusting the prose. A full two-run live differential exercise was not performed within this task's scope; disclosed as an open item alongside item 4(c). |
| 6. Divergence reporting (TEST-027a) and file-based authority (TEST-027b) | AC-027a, AC-027b | Text inspection: confirm the wording requires stating both (a) that a disagreement occurred and (b) which source was acted on, and confirm the wording states the file-based (`## Routing`) conclusion is always the one acted on. Full live divergence-scenario exercise not performed within this task's scope; disclosed as an open item alongside item 4(c)/5. |
| 7. AC-017…020 dual-runtime grid | TEST-017…020 | No determined method (OQ-009). Per orchestrator instruction, record only what the Done-When requires: an explicitly recorded manual verification per runtime, disclosing the undetermined method rather than fabricating a text-based substitute. See `03-dual-runtime-manual-verification.md`. |
| 8a. `tests/workflow-documentation.tests.sh` passes unmodified | AC-027, TEST-027 | Regression: run the suite unmodified, record pass/fail output verbatim. |
| 8b. No file under `mcp/` touched | BL-001 | Verified by `git diff --stat` / `git status` showing only `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` and this `verification/` directory changed. |

## Disclosure

Items 4(c), 5, and 6's "full live runtime exercise" halves are **not**
performed by this task. `acceptance-tests.md`'s Test Type row for T-001
labels AC-008/009/012/027a/027b as "integration (bootstrap run, real
repository state)" / "integration (differential)" / "integration
(probe/file divergence)" — a genuine end-to-end run of `/sdd-bootstrap:
bootstrap` through a live Claude Code or Codex session, exercised under
each of the named conditions. That is out of scope for a task whose only
writable target is one Markdown file plus this verification record, and
attempting to fabricate it via a text-only substitute would be exactly the
FP-02 / text-marker failure this feature's own AC-001 wording guards
against. What **is** verified here, honestly and without fabrication, is:
(1) the wording is structurally correct and complete for every element a
human or an agent reading it would need, and (2) `## Routing`'s existing
control flow is provably unchanged, which makes AC-012's outcome-equality
guarantee a structural fact rather than an assertion resting on the prose
alone. The remaining, genuinely-runtime-only halves are named here rather
than hidden, for the quality gate to weigh.
