# T-002 — Acceptance-first Done-When ↔ TEST mapping

Per `Required Workflow: acceptance-first` (`tasks.md` T-002). The OQ-002 /
INV-013 insertion-point recheck (`01-inv-013-range-recheck.md`) was performed
against the live file, by direct read, before any candidate content was
staged. The candidate was then derived from that confirmed insertion point.

**Note on this task's shape.** Unlike T-001, T-002 never opens the live
`plugins/sdd-ship/skills/ship/SKILL.md` for write — `plugins/sdd-ship/skills/
ship/SKILL.md` is on both `PROTECTED_GATE_SUFFIXES` and
`PHASE2_HUMAN_COPY_TARGETS` (confirmed fresh in `01-inv-013-range-recheck.md`).
Every Done-When bullet below is therefore verified against the **staged
candidate** at `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/
skills/ship/SKILL.md` and the **manifest**, never against a live edit.

## Done-When ↔ TEST mapping and verification method

| Done-When bullet | TEST/AC | Verification method used |
|---|---|---|
| 1. Candidate exists at the human-copy path, derived from live `ship/SKILL.md` + probe step at the OQ-002 point; 3 required elements present; candidate not produced by a live-path write (AC-002, TEST-002) | AC-002, TEST-002 | Integration (real file read): grep the staged candidate for `get_next_sdd_command`, `read-only`, and the advisory/non-deciding statement, each independently; confirm placement between `## Preconditions` and `## Step 1` by line-number read; confirm via `git status`/`git diff` on the live path that no agent write occurred there. |
| 2. Attempt-and-degrade phrasing; 4 absence assertions re-run against the candidate; unconditional across track/invocation form; divergence wording (TEST-027a/b, ship leg) | D-001, AC-004…007 (ship leg), OQ-004, AC-027a/AC-027b (ship leg) | Text inspection + unit (literal-absence): grep the candidate for `claude mcp`, `.codex/config.toml`, the marker-block prefix `>>> `, and `mcp.json` (all absent); grep for `registered`/`check whether` (absent, confirming no detect-then-branch); read the unconditional sentence naming both invocation forms and both tracks; read the divergence paragraph for both required elements. |
| 3. `ship` completes normal file-based flow, no error surfaced (TEST-010, TEST-011) | AC-010, AC-011 | Structural + partial live: (a) confirm the wording textually instructs continuing to the unmodified `## Step 1` flow without surfacing an error, for both "unavailable" and "call fails"; (b) record genuine first-hand environmental evidence — this session has no `get_next_sdd_command` MCP tool registered, a real, unfabricated TEST-010 instance; (c) disclose that a full live `/sdd-ship:ship` run under the TEST-011 (registered-but-failing) condition was not performed within this staging task's scope. |
| 4. Differential outcome equality (TEST-013) | AC-013 | Structural: diff the candidate against the live file and confirm `## Step 1` onward (target selection through the end of the file) is byte-for-byte unchanged and contains no new conditional reading the probe's result. A full live two-run empirical differential was not additionally performed — disclosed as an open item alongside item 3(c). |
| 5. MANIFEST.sha256 entry matches staged candidate exactly (AC-025, TEST-025) | AC-025, TEST-025 | Integration (hash conformance): compute SHA-256 of the staged candidate; confirm a `<sha256>  plugins/sdd-ship/skills/ship/SKILL.md` line (two-space separated) exists in `MANIFEST.sha256` and matches, via `shasum -a 256 -c`. |
| 6a. Live path never opened for write; diff/provenance confirms no agent-authored edit (AC-002 2nd half, AC-026, TEST-003, TEST-026) | AC-002 (2nd half), AC-026, TEST-003, TEST-026 | Integration (guard/provenance + hash conformance): `git status --porcelain` / `git diff --stat` against the live path, both empty, confirming zero agent write; no `Write`/`Edit` tool call targeted the live path at any point in this task. |
| 6b. Live-file half of conformance is expected red pre-human-copy | — | Disclosure, not a test: recorded explicitly in `02-verification-record.md` and in the implementation report; not treated as a failure of this task. |
| 7. AC-017…020 dual-runtime grid, ship leg | TEST-017…020 | No determined method (OQ-009). Recorded as an explicit manual verification per runtime, disclosing the undetermined method rather than fabricating a text-based substitute. See `03-dual-runtime-manual-verification.md`. |
| 8. No file under `mcp/` touched (BL-001) | BL-001 | Verified by `git status --porcelain -- mcp/`, empty. |

## Disclosure

Items 3(c) and 4's "full live runtime exercise" halves are **not** performed
by this task, for the same reason T-001 disclosed the equivalent gap: a
genuine end-to-end `/sdd-ship:ship` run through a live Claude Code or Codex
session, under each named condition, is out of scope for a task whose only
writable targets are the staged candidate, the manifest, and this
verification directory. Fabricating a text-only substitute for that would be
the same FP-02 / text-marker failure AC-001/AC-002's own wording guards
against. What is verified here, honestly and without fabrication: (1) the
candidate's wording is structurally correct and complete for every element a
human or an agent reading it would need; (2) the live file's `## Step 1`
onward content is provably unchanged in the candidate, which makes AC-013's
outcome-equality guarantee a structural fact; and (3) the live protected path
carries zero agent-authored edit, verified by diff, not merely asserted.
