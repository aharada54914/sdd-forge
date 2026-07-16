# Risk-Upgrade Policy

This policy is the protected, deterministic decision contract for determining
whether a requested lite workflow must be upgraded to the full SDD track.
It is local only: it never retrieves issue content or follows a URL.

## Input and result contract

Both `check-risk-upgrade.sh` and `check-risk-upgrade.ps1` accept one path to
UTF-8 source text.

- A policy match prints `full-required: <primary-id>; triggers=<ordered-ids>`
  and exits 10.
- No match prints `lite-eligible` and exits 0.
- A missing, unreadable, NUL-containing, or malformed UTF-8 input prints
  `risk-upgrade: input unavailable` and exits 2.

Only ASCII `A` through `Z` are normalized to lowercase. CRLF and CR normalize
to LF; each run of ASCII space, tab, or LF normalizes to one ASCII space.
Every non-ASCII code point is a token boundary but is otherwise preserved.
A token boundary is start/end or a character outside `[a-z0-9_]`; hyphen is a
boundary and underscore is not. Bounded `design token` and `design tokens`
phrases are excluded without suppressing a separate trigger such as
`token-value`, `design-token`, or `token` followed by a non-ASCII character.

## Ordered trigger matrix

The first matching row is the primary diagnostic. All matching IDs are emitted
in this exact order.

| Order | ID | Trigger | Exclusion |
|---:|---|---|---|
| 1 | `AUTH_BOUNDARY` | whole-token `auth`, `authentication`, `authorization`, `oauth`, or `oidc` | No substrings such as `author` or `oauthless`. |
| 2 | `TOKEN_CREDENTIAL` | whole-token `token`, `tokens`, `credential`, `credentials`, `password`, or `passwords`; or `private key` / `private keys` | A bounded `design token` or `design tokens` phrase is removed first. |
| 3 | `MCP` | whole-token `mcp` | No substring such as `mcpish`. |
| 4 | `EXTERNAL_API` | `external API(s)` or `third-party API(s)` / `third party API(s)` with normalized whitespace or hyphen | `API design` alone does not match. |
| 5 | `SECRET` | whole-token `secret` or `secrets` | No substring such as `secretion`. |
| 6 | `GITHUB_ACTIONS` | `github actions` separated by normalized whitespace | No substring such as `github-actionable`. |

## Workflow use

`lite-spec` passes the complete user-supplied source body to a checker before
creating any lite artifact. An opaque URL is input-unavailable unless its body
was already read into a local UTF-8 source file.

`ship` passes the selected complete `## T-NNN` block followed by that feature's
`requirements.md` to a checker whenever lite could otherwise be selected. A
risk match always selects full, including when `--lite` was requested. Missing
task-block or requirements input stops with the input-unavailable diagnostic;
it never falls back to the lite gate. `--full` is a deliberate override and
does not invoke the scan.
