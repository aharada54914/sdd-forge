---
name: sdd-bootstrap-interviewer
description: Interview-driven Spec-Anchored AI Development bootstrap skill. Use at the start of a new project or feature to generate AGENTS.md, CLAUDE.md, requirements, design, ADRs, contracts, tasks, acceptance tests, traceability, and CI templates before implementation.
---

# SDD Bootstrap Interviewer

Use this skill to prepare a new software project for Spec-Anchored AI Development.

This skill creates specifications and project operating documents. It does not implement application code.

## Invocation

Codex:

```txt
Use the sdd-bootstrap-interviewer skill.
Project name: <project-name>
Feature slug: <feature-slug>
Mode: interactive
```

Claude Code:

```txt
/sdd-bootstrap:sdd-bootstrap-interviewer <project-name> <feature-slug>
```

Example:

```txt
/sdd-bootstrap:sdd-bootstrap-interviewer equipment-reservation reservation
```

## Operating Rules

- Treat `AGENTS.md` as the canonical shared instruction file for all coding agents.
- Treat `CLAUDE.md` as a thin Claude Code bridge, not a copy of `AGENTS.md`.
- Keep long procedures in skills, templates, references, specs, and ADRs.
- Ask concise interview questions before generating project-specific content.
- Prefer structured Markdown, YAML, and JSON artifacts over chat-only decisions.
- Do not implement application code.
- Do not add MCP, Figma, Jira, Linear, multi-agent orchestration, or UI generation flows.
- If a decision is unknown, record it in `Open Questions` instead of inventing it.

## Required References

Read these bundled references as needed:

- `references/interview-question-bank.md`
- `references/phase-quality-gates.md`
- `references/task-splitting-rules.md`
- `references/api-contract-rules.md`
- `references/architecture-rules.md`

Use these bundled templates when creating artifacts:

- `templates/AGENTS.template.md`
- `templates/CLAUDE.template.md`
- `templates/requirements.template.md`
- `templates/design.template.md`
- `templates/tasks.template.md`
- `templates/acceptance-tests.template.md`
- `templates/traceability.template.md`
- `templates/adr.template.md`
- `templates/openapi.template.yaml`
- `templates/json-schema.template.json`
- `templates/ci-github.template.yml`
- `templates/ai-task.template.md`
- `templates/review-ticket.template.md`
- `templates/pull-request.template.md`

## Phase 0: Project Constitution

Goal: create the AI development workbench.

Ask:

- Project name
- Product overview
- Target users
- Whether the project is closest to Web, API, CLI, Mobile, or Batch
- Whether repository management is GitHub, GitLab, or local
- AI agents the team wants to use
- Preferred technology stack
- MVP must-have features
- MVP non-goals
- Important constraints

Generate:

- `AGENTS.md`
- `CLAUDE.md`
- Initial directory structure
- A README development workflow section when missing

Quality gate:

- Project name is defined
- Target repository style is defined
- AI agent usage rule is defined
- MVP scope and non-goals are listed

## Phase 1: Requirements

Generate:

- `specs/<feature>/requirements.md`

Required sections:

- Overview
- Target Users
- Problems
- Goals
- Non-goals
- User Stories
- Acceptance Criteria
- Roles and Permissions
- Main Workflows
- Edge Cases
- Assumptions
- Open Questions
- Risks

Quality gate:

- At least 3 user stories exist
- Acceptance criteria are testable
- Roles are defined
- Open questions are separated from assumptions

## Phase 2: Design

Generate:

- `specs/<feature>/design.md`

Required sections:

- Technical Summary
- Architecture
- Frontend Plan
- Backend Plan
- Data Plan
- API / Contract Plan
- Test Strategy
- Security Considerations
- Deployment / CI Plan
- Assumptions
- Open Questions
- Risks

Quality gate:

- Frontend/backend/database necessity is clear
- Test strategy is defined
- Security and deployment assumptions are listed

## Phase 3: Architecture and ADR

Generate:

- `docs/architecture/c4-context.md`
- `docs/architecture/c4-container.md`
- `docs/architecture/c4-component.md`
- `docs/adr/0001-use-selected-architecture.md`
- `docs/adr/0002-use-selected-database.md`
- `docs/adr/0003-use-openapi-first.md`

ADR format:

- Status
- Context
- Decision
- Consequences

Quality gate:

- System context is described
- Container/component responsibilities are described
- Major technical decisions have ADRs

## Phase 4: Contract

If the project has an HTTP API, generate:

- `contracts/openapi/<feature>.yaml`
- `contracts/schemas/<feature>.schema.json`

If the project has no HTTP API, generate:

- `contracts/schemas/<feature>.schema.json`
- `docs/contracts/data-contract.md`

Rules:

- OpenAPI must use at least `openapi: 3.1.0`.
- JSON Schema must use draft 2020-12.
- Unknown operations should remain placeholders, not invented endpoints.

Quality gate:

- API or data contract exists
- Error response shape is described when applicable
- JSON Schema or equivalent data shape exists

## Phase 5: Tasks

Generate:

- `specs/<feature>/tasks.md`
- `specs/<feature>/acceptance-tests.md`

Task rules:

- One task must fit in one PR/MR.
- Each task must include `Goal`.
- Each task must include `Must Read`.
- Each task must include `Scope`.
- Each task must include `Done When`.
- Tests must be part of each task's Done conditions.
- The first task should be environment setup or domain model.
- Do not implement automatically.

Quality gate:

- Tasks are small enough for PR/MR
- Each task has Done When
- Each task has tests
- Each task has Must Read references

## Phase 6: Implementation Ready

Generate:

- `specs/<feature>/traceability.md`
- `.github/workflows/ci.yml`
- `.github/ISSUE_TEMPLATE/ai-task.md`
- `.github/ISSUE_TEMPLATE/review-ticket.md`
- `.github/pull_request_template.md`

`traceability.md` must use this table:

```md
| Requirement | Design | API/Schema | Code Target | Test Target | Status |
|---|---|---|---|---|---|
```

Quality gate:

- `traceability.md` connects requirements, design, code targets, and tests
- CI template exists
- Issue and PR templates exist

## Completion Report

Report:

- Generated files
- Open questions
- Risks
- Next action for the human
- Explicit reminder that implementation has not started
