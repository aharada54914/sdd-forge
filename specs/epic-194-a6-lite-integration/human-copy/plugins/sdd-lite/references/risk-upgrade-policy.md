# Risk-Upgrade Policy

This policy is the protected, deterministic decision contract for determining
whether a requested lite workflow must be upgraded to the full SDD track.
It is local only: it never retrieves issue content or follows a URL.

## Input and result contract

Both `check-risk-upgrade.sh` and `check-risk-upgrade.ps1` accept one path to
UTF-8 source text, and an optional second argument (`--capability-reasons
<fragment-path>` / `-CapabilityReasons <fragment-path>`, epic-194-a6-lite-
integration T-002, REQ-002).

- A policy match prints `full-required: <primary-id>; triggers=<ordered-ids>`
  and exits 10.
- No match prints `lite-eligible` and exits 0.
- A missing, unreadable, NUL-containing, or malformed UTF-8 primary source
  input prints `risk-upgrade: input unavailable` and exits 2.
- When the second argument is supplied and the named fragment is
  unreadable, not valid JSON, missing its `capabilities` key, has a
  non-array `capabilities` value, or has any entry missing `id` or
  `eligible`, the script prints `risk-upgrade: capability-reasons fragment
  invalid` and exits 2 -- distinct from the primary-source-unavailable
  diagnostic above, and never silently degraded to "no Capability-derived
  trigger."

Only ASCII `A` through `Z` are normalized to lowercase. CRLF and CR normalize
to LF; each run of ASCII space, tab, or LF normalizes to one ASCII space.
Every non-ASCII code point is a token boundary but is otherwise preserved.
A token boundary is start/end or a character outside `[a-z0-9_]`; hyphen is a
boundary and underscore is not. Bounded `design token` and `design tokens`
phrases are excluded without suppressing a separate trigger such as
`token-value`, `design-token`, or `token` followed by a non-ASCII character.

## Ordered trigger matrix (unchanged, keyword-derived)

The first matching row is the primary diagnostic when any keyword row
matches. All matching IDs are emitted in this exact order.

| Order | ID | Trigger | Exclusion |
|---:|---|---|---|
| 1 | `AUTH_BOUNDARY` | whole-token `auth`, `authentication`, `authorization`, `oauth`, or `oidc` | No substrings such as `author` or `oauthless`. |
| 2 | `TOKEN_CREDENTIAL` | whole-token `token`, `tokens`, `credential`, `credentials`, `password`, or `passwords`; or `private key` / `private keys` | A bounded `design token` or `design tokens` phrase is removed first. |
| 3 | `MCP` | whole-token `mcp` | No substring such as `mcpish`. |
| 4 | `EXTERNAL_API` | `external API(s)` or `third-party API(s)` / `third party API(s)` with normalized whitespace or hyphen | `API design` alone does not match. |
| 5 | `SECRET` | whole-token `secret` or `secrets` | No substring such as `secretion`. |
| 6 | `GITHUB_ACTIONS` | `github actions` separated by normalized whitespace | No substring such as `github-actionable`. |

This table is unchanged by T-002: no new keyword row is added, and no
Predicate-DSL/Registry-matching logic of the script's own is introduced
(requirements.md AC-009).

## Capability-derived trigger source (new, T-002, REQ-002)

When `--capability-reasons`/`-CapabilityReasons` is supplied and the named
fragment is valid, its shape is:

```json
{
  "capabilities": [
    {"id": "durable-workflow-svc", "eligible": false,
     "upgrade_reasons": ["durable_workflow"]},
    {"id": "internal-tool-only", "eligible": false,
     "upgrade_reasons": []}
  ]
}
```

Every entry with `eligible: false` contributes, in fragment array order:
its own `upgrade_reasons` tokens if the array is non-empty, or else a
single synthetic token `ineligible:<id>` -- an entry with `eligible: false`
and no named reason still produces a non-empty trigger, never silently
nothing. An entry with `eligible: true` contributes nothing. Each token
inside `upgrade_reasons` is already validated upstream (by whatever
produced the fragment) against the lite-upgrade-reason-catalog; this script
does not re-validate the token values themselves, only the fragment's own
shape and readability.

## Merge order

`all_triggers = keyword_triggers ++ capability_triggers` -- keyword-derived
tokens (today's six-row scan) always precede Capability-derived tokens.
When the second argument is omitted entirely, `capability_triggers` is
always empty and behavior is byte-identical to the pre-T-002 script
(requirements.md AC-007); this is the only condition that guarantee
applies to. The primary id (`full-required: <primary-id>`) is the first
entry of the merged list: unchanged from today whenever any keyword row
matches, and equal to the first Capability-derived token only when no
keyword row matches but at least one Capability-derived token does.

## Workflow use

`lite-spec` passes the complete user-supplied source body to a checker
before creating any lite artifact, and (T-003, REQ-005) additionally
assembles a Capability-derived trigger fragment from every matched,
ineligible Registry Capability and supplies it as the second argument. An
opaque URL is input-unavailable unless its body was already read into a
local UTF-8 source file.

`ship` passes the selected complete `## T-NNN` block followed by that
feature's `requirements.md` to a checker whenever lite could otherwise be
selected. A risk match always selects full, including when `--lite` was
requested. Missing task-block or requirements input stops with the
input-unavailable diagnostic; it never falls back to the lite gate.
`--full` is a deliberate override and does not invoke the scan.
