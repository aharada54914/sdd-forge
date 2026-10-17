# A7 structural parser repair — 2026-10-17

The structural comparison previously treated everything following a YAML key's
colon as a raw string. Closed frontmatter containing unterminated flow sequences,
flow mappings or quoted scalars therefore passed, as did unknown executable tags.
Valid nested mappings failed instead. This invalidated the parse-failure boundary
used by both recorded fixtures and the refresh command.

Both existing shell entry points now call one Markdown canonicalizer using the
repository's existing locked `js-yaml` dependency. YAML core-schema parsing rejects
invalid syntax, duplicate keys and unknown tags; normalization rejects cycles and
non-finite numbers before any stdout is emitted. It preserves ordered ATX headings,
normalizes horizontal whitespace, and compares semantic mapping/sequence/scalar
values. The twelve parser cases extend the existing structural suites; no new
suite, loop driver, or dependency package was introduced.

## Verification

- Before repair, the ten initial parser cases produced five failures: invalid flow
  sequence, flow mapping, quoted scalar and executable tag were accepted; a valid
  nested mapping was rejected. The existing suite reported 66 passed, 5 failed.
- After repair, Bash structural compatibility reports 76 passed, 0 failed. This
  includes semantic values and cyclic-alias/non-finite rejection cases.
- PowerShell structural compatibility reports 83 passed, 0 failed.
- The refresh dry-run accepts the existing F2 corpus and rejects closed frontmatter
  with an invalid flow value without writing the corpus.
- Existing Bash byte-identical compatibility: 25 passed, 0 failed.
- Existing Bash/PowerShell skip allowlist: 29/32 passed, 0 failed.
- Existing Bash/PowerShell loop escalation: 37/36 passed, 0 failed.
- Existing Bash loop consistency: 34 passed, 0 failed.
- Existing golden-baseline mutation guards: 3 passed, 0 failed in Bash and
  PowerShell.
- Bash/Node syntax and whitespace checks passed. An independent ordinary code
  review found no blocking issue in the parser repair. This does not manufacture
  a historical workflow verdict.

PowerShell was exercised on Linux. Native Windows/macOS and latest-head CI results
must be checked on the PR before merging.

## Runtime and scope reconciliation

The old requirements assumption that this epic introduces no runtime beyond Bash,
PowerShell and jq predates the repository's current Node-based MCP and regression
checks. The user explicitly authorized root-cause repairs and simple code reuse.
This repair deliberately reuses the existing Node.js and locked `js-yaml` package
instead of growing two handwritten YAML parsers or narrowing YAML acceptance.
For local structural checks, run `npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts`
first. The OS test matrix and POSIX inventory shards perform the same setup. No
installed plugin's runtime requirements change.

The orchestration changes retain the existing loop-inventory, shared loop driver,
event-trace collector and escalation suites. Invalid Context traces execute the
real sidecar generator/validator with a fixture-only key, positive valid-Context
and absent-Context controls, and stop-only golden comparisons.

This PR improves the existing compatibility tests; it does not establish native
host activation or a production interviewer-to-resolver invocation. In particular,
TEST-019.10b and TEST-019.11c still cannot prove an LLM-driven SKILL caller's real
behavior from executable-source scanning. F3/F5/F6 structural cases remain
allowlisted skips under the current public normative inputs. Issue #195 must stay
open for the outstanding live evidence; old fixture/CI success is not that proof.
