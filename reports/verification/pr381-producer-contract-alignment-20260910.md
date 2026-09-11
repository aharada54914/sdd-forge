# PR381 producer / contract alignment

Status: diagnostic evidence only; implementation, formal review and CI incomplete.
Pinned commit: `3971c93a5705dc15f86ba56cc62118613e4b19db`.

## New observations

The unchanged pinned `contracts/cross-critique.v1.schema.json` was loaded
through `git show` and compiled with the existing ci-mcp Ajv installation.
Settings matched the committed test driver: allErrors and strict enabled,
strictRequired, strictTypes and validateFormats disabled. No schema, test,
protected executable or persisted verdict was modified.

The complete annex fixture used `cross-critique.v1`, round `probe`, timestamp
`2026-09-10T00:00:00Z`, and a severity-change verdict with code evidence,
one nonempty citation and scope evidence `REQ-1`. Individual mutations gave:

| Input mutation | Actual validation |
| --- | --- |
| proposed_severity CRITICAL | rejected: enum |
| proposed_severity HIGH | rejected: enum |
| proposed_severity MEDIUM | rejected: enum |
| proposed_severity LOW | rejected: enum |
| proposed_severity Critical | accepted |
| proposed_severity Major | accepted |
| proposed_severity Minor | accepted |
| in_scope, AC-1 only, evidence AC-1 | accepted |
| in_scope, T-1 only, evidence T-1 | accepted |

These nine observations are not a product PASS or proof of live reviewer output.

At this same commit, `skills/adversarial-review/references/reviewer-prompts.md`
lines 66 and 127 require Phase 1 severity CRITICAL/HIGH/MEDIUM/LOW, while line
161 asks Phase 2 for a severity change without naming the annex vocabulary.
The schema explicitly uses Critical/Major/Minor. The producer must explicitly
distinguish those vocabularies; do not invent an unapproved four-to-three
severity mapping or silently rewrite historical findings.

The same prompt, line 174, requires a REQ reference for in_scope, whereas
the schema scope conditional accepts any one of REQ, AC or Task. Issue #348's
current body, read from GitHub on 2026-09-10, explicitly permits any of these
three. Correct the producer and the schema's stale related_requirements
description to that rule, preserving rejection of an in_scope object with
no references. AC-only and Task-only are necessary positive controls.

The committed `tests/adversarial-review-contracts.tests.mjs` baseVerdict
positive fixture supplies no scope evidence. When the previously recorded
missing-evidence validation gap is repaired, that fixture must gain real
fixture evidence; do not exempt it or weaken the intended evidence rule.
Scope reference existence/resolution remains distinct from JSON syntax.

## Governing task and authorization

`git log --all --format='%h %s' -- specs/review-cross-critique/tasks.md`
returned no entries in the locally available refs. This does not prove that
no external or differently named task exists. A governing approved task must
be located, or the missing task decomposition formally created and reviewed,
before product edits. Do not label a nonexistent task Approved or Done.

The older handoff's statement that RT-20260909-001 awaits human scope approval
is superseded: the current ticket records the explicit 2026-09-09 approval
to preserve all required dependencies and checks and additionally require
POSIX success, including specification amendment, implementation, regression
and formal re-review. That authorization does not itself establish completed
reviews, successful CI or permission to bypass protected-file denial.

## Next implementation boundary

Keep the previously reproduced missing proposed_severity and missing/blank
scope-evidence cases RED until repaired. Bind the producer, schema and test
changes together; preserve advisory-only disposition, concern separation,
out_of_scope refusal, unclear human-decision routing and quality-gate
requirements. No commit, push, merge, issue closure or review-state change
was performed by this diagnostic work.
