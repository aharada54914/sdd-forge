# Task Review Rubric

Calibration guide for TYPE-H checks. For TYPE-D checks, see
`references/task-review-checklist.md` — their pass/fail criteria are
fully deterministic and do not require this rubric.

---

## OBSERVABLE-DONE — Forbidden Verb List

A Done When item must name a concrete, independently verifiable artifact, test
result, metric, or command output. The following patterns are forbidden because
they cannot be verified without additional specification.

### Forbidden: "ensure"

The word "ensure" requires the reviewer to define what "ensuring" means, which
is not observable.

| Forbidden | Preferred |
|---|---|
| Ensure user input is validated | `validate_user_input()` unit tests pass with 0 failures |
| Ensure migrations run cleanly | `db:migrate` exits 0 on a clean test database |
| Ensure no regressions | `npm test` passes with no new failures vs baseline |

### Forbidden: "consider"

"Consider" is a subjective instruction, not a verifiable outcome.

| Forbidden | Preferred |
|---|---|
| Consider adding logging | Structured log entry emitted for each failed login attempt (verified by test `test_login_failure_log`) |
| Consider performance impact | P95 response time ≤ 200 ms under 100 concurrent users (load test output attached) |

### Forbidden: "update \<X\>" without measurable target

"Update" without specifying what the updated state looks like is not verifiable.

| Forbidden | Preferred |
|---|---|
| Update documentation | `docs/api.md` section "Authentication" updated to describe new token format (diff shows ≥ 1 changed line in that section) |
| Update traceability.md | T-005 row in traceability.md maps to REQ-012 and AC-007 (reviewable by reading the file) |
| Update CLAUDE.md | CLAUDE.md `## Known Patterns` section contains a new entry describing the retry-queue pattern introduced in this task |

Exception: "Update traceability.md" is allowed as a Done When item when the
task spec explicitly names which task IDs and requirement IDs will be added.

### Forbidden: "verify is correct"

"Correct" is undefined without specifying the criterion for correctness.

| Forbidden | Preferred |
|---|---|
| Verify payment calculation is correct | `test_payment_rounding` passes with expected output `$12.50` for input `$12.499` |
| Verify API response is correct | GET /users/1 returns HTTP 200 with body `{"id":1,"email":"..."}` matching contract schema v2 |

### Forbidden: "works correctly"

Identical issue — no observable criterion.

| Forbidden | Preferred |
|---|---|
| Feature works correctly end-to-end | All 5 acceptance tests in AC-003 through AC-007 pass in the CI pipeline |
| Authentication works correctly | `POST /auth/login` with valid credentials returns HTTP 200 and a JWT; with invalid credentials returns HTTP 401 (verified by integration test suite) |

---

## SINGLE-CONCERN — "And" Allowed vs Forbidden Examples

The presence of "and" in a task title or scope requires evaluation against the
allowed categories.

### Allowed: Test/Verification Tied to Primary Clause

The second clause tests or verifies the thing implemented in the first clause.
The two concerns cannot be separated without creating an untested implementation.

| Allowed Example |
|---|
| "Implement login rate-limiting and write integration tests for rate-limit enforcement" |
| "Add caching layer for user profiles and verify cache invalidation on profile update" |
| "Create password-reset email template and write snapshot test for the rendered output" |

### Allowed: Mandatory Housekeeping

The second clause updates a mandatory tracking file that is always required when
the first clause is completed. AGENTS.md, CLAUDE.md, and traceability.md fall
into this category because the SDD process mandates their update.

| Allowed Example |
|---|
| "Add feature flag `enable_new_checkout` and update AGENTS.md Known Patterns section" |
| "Migrate user_sessions table schema and update traceability.md T-008 row" |
| "Implement RetryQueue class and update CLAUDE.md with the retry-queue usage pattern" |

### Forbidden: Two Distinct Feature Concerns

The two clauses implement separate functional capabilities that could be separate
tasks without any inherent coupling.

| Forbidden Example | Reason |
|---|---|
| "Add user profile page and implement notification preferences" | Two distinct UI features; profile and notifications are independent concerns |
| "Create database index on orders.user_id and add CSV export endpoint" | Performance optimisation and a new API endpoint are unrelated |
| "Implement search autocomplete and redesign the navigation header" | Two independent UI features with no shared implementation |
| "Write unit tests for AuthService and refactor PaymentService" | Testing one module and refactoring another are independent concerns |

---

## RISK-APPROPRIATE — Sentinel Surface Proximity Rule

The proximity rule requires task-reviewer-b to scan the task's `Scope`, `Done
When`, and `Goal` sections for sentinel surfaces. Finding any of these surfaces
in the task body creates a presumption of Risk: high or critical that the
reviewer must confirm or rebut.

### Sentinel Surfaces Requiring Risk: high or critical

| Surface | Keywords to Match |
|---|---|
| Authentication | auth, login, logout, password, token, session, OAuth, SAML, MFA, 2FA, credential |
| Authorization | permission, role, ACL, access control, admin, privilege, RBAC |
| Payment | payment, billing, charge, invoice, subscription, refund, Stripe, card, PCI |
| PII storage | personal data, email, phone, address, SSN, DOB, GDPR, CCPA, user data |
| Data migration | migration, migrate, schema change, ALTER TABLE, backfill, data transform |
| External API contracts | API contract, breaking change, versioned endpoint, client SDK update |

### Example: Under-classification (Major finding)

Task scope: "Update the `users` table to add an encrypted `phone_number` column
with backfill of existing records."

Analysis: "phone_number" is PII; "backfill" is data migration. Both sentinel
surfaces are present in proximity. Risk: low is a Major finding.

### Example: Over-classification (Major finding)

Task scope: "Update button label from 'Submit' to 'Send Request' in the
contact form."

Analysis: No sentinel surface. Risk: high is a Major finding (wastes TDD
enforcement on a trivial UI copy change).

### Example: Correct Classification

Task scope: "Implement JWT refresh-token rotation in AuthService."

Analysis: "JWT" and "auth" are present. Risk: high is appropriate. Task must
also include Red→Green evidence and independent review verdict in Done When.

---

## DEPENDENCY-COMPLETE — Artifact Reference Detection Examples

When checking whether a Blocker relationship is genuine (for the DEPENDENCY-OVERLAP
check in task-reviewer-b), look for these artifact reference patterns in the
downstream task's scope:

### Evidence of Genuine Dependency

| Downstream scope contains | Upstream task produces | Assessment |
|---|---|---|
| "Uses `RetryQueue` class from T-003" | `RetryQueue` implementation | Genuine blocker |
| "Reads migration output from T-001's schema change" | Schema migration | Genuine blocker |
| "Calls the API endpoint created in T-002" | REST endpoint | Genuine blocker |
| "Depends on the feature flag added in T-004" | Feature flag definition | Genuine blocker |

### Evidence of Spurious Dependency

| Downstream scope | Upstream scope | Assessment |
|---|---|---|
| "Update CSS for the login page" | "Update CSS for the dashboard" | Spurious — both are independent CSS tasks |
| "Write unit tests for UserService" | "Write unit tests for OrderService" | Spurious — independent test tasks |
| "Update CLAUDE.md after T-001" | "Implement any feature" | Spurious if CLAUDE.md update is not conditional on T-001's specific output |
