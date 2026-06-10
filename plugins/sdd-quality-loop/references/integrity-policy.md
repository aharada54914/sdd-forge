# Integrity Policy

Traceability connects requirements, design, contracts, implementation, tests,
and status.

Valid statuses are `Planned`, `In Progress`, `Blocked`,
`Implementation Complete`, `Done`, and `Drift Detected`.

Detect drift when requirements lack code or tests, implementation lacks an
approved task, APIs differ from OpenAPI, data differs from JSON Schema, or
architecture changes lack an ADR.

Small mapping gaps may be corrected directly. Ambiguous or major gaps require a
review ticket. Do not mark `Done` unless implementation, tests, verification,
critical review, and traceability are complete.
