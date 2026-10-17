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
instead of growing two handwritten YAML parsers. Numeric acceptance is bounded
by the exact integer range of the canonical JSON representation; larger integers
must remain quoted strings.
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

## Review follow-up: numeric identity and mutation isolation

The review identified distinct YAML integer values above JavaScript's exact integer
range collapsing to the same canonical value. Numeric scalar construction now
rejects unsafe integers before mapping keys can become strings; normalization also
rejects unsafe integer values. This includes negative, hexadecimal, exponent,
nested, and numeric-key forms. Safe boundaries, quoted large integers, and finite
fractional values remain accepted. Rejection emits no partial canonical output.

The added regression cases failed before the repair (84 passed, 7 failed) and pass
afterward: Bash 91 passed, 0 failed; PowerShell 98 passed, 0 failed.

The T-004 mutation driver now copies the shared parser, its fixture and package
metadata into each isolated root, with access to the installed locked dependency.
Each run first proves the unmodified isolated Bash and PowerShell suites pass.
Parser mutations target the executable shared implementation and require an actual
source change. The unsafe-integer rejection has its own mutation.

Optional modulo sharding partitions every mutation pair without omitting cases.
Within a mutant run only, the target diagnostic ends the suite after that assertion
actually fails; unrelated failures cannot kill that mutant. Normal suites and
unmodified control/restore runs execute all assertions.

The exhaustive four-shard run completed with 118 unique mutant/runtime cases
killed and zero survivors (57 paired mutations plus four runtime-specific cases).
All eight unmodified isolated controls passed. Final full restoration checks
reported Bash 91 passed, 0 failed and PowerShell 98 passed, 0 failed. The ANSI/
wrapped-diagnostic classifier self-test and invalid-shard rejection checks passed.
