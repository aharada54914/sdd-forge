# Security Specification: SDD context continuity

Status: Draft — bounded rules, no security-test result

## Trust Boundaries

| Boundary | Source → destination | Validation / authority | REQ | AC |
|---|---|---|---|---|
| B1 | Host observation → private store | Schema, owner, safe path, effective Git exclusion, pre-write redaction | REQ-001, REQ-005, REQ-009 | AC-007, AC-014–017 |
| B2 | Store → recovery | Integrity/expiry/owner checks; current SDD files win | REQ-002, REQ-004–006, REQ-010–011 | AC-001–008, AC-013, AC-018 |
| B3 | Registry → OS cleanup | Same account, exact owned store/files, fresh path validation + lock | REQ-005, REQ-009 | AC-013, AC-016 |
| B4 | Private evidence → review/diagnostic | Synthetic fixtures/content-free results only | REQ-009 | AC-014–015 |

## STRIDE Analysis

| Boundary | Threat / abuse | Mitigation | Verification |
|---|---|---|---|
| B1 | Spoofing: foreign session/worktree input | Canonical owner tuple; no text/turn-only dedup | TEST-019–023/057–059 |
| B1 | Disclosure: raw secret/Git-tracked capture | Redact before persistence; effective ignore + tracked check fail closed | TEST-045/046/052–056 |
| B2 | Tampering: forged approval/stale HANDOFF | Read-only current authority, source/hash reconciliation | TEST-009–018/061 |
| B2 | Denial of service: huge/partial corrupt records | Bounded scan/time/output; explicit unavailable, no fabricated prefix | TEST-024/025/034/060 |
| B3 | Elevation/confused deputy: replaced registry target | Revalidate account/owner/opened path, exact fixed filenames, no home scan | TEST-044g/056 |
| B3 | Tampering: cleanup races append | Shared lock and validated replacement, preserve nonexpired data | TEST-044f/h/066 |
| B4 | Disclosure: exception leaks private content/path | Content-free allowlisted diagnostic fields; synthetic evidence | TEST-045–051 |
| B4 | Repudiation: failed storage reported success | Stage-specific result only after sync; no raw diagnostic fallback | TEST-047/048 |

## Authentication Flow

N/A — no web login, OAuth, network credentials or new privileged identity.
Existing local OS account and independently verified native event/session context
scope operations. Session fields are evidence selectors, not authentication or
human approval. No permission escalation, trust weakening or alternate refusal
bypass. Dedicated new files/directories require restrictive creation modes or
per-user ACLs; this does not authorize relaxing existing/foreign permissions.

## Authorization

Default deny persistence/cleanup unless canonical root/worktree/git-dir, feature,
session relationship and private owned path are verified. HEAD changes invalidate
views, not owner. Resolve canonical aliases but reject escaping symlinks/junctions,
traversal, replaced targets and unknown schema. Revalidate immediately before
open/use; compare opened file identity where the OS supports it. Native Windows
path/case/junction behavior remains TEST-056/062, not a portable success claim.
Read authority without writes, approval changes or protected-file edits.

Before any journal write, verify effective Git ignore for each planned private
content path and confirm not tracked; missing/negated ignore, Git errors or tracked
files reject capture. Never auto-edit ignore/index, remove tracked files or relax
permissions on existing/foreign files. Create dedicated new files with restrictive
mode/ACL, verify access restriction, and reject persistence if it cannot be assured.
Initial safe exclusion/registration provisioning belongs to a later explicitly
approved installer task, not this draft. Reverify shared ignore/guard membership
at review and implementation (REQ-009; TEST-052–056).

## Data Classification and Protection

Redacted conversation, derivatives, content-bearing cursors, hashes and ownership
paths remain **private**. OS-user restricted files/directories; rely on existing
OS/disk protection, no new encryption key system or claim of encrypted storage.
No network transit/upload/export. Retention and all-copy deletion follow
[infrastructure](infra-spec.md#data-residency-and-retention), REQ-009/AC-013.
Public source specs/reports must contain no actual journal/session/private path,
personal data or secret; synthetic IDs and repo-relative source citations only.

## OWASP Mapping

Broken access control → owner/path checks (TEST-019–023/056/044g).
Injection → inert quoted evidence, never executable shell/template/approval input
(TEST-013/061). Sensitive-data failures → pre-persistence redaction and Git/public
boundary (TEST-045/046/052–055). Web CSRF/CORS/cookies/TLS endpoints are N/A:
no browser service. Local filesystem encryption limits are disclosed, not hidden.

## Secrets Management

OQ-011 design candidate is deterministic bounded redaction, applied in memory
before journal, staging, projection, quarantine, cursor content or diagnostic.
Fixed ordered rule families (longest matching spans merged before replacement):

1. PEM private-key blocks with matching BEGIN/END private-key labels, multiline.
2. Credential assignments/header values with case-insensitive exact key names
   `password`, `passwd`, `secret`, `api_key`, `apikey`, `access_token`,
   `refresh_token`, `client_secret`, `authorization`; quoted/unquoted JSON,
   YAML, dotenv and HTTP forms, Bearer/Basic value included.
3. URL userinfo credentials and query values for the same explicit sensitive keys.
4. Recognizable token prefixes: OpenAI `sk-`, GitHub `ghp_`/`github_pat_`, AWS
   access-key IDs `AKIA`/`ASIA`, and three-segment JWT-shaped bearer tokens;
   grammar/length bounds below are design choices, not provider-validity checks.

### Existing reuse and limits

Existing `mcp/local-env-mcp/src/diagnostics.ts:52–83` collects local identity and
every environment value of length >=4, longest first; `:87–100` escapes literal
regex metacharacters and replaces verbatim matches. `:108–132` restricts diagnostic
fields and discards stack/cause. Reuse the allowlist/no-stack principle and
longest-first literal-replacement principle, not `scrubMessage` itself: this feature
does not collect environment-wide values/local identities, import the MCP logger,
or emit free-form error messages. That known-value scrubber has no conversation
grammar/encoded matching and cannot satisfy TEST-045 alone. Reverify this shared
source before review/implementation. No dependency is added; use Node built-ins.

### Rule version 1 grammar and processing order

Design limits: 1 MiB UTF-8 observation (frontend input budget), 4,096 UTF-8 bytes
per identified sensitive value, 512 matched spans per observation, total core
1,000 ms deadline. These are bounds, not measured throughput. Process complete
host-decoded text once; never decode the whole prose recursively. Validate host
JSON with JSON.parse; invalid schema/JSON/isolated surrogates reject capture.
Scan the immutable in-memory text, gather original spans, merge overlaps, then
replace from the end. Each replacement includes the rule-family placeholder and
omission flag; raw spans and hashes are not persisted.

Assignment key recognition uses ASCII case-insensitive whole-token regex
`/^(password|passwd|secret|api_key|apikey|access_token|refresh_token|client_secret|authorization)$/i`.
No Unicode case folding or fuzzy names. In the table, “assignment-key set” means
exactly these names.

| Family | Exact bounded recognition / replacement |
|---|---|
| PEM | Exact ASCII BEGIN/END labels PRIVATE KEY, RSA PRIVATE KEY, EC PRIVATE KEY or OPENSSH PRIVATE KEY, same label; linear delimiter search, multiline span <=4,096 bytes. Remove entire block. Found opening label without matching close, or oversized block, rejects capture. No arbitrary PEM types. |
| Assignment | Whole key token matches the assignment-key set above. Key is bare `[A-Za-z_][A-Za-z0-9_]*` or a matching single/double-quoted token; surrounding whitespace is ASCII space/tab. Next delimiter must be `:` or `=`. Remove value span, not key. |
| Assignment value | Single/double-quoted value ends at first unescaped matching quote, counting odd preceding backslashes as escape; double-quoted value uses JSON.parse on the quoted literal, single quote supports only escaped quote/backslash. No recursive decoding. Bare value ends at whitespace, comma, semicolon, `}` or `]`; empty value is already empty. An identified value using YAML block `\|`/`>` or unclosed quote/invalid escape rejects capture. This supports single-line JSON/YAML/dotenv subsets, not full YAML. |
| Header | Case-insensitive exact `Authorization` at line start after ASCII space/tab, followed by `:`. Remove complete nonempty remainder up to CR/LF (including Bearer/Basic scheme), <=4,096 bytes; never decode Basic payload. Header recognition takes precedence over generic assignment termination. |
| URL | Scan absolute `http://`/`https://` tokens through whitespace or enclosing quote/angle bracket, <=4,096 bytes; parse with Node URL. If username/password is nonempty, or any query key matches the assignment-key set after URLSearchParams one-pass percent/+ decoding, remove the **entire original URL token**. This avoids reserializing leaked fragments. Invalid URL or malformed percent escape in a candidate containing `@` or a sensitive raw/decoded query key rejects capture. No recursive percent decoding or arbitrary URI schemes. |
| Prefix tokens | Case-sensitive prefix `sk-`, `ghp_` or `github_pat_` followed by 20–256 ASCII `[A-Za-z0-9_-]` characters; non-token boundary or input end on both sides. AWS `AKIA`/`ASIA` followed by exactly 16 `[A-Z0-9]` with ASCII alphanumeric boundary. Remove whole token. Oversized suffix after a recognized prefix rejects capture, rather than partial masking. |
| JWT-shaped | Three `[A-Za-z0-9_-]{8,2048}` segments separated by literal dots, with non-base64url/dot boundaries; remove whole span. Scan segments linearly, not nested/backtracking regex. Three-segment candidate exceeding bound rejects capture. No JWT validity/signature claim or Base64 decoding. |

Order: host JSON decode → PEM/header/assignment/URL/token span discovery on the
same text → URL query decode only for classification, quoted-value decode only
for validation → merged-span substitution → final UTF-8 size/schema checks.
Diagnostics are allowlisted reason/stage constants only, never raw text passed
through a scrubber. Any scanner/decoder failure, bound/deadline exhaustion or
uncertain identified sensitive span rejects this capture before all writes; warn
and continue ordinary work, no raw fallback/temp/backup. Unknown unlabeled formats
are not automatically errors or evidence of cleanliness: the limits below apply.

### Planned synthetic verification

TEST-045 must enumerate all four PEM labels; every named assignment key in bare,
single/double-quoted, mixed-case and colon/equal forms; header Bearer/Basic; URL
userinfo and each percent/+ decoded sensitive query key; all token prefixes and
JWT; overlapping spans, CRLF, Unicode, escaped quotes, and exact bound values.
Assert absence across primary/staging/derived/quarantine/cursor/output paths,
placeholder/omission disclosure and no raw digest. Non-key substrings, unsupported
URI schemes, too-short tokens, nested encodings and unlabeled PII are negative or
documented-gap controls, not a comprehensive-detection PASS. TEST-046 covers
unclosed PEM/quote, invalid escapes/JSON, malformed sensitive URL, oversized value/
token/input, >512 spans, scanner exception and deadline; each asserts no write,
no raw diagnostic/backup, warning and continued work. These are planned additions
within existing TEST-045/046, not executed tests or changed acceptance rows.

Replace with `[REDACTED:<rule-family>]`, retain no original span/digest/backup,
and set omission=true; recovery says removed content is unrecoverable. Test each
family and multiline/Unicode/escaped boundaries on every copy/output path
(TEST-045). Unknown formats, arbitrary opaque tokens, encoded/obfuscated secrets,
unlabeled credentials, PII and secret fragments may evade detection. False
positives can remove useful text. This is not comprehensive DLP; even sanitized
content remains private. No environment-wide value harvesting or claim all secrets
are found. Pattern validation/processing failure rejects persistence, warning and
ordinary work continues without raw fallback (TEST-046/047–051). Redaction is
not an authorization boundary or approval mechanism.

## SBOM and Supply Chain

Reuse existing locked Node/build dependencies; no addition. Reverify lock/build
state before implementation review; existing scanning/provenance workflow applies,
no new SBOM service/signature infrastructure. Security implementer owns dependency
regression evidence, and host integration changes cannot bypass trust approval.

## Security Tests

Synthetic-only TEST-019–026, TEST-041–046/044a–i, TEST-047–059/061/062/066 cover
owner/corruption/expiry/redaction/failure/path/readonly races. Native tests must
record each OS separately; fixtures cannot establish ACL/junction/scheduler
behavior. Test retained pre-expiry and foreign host-transcript controls unchanged.
No real capture, cleanup or scan result is asserted by this document.

## Open Questions

OQ-009: security implementer owns native owner/path/ignore/access tests, blocking
storage safety. OQ-011: exact bounded rule-version-1 grammar is a design candidate
above; synthetic verification and independent review remain pending, and independent
review must assess false-negative limits. OQ-005/008: native identity/trust proof
belongs to adapter implementer, never inferred from PreToolUse canary success.
