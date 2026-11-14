# Frontend Specification: SQLite Task Board

## Technology Stack
Plain semantic HTML, CSS and browser JavaScript with fetch/AbortController. No framework, bundler or runtime dependencies. Modern browser; actual browser version recorded during TEST-004/005.

## Component Tree
Page shell owns heading, add form, task list, status/error region and Retry. API adapter owns requests; server owns all durable state. No lazy-load boundary is needed for one small page.

## State Shape
tasks: array of {id: positive integer, title: string, completed: boolean}; status: loading/ready/error; draftTitle: string; pending operation: null or {action,id}; error: null/string. Draft and request state are memory-only; SQLite owns tasks (REQ-001–005, AC-001–005).

## Routes and Components
GET / serves the board; /app.js and /style.css are fixed static assets. No client routing or authentication. Initial list fetch has a page-level loading/error boundary; mutation errors retain input and allow refresh.

## API Client Strategy
Relative same-origin URLs from contracts/task-api.md. JSON request/response, 10-second AbortController timeout, no automatic mutation retries. Normalize HTTP/network/parse failures to safe visible messages. On uncertain mutation outcome refresh canonical state before retry; duplicate titles are allowed. Render task text using textContent. No localStorage, telemetry or client-side credentials.

## Code Splitting and Size Budget
Eager HTML/CSS/JS, no chunks or prefetch. Combined uncompressed assets <=100 KiB measured from file bytes (AC-007, TEST-007).

## Performance Budget
Local list for 100 tasks <=1 second each over 20 requests; record host/timings (AC-007). No public-network Core Web Vitals SLO for this local-only prototype.

## Empty, Loading, Error, and Success Behavior
Use UX component-state table (AC-005). Clear draft only after successful add; reload list after successful mutation; show refresh failure distinctly from write failure. Keep controls keyboard reachable and prevent duplicate pending actions.

## Dependencies
Runtime: none beyond browser and Python. Verification may use available browser tooling, with exact version and execution logs; it is not a product dependency.

## Testing
TEST-001–004 real browser behavior and persistence. TEST-005 keyboard, live regions, contrast and two viewport widths. TEST-006 literal hostile text. TEST-007 assets/timings. Integration tests use temporary data and no production fixtures.

## Open Questions
None beyond the shared UI interview confirmations in ux-spec.md.
