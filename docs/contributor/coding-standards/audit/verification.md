# Intake verification (2026-11-01)

This records checks of the #686 deliverables, not a whole-repository compliance
verdict. Source baseline: `82b536954626e73b36853711b264cbf5df400d22`.

- Compared the 11,501 population paths against `git ls-files -z`: exact set,
  no duplicates. For every recorded `git_blob`, read `git cat-file blob` and
  recomputed SHA-256: all matched `source_sha256`. This checks enumeration and
  byte pins, not semantic review of those files. The symlink is represented by
  target text and was not followed.
- Validated `findings.json` against `schema.json` with the installed `jsonschema`.
  Intake has no recorded findings yet; this is not zero observed violations.
- Checked that the rule index has exactly CS-001 through CS-030, all rule source
  references resolve to Source records, and local Markdown links exist.
- Ran `python plugins/sdd-quality-loop/scripts/validate-research-evidence.py
  --file docs/contributor/coding-standards/research/records/research-evidence.json`:
  `VALID coding-standards scope=file history=unchecked sources=16 claims=5`.
- Also validated `--previous` against the exact metadata in commit `212028cd`:
  `history=checked`; the six supplemental sources append without rewriting the
  initial Source/Claim revisions.
- The existing planner/merger ran over the initial ten-source set. Its strict
  graph command passed while records were staged in the proposed feature path.
  Final contributor placement intentionally has no repository-mode research-gate
  admission; graph/binder require repository inputs and no current graph/binder
  PASS is claimed. The research map explains this distinction.
- `git diff --check` passed. No protected mirror, frozen evidence or approval
  artifact was modified by the intake work.

Native language-tool execution, semantic reviews, actual code fixes and their
regressions belong to the linked language/check/reuse work. The final #692
reconciliation must refresh the population for added/changed tracked files and
retain unresolved states. Tool timings, token consumption, recurrence reduction,
and a before/after whole-repository defect count were not measured by this
intake check and remain unknown.
