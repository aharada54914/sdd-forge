# CLAUDE.md

This project follows Spec-Anchored AI Development.

## Shared Instructions

The canonical shared instructions for all AI coding agents are in:

- AGENTS.md

Claude Code must treat AGENTS.md as the source of truth for:

- project workflow
- coding rules
- testing rules
- quality loop
- review ticket workflow
- traceability requirements

## Claude Code Usage

Use Claude Code for:

- interactive planning
- local implementation assistance
- test generation
- quality gate execution
- review ticket fixes
- traceability updates

Do not rely on free-form chat when a standard Skill exists.

Prefer the following skills when available:

- /sdd-bootstrap:sdd-bootstrap-interviewer
- /sdd-quality-loop:quality-gate
- /sdd-quality-loop:fix-by-review-ticket
- /sdd-quality-loop:update-traceability

## Context Rules

Before implementation, Claude Code must read:

- AGENTS.md
- specs/<feature>/requirements.md
- specs/<feature>/design.md
- specs/<feature>/tasks.md
- specs/<feature>/traceability.md
- related ADRs
- related OpenAPI / JSON Schema files

## Do Not

- Do not implement code before requirements and design exist.
- Do not make large unrelated changes.
- Do not change requirements silently.
- Do not perform broad refactoring unless explicitly requested.
- Do not treat chat-only review feedback as durable; convert it to review tickets.

## Memory Hygiene

Keep this file short.

Long procedures must live in:

- plugin skills
- references/
- templates/
- AGENTS.md
- specs/
- docs/adr/
