---
name: sdd-adopt
description: Adopt SDD in an existing repository. Creates only what is missing — structure directories, AGENTS.md, CLAUDE.md, host-appropriate CI/issue/PR templates — without writing specifications or application code.
disable-model-invocation: true
user-invocable: false
---

# SDD Adopt

Bring a pre-existing project up to the structure the SDD workflow requires.
Create structure and constitution documents; do not write specifications or
application code.

## Invocation

Codex:

```txt
Use the sdd-adopt skill.
```

Claude Code:

```txt
/sdd-bootstrap:sdd-adopt [project-root]
```

`project-root` defaults to the repository root when omitted.

## Process

1. Run `scripts/check-sdd-structure.sh [project-root]` (or `.ps1` on Windows)
   and treat its output as the source of truth.
   - Lines prefixed `missing:` are required items that must be created.
   - Lines prefixed `advisory:` are recommended items; confirm with the user
     before creating.
   - Lines prefixed `drift:` identify spec-local ADR directories to relocate.
   - Lines prefixed `host:` declare the detected VCS host (GitHub / GitLab /
     local).
   - If the script exits 0 with no `missing:`, `advisory:`, or `drift:` lines,
     report "already compliant" and stop.

2. Create missing directories mechanically. Place a `.gitkeep` in each empty
   directory so it is tracked by Git.
   - Required: `reports/implementation/`, `reports/quality-gate/`,
     `docs/adr/`, `docs/review-tickets/`
   - Advisory (confirm with user): `contracts/schemas/`, `docs/architecture/`

3. Create `AGENTS.md` when absent. Populate it from the
   `sdd-bootstrap-interviewer` skill's bundled `templates/AGENTS.template.md`,
   substituting facts read from the repository (README, build files, test
   layout). Record every unknown product decision as an Open Question; never
   invent answers.

4. Create `CLAUDE.md` from the bundled `templates/CLAUDE.template.md` when
   absent.

5. Use the `host:` output from `check-sdd-structure` to select templates.
   - GitHub → create GitHub Actions workflow (`ci-github.template.yml` →
     `.github/workflows/`), Issue templates (`.github/ISSUE_TEMPLATE/`), and a
     PR template (`.github/pull_request_template.md`).
   - GitLab → create GitLab CI (`ci-gitlab.template.yml` → `.gitlab-ci.yml`),
     Issue templates (`.gitlab/issue_templates/`), and MR templates
     (`.gitlab/merge_request_templates/`).
   - Never create `.github/` templates on a GitLab host or `.gitlab/` templates
     on a GitHub host.
   - `local` or unknown host → skip CI/issue/PR templates; report the gap.

6. Relocate ADR drift. For each `drift:` line identifying a `specs/*/adr/`
   directory:
   - Move each ADR file to `docs/adr/NNNN-<slug>.md` using a 4-digit
     repository-wide sequence (continue from the highest existing number in
     `docs/adr/`).
   - Update every reference to the old path across all Git-tracked files (grep
     and replace).
   - List each move in the Handoff.

7. Never overwrite an existing file. When an existing file conflicts with the
   SDD constitution, report the conflict and leave the file unchanged.

## Boundaries

- Do not generate feature specifications; that is `sdd-bootstrap-interviewer`'s
  job.
- Do not modify application source code or tests.
- Do not commit, push, or create a PR/MR unless explicitly requested.

## Handoff

Report:

- Files created and directories created (with `.gitkeep`).
- ADRs moved (old path → new path).
- Host detected and templates applied.
- Conflicts (existing files that were not overwritten).
- Open Questions recorded in `AGENTS.md`.
- Next step: run `sdd-bootstrap-interviewer` in `feature` (or other) mode to
  generate specifications.
