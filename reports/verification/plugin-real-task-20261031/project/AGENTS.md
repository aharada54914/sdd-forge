# AGENTS.md

This project follows Spec-Anchored AI Development, using spec_profile: lite.

## Required Workflow

1. Use `sdd-lite:lite-spec` to create requirements, design, and Draft tasks.
2. A human reviews specifications and changes selected tasks to Approved.
3. Use `implement-task` for one Approved task.
4. Use `sdd-lite:lite-gate` for verification and the Done decision.
5. Use `fix-by-review-ticket` for approved review-ticket fixes, then rerun the gate.

## Sources Of Truth

- REQUEST.md: supplied product requirements.
- specs/junit-summary/tasks.md: approval, execution order, and status.
- specs/junit-summary/requirements.md and design.md: proposed behavior and approach.
- docs/review-tickets/*.yml: unresolved quality findings.

## Active Spec Directories

- specs/junit-summary/

## Source Artifact Locations

- specs/junit-summary/requirements.md
- specs/junit-summary/design.md
- specs/junit-summary/tasks.md
- reports/implementation/junit-summary/: implementation reports and raw Red/Green outputs.
- reports/quality-gate/: quality reports naming the task.
- docs/adr/NNNN-*.md: repository-wide ADR location if needed.
- docs/review-tickets/*.yml

Lite does not require traceability, separate acceptance tests, contracts, or architecture documents.

## Rules

- Do not implement Draft tasks or approve tasks as an agent.
- Do not guess ambiguous requirements or design decisions.
- Preserve unrelated user changes and all XML input bytes.
- Implement one task at a time; only the applicable quality gate may set Done.
- Do not commit, push, create PRs/MRs, deploy, delegate, or use other models.
- This stage authorizes structure and Draft specifications only.

## Observed Project Context

REQUEST.md and README.md describe a local Python standard-library CLI. At intake,
only those documents and scripts/check-sdd-structure.sh exist as project files.
No application, tests, dependency manifest, or remote CI exists. Planned entry:
`python3 junit_summary.py REPORT.xml [REPORT.xml ...]`. Planned verification:
`python3 -m unittest discover -s tests -v`. Independent final review occurs in
another context. No Project Context approval or task approval is asserted here.

## Open Questions

No unresolved product decisions identified. Proposed serialization and diagnostic
conventions in design.md are subject to human review, not existing behavior.
