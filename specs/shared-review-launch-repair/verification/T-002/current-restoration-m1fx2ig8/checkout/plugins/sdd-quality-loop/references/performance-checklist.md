# Performance Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches data access, loops over user-controlled sizes, hot
paths, or rendering. A regression with measured impact on a stated performance
acceptance criterion is `Major`; a clear algorithmic defect on a hot path is
`Critical`. Without a stated performance requirement, treat findings as
`Minor`/advisory unless they are obviously pathological.

Measure before claiming. Prefer a profile, a query log, or a timing over
intuition.

## Data access

- No N+1 query patterns: collection access batches or eager-loads instead of
  querying per item.
- Queries are bounded (pagination, `LIMIT`) and use indexed columns for
  filters and joins.
- Large result sets stream rather than materialize entirely in memory.

## Computation & loops

- No unbounded loops or recursion over user-controlled input.
- Avoid accidental quadratic work (nested scans, repeated `.includes`/`.find`
  inside a loop — use a map/set).
- Heavy work is hoisted out of hot paths and tight loops; results are memoized
  where inputs repeat.

## Concurrency & I/O

- Independent I/O runs concurrently rather than serially awaited.
- Blocking work is kept off the request/render path; long jobs are queued.
- External calls have timeouts and bounded retries (no unbounded fan-out).

## Memory & allocation

- No per-request allocation in hot paths that could be reused.
- No unbounded caches or accumulators that grow with traffic (leak risk).

## Frontend rendering

- No avoidable re-renders (stable keys, memoized props/handlers where it
  matters).
- Large lists are virtualized; heavy assets are lazy-loaded or code-split.
- Layout-thrashing read/write interleaving is avoided.

## Verification

- For a stated performance acceptance criterion, a measurement (timing,
  profile, or query count) is captured as evidence and meets the target.
- Hot-path changes include a before/after number when feasible, not a claim.

## Source

Adapted for SDD from the open-source `addyosmani/agent-skills`
`performance-optimization` skill and `performance-checklist` reference.
