# Acceptance Tests: epic-136-phase4-docs

## Test Matrix

| Test ID | AC | Test Type | Target | Assertion in one line |
|---|---|---|---|---|
| TEST-001 | AC-001 | integration (real file read) | `cross-model-verification-policy.md` | all five failure-mode names present, each with a stated exit code |
| TEST-002 | AC-002 | integration (real file read) | same | the rate-limit row states it is not separately handled |
| TEST-003 | AC-003 | unit (stub CLI, 7 sub-cases) | 4 runners | `SDD_PANELIST_TIMEOUT` parsing; invalid values exit 2 **without invoking the CLI** |
| TEST-004 | AC-004 | integration (stub CLI, real process) | shell runners | bound is enforced in wall-clock time **and** the child is dead afterwards |
| TEST-005 | AC-005 | integration (stub CLI) | shell runners | timeout → exit 1 **and** no verdict JSON written |
| TEST-006 | AC-006 | integration (composed with the gate) | runner → `check-cross-model` | a timed-out sole non-Anthropic panelist makes the gate fail, no consensus PASS |
| TEST-007 | AC-007 | integration (real file read) | `docs/THREAT-MODEL.md` | ten OWASP identifiers present, every disposition cell non-empty |
| TEST-008 | AC-008 | integration (real file read) | same | ≥1 N/A row with a reason **and** ≥1 row citing an existing control |
| TEST-009 | AC-009 | integration (real file read) | same | five surface identifiers each present by literal string |
| TEST-010 | AC-010 | integration (real file read) | same | `--dangerously-bypass-hook-trust` named, with what it forfeits |
| TEST-011 | AC-011 | regression | `tests/cross-model.tests.{sh,ps1}` | both suites pass, including the pre-existing cases unmodified |
| TEST-012 | AC-012 | unit | test suites | the asserted default is read from the script, not hard-coded in the test |
| TEST-013 | AC-013 | integration (real file read) | `docs/THREAT-MODEL.md` | the MCP cross-reference names all three MCP servers with a trust posture each |

## Test Details

### TEST-001 (AC-001) — the taxonomy is complete, not merely present

Read `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` and assert, **for each of the five failure modes**, that all three elements REQ-001 requires are present: the mode's name, its exit code, whether a verdict file is produced, and how it propagates to the gate verdict.

Deliberately not a section-heading check — a heading assertion passes against an empty section. **And deliberately not an exit-code-only check either.** An earlier draft of this test asserted only the mode names plus an adjacent exit code, which would have passed against five bare `name → 1` lines while the propagation narrative was never written. That is the same FP-02 text-marker failure the paragraph above warns about, reproduced one level down in the test that was supposed to prevent it.

Expected exit codes, all verified against the implementation rather than assumed: CLI absent → 1; CLI exits non-zero → 1; CLI rate-limited → 1 via one of those two; CLI exceeds the bound → 1; **CLI returns malformed output → 1** (`run-panelist-gpt.sh:252,259,266,270,274`, all `sys.exit(1)` inside the validation block at `:241-297`, all before the verdict file is written).

### TEST-002 (AC-002) — the limitation is stated, not papered over

Assert the rate-limit row says it reaches the gate *through* the exit-non-zero or timeout path rather than by a mechanism of its own. A specification claiming a rate-limit-specific guarantee would be unverifiable, so this test's job is to confirm the honest phrasing survived.

### TEST-003 (AC-003) — configuration parsing, with a non-invocation assertion

Seven sub-cases per runner: unset, empty, `600`, `1`, `0`, `-5`, `abc`.

- First three: the runner proceeds to invoke the CLI.
- Last three: exit **2**, and the stub CLI records that it was **never called**.

The non-invocation assertion is the substantive part. A runner could validate late and still exit 2 after burning a vendor call, which defeats the point of treating misconfiguration as a caller bug.

### TEST-004 (AC-004) — the bound bounds, and the child dies

Three sub-cases, not one. Round 1 of spec review found the original single case — a 1-second bound against a 30-second `sleep` stub — could only ever exercise the unambiguously-hung path, leaving two branches of the chosen mechanism untested.

**(a) The clearly-hung case.** `SDD_PANELIST_TIMEOUT=1`, stub sleeps 30s. Assert:

1. elapsed wall-clock ≤ 10s (generous margin over the 1s bound plus the 2s SIGTERM grace), and
2. the stub's PID is no longer alive after the runner returns.

Assertion 2 is what distinguishes a genuine kill from a parent that merely stopped waiting. Without it a runner that abandons an orphaned vendor process would pass.

**(b) The `SIGTERM`-ignoring case (Edge Case 7).** Same bound, but the stub installs `trap '' TERM` and keeps running. Assert the runner still returns within the margin and the stub is dead — which can only happen via the `SIGKILL` escalation. A stub built from plain `sleep` dies on the first `SIGTERM` by default disposition, so without this sub-case an implementation whose escalation is broken or entirely absent would pass every other test.

**(c) The polling boundary race (Edge Case 6).** `SDD_PANELIST_TIMEOUT=2` with a stub that exits **successfully** at ~2 seconds — inside the interval where the poller is about to declare expiry. Assert the runner reports success and writes its verdict; it must not report a timeout for a child that already finished. Run this sub-case repeatedly (≥ 5 iterations) since it targets a race, and treat any single timeout report as a failure rather than flakiness.

### TEST-005 (AC-005) — no partial verdict survives

After the TEST-004 timeout, assert exit code 1 **and** that the output directory contains no verdict JSON for the task. A runner that exits 1 after writing a truncated verdict would be worse than one that hangs, because `check-cross-model` would then read it.

### TEST-006 (AC-006) — the gate actually fails

Compose TEST-004/005 with `check-cross-model` over the resulting verdict directory, with the timed-out panelist as the only non-Anthropic vendor. Assert non-zero exit and that no consensus PASS is reported.

This is the only test that demonstrates the issue's stated concern — a loophole in `critical` verification — is closed. TEST-005 alone only proves the runner behaved.

### TEST-007 / TEST-008 (AC-007, AC-008) — the OWASP mapping, with an anti-padding check

TEST-007 asserts all ten identifiers `LLM01`…`LLM10` appear and that each row's disposition cell is non-empty.

TEST-008 asserts at least one row is N/A **with a reason** and at least one row names an existing control. This fails a table claiming universal coverage and a table claiming none. It cannot verify the judgements are correct — that is the impl-review gate's job — but it does catch the most likely failure, which is a mapping padded to look complete.

### TEST-009 / TEST-010 (AC-009, AC-010) — the five surfaces, by literal identifier

Per surface, **two** assertions, both required: the identifier by literal string (`--dangerously-bypass-hook-trust`, `hooks.state`, the MCP-registration marker, `claude-hooks.json`, and the Claude Code settings/permissions surface), **and** that a trust-assumption statement plus a mitigation-or-residual-risk statement accompany it in the same section.

An earlier draft asserted only the identifier, which would have passed against a document that name-drops `hooks.state` in an unrelated sentence. TEST-010 on the same requirement already asserted an accompanying statement, which is what made the weaker form here an inconsistency rather than a considered choice.

`.codex/agents/*.toml` is **not** asserted here: it is already documented (INV-010) and REQ-005 forbids re-documenting it. A test asserting its presence would pass without this feature doing anything, which makes it a vacuous test.

### TEST-011 (AC-011) — regression, both runtimes

`tests/cross-model.tests.sh` and `tests/cross-model.tests.ps1` both pass. The pre-existing absent-CLI and non-zero-exit cases must pass **unmodified**; needing to edit one is evidence BL-001 was broken and must be reported, not accommodated.

All new cases drive a stub CLI placed on `PATH`. No test may invoke a real `codex` or `gemini` binary: a test requiring vendor credentials or a network is not a regression signal, and would make CI failures unattributable.

### TEST-013 (AC-013) — the MCP half of REQ-004 is actually checked

Assert `docs/THREAT-MODEL.md`'s MCP cross-reference names `sdd-forge-mcp`, `local-env-mcp` and `ci-mcp`, and that each carries a stated trust posture.

This test exists because round 1 of spec review found REQ-004's MCP clause had **no criterion and no test whatsoever** — AC-007 and AC-008 covered only the OWASP table, so an implementation could have satisfied every stated criterion for REQ-004 while omitting the MCP cross-reference entirely. The gap was concealed by an unresolved investigation open question, now resolved in AC-013: cite primary MCP documentation, because no authoritative third-party MCP security checklist is established by anything in this repository and requiring one this specification cannot name would be unverifiable.

### TEST-012 (AC-012) — the default is not duplicated

The default asserted by the tests is derived from the runner script itself, not written as a literal `600` in the test. A test carrying its own copy of the constant keeps passing after someone changes the script's default, which converts the test from a guard into a decoration.

## Notes

- Test types follow the repository's own convention: a case that drives a real process through a stub binary on `PATH` is **integration**, not unit, even though it exercises one script. The `epic-136-phase4-mcp` gate recorded a Minor for exactly this mislabelling (`acceptance-tests.md:14` versus `tasks.md:195`), so the tier is stated deliberately here.
- Every `file:line` in this document must be re-verified at implementation start. Citations that were accurate when written and stale when used are a recorded, recurring defect class in this repository (WFI-011).
- TEST-004's 10-second margin is loose on purpose. A tight margin turns an unrelated slow CI runner into a flaky failure, and a flaky guard gets disabled.
