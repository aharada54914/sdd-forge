# Design: SQLite Task Board

Impl-Review-Status: Pending
Feature Type: project

## Technical Summary
Standard-library Python HTTP server serves a fixed static asset allowlist and JSON API. SQLite owns durable state. Commit before responding; browser reloads canonical list after writes.

## Architecture
Browser -> loopback HTTP server -> sqlite3 -> local database file. No external services. ADR: docs/adr/0001-local-standard-library.md.

## Components
| Component | Responsibility (Owns / Does Not Own) | Public Contract & Encapsulated Knowledge | State, Failure & Change Blast Radius | Technology | New/Existing |
|---|---|---|---|---|---|
| app.py | CLI/HTTP validation, not UI rendering | contracts/task-api.md; static allowlist | Per-request errors; startup fails for unusable DB | http.server/json | New |
| Storage | Committed CRUD/schema, not HTTP | Task record and missing-ID result | Rollback failures; connection per request | sqlite3 | New |
| Static page | Presentation/requests, not durable authority | Task API | Preserve input on error; refresh on success | HTML/CSS/JS | New |

## Layer Specifications
| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | One page and accessible states | ux-spec.md#scope-and-user-journeys | implementer | Draft |
| Frontend | Plain DOM and fetch | frontend-spec.md#technology-stack | implementer | Draft |
| Infrastructure | Local process and file | infra-spec.md#deployment-topology | local operator | Draft |
| Security | Loopback and validation | security-spec.md#trust-boundaries | implementer | Draft |

## Design System Compliance
N/A — ds_profile: none

## Cross-Layer Dependencies
| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| UX | Frontend | Visible mutation states | REQ-001–005 | AC-001–005 | TEST-001–005 |
| Security | Infrastructure | Loopback enforcement | REQ-006 | AC-006 | TEST-006 |
| Frontend | API contract | JSON shapes/errors | REQ-001–004 | AC-001–004 | TEST-001–004 |

## ADR Change Log
| ADR | Decision | Status | Layer Impact | Supersedes | Date |
|---|---|---|---|---|---|
| 0001 | Local standard-library architecture | Proposed | all | none | 2026-11-07 |

## Data Plan
Task(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1))). New data only. Create schema on startup with user_version=1; refuse unsupported future versions. Ascending ID order, parameterized SQL, connection per request, 5-second busy timeout, transaction per mutation. Live-row deletion does not promise secure erasure.

## API / Contract Plan
contracts/task-api.md is canonical. Static allowlist: /, /app.js, /style.css. Unknown routes 404. Positive integer IDs; 4096-byte request cap. Safe JSON errors without tracebacks. No automatic POST retry.

## Test Strategy
TEST-001–007: unittest integrations with temporary DB, actual browser interactions, restart, accessibility, timing and saved evidence. Independent quality gate owns Done. Verify available browser tooling before implementation completion claims.

## Security Boundaries
Browser/server: validated Host/Origin, safe text rendering. Server/database: fixed path, parameterized SQL. See security-spec.md.

## Deployment / CI Plan
python3 app.py --db data/tasks.sqlite3 --port 8000; fixed bind 127.0.0.1. Local unittest/py_compile and browser checks, no hosted CI or publishing.

## Constraint Compliance
Standard-library runtime/plain assets satisfy REQ-006; stable database path and committed writes satisfy REQ-004.

## Assumptions
No application login is inferred from the workspace name. Proposed product defaults are reviewable.

## Open Questions
Owner human reviewer: confirm pending UI reachability/safety and ds_profile answers before implementation.

## Risks
Disk/locking failure, permanent deletion, local process access and possible native reviewer identity-lifecycle unavailability.
