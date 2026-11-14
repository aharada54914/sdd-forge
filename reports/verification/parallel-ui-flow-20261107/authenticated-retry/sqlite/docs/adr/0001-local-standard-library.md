# ADR 0001: Local standard-library task application

Status: Proposed
Date: 2026-11-07

## Context
REQ-001–006 require a small local UI with durable CRUD, no external publishing and preferred Python standard library/plain HTML/JS.

## Decision
Use http.server, sqlite3 and static HTML/CSS/JS with same-origin JSON endpoints. Bind only loopback; one SQLite file owns state. No accounts or external services.

## Alternatives
A web framework adds installation overhead. Browser localStorage does not meet SQLite requirement. A hosted backend conflicts with local-only scope.

## Consequences
Simple startup and no runtime packages. Intended for trusted local use only; no application user authentication. Host/Origin checks and safe text rendering remain necessary. Real browser and process-restart tests are required before Done.
