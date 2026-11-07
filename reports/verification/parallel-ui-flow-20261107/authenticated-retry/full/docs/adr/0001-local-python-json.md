# ADR 0001: Local Python standard library and JSON

Date: 2026-11-07
Status: Proposed

## Context

Greenfield small task UI, local single user, JSON file persistence, time priority. Follow-up interview explicitly selects Python standard library plus plain HTML/JS and ds_profile:none. This is not task approval.

## Decision

Use Python3.12 HTTPServer and standard JSON/filesystem APIs, single process, 127.0.0.1 only. Serve explicit local assets. Persist versioned task document using same-directory temp file + fsync + os.replace. Browser renders plain text and confirms state from server. Runtime third-party dependencies zero.

## Alternatives

External web framework and SQLite are unnecessary for this small scope; SQLite would not meet JSON-as-primary-store selection. Browser-only localStorage does not meet JSON file persistence. Multi-process server would require extra locking and is outside small local scope.

## Consequences

No build/package setup. Single-user/local trust model only, no network deployment. File updates must fail safely. No multi-process sharing or power-loss durability guarantee. Verify restart/reload, serialization, storage failure and browser security. Related design: ../../specs/task-board/design.md; contract: ../../contracts/task-board-api.md.
