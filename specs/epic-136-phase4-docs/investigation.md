# Investigation: epic-136-phase4-docs

| Field | Value |
|-------|-------|
| Feature | epic-136-phase4-docs (cross-model panelist failure policy & THREAT-MODEL security checklist) |
| Mode | documentation (specification + threat-model gap-fill) |
| Date | 2026-07-31 |
| Investigator | sdd-investigator (read-only codebase survey), with one orchestrator correction marked below |

Source: GitHub issues `#133`, `#134` (Phase 4 documentation tasks within epic `#136`), against branch `feature/epic-136-phase4` @ HEAD. Read-only investigation with `file:line` evidence.

**Persistence note.** `sdd-investigator` is read-only by charter and holds no write tool, so it returned this body and the orchestrating session wrote it to disk. One finding carries an explicit `[ORCHESTRATOR CORRECTION]` block where the orchestrator re-verified a claim and it did not hold as stated; the investigator's original wording is preserved above the correction rather than silently rewritten.

## Scope

1. **#133** — "docs: cross-model パネリスト API 失敗時ポリシー(skip-pass vs block)を明文化"
   - **Concern**: when a panelist CLI (GPT vendor via `codex`, Gemini vendor via `gemini`) fails — timeout, rate limit, network error, CLI crash — is the policy skip-and-pass or block? A hole here would weaken `critical` verification.
   - **Named files**: `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh`, `run-panelist-gemini.sh`, `plugins/sdd-quality-loop/references/cross-model-verification-policy.md`
   - **Acceptance**: failure policy documented; script behaviour matches it.

2. **#134** — "docs(security): THREAT-MODEL.md を作成(OWASP LLM / MCP security checklist 照合)"
   - **Acceptance**: main trust boundaries and mitigations tabulated; checklist cross-reference results recorded.
   - A 2026-07-10 addendum additionally requires Codex runtime surfaces: hook trust (first-run approval, `--dangerously-bypass-hook-trust`), `~/.codex/config.toml` `hooks.state`, the installer's MCP-registration marker block, `.codex/agents/*.toml` (`developer_instructions` required), and on the Claude Code side `hooks/claude-hooks.json` (node exec form) plus settings/permissions.

## Summary

**#133 — the already-solved half and the still-open half.** The non-zero-exit path is fully handled: both runner scripts exit 1 when the vendor CLI is absent or errors (INV-001, INV-002), the PowerShell variants match (INV-003), and the policy document states the fail-closed posture explicitly (INV-005). What is **not** handled anywhere is an indefinitely hung CLI: none of the four runner scripts, the gate, or the orchestrating skill imposes a timeout (INV-001, INV-003, INV-004, INV-006). A hang is therefore neither skip-and-pass nor block — the collection phase simply stalls. The repository's own performance checklist already requires bounded external calls (INV-007), so this is an internal inconsistency, not merely an omission.

**#134 — a gap-fill, not a create.** `docs/THREAT-MODEL.md` already exists (164 lines) and tabulates trust boundaries and mitigations (INV-008), so the issue title's "を作成" is stale. Two acceptance gaps remain: zero OWASP LLM Top 10 / MCP checklist cross-references (INV-009), and five of the six Codex/Claude runtime surfaces the addendum names are absent — only `.codex/agents/*.toml` is covered (INV-010 through INV-016).

## Findings

### Stream A — #133 (panelist runner error & timeout policy)

#### INV-001: `run-panelist-gpt.sh` documents error handling but omits timeout

`plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:13-15`

```
#   - codex CLI absent → exit 1 (non-zero, not exit 2; not a tool error)
#   - codex CLI errors → exit 1 with message to stderr
#   - Scratch dir always cleaned up via trap
```

Two error cases documented: absent CLI, and non-zero exit. No mention of timeout or indefinite hang.

`plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:216-220`

```sh
if ! "$_codex_cmd" --model "$model" --effort "$effort" --no-project-doc < "$_combined" > "$_raw_output" 2>&1; then
    _rc=$?
    printf 'run-panelist-gpt: codex CLI exited %d\n' "$_rc" >&2
    cat "$_raw_output" >&2
    exit 1
fi
```

The `if !` construct detects only a non-zero exit. No subprocess timeout. If the CLI hangs, the script hangs with it.

#### INV-002: `run-panelist-gemini.sh` implements the identical error-only handling

`plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh:137-142` — same shape: error on non-zero exit, no timeout.

#### INV-003: the PowerShell variants also have no timeout

`plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1:184-195` uses `Start-Process … -Wait -PassThru -NoNewWindow` with **no** `-Timeout`/`-TimeoutSeconds`. `-Wait` without a bound blocks indefinitely on a hung process. `run-panelist-gemini.ps1` matches.

#### INV-004: the gate itself does not block — it reads verdict files from disk

`plugins/sdd-quality-loop/scripts/check-cross-model.sh:89-97`

```python
verdict_files = [... if f.startswith(prefix) and f.endswith(suffix)]
if not verdict_files:
    print(f"check-cross-model: no verdict files found matching {prefix}*{suffix} in {verdict_dir}", file=sys.stderr)
    sys.exit(2)
```

The gate neither invokes nor polls panelists. A panelist that hangs and never writes its verdict would, *if the gate were reached*, produce exit 2. **The stall point is upstream**: the orchestrating skill runs panelists and waits. This distinction matters for the fix — a timeout belongs in the runner or its caller, not in the gate.

#### INV-005: the policy document covers absence and error, not hang

`plugins/sdd-quality-loop/references/cross-model-verification-policy.md:202-210`

```
## Absence of Consensus: Fail-Closed Default

If no verdict JSONs are found for the task:
- Exit 1 (fail closed).
- Diversity requirement cannot be met; gate fails.
- Caller opens a review ticket.

This surfaces the silent-degradation failure mode of external fusion panels where a CLI
is absent or fails silently.
```

and `:28-31`

```
If the non-Anthropic vendor's CLI is absent or errors, the gate evaluates only the
collected verdicts but still enforces the diversity minimum. If diversity is unmet
(e.g., all vendors are Anthropic), `check-cross-model` fails and blocks auto-Done
(unless the task is explicitly waived).
```

"Absent or errors" is the non-zero-exit path. A hung CLI produces no verdict and never returns, so the documented reasoning never gets a chance to run.

#### INV-006: the orchestrating skill imposes no bound either

`plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md:98-131`, Step 3 — "Run ALL panelists simultaneously. Do not wait for one before starting another." No per-panelist timeout, no collection-phase timeout.

#### INV-007: the repository's own checklist already requires bounded external calls

`plugins/sdd-quality-loop/references/performance-checklist.md` — "External calls have timeouts and bounded retries (no unbounded fan-out)."

A panelist invocation is an external API call. The checklist requirement and the runner implementation disagree, which makes this an internal inconsistency the repository can be held to, not a matter of taste.

### Stream B — #134 (THREAT-MODEL.md coverage)

#### INV-008: `docs/THREAT-MODEL.md` already exists and covers core controls

164 lines: Trust Assumptions (`:3-17`), Assets Protected (`:20-45`), Controls Table (`:48-65`), Threats & Mitigations (`:69-109`), Residual Risks (`:112-137`), Enforcement by Runtime (`:140-155`), Cross-References (`:158-164`).

**This is a gap-fill task.** The issue title's "を作成" (create) is stale and the specification must not restate it.

#### INV-009: no OWASP LLM Top 10 or MCP checklist cross-reference exists

`grep -cin "owasp\|LLM0\|LLM Top" docs/THREAT-MODEL.md` → **0**. The document does name "External LLMs (GPT / Gemini panelists)" at `:16` and describes mitigations at `:103-109`, but with no external framework alignment.

#### INV-010: `.codex/agents/*.toml` enforcement IS documented

`docs/THREAT-MODEL.md:39-41` (Assets Protected) and `:56` (Controls Table, Agent-role guard row) both cover it, including the `developer_instructions` requirement and the guard that enforces it. This is the one addendum item already satisfied.

#### INV-011 – INV-015: five addendum surfaces are absent

Zero matches in `docs/THREAT-MODEL.md` for each of:

| # | Addendum surface | Search result |
|---|---|---|
| INV-011 | Codex hook trust — first-run approval, `--dangerously-bypass-hook-trust` | absent |
| INV-012 | `~/.codex/config.toml` `hooks.state` | absent |
| INV-013 | installer's MCP-registration marker block in `~/.codex/config.toml` | absent (MCP servers `local-env-mcp` / `sdd-forge-mcp` / `ci-mcp` are not mentioned in the threat model at all) |
| INV-014 | `plugins/sdd-quality-loop/hooks/claude-hooks.json` (node exec form) | absent — the file exists (28 lines, `PreToolUse` matchers invoking `kill-switch.js` and `sdd-hook-guard.js --emit exit`) but the threat model never names it |
| INV-015 | Claude Code settings/permissions model | absent |

#### INV-016: the hook configuration files are not referenced at all

`docs/THREAT-MODEL.md:164` cross-references the hook-guard *implementations* (`sdd-hook-guard.{py,ps1,js}`) but never the configuration files that invoke them (`hooks/hooks.json` for Codex CLI, `hooks/claude-hooks.json` for Claude Code). Both are declared from `.claude-plugin/plugin.json`.

#### INV-017: none of this feature's target files is guard-protected

> **Investigator's original text, preserved:** "No reference to `PROTECTED_GATE_SUFFIXES` in this worktree's active config, so no staging gate applies to any of these files during this investigation."

**[ORCHESTRATOR CORRECTION]** The stated reason is wrong; the conclusion is right. `PROTECTED_GATE_SUFFIXES` very much exists in this worktree, at `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js:5`, with **42 entries**. It was read directly rather than inferred. What matters is that the list does **not** contain any of this feature's targets:

| Target | In PROTECTED_GATE_SUFFIXES? |
|---|---|
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | no |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh` | no |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1` | no |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1` | no |
| `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` | no |
| `plugins/sdd-quality-loop/scripts/check-cross-model.sh` | no |
| `docs/THREAT-MODEL.md` | no |

So no `human-copy` staging round is required for this feature — unlike `epic-136-phase3`, whose `.github/workflows/test.yml` target *is* on the list and forced the draft-then-human-apply pattern.

**Separate hazard, recorded because it cost a command during this investigation:** the guard's *Bash-command* matcher is broader than the write-path suffix list. A purely read-only command whose text merely mentions gate-script paths can be denied. Implementation agents should expect this and restructure the command rather than work around the guard.

## Open Questions

**#133**

1. Does a rate-limited `codex` / `gemini` CLI exit non-zero (→ the handled path of INV-001) or retry/hang (→ the unhandled path of INV-003)? Unresolved from the repository alone; it depends on vendor CLI behaviour that this repository does not control or pin.
2. If a bound is added: what value, and scoped per-panelist or per-collection-phase?
3. Should a timed-out panelist exit 1 (missing verdict → diversity → fail closed, consistent with INV-005) or exit 2 (tool error)? OQ-3 is the load-bearing design decision for #133.
4. Should timeout behaviour be exercised by `tests/cross-model.tests.{sh,ps1}`?

**#134**

1. Which OWASP LLM Top 10 entries does this repository's surface actually touch, and which are genuinely N/A? The mapping must be honest about non-applicability rather than padded.
2. Is there an authoritative MCP security checklist to cite, or must the cross-reference be to primary MCP documentation?
3. Should a residual-risk entry be added for "hung external panelist" — i.e. does #133's finding land in #134's document as well?

## Acceptance Criteria Verification

**#133** — "失敗時ポリシーが文書化 / スクリプト挙動と一致"

- Documented for the absent/error path — INV-001, INV-005.
- Script behaviour matches for that path — INV-001, INV-002, INV-003.
- **Not** documented for the timeout/hang path — INV-003, INV-005, INV-006.
- **Not** implemented for the timeout/hang path — no bound anywhere, contradicting INV-007.

**#134** — "主要信頼境界と対策が一覧化 / チェックリスト照合結果が記載"

- Trust boundaries tabulated — INV-008 (already satisfied).
- Mitigations named per boundary — INV-008 (already satisfied).
- **Checklist cross-reference absent** — INV-009.
- **Five of six addendum runtime surfaces absent** — INV-011 through INV-015; only `.codex/agents/*.toml` is covered (INV-010).
