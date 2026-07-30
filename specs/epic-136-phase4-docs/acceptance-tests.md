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

## Test Details

### TEST-001 (AC-001) — the taxonomy is complete, not merely present

Read `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` and assert the presence of all five failure-mode names **and** an exit code adjacent to each: CLI absent, CLI exits non-zero, CLI rate-limited, CLI exceeds the time bound, CLI returns malformed output.

Deliberately not a section-heading check. A heading assertion passes against an empty section — the exact text-marker failure mode recorded as FP-02 in the `epic-136-phase3` retrospective, where a conformance AC was satisfied by line shapes while the artifact was invalid.

### TEST-002 (AC-002) — the limitation is stated, not papered over

Assert the rate-limit row says it reaches the gate *through* the exit-non-zero or timeout path rather than by a mechanism of its own. A specification claiming a rate-limit-specific guarantee would be unverifiable, so this test's job is to confirm the honest phrasing survived.

### TEST-003 (AC-003) — configuration parsing, with a non-invocation assertion

Seven sub-cases per runner: unset, empty, `600`, `1`, `0`, `-5`, `abc`.

- First three: the runner proceeds to invoke the CLI.
- Last three: exit **2**, and the stub CLI records that it was **never called**.

The non-invocation assertion is the substantive part. A runner could validate late and still exit 2 after burning a vendor call, which defeats the point of treating misconfiguration as a caller bug.

### TEST-004 (AC-004) — the bound bounds, and the child dies

`SDD_PANELIST_TIMEOUT=1`, stub CLI sleeps 30s. Assert:

1. elapsed wall-clock ≤ 10s (generous margin over the 1s bound plus the 2s SIGTERM grace), and
2. the stub's PID is no longer alive after the runner returns.

Assertion 2 is what distinguishes a genuine kill from a parent that merely stopped waiting. Without it a runner that abandons an orphaned vendor process would pass.

### TEST-005 (AC-005) — no partial verdict survives

After the TEST-004 timeout, assert exit code 1 **and** that the output directory contains no verdict JSON for the task. A runner that exits 1 after writing a truncated verdict would be worse than one that hangs, because `check-cross-model` would then read it.

### TEST-006 (AC-006) — the gate actually fails

Compose TEST-004/005 with `check-cross-model` over the resulting verdict directory, with the timed-out panelist as the only non-Anthropic vendor. Assert non-zero exit and that no consensus PASS is reported.

This is the only test that demonstrates the issue's stated concern — a loophole in `critical` verification — is closed. TEST-005 alone only proves the runner behaved.

### TEST-007 / TEST-008 (AC-007, AC-008) — the OWASP mapping, with an anti-padding check

TEST-007 asserts all ten identifiers `LLM01`…`LLM10` appear and that each row's disposition cell is non-empty.

TEST-008 asserts at least one row is N/A **with a reason** and at least one row names an existing control. This fails a table claiming universal coverage and a table claiming none. It cannot verify the judgements are correct — that is the impl-review gate's job — but it does catch the most likely failure, which is a mapping padded to look complete.

### TEST-009 / TEST-010 (AC-009, AC-010) — the five surfaces, by literal identifier

Literal-string search per surface: `--dangerously-bypass-hook-trust`, `hooks.state`, the MCP-registration marker, `claude-hooks.json`, and the Claude Code settings/permissions surface. TEST-010 additionally asserts the bypass flag is accompanied by a statement of what an operator forfeits by using it.

`.codex/agents/*.toml` is **not** asserted here: it is already documented (INV-010) and REQ-005 forbids re-documenting it. A test asserting its presence would pass without this feature doing anything, which makes it a vacuous test.

### TEST-011 (AC-011) — regression, both runtimes

`tests/cross-model.tests.sh` and `tests/cross-model.tests.ps1` both pass. The pre-existing absent-CLI and non-zero-exit cases must pass **unmodified**; needing to edit one is evidence BL-001 was broken and must be reported, not accommodated.

All new cases drive a stub CLI placed on `PATH`. No test may invoke a real `codex` or `gemini` binary: a test requiring vendor credentials or a network is not a regression signal, and would make CI failures unattributable.

### TEST-012 (AC-012) — the default is not duplicated

The default asserted by the tests is derived from the runner script itself, not written as a literal `600` in the test. A test carrying its own copy of the constant keeps passing after someone changes the script's default, which converts the test from a guard into a decoration.

## Notes

- Test types follow the repository's own convention: a case that drives a real process through a stub binary on `PATH` is **integration**, not unit, even though it exercises one script. The `epic-136-phase4-mcp` gate recorded a Minor for exactly this mislabelling (`acceptance-tests.md:14` versus `tasks.md:195`), so the tier is stated deliberately here.
- Every `file:line` in this document must be re-verified at implementation start. Citations that were accurate when written and stale when used are a recorded, recurring defect class in this repository (WFI-011).
- TEST-004's 10-second margin is loose on purpose. A tight margin turns an unrelated slow CI runner into a flaky failure, and a flaky guard gets disabled.
