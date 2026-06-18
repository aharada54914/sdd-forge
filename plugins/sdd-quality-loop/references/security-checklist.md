# Security Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches user input, authentication, authorization, secrets,
external systems, or AI/LLM features. It complements `evaluation-rubric.md`:
an unaddressed item below that is exploitable is a `Critical` finding; a
defensive gap with no current exploit path is `Major`.

Anchor every judgement in observed evidence (code read at line level, command
output), not in the implementation report's claims.

## Threat modeling first

- Start at the trust boundaries the change introduces or crosses (network,
  process, tenant, privilege). Name what data crosses each boundary.
- Apply STRIDE to the changed surface: Spoofing, Tampering, Repudiation,
  Information disclosure, Denial of service, Elevation of privilege.
- Prefer concrete, exploitable findings over theoretical risk. A finding
  should name the input, the path, and the impact.

## Input handling

- All external input is validated at the boundary against an explicit schema.
- Queries are parameterized or use an ORM; no string-built SQL/NoSQL.
- Output is encoded for its sink (HTML, shell, SQL, URL); no raw interpolation.
- File uploads are restricted by size and verified by content (magic bytes),
  not by extension or client-supplied MIME type.
- Redirects and `Location` targets are allowlisted, not reflected from input.

## Authentication & authorization

- Every protected route performs an explicit authorization check; access is
  denied by default.
- Object access is scoped to the caller (no IDOR — verify ownership, not just
  authentication).
- Passwords are hashed with a slow KDF (bcrypt 12+ rounds, scrypt, or argon2).
- Sessions/tokens use secure, httpOnly, same-site cookies; tokens expire and
  can be revoked.
- Auth and other abuse-prone endpoints are rate-limited.

## Data protection

- No secrets in source, history, logs, or error responses.
- Secrets resolve from the environment or a secret store, never hard-coded.
- PII is minimized, access-controlled, and encrypted in transit (HTTPS) and at
  rest where required.
- Sensitive fields (password hashes, tokens, internal ids) are stripped from
  API responses.

## Infrastructure & dependencies

- Security headers are present where applicable; CORS is restrictive, not `*`
  with credentials.
- Error responses are sanitized; no stack traces or internal paths leak.
- Lockfiles are committed; CI installs with a frozen lockfile (e.g. `npm ci`).
- Dependency audit shows no unresolved critical/high advisories; watch for
  typosquats and unexpected postinstall scripts.

## Third-party integrations

- API keys are stored server-side and least-privilege scoped.
- Webhooks verify signatures before acting on the payload.
- Outbound requests defend against SSRF: allowlist schemes/hosts, reject
  private/link-local ranges, and close TOCTOU gaps (resolve once, then use).

## AI / LLM features

- Treat all model output as untrusted input; never `eval`/exec it or pass it to
  a privileged tool unchecked.
- Keep secrets and cross-tenant data out of prompts and context windows.
- Run agents/tools under least privilege; bound token and tool-call budgets to
  prevent runaway cost.
- Guard against prompt injection from retrieved or user-supplied content.

## Verification

- No secrets found in the diff or git history.
- Dependency audit: no unresolved critical/high findings (or a recorded waiver).
- Every protected route exercises an authorization check, evidenced by a test.
- Input validation, output encoding, and rate limits are present on the changed
  surface, evidenced by code and tests.

## Source

Adapted for SDD from the open-source `addyosmani/agent-skills`
`security-and-hardening` skill and `security-checklist` reference.
