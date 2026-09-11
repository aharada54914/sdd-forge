# RT002 design round-2 preparation

Date: 2026-09-09. Status: partial amendment applied; formal review pending.

## Applied changes

The authorized design-remediation scope was used to add a Design System
Compliance section to the A1 design. A real read-only lstat probe at
2026-09-09T13:12:04.001Z returned ENOENT for the repository-root design-system
entry. The section cites the absent-directory branch at
`plugins/sdd-review-loop/agents/impl-reviewer-a.md:243-247`, requires a fresh
probe immediately before review, and stops on changed state or other errors.
It does not invent a configured ds_profile or broaden reviewer filesystem
access. This is evidence supplied for the next review, not an override of the
existing DESIGN-SYSTEM-CONFORMANCE FAIL.

Four abbreviated ADR filenames in the ADR Change Log were expanded to their
canonical docs/adr paths. The seven named ADR files (0011, 0016, 0018, 0019,
0020, 0023, 0025) were each observed as regular non-symlink files and hashed.
In particular ADR-0025 exists, SHA-256
`d930ddc333d05f8c8a35ada83ba51f44ffe84f905c6a76bbac142d41303cd208`.
This does not authorize those files in the old reviewer manifests. RT004's
complete admission/consumer contract repair remains necessary. Full-path
declarations avoid requiring a candidate extractor to infer a directory from
neighboring prose references.

Final design SHA-256:
`2c0d72ebdbdd68869c1d67c045787752f39f35f177c1817b6d5cd9fe5f996ba5`.

## Review and checks

Local author review found no new critical issue in this documentation-only
delta; independent formal review is still pending. Read-only Node assertions
confirmed a single compliance section, explicit fail-on-changed-state wording,
the current absent entry, and unchanged requirements/acceptance hashes against
the preceding review manifest. These assertions passed before the subsequent
path-only ADR expansion. Final scoped git diff --check exited 0.
The identifier sweep across requirements, design, acceptance, all four layer
specifications and tasks found the applicability declaration only in design;
old verification contracts remain historical and unchanged. No product-code
suite was claimed for this documentation-only change.

## Still required

- Reconcile schema protection: design component table line 220 currently says
  the approver-registry schema is not protected, while its schema subsection
  says it is. The canonical manifest enumerates 24 concrete and 4 reserved
  targets without that schema. Resolve all declarations and derived contracts
  consistently without silently weakening the promised protection.
- Finish RT004's saved Bash/PowerShell contract candidates, negative fixtures,
  independent review, human protected application and original-path tests.
- Run a fresh precheck and both independent design reviewers only once the
  complete corrected input set is admissible; preserve attempt-5 round-1.
- Task provenance, RT002 implementation and fresh native activation proof,
  required CI and main integration remain incomplete.

Fresh GitHub polling found 11 open PRs and no queued/in-progress check runs.
Failures remain on 245–405's integration queue as recorded by each PR; no
failed-check list is interpreted as complete mandatory-CI success. In
particular PRs 245, 403 and 405 show conflicts and only a CodeRabbit success,
not full CI evidence. No external mutation was performed.

This turn made implementation-policy amendment progress, not a verified wait.
No ticket or issue was closed, no task was set Done, and no commit/push/merge
was performed. The full issue-resolution goal remains active.

## Inventory finding remediation (later on 2026-09-09)

Further source inspection established an explicit existing decision, not merely
an omission: tasks.md:2093-2098 states that T-004's schema is not a protected
registration target. Its planned-file entry at tasks.md:990 likewise describes
the schema as agent-editable. This agrees with the design Components table at
line 220, requirements.md:905-924, and the canonical manifest's 28 entries.
The generator's EPIC_A1_TARGETS tuple at lines 148-177 also contains registry
data, not that schema. These are source observations, not a runtime verdict.

Accordingly, the authorized design correction replaced the contradictory
"both" sentence with the existing explicit classification and its evidence,
plus a mandatory fresh shared-registration check. This supersedes the earlier
proposal to expand the inventory: such an expansion is not necessary to align
the normative requirements and explicit approved task contract. No registry,
generator, generated output, acceptance criterion or mandatory check was
removed or weakened. The independent SECURITY-COVERAGE finding remains open
until genuine re-review; this local correction cannot waive it. The previous
design hash above is historical and no longer describes the amended file.

The complete identifier sweep covered requirements, design, acceptance, tasks
and all four layer specifications. The source excerpts show the existing
non-registration classification consistently after this correction.
Scoped git diff --check exited 0.

Two subsequent operations were rejected by the live PreToolUse guard:

1. Original generator command:
   `rtk proxy python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`.
2. A separate read-only Node assertion over manifest rows, design wording and
   prior spec input hashes. That assertion did not run and is not PASS.

Both returned the bilingual deterministic-gate prohibition. Neither was
retried through another interpreter, copied executable, renamed target or
plugin-cache modification. The generator's current --check result remains
unknown. The second operation was static data inspection, not a substitute
execution of the generator; its rejection is retained as a distinct outcome.

Human verification, in the current repository (no application or publication):

```bash
cd /Users/jrmag/sdd-forge || exit 1
rtk proxy python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check
printf 'generator exit: %s\n' "$?"
rtk proxy git diff --check -- specs/epic-189-a1-project-context/design.md
printf 'whitespace exit: %s\n' "$?"
rtk proxy shasum -a 256 specs/epic-189-a1-project-context/design.md
```

Send the output to Codex. Do not commit, push, merge, or change review verdicts.
ADR input-contract repair and independent review remain pending separately.

## Human verification received (2026-09-09)

The user supplied the requested terminal results after the inventory-wording
correction:

```text
generator exit: 0
whitespace exit: 0
9aea7f51d7d70fcd4c9f1e3ea339c8cdd20f5826010ff2539e31f2d1ba9faf91  specs/epic-189-a1-project-context/design.md
```

Attribution: human-executed verification, reported in this conversation; not
an agent rerun. This resolves the previously unknown generator check result
for that reported verification and records the amended design hash. It does
not erase either agent-side guard rejection or establish a live activation
handshake. The earlier `2c0d72...` hash remains historical.

Formal design re-review, admissible hash-bound ADR inputs through RT004,
downstream verification, required CI and main integration remain pending.
No review verdict, task status or ticket resolution is changed by receipt
of these successful scoped checks.
