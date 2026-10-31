# MCP owner feedback and selected B implementation

The owner supplied an A-only `mcp-human-local-observation/v1` record for protocol
revision 4, then requested implementation of condition 2/B. The preceding chat
explicitly rejected raw MCP responses and selected B. The frozen assignment is
A=baseline raw response, B=candidate human-facing status view.

The submitted fragment omitted its opening `{`; restoring that outer delimiter
allowed preservation of the supplied structure. Participant identity and the
normalized raw record remain private and are not included in this report.

| Observation | Actual result |
|---|---|
| A start / submission | 17,464 / 48,049 local monotonic milliseconds |
| A answer interval | 30,585 ms; no explicit pause |
| Review / next action / authorization / later states | Each answered 「わからん」 |
| Misoperations | 「わからん」; count remains null |
| B trial / matched improvement | Not supplied / not established |
| Owner choice | B, followed by an explicit implementation request |

Events are monotonic and the interval matches subtraction. Repeated export
events are valid. Only A is submitted; `active_draft:null` does not mean the
two-condition evaluation completed. The interval includes reading/answering and
is not authenticated human active time. Unknown responses are not inferred to
be correct merely because a later workflow state is also unknown.

The selected implementation already exists on main `e105d955`:
`mcp/sdd-forge-mcp/src/index.ts` starts `startStatusView()` with `--status-ui`.
Its MCP subtree is identical at tested integration source `4b6a6d63` and merged
main `8ce4d9e3`. It reads the actual project through the existing guarded owners,
shows current phase/next command/per-stage state, and keeps raw evidence in a
collapsed disclosure. It is loopback-only; the published comparison is a fixed
data preview, not a live remote project server.

Fresh verification on an exact source export passed type checking, build, all
299 MCP tests and the nine checks in [mobile-check.json](mobile-check.json).
The mobile run used actual loopback HTTP and a temporary copy of the original
project fixture, not API replay. It selected `project-skill-observation` at
402×714 pixels and checked refresh after changing only the temporary fixture.
No product source change was necessary to implement the selected existing view.

Two evaluation setup failures were retained locally: an initial package-only
export omitted contracts/fixtures needed by the full suite, and the first mobile
harness asserted before selecting the requested feature. Complete source export
and explicit selection fixed the harness; product checks were not weakened.

Protocol SHA-256: `cd34235e95662ca3f3232ce8644715955cd4390758293ccc8f6c5de3fb870bff`.
Published HTML SHA-256: `88109895bb6deabe9c8ba584c627771de009e6c7cfb08355ca5c647513765bc8`.
Candidate bundle SHA-256: `0059f515fd123f57c0a742f9d8bc695bbff3efabf8f787e17cc228273d3afea6`.

The adoption goal and recurrence checks are handed to
[WFI-063](../../../docs/workflow-improvements/WFI-063.md), which remains Draft.
No B timing, correctness improvement, WFI verification or task/release approval
is inferred from this feedback. Issues #622/#624 retain their missing comparison
conditions; this report does not silently reduce their scope.
