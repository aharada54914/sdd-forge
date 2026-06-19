# Implementation Policy Review Rubric

Calibration guide for TYPE-H checks in the impl-review-loop. For TYPE-D checks,
see `references/impl-review-checklist.md` — their pass/fail criteria are
deterministic and do not require this rubric.

---

## DECISION-JUSTIFIED — What Constitutes a Rationale

Every technology choice or architectural decision must include a rationale.
The rationale must explain *why* the chosen option is preferred over alternatives
for this specific feature's context.

### Sufficient Rationale Patterns

| Decision | Sufficient Rationale |
|---|---|
| "We will use PostgreSQL for session storage" | "because we need transactional guarantees and the existing infrastructure already runs PostgreSQL, avoiding a new operational dependency." |
| "We chose Redis for rate-limiting counters" | "since Redis atomic INCR/EXPIRE operations support the required precision without distributed lock contention." |
| "We will use JWT for API authentication" | "because the mobile client is stateless and cannot maintain server-side sessions; see ADR-0012." |

### Insufficient Rationale Patterns

| Decision | Problem |
|---|---|
| "We will use React for the frontend." | No rationale stated — is this existing, mandated, or chosen? Why not another framework? |
| "PostgreSQL will be used for data storage." | Describes what, not why. |
| "We chose a microservice approach." | No comparison to alternatives or justification for this feature's context. |

### ADR Reference as Rationale

A decision may cite an ADR instead of providing inline rationale:
"We will use the event-sourcing pattern for order history (see ADR-0015)."
This is sufficient if ADR-0015 exists and contains the rationale. A reference
to a non-existent ADR is not sufficient and is flagged by ADR-PRESENT.

---

## OPEN-QUESTIONS-RESOLVABLE — Required Fields Per Question

Each open question in `## Open Questions` must follow this format:

```
### OQ-NNN: <question title>

<Question description>

Owner: <Role or person responsible for resolution>
Blocks Implementation: yes | no
Resolution Path: <Concrete action to resolve — e.g. "Schedule spike with
  platform team", "Check with legal on GDPR applicability", "Run load test">
```

### Blocking Question Examples

| Example | Assessment |
|---|---|
| "Can the legacy API handle the new payload format?" (no owner, no resolution path) | Major finding — blocking question with no resolution mechanism |
| "What is the correct timeout for external payment calls?" Owner: Backend Lead. Blocks Implementation: yes. Resolution Path: "Review Stripe documentation and existing error logs." | Acceptable — owner and resolution path stated |

### Non-Blocking Question Examples

| Example | Assessment |
|---|---|
| "Should we add telemetry for the new endpoint?" Owner: Product. Blocks Implementation: no. | Acceptable — non-blocking with owner; Minor advisory if Resolution Path absent |
| "Consider redesigning the entire auth flow." (no owner, no resolution path) | Major finding even if non-blocking — "consider" without ownership is not an open question, it is an ambiguous scope item |

---

## ASSUMPTIONS-VALID — Grounding Hierarchy

### Tier 1: Grounded in investigation.md (strongest)

An assumption is fully grounded when it cites an INV-xxx finding from
`specs/<feature>/investigation.md`:

"Assumption: The orders table has < 1M rows at time of migration. [INV-003:
database row count verified 2024-11-15, 450k rows]"

### Tier 2: Reasonable technical default (acceptable)

An assumption about well-known framework or platform behaviour that any
competent engineer would accept without investigation:

"Assumption: Next.js server components do not share state between requests."

This is a reasonable technical default. No investigation required.

### Tier 3: Accepted risk (requires explicit marking)

An assumption that is not grounded and not a technical default but the team
has decided to proceed:

"Assumption: External payment provider uptime is sufficient (accepted risk;
SLA reviewed with operations team)."

This is acceptable when marked as accepted risk with a brief basis.

### Unacceptable Assumptions

| Assumption | Problem |
|---|---|
| "The authentication service is fast enough." | Ungrounded; "fast enough" is unmeasured |
| "Users will not send malformed input." | Ungrounded security assumption; should be covered in Security Boundaries |
| "The database can handle the load." | Ungrounded; no investigation, no measurement, no accepted-risk marking |

### investigation.md Absence Rule

If `specs/<feature>/investigation.md` is absent AND the Assumptions section
contains more than one non-trivial assumption (excluding tier-2 technical
defaults), emit a Major finding. One non-trivial assumption without investigation
is a Minor advisory; more than one triggers Major.

---

## SECURITY-COVERAGE — Trust Boundary and PII Examples

### Required Elements for ## Security Boundaries

1. **Trust boundaries**: every system boundary the feature crosses must be named.

   Good: "Client → API Gateway (HTTPS/TLS 1.3, JWT validation at gateway),
   API Gateway → Database (VPC-internal, service account credentials)."

   Insufficient: "Secure communication is used throughout."

2. **Auth/authz mechanism**: the specific mechanism at each boundary.

   Good: "JWT bearer token with RS256 signing; scope `orders:read` required for
   GET /orders; scope `orders:write` for POST/PUT."

   Insufficient: "Standard authentication is applied."

3. **PII data classification**: what PII is stored, how it is protected.

   Good: "User email (PII) stored encrypted at rest (AES-256-GCM); never logged
   in plaintext; purged after 30-day retention period per GDPR Article 17."

   Insufficient: "User data is handled securely."

4. **OWASP concerns addressed**: at minimum, injection and broken auth.

   Good: "SQL injection: all queries use parameterised statements via ORM.
   Broken auth: JWT expiry enforced at 15 minutes; refresh token rotation on use."

### PII Keywords for Fallback Scan (TYPE-H)

When `## Security Boundaries` is absent, scan `## User Stories` in requirements.md
for these keywords (case-insensitive):

`email`, `phone`, `password`, `address`, `ssn`, `social security`, `date of birth`,
`dob`, `payment`, `credit card`, `card number`, `bank account`, `account number`,
`token`, `auth`, `login`, `pii`, `personal`, `gdpr`, `ccpa`, `hipaa`

Finding two or more of these keywords without a Security Boundaries section is
a Major finding. A single keyword triggers a Minor advisory.

---

## DESIGN-WITHIN-SCOPE — Scope Creep vs Under-scope Examples

### Scope Creep (Extra Functionality Not in Requirements)

| Design Element | Status in Requirements | Assessment |
|---|---|---|
| "Admin dashboard for managing feature flags" | Not in requirements.md Goals or User Stories | Scope creep — Major finding |
| "Real-time push notifications for order updates" | Not requested; requirements say "email notifications" | Scope creep — Major finding |
| "Multi-language support for the new form" | Not in requirements | Scope creep unless it appears in Non-goals as a known future item |

### Under-scope (Missing Required Functionality)

| Requirement | Design Coverage | Assessment |
|---|---|---|
| REQ-005: "Users can export their order history as CSV" | No export endpoint or frontend element in design | Under-scope — Major finding |
| REQ-008: "System must support 1000 concurrent users" | No performance design strategy mentioned | Under-scope for PERF-ADDRESSED check |

### Acceptable Out-of-Scope References

Design may reference existing system capabilities without specifying them:
"The feature uses the existing AuthService for JWT validation" is not scope creep
if AuthService is an established component.
