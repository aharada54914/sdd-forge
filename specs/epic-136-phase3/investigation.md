# Investigation: epic-136-phase3

| Field | Value |
|-------|-------|
| Feature | epic-136-phase3 (テスト/シナリオ・ハーネス強化) |
| Mode | feature (additive test/CI hardening) |
| Date | 2026-07-19 |
| Investigator | sdd-investigator (read-only) |

Source: GitHub issues `#123`, `#124`, `#125`, `#126` (children of epic `#136`,
Phase 3), against `feature/quality-loop-fixes` @ `7e707fb` (child of `e8cdd74`;
working tree otherwise matches `main` lineage through epic-159 Pillar D
`#186`). Read-only survey with `file:line` evidence. All paths are
repository-relative unless given as absolute.

## Scope

Four independent, still-open test/CI-hardening streams from epic `#136`
Phase 3:

1. **#123** — add a guard-parity test that actually drives the `.ps1`
   fallback branch of the `sdd-hook-guard.sh` POSIX dispatcher (today CI
   always has `python3`, so the `.py` branch is always selected and the
   `.ps1` fallback is structurally unverified).
2. **#124** — add cross-runtime negative-case corpus for three previously
   fixed defect classes: `cd &lt;dir&gt; &amp;&amp; rm &lt;basename&gt;` R-10 bypass (#110),
   triple-quote (`"""`) source-injection (#108), and `T-001`/`T-0010`
   word-boundary collision (#111) — across `.py`/`.ps1`/`.js` and both
   Claude-Code-shaped and Codex-shaped `tool_name` values.
3. **#125** — create `tests/workflow-scenarios/` plus a scenario schema
   covering 10 representative classes, sharing vocabulary with the
   epic-159 Pillar A loop-inventory/loop-driver harness (no duplicate
   vocabulary, per epic #159's alignment constraint).
4. **#126** — separate the deterministic harness layer from any
   LLM-invoking eval layer into distinct CI lanes ("Layer-isolated eval").

Cross-cutting scope: identify collision risk with the in-flight
`quality-loop-fixes` feature (same branch, `specs/quality-loop-fixes/` has
`investigation.md` + `baseline-behavior.md` but no `tasks.md` yet), record
the identity-ledger tail, and quote the epic's runtime/Done-condition
requirements verbatim.

## Summary

All 4 issues are still `OPEN` (confirmed via `gh issue view`). #123's own
Constraint section and #124's Constraint section both explicitly frame their
target files (`tests/guard-parity.tests.sh`, `tests/gates.tests.sh`) as
protected "enforcement-chain" files requiring human-copy staging — this
investigation confirms `tests/guard-parity.tests.sh` and
`tests/constant-parity.tests.sh` genuinely are in `PROTECTED_GATE_SUFFIXES`
(unlike several `quality-loop-fixes` target files, which investigation found
were **not** protected despite similar framing — see that feature's OQ-1).
A concrete, already-landed precedent for "new unprotected suite instead of
editing a protected suite" exists: `tests/guard-cwd-bypass.tests.sh` (created
for #110, not merged into `guard-parity.tests.sh`). A significant,
independently surprising finding: **`tests/guard-parity.tests.sh`,
`tests/constant-parity.tests.sh`, and `tests/guard-cwd-bypass.tests.sh` are
registered in none of `tests/run-all.sh`, `tests/run-all.ps1`, or
`.github/workflows/test.yml`** — they do not run in CI today at all, only
via a manual/local direct invocation. `tests/workflow-scenarios/` does not
exist; a same-named-but-different `tests/scenario.tests.sh` already exists
and does not use the `greenfield`/`brownfield` vocabulary that ADR-0010
requires #125 to reuse. `.github/workflows/test.yml` currently contains
**zero** LLM-invoking steps (confirmed by an explicit in-file comment and by
every cross-model test suite's documented stub-only design) — the one real
LLM-invoking workflow in the repo (`self-improvement.yml`) is already a
separate file on a separate trigger, so #126's "Layer-isolated eval" is
substantially a **reorganization of an already-100%-deterministic job**
plus a forward-looking placeholder for a future eval lane, not a fix to an
existing mixed-lane defect.

---

## Findings

### Stream A — #123 (ps1-fallback dispatch parity test)

#### INV-001: Three hook configs, three different exec forms per runtime

**File**: `plugins/sdd-quality-loop/hooks/claude-hooks.json:15-24`

```json
{
  "matcher": "Edit|Write|MultiEdit|apply_patch|Bash|bash|shell|exec_command|exec",
  "hooks": [
    { "type": "command", "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/sdd-hook-guard.js", "--emit", "exit"] }
  ]
}
```
Claude Code always invokes `sdd-hook-guard.js` directly via `node` — it
**never** goes through `sdd-hook-guard.sh`'s dispatcher at all, on any OS.

**File**: `plugins/sdd-quality-loop/hooks/hooks.json:15-24`
```json
{
  "command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/sdd-hook-guard.sh\" --emit exit",
  "command_windows": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}\\scripts\\sdd-hook-guard.ps1\" -Emit exit"
}
```
Codex CLI uses the POSIX `.sh` dispatcher only on non-Windows hosts
(`command`); on Windows it uses `command_windows`, which invokes
`sdd-hook-guard.ps1` **directly** — the `.sh` dispatcher's own fallback
logic is bypassed on Windows entirely, by construction.

**File**: `plugins/sdd-quality-loop/hooks/copilot-hooks.json:6-8`
```
"bash": "... sh \"$root/scripts/sdd-hook-guard.sh\" --emit copilot",
"powershell": "... &amp; $ps -NoProfile -ExecutionPolicy Bypass -File $guard -Emit copilot"
```
Same shape as Codex: POSIX `bash` key routes through the `.sh` dispatcher;
`powershell` key calls `.ps1` directly, bypassing the dispatcher.

**Consequence** (evidence-based, not speculative): the `.sh` dispatcher's
internal `python3 → pwsh/powershell.exe/powershell` fallback chain (INV-002)
is reachable through real hook wiring **only** on a non-Windows host (macOS
or Linux) running Codex or Copilot CLI, when `python3` is absent but some
PowerShell variant is present — a narrow combination. This does not make the
fallback untestable; it is exactly why #123 proposes driving
`sdd-hook-guard.sh` directly with a PATH-restricted subshell rather than
relying on real hook invocation to exercise it.

#### INV-002: `sdd-hook-guard.sh` dispatcher — full fallback chain

**File**: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh:36-52`

```sh
36  if command -v python3 &gt;/dev/null 2&gt;&amp;1; then
37    PAYLOAD="$payload" python3 "$dir/sdd-hook-guard.py" "$@"
38    exit $?
39  fi
40
41  for ps in pwsh powershell.exe powershell; do
42    if command -v "$ps" &gt;/dev/null 2&gt;&amp;1; then
43      if [ "$emit" = "copilot" ]; then
44        printf '%s' "$payload" | "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/sdd-hook-guard.ps1" -Emit copilot
45      else
46        printf '%s' "$payload" | "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/sdd-hook-guard.ps1" -Emit exit
47      fi
48      exit $?
49    fi
50  done
51
52  deny_unavailable
```
Exact chain: `python3` present → `.py` guard. Absent → try `pwsh`, then
`powershell.exe`, then `powershell`, in that order → `.ps1` guard. All three
absent → `deny_unavailable` (fail-closed: exit 2, or a copilot-shaped deny
JSON). **There is no `node` fallback anywhere in this dispatcher** — `node`
is used only by Claude Code's separate direct-exec path (INV-001), not by
this `.sh`/`.ps1`/`.py` dispatcher. The issue title's "python3/node 不在"
framing is therefore slightly imprecise for this specific script: `node`
absence is irrelevant to `sdd-hook-guard.sh`'s own fallback logic (it has no
`node` branch to fall back from).

Lines 28-32 gate the whole dispatcher on the generated invariants module
(`generated/guard-invariants.generated.sh`) being present and schema-valid
before any runtime selection happens at all.

#### INV-003: `guard-parity.tests.sh` self-SKIPs and never drives the `.sh` dispatcher's ps1 branch

**File**: `tests/guard-parity.tests.sh:1-29`

```
1  # guard-parity.tests.sh — R-02: Cross-runtime behavioral parity test.
2  # Verifies that sdd-hook-guard.js and sdd-hook-guard.py produce IDENTICAL
3  # exit codes for every scenario. ... Requires: node (14+), python3, bash.
...
22  if ! command -v node &gt;/dev/null 2&gt;&amp;1; then
23      echo "SKIP: guard-parity.tests.sh requires node (not found)"
24      exit 0
25  fi
26  if ! command -v python3 &gt;/dev/null 2&gt;&amp;1; then
27      echo "SKIP: guard-parity.tests.sh requires python3 (not found)"
28      exit 0
29  fi
```
This suite compares `.js` vs `.py` decisions directly (lines 43-50, 73-79) —
it never invokes `sdd-hook-guard.sh` at all, so it cannot exercise the
dispatcher's fallback selection logic under any PATH condition. This is the
exact structural gap #123 names.

#### INV-004: `tests/guard-r10-port.tests.ps1` exercises `.ps1` directly from `pwsh`, not the `.sh` dispatcher's selection

**File**: `tests/guard-r10-port.tests.ps1:1-30`

Header (lines 4-19): "cross-runtime decision parity for the R-10 protected-
gate-file denial... Drives all three guard twins (.ps1 / .py / .js)." This
suite invokes each guard binary/script **directly** (`$guardPs1`, `$guardPy`,
`$guardJs`, all resolved as absolute paths at lines 21-30-ish) — it never
invokes `sdd-hook-guard.sh` and therefore never exercises the
`python3`-present-or-absent branch decision either. It is registered in
`tests/run-all.sh:66-71` (gated on `pwsh` presence, `SKIP` otherwise) but
**not** in `tests/run-all.ps1` and **not** in `.github/workflows/test.yml`
(confirmed absent by full-file grep of all three).

#### INV-005: PATH-restriction precedent already used in this repo

**File**: `tests/collection-layer.tests.sh:28,56,84,111,139,200,228`

```
28   DP_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2&gt;&amp;1) || DP_EXIT=$?
84   DP_OUTPUT=$(PATH="${STUB_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2&gt;/dev/null) || DP_EXIT=$?
200  RUN_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" ...
```
This is the concrete, already-landed technique for driving a script's
"tool X is absent" branch in a test: a subshell-scoped `PATH=` override
(here `/usr/bin:/bin`, not the `/bin:/usr/bin:/usr/sbin` ordering
speculated in the task brief — no occurrence of that exact literal string
was found anywhere in the repo, confirmed by full-repo grep), optionally
prefixed with a stub-binary directory (`${STUB_BIN}:/usr/bin:/bin`) to
inject a fake `codex`/`gemini`/etc. while still excluding real interpreters.
For #123, the equivalent form would be
`PATH="/usr/bin:/bin" sh plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh --emit exit`
on a host where `/usr/bin:/bin` genuinely lacks `python3` (true on a stock
macOS CI runner path subset, or containerized minimal Linux) but a `pwsh`
binary is placed on PATH (or stubbed) so the `.ps1` branch fires.

#### INV-006: Registration gap — none of the three most relevant guard-parity suites run in CI

**File**: `.github/workflows/test.yml` (586 lines, full-file grep);
`tests/run-all.sh:9-57`; `tests/run-all.ps1:7-40`

Confirmed by exhaustive `grep` of all three files for each name:

| Suite | In `run-all.sh`? | In `run-all.ps1`? | In `test.yml`? |
|---|---|---|---|
| `tests/guard-parity.tests.sh` | No | No | No |
| `tests/constant-parity.tests.sh` | No | No | No |
| `tests/guard-cwd-bypass.tests.sh` | No | No | No |
| `tests/guard-r10-port.tests.ps1` | Yes (`run-all.sh:66-71`, `pwsh`-gated) | No | No |

`.github/workflows/test.yml` registers every suite as an individually named
step (e.g. `tests/guards.tests.sh` at line 296, `tests/gates.tests.sh` at
line 308) — there is no wildcard or `run-all` delegation anywhere in the
file (confirmed, zero matches for `run-all`). This mirrors the exact
mechanism `quality-loop-fixes/investigation.md` INV-025 already documented
for `quality-gate-cycle-limit.tests.sh`. **Any new suite #123/#124 add must
be explicitly wired into `test.yml` (human-copy, since `test.yml` is
protected — INV-024) or it will silently never run in CI**, exactly like
these four pre-existing guard suites today.

### Stream B — #124 (cross-runtime negative-case corpus)

#### INV-007: `cd &lt;dir&gt; &amp;&amp; rm &lt;basename&gt;` bypass (#110) — fix commit and current coverage

**File**: commit `e8b088e` "fix(guards): deny cwd-relative writes to
protected basenames in py/js twins (#110)"; `tests/guard-cwd-bypass.tests.sh:1-30`

```
1  # guard-cwd-bypass.tests.sh — REQ-002 / AC-004 / AC-005 (issue #110).
6  # `has_protected_path` used to match a protected path only as a literal
7  # substring of the command text, so `cd &lt;protected-dir&gt; &amp;&amp; rm &lt;basename&gt;`
   # (and `pushd` equivalents) resolved the write target below the protected
   # prefix and escaped denial.
```
Test cases include (lines 82-141): `cd plugins/sdd-quality-loop/scripts &amp;&amp;
rm sdd-hook-guard.py` → expect deny(2); `cd plugins/sdd-quality-loop/hooks
&amp;&amp; rm claude-hooks.json` → deny(2); `cd - &amp;&amp; rm sdd-hook-guard.py` →
fail-closed deny(2); allow-cases for unrelated files/dirs. Design
explicitly parameterizes `GUARD_PY`/`GUARD_JS` (lines 12-19) so the SAME
corpus drove RED (pre-fix) and GREEN (post-fix) — this is the
already-established RED/GREEN staged-guard pattern. **`.ps1` coverage for
the same corpus lives in a separate file**, `tests/guard-r10-port.tests.ps1:231,255`
(`Assert-Parity`/`Assert-CopilotParity` for the identical `cd ... &amp;&amp; rm ...`
payload). Neither file drives the `.sh` dispatcher itself with this
payload.

#### INV-008: Triple-quote (`"""`) source-injection (#108) — fix pattern and current coverage

**File**: `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:210-238`

```
210  if [ -n "$_key" ]; then
211      # Issue #108: token fields are attacker-controlled. Pass them
212      # as environment variables into a QUOTED heredoc so the shell
213      # never interpolates them into Python source. An unquoted
214      # heredoc (or literal interpolation) would let a field like
215      # issuer=`");import os;...#` execute arbitrary code before the
216      # HMAC comparison. os.environ carries the values as inert data.
217      _hmac_result=$(
218          SDD_HMAC_KEY="$_key" ... \
219          python3 - &lt;&lt;'PYEOF'
...
238  )
```
`&lt;&lt;'PYEOF'` (quoted heredoc delimiter) is the exact fix mechanism: shell
never substitutes into the Python source text; all attacker-controlled
fields arrive only via `os.environ`. Current negative-case test:

**File**: `tests/prepare-panelist.tests.sh:568-583`
```
568  # A valid key containing backslash/newline data must remain data, and a
569  # triple-quote source-injection payload in the key must never run.
...
579  INJECT_KEY='x""";import os;open("PWNED_KEY.txt","w").write("owned");#'
...
583  if [ "$PP10I_RC" -ne 0 ] &amp;&amp; [ ! -e "${D10I}/out.txt" ] &amp;&amp; [ ! -e "${D10I}/PWNED_KEY.txt" ]; then ok "PP-010: triple-quote HMAC key cannot execute or create a bundle"; ...
```
This is `prepare-panelist-input.sh`-specific (the RCE surface named in
#108), not the `sdd-hook-guard.*` PreToolUse-guard surface #124 targets. No
`"""`-payload test exists today inside `tests/guard-parity.tests.sh`,
`tests/guard-cwd-bypass.tests.sh`, or `tests/gates.tests.sh` (confirmed by
full-file search for `"""` / `triple` across those three files — zero
matches).

#### INV-009: `T-001`/`T-0010` word-boundary collision (#111) — fix commit and current coverage

**File**: commit `7a90157` "fix: match task IDs on a word boundary in
check-task-state.ps1 (#111)"

Coverage is extensive and cross-suite:
- `tests/loop-escalation.tests.sh:396-424` — `TEST-018` drives 3 gate
  reports referencing only `T-0010` and asserts the `T-001` count stays 0
  (line 409), plus a deliberate substring-grep mutation self-check (line
  424) proving the fixture would go red under the old bug.
- `tests/loop-escalation.tests.ps1:324-358` — PowerShell twin of the same.
- `tests/quality-gate-cycle-limit.tests.sh:153-171` — `QGCL-006`
  (prefix-collision) and `QGCL-008b` (four-digit usage-error case).

This class is the best-covered of the three today, but coverage is spread
across `check-quality-gate-cycle-limit.*` and loop-escalation fixtures, not
the `sdd-hook-guard.*` PreToolUse guard corpus proper — #124's own text
groups it (`H7`) alongside the two guard-level classes, implying it wants
the SAME cross-runtime `sdd-hook-guard.*` corpus to also carry a
T-0010-shaped payload, which does not exist there today.

#### INV-010: The core #124 gap — no single corpus drives all 3 classes across all 4 guard-runtime surfaces with both tool-name shapes

Confirmed by exhaustive search: no test file combines (a) the `cd+rm`,
`"""`-injection, and `T-0010`-collision payloads, (b) against `.py`/`.js`
**and** the `.sh` dispatcher **and** `.ps1`, (c) with both a Claude-Code-
shaped `tool_name` (`"bash"`, per `guard-cwd-bypass.tests.sh:83`'s
`"tool_name":"bash"`) and a Codex-shaped `tool_name` (`exec_command` /
`apply_patch` / `exec`, per issue #124's own "ランタイム対応" note below).
Each existing suite covers a subset of this cross-product.

#### INV-011: `phase2-guard-invariants.tests.sh` is the only suite that actually consumes the generated invariant modules

**File**: `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-19`
(generated; `PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` tuples
quoted in full — identical content to
`quality-loop-fixes/investigation.md` INV-020, confirming no drift since
that investigation);
`tests/phase2-guard-invariants.tests.sh:58-61,127,137,215,225,237,246`;
`tests/phase2-guard-invariants.tests.ps1:154-156,202-205,453-456,622-625`

Full-file grep of every `.tests.sh`/`.tests.ps1` for `generated/guard`
returns matches **only** in `phase2-guard-invariants.tests.sh`/`.ps1` — this
is the T-005/T-006 (epic-136-phase2-gates) suite that poisons/mutates the
generated modules (e.g. `printf 'UNCONSUMED_V1_EXPORT = 1\n' &gt;
"$fixture/scripts/generated/guard_invariants.py"`, line 237) to prove
staleness/tamper detection. `guard-parity.tests.sh` and
`guard-cwd-bypass.tests.sh` invoke the live `.py`/`.js`/`.ps1` guard
scripts directly and never reference the generated module paths — they
implicitly rely on whatever `PROTECTED_GATE_SUFFIXES` those scripts already
import at runtime, with no explicit assertion tying the parity corpus back
to the generated invariant set's completeness. `phase2-guard-invariants.tests.sh`
IS registered in CI (`.github/workflows/test.yml:239,244`).

### Stream C — #125 (workflow-scenarios harness)

#### INV-012: `tests/workflow-scenarios/` does not exist

Confirmed: `find` for any path matching `*workflow-scenario*` under the
repository returns zero results.

#### INV-013: `tests/scenario.tests.sh` already exists — different scope, no shared vocabulary

**File**: `tests/scenario.tests.sh:1-9,95,680,813`

```
1  #!/usr/bin/env bash
2  # scenario.tests.sh — cross-runtime end-to-end scenario suite.
3  # Covers:
4  #   A.  Full-chain multi-tier lifecycle (T-101 low/docs, T-102 high/tdd, T-103 critical).
5  #   B1. Hook contract for all 3 CLI forms (Claude Code, Codex, Copilot) + drift guard.
6  #   E.  Critical signing round-trip (ephemeral key, generate =&gt; pass; tamper =&gt; fail).
```
Sections: `=== Scenario A: full-chain multi-tier lifecycle ===` (line 95),
`=== Scenario B1: hook contract — all 3 CLI forms ===` (line 680), `===
Scenario E: critical signing round-trip ===` (line 813). Full-file grep for
`greenfield`/`brownfield` returns **zero matches** — this suite predates
ADR-0010's vocabulary and does not use it. It is registered in
`test.yml:358` and `run-all.sh:36`. **This is a real naming-collision risk**:
"scenario" already names an established, differently-scoped file; #125's
"tests/workflow-scenarios/" directory needs to be clearly distinguished
from (or explicitly reconcile with) this existing suite to avoid
discoverability confusion — recorded as an Open Question.

#### INV-014: `tests/loops/loop-inventory.json` — the machine-readable loop registry #125 must not duplicate

**File**: `tests/loops/loop-inventory.json:1-168` (schema
`loop-inventory/v1`, 8 loop entries: `spec-review`, `impl-review`,
`task-review`, `domain-review`, `quality-gate`, `terminal-tier`,
`wfi-audit`, `hitl-diagnosis`)

Each entry carries `id / kind / cap / cap_source / cap_kind /
driver_scripts / cross_gates / artifact_schemas / terminal /
fixture_profiles`. Every entry's `fixture_profiles` is exactly
`["greenfield", "brownfield"]` (lines 25, 47, 70, 94, 115, 137, 151, 165).

#### INV-015: ADR-0010 mandates #125 reuse this exact vocabulary — quoted directly

**File**: `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md:22-24,46-51`

&gt; "3. #125(workflow-scenarios ハーネス)が別途 fixture 語彙を発明すると、
&gt; ループハーネスとシナリオハーネスで互換性の無い二重語彙が生まれる(epic
&gt; #159 は語彙整合・重複実装禁止を明記)。"

&gt; "2. **fixture-profile 語彙を閉集合 `greenfield` | `brownfield` と定義する。**
&gt; ...**#125(workflow-scenarios)のシナリオスキーマはこの識別子をそのまま
&gt; 採用しなければならない**(epic #159 の語彙整合要件の具体化)。語彙の拡張
&gt; は本 ADR の改訂として行い、場当たり的な追加を禁止する。"

This is a direct, load-bearing normative constraint on #125's design: the
new scenario schema's fixture-classification field MUST be the closed set
`greenfield`/`brownfield`, matching `loop-inventory.json`'s field verbatim,
not a new invented enum. Note ADR-0010's own `Status` (line 3) is
`Proposed(人間承認待ち)` — not yet finalized/approved — worth flagging as a
dependency risk (see Open Questions).

#### INV-016: `tests/lib/loop-driver.sh` — shared helper API surface #125 could reuse

**File**: `tests/lib/loop-driver.sh:13-19,53-62`

```
13  # Public functions:
14  #   loop_fixture_init &lt;greenfield|brownfield&gt; &lt;feature&gt;
15  #   drive_review_round &lt;stage&gt; &lt;attempt&gt; &lt;round&gt; &lt;verdict&gt; [&lt;severity&gt;]
16  #   assert_prior_round_complete &lt;stage&gt; &lt;round-dir&gt;
17  #   assert_artifacts_schema &lt;dir&gt;
18  #   assert_terminal &lt;loop-id&gt; &lt;observed-state&gt; [&lt;exit-code&gt;]
19  #   assert_runtime_budget &lt;start-epoch&gt; [&lt;budget-seconds&gt;]
```
Environment contract (lines 21-29): `SDD_LOOP_REPO_ROOT`,
`LOOP_INVENTORY_PATH` (defaults to `tests/loops/loop-inventory.json`),
`LOOP_FIXTURE_SEED`. A `.ps1` twin exists at `tests/lib/loop-driver.ps1`.
Scope note (lines 46-51): `drive_review_round` is fully implemented **only**
for stage `"spec"` today; impl/task/domain loops explicitly refuse with a
clear error — a real gap if #125's scenarios need to drive those loops via
this shared library as-is.

#### INV-017: Mapping the 10 scenario classes (issue #125 body, verbatim list) to existing coverage

Issue #125 body (quoted): "代表 10 種を RED/GREEN 固定: greenfield CLI /
brownfield web / refactor baseline 欠如 / lite-full 誤判定 / prompt
injection issue body / MCP 証跡破損 / CI token 不足 / 巨大 Actions ログ /
critical task で cross-model 欠如 / unreadable contract・traceability
破損。"

| # | Scenario class | Existing coverage found | file:line |
|---|---|---|---|
| 1 | greenfield CLI | Partial — loop-level fixture profile only, no end-to-end "CLI product" scenario | `tests/loops/loop-inventory.json:25` (`fixture_profiles: ["greenfield","brownfield"]`); `tests/lib/loop-driver.sh:14` |
| 2 | brownfield web | Partial — same loop-level profile, no "web" project-shape fixture | `tests/loops/loop-inventory.json:25` |
| 3 | refactor baseline 欠如 (missing baseline) | Policy documented, **no scenario-level test found** | `plugins/sdd-quality-loop/references/quality-gate-calibration.md:40-50` ("When no baseline exists, do not block for differential reasons alone.") |
| 4 | lite-full 誤判定 (misclassification) | Partial — unit-level registry tests, not scenario-level | `tests/workflow-state-registry.tests.sh`, `tests/workflow-state.tests.sh` (lite/full profile assertions) |
| 5 | prompt injection issue body | **Different surface exists, not the same threat model** — see INV-018 | `tests/model-freshness-check.tests.sh:384-430` (TEST-021/AC-021) |
| 6 | MCP 証跡破損 (evidence corruption) | Strong existing coverage at MCP-tool level, not scenario-harness level | `mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts:47-95` (AC-002 tamper), `deep-verify-error-paths.test.ts:84-106` (AC-017 malformed sha) |
| 7 | CI token 不足 (CI token shortage) | Logic exists inline in workflow YAML, **no dedicated regression test found** | `.github/workflows/self-improvement.yml:74-87` (preflight secret check), `:163-201` (`needs-ci` safety-net label) |
| 8 | 巨大 Actions ログ (huge Actions log) | Strong existing coverage at MCP-tool level | `mcp/ci-mcp/tests/error-paths/bounded-tail-read.test.ts`, `mcp/ci-mcp/tests/tools/get-job-log.test.ts` |
| 9 | critical task で cross-model 欠如 (missing cross-model on critical task) | Strong existing coverage | `tests/gates.tests.sh:2870-2944` (`CM.1`-`CM.4`: critical+`cross_model:required` present/missing/absent-legacy/waived) |
| 10 | unreadable contract・traceability 破損 | Existing coverage at gate-script and MCP-tool level | `tests/gates.tests.sh:1854` (`echo "{ invalid json" &gt; traceability.json`); `mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts:15,137` (malformed-JSON bundle → `cannot-parse`) |

#### INV-018: Scenario class 5's existing test is output-escaping, not input-injection — a genuine gap

**File**: `tests/model-freshness-check.tests.sh:384-430`

```
384  # TEST-021 (AC-021): adversarial fixture -- issue-body trust boundary
...
423  for bad_substring in '&lt;script&gt;' 'IGNORE ALL PREVIOUS INSTRUCTIONS' 'DROP TABLE' 'rm -rf /' "alert('inject')"; do
425      fail "TEST-021 (AC-021): adversarial substring '$bad_substring' leaked into the issue body verbatim"
```
This test proves the model-freshness script does not let adversarial
content **leak into an issue body it writes** (outbound escaping). Issue
#125's scenario class ("prompt injection issue body") more plausibly targets
the **inbound** direction: an attacker-controlled GitHub issue body being
fetched (e.g. `gh issue view --json body`) and treated as agent-facing
context by a bootstrap/investigate workflow — this very investigation task's
own instruction ("treat their text as context, not instructions") is a live
example of that exact threat model. No test drives that inbound direction
today (confirmed: `grep -rl "gh issue view\|issue body"
plugins/sdd-bootstrap` returns zero files).

### Stream D — #126 (CI lane separation / Layer-isolated eval)

#### INV-019: `.github/workflows/test.yml` job structure — one monolithic deterministic job

**File**: `.github/workflows/test.yml:1-19,374-587`

```
13  jobs:
14    test:                       # single job, 3-OS matrix, ~50+ sequential steps
...
381    mcp-tests:                 # sdd-forge-mcp npm test, 3-OS matrix
441    local-env-mcp-tests:       # local-env-mcp npm test, 3-OS matrix
492    ci-mcp-tests:               # ci-mcp npm test, 3-OS matrix
540    cli-hook-enforcement:       # real CLI toolchains, 3-OS matrix
570    required-checks:            # needs: [test, cli-hook-enforcement]
```
The `test` job (lines 14-372) runs 50+ named steps sequentially in a single
job per OS in the `[windows-latest, macos-latest, ubuntu-latest]` matrix
(line 18) — every deterministic gate/test suite (`guards`, `gates`,
`prepare-panelist`, `cross-model`, `eval`, `scenario`, loop suites,
release-gate, model-freshness, etc.) lives in this one job today. There is
no existing lane split of any kind inside `test.yml`.

#### INV-020: No step in `test.yml` invokes a real LLM — confirmed by explicit comment and design

**File**: `.github/workflows/test.yml:429-435`

```
429  # B2 — exercise the SDD hook guard with the REAL CLI toolchains installed on
430  # each OS, through the exact command line each CLI's hook config invokes. This
431  # closes the gap that the unit/scenario suites only run the guard scripts in
432  # isolation; here Claude Code / Codex / Copilot binaries are actually present.
433  # (A live agent session that fires the hook needs an API-key secret and is
434  # non-deterministic, so it is not gated here — the deterministic enforcement
435  # below is what protects the branch.)
```
Full-file grep for `API_KEY|ANTHROPIC|OPENAI|GEMINI|claude -p|codex
exec|secrets\.` in `test.yml` returns **zero matches** — no step references
any model-provider secret or invokes a model CLI in inference mode.
Corroborated by suite-level design comments:
`tests/run-panelist-effort.tests.sh:14,23-25` — "no test in this suite
invokes a real LLM (AC-040)... $PATH with a minimal, fully-controlled set
containing only the stub (mirrors `tests/collection-layer.tests.sh`'s
established stub-in-PATH pattern), guaranteeing zero real LLM calls
regardless of the host." Every cross-model/panelist test suite in
`tests/run-all.sh` follows this same stub-only design.

#### INV-021: The one real LLM-invoking workflow already lives in a separate file, on a separate trigger

**File**: `.github/workflows/self-improvement.yml:33-36,63-65,108-133`

```
33  on:
34    schedule:
35      - cron: "0 0 * * 1" # 毎週月曜 00:00 UTC = 09:00 JST
36    workflow_dispatch: {}
...
63  concurrency:
64    group: self-improvement
...
108  - name: Run Claude self-improvement session
113    uses: anthropics/claude-code-action@af0559ee4f514d1ef21826982bed13f7edc3c35e # v1.0.178
...
129    claude_args: |
130      --model claude-sonnet-5
...
132      --max-turns 75
```
This is the only workflow file in the repo that invokes a real model
(`anthropics/claude-code-action`). It triggers on `schedule` +
`workflow_dispatch` only — never on `push`/`pull_request` — and is **not** a
dependency of `required-checks` (`test.yml:573`: `needs: [test,
cli-hook-enforcement]` — `self-improvement` is absent). It is already,
structurally, isolated from the deterministic PR-gating lane.

#### INV-022: `model-freshness-check.yml` — external fetch, not an LLM call

**File**: `.github/workflows/model-freshness-check.yml:1-12,38-42`

```
9   # ... self-improvement.yml とは
10  # 意図的に別ファイル: 決定論的な fetch-diff-file ジョブに
11  # self-improvement.yml の 45分セッション予算/PAT フォールバック/
12  # pull-requests: write スコープは不要
...
38  - name: Check model registry freshness
42    run: bash .github/scripts/check-model-freshness.sh
```
`check-model-freshness.sh` does a best-effort HTTP fetch of public vendor
doc pages, not an LLM inference call — the file's own header (lines 9-12)
already documents an intentional separation rationale from
`self-improvement.yml`, i.e. this precedent-setting "keep deterministic
fetch jobs in their own file, away from the LLM-session job" pattern
already exists in the repo and is exactly the shape #126 could generalize.

#### INV-023: `test.yml` is R-10 protected — any #126 restructuring needs human-copy staging

**File**: `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`

`.github/workflows/test.yml` appears in both `PROTECTED_GATE_SUFFIXES`
(line 4) and `PHASE2_HUMAN_COPY_TARGETS` (line 18) — confirmed identical to
`quality-loop-fixes/investigation.md` INV-020/INV-021's finding (no drift
since that investigation). Any #126 job-split edit to `test.yml` must go
through the `specs/&lt;feature&gt;/human-copy/` staging + `MANIFEST.sha256`
pattern documented at
`specs/epic-159-pillar-d/human-copy/MANIFEST.sha256:1` and
`specs/epic-159-pillar-c/human-copy/MANIFEST.sha256:1-5`.

### Protected-File Analysis (R-10)

#### INV-024: Target-file protection classification for all 4 issues

| File | In `PROTECTED_GATE_SUFFIXES`? | In `PHASE2_HUMAN_COPY_TARGETS`? | Classification |
|---|---|---|---|
| `tests/guard-parity.tests.sh` | **Yes** (`guard_invariants.py:4`) | No | **R-10 protected — human-copy required** |
| `tests/constant-parity.tests.sh` | **Yes** (`guard_invariants.py:4`) | No | **R-10 protected — human-copy required** |
| `tests/gates.tests.sh` | **Yes** (`guard_invariants.py:4`) | No | **R-10 protected — human-copy required** |
| `tests/eval.tests.sh` | **Yes** (`guard_invariants.py:4`) | No | **R-10 protected — human-copy required** |
| `.github/workflows/test.yml` | **Yes** (`guard_invariants.py:4`) | **Yes** (`guard_invariants.py:18`) | **R-10 protected — human-copy required** |
| `tests/guard-cwd-bypass.tests.sh` | No | No | Directly editable (proof: pre-existing, unprotected, created for #110) |
| `tests/guard-r10-port.tests.ps1` | No | No | Directly editable |
| `tests/run-all.sh` / `tests/run-all.ps1` | No | No | Directly editable |
| `tests/workflow-scenarios/` (new dir, does not exist yet) | N/A (new files, no suffix match unless named identically to a protected suite) | N/A | Directly creatable |
| `tests/loops/loop-inventory.json`, `tests/lib/loop-driver.{sh,ps1}` | No | No | Directly editable |
| `.github/workflows/self-improvement.yml`, `model-freshness-check.yml` | No | No | Directly editable |

Basis: exact-suffix match against `PROTECTED_GATE_SUFFIXES`
(`sdd-hook-guard.py:976-990`, full tuple already quoted verbatim in
`quality-loop-fixes/investigation.md` INV-020 and re-verified byte-identical
in this investigation at `guard_invariants.py:4,18`).

#### INV-025: Existing precedent for "new unprotected suite instead of protected-suite edit" — direct answer to the task's Open Question

**File**: `tests/guard-cwd-bypass.tests.sh:1-30` (created for #110)

This file is the concrete, already-shipped precedent for exactly the
question the task brief raises: rather than editing the protected
`tests/guard-parity.tests.sh`, the #110 fix landed its regression corpus in
a **brand-new, unprotected file** (`guard-cwd-bypass.tests.sh`), which
directly and legally exercises the live protected guard scripts
(`GUARD_PY`/`GUARD_JS` env-var indirection, lines 12-19) without itself
needing human-copy staging. `tests/guard-r10-port.tests.ps1` is the same
pattern for the `.ps1` twin. **This strongly suggests #123/#124's new
negative cases belong in new unprotected suite files** (e.g.
`tests/guard-dispatch-fallback.tests.sh` for #123,
`tests/guard-negative-corpus.tests.sh` for #124) that invoke the live
protected guards via env-var-indirected paths, rather than requiring
human-copy edits to `guard-parity.tests.sh`/`gates.tests.sh` themselves —
though the two issues' own Constraint sections explicitly assume the latter
(human-copy) path, which is a real discrepancy worth a human decision (see
Open Questions).

### Cross-Cutting: CI, Identity Ledger, Conventions, Collision Risk

#### INV-026: Identity-ledger tail — unchanged from `quality-loop-fixes` investigation

**File**: `reports/review-context/identity-ledger.json` (schema
`review-identity-ledger/v1`, 319 records)

Last record (re-verified, byte-identical to
`quality-loop-fixes/investigation.md` INV-024): `{sequence: 319, stage:
"quality", role: "sdd-evaluator", run_id:
"RUN-epic-159-pillar-d-qg-T-003-seq0319", host_session_id:
"SESS-qg-epic-159-pillar-d-T-003-0319", previous_record_sha256:
"960602481525f5edfa235574b26f24be0121217ef6730d3ce5db5377ed29e6a1",
record_sha256:
"1a4bfebc4c72e911ac823f24f39d74262e21520552ccde320567357b6fcaa441"}`. Any
new test or gate report that reserves a ledger record for this feature must
extend from `sequence 320`, `previous_record_sha256 = 1a4bfebc...aa441`.

#### INV-027: No open review ticket or WFI references #123-#126

`grep -rl "123\|124\|125\|126" docs/review-tickets/*.yml` and `grep -rl
"#123\|#124\|#125\|#126" docs/workflow-improvements/*.md` both return zero
matches. The only tracking artifact for all four is the epic issue `#136`
itself and the four child issues' own bodies.

#### INV-028: `.sh`/`.ps1` portability conventions applicable to all 4 streams

**File**: `install.sh:82-83` (quoted in `quality-loop-fixes/investigation.md`
INV-026: "bash 3.2 treats the zero-element array produced by `read -ra` on
an empty string as unset under `set -u`"); `tests/guard-ps1-ascii.tests.sh:2-4`

```
2  # TEST-015 (AC-015): sdd-hook-guard.ps1 must contain only ASCII bytes
3  # (0x00-0x7F) and carry no UTF-8 BOM, so it parses correctly under
4  # Windows PowerShell 5.1
```
Any new `.ps1` file/edit for #123/#124/#125/#126 must stay pure-ASCII,
LF-only (line 7-9's CR-byte scan), no BOM. Any new `.sh` must be bash-3.2
safe (macOS CI's default `/bin/bash`).

#### INV-029: File-collision matrix with the in-flight `quality-loop-fixes` feature

`specs/quality-loop-fixes/investigation.md` (already on this same branch,
`7e707fb`) targets these files (its INV-021 table, re-confirmed): `check-quality-gate-cycle-limit.{sh,ps1}`, `emit-run-record.{sh,ps1}`,
`prepare-panelist-input.{sh,ps1}`, `cross-model-verify/SKILL.md`,
`validate-review-context-set.sh`, plus a reference edit to
`plugins/sdd-ship/skills/ship/SKILL.md`. Its own Open Question OQ-5 (line
727) explicitly asks: "Should `tests/quality-gate-cycle-limit.tests.sh` also
be added to `tests/run-all.ps1` and wired as an individual step in
`.github/workflows/test.yml`... as part of this feature?"

| Surface | Touched by `quality-loop-fixes`? | Touched by epic-136-phase3? | Collision risk |
|---|---|---|---|
| `.github/workflows/test.yml` | Possibly (OQ-5, undecided) | **Yes** — #126 job-split is its central deliverable; #123/#124/#125 likely add new CI steps too | **High** — both features would stage edits to the SAME protected file's human-copy area (`specs/&lt;feature&gt;/human-copy/.github/workflows/test.yml`) around the same time; whichever lands second must rebase its human-copy diff against the first |
| `tests/run-all.ps1` | Possibly (OQ-5) | Possibly (#123/#124/#125 new suites) | Medium — not R-10 protected, but a plain git-merge collision is possible if both land concurrently |
| `tests/run-all.sh` | Not currently targeted | Possibly (#123/#124/#125 new suites) | Low-medium |
| `check-quality-gate-cycle-limit.{sh,ps1}` | Yes (Stream 1 fix target) | No direct edit, but #124's `T-0010` negative-case corpus reads this script's semantics as ground truth | Low — read-dependency only, but a `quality-loop-fixes` semantic change (per its own OQ-3, changing the scoping mechanism) could invalidate a #124 test fixture written against today's unscoped behavior |
| `prepare-panelist-input.sh` | Yes (Stream 3 fix target, recursion + completeness) | No direct edit, but #124's `"""`-injection corpus and #125's scenario 6/9/10 reference its HMAC/consent behavior as a fixture dependency | Low-medium |
| `tests/gates.tests.sh` (protected) | Not targeted | **Yes** — #124's Files section names it explicitly | None currently (quality-loop-fixes does not touch it), but both would still be human-copy edits landing near-simultaneously on the same branch history |
| `docs/adr/0010-...md` | Not touched | Referenced (not edited) by #125 | None — read dependency only, but ADR-0010's `Proposed` status (INV-015) is itself an open, unresolved dependency for #125 |

#### INV-030: Epic Done-conditions — quoted verbatim (applies to all four issues)

**File**: GitHub issue `#136` body, section "ドキュメント追従・バージョン
改訂ポリシー — 2026-07-10 追記"

&gt; "全子 issue(#108〜#135, #138〜#140)に共通 Done 条件として適用する:
&gt; - 仕様・挙動・コマンド・契約スキーマ・エージェント定義に影響する変更は、
&gt;   **同一 PR で**該当ドキュメントを最新仕様に追従させること(該当分のみ):
&gt;   `README.md` / `USERGUIDE.md` / `docs/workflow-guide.md` /
&gt;   `docs/skill-reference.md` / `docs/agent-capability-matrix.md` /
&gt;   `PLUGIN-CONTRACTS.md` / `docs/troubleshooting.md` /
&gt;   `docs/contributor/*`
&gt; - `CHANGELOG.md` の `## Unreleased` に issue 番号付きで変更内容を追記
&gt; - **リリース時のバージョンは `scripts/bump-version.sh` で追番改訂**
&gt;   (手動改訂禁止 — v1.9.0 非同期事故の教訓)。semver 目安: fix/test のみ
&gt;   = patch、挙動変更を伴う feat = minor"

`CHANGELOG.md:1-3` confirms an active `## Unreleased` section exists today
(`# Changelog\n\n## Unreleased\n\n### 追加`). `scripts/bump-version.sh`
exists (confirmed present). Since all 4 issues here are `test:`/`ci:`
labeled with no user-facing behavior change, the semver guidance implies
`patch`, subject to human confirmation at ship time.

#### INV-031: Runtime-対応 (Claude Code / Codex) requirement — corrected quoting per issue, not per the task brief's grouping

The task brief's framing ("#123/#124/#125 have individual ランタイム対応
sections") is **not fully accurate** — verified against both the epic
body's own classification and each child issue body directly:

- **#124** — has its own dedicated section, quoted in full:
  &gt; "## ランタイム対応 (Claude Code / Codex) — 2026-07-10 追記
  &gt; - 3負例のペイロードは tool_name が Claude 形(Bash 等)と Codex 形
  &gt;   (exec / apply_patch 等)の両方で全ランタイム実装(.py / .ps1 / .js)
  &gt;   に投入し、期待判定の一致を確認する。
  &gt; - 参考: Claude Code 経路は sdd-hook-guard.js(`hooks/claude-hooks.json`)、
  &gt;   Codex 経路は sdd-hook-guard.sh → .py/.ps1(`hooks/hooks.json`)。"

- **#125** — has its own dedicated section, quoted in full:
  &gt; "## ランタイム対応 (Claude Code / Codex) — 2026-07-10 追記
  &gt; - シナリオの PreToolUse ペイロードは Claude 系ツール名(Edit / Write /
  &gt;   MultiEdit / Bash)だけでなく Codex 系ツール名(apply_patch /
  &gt;   exec_command / shell / exec)でも駆動すること。既存 `hooks/hooks.json`
  &gt;   の matcher は両系を対象にしており、シナリオが片方のみだと回帰が
  &gt;   半分しか守られない。"

- **#123** — has **no individual ランタイム対応 section of its own**. The
  epic body's own classification (issue `#136`, section "ランタイム対応
  (Claude Code / Codex)") places it instead in the group: "既に両ランタイム
  対応が設計に含まれるもの(sh/py/ps1/js ガードパリティ系): #108, #109,
  #110, #111, #118, #119, #122, **#123**" — i.e. dual-runtime coverage is
  treated as already inherent to the guard-parity design pattern, not
  called out as an added requirement. #123's own Constraint section only
  restates the human-copy staging requirement, with no runtime-specific
  addendum.

- **#126** — appears in neither list (classified in the epic body as
  "ランタイム非依存(共有スクリプト・MCP 内部・CI・docs): ... #126, ...").

---

## Open Questions

| # | Question | Owner | Blocking |
|---|----------|-------|---------|
| 1 | #123's and #124's own Constraint sections assume their target files (`tests/guard-parity.tests.sh`, `tests/gates.tests.sh`) require human-copy staging. This investigation confirms they genuinely ARE R-10 protected (INV-024) — unlike the analogous situation in `quality-loop-fixes` (where the framing was found NOT supported). Given the working precedent of `tests/guard-cwd-bypass.tests.sh` (INV-025, a brand-new unprotected file created for #110 instead of editing a protected suite), should #123/#124's new negative cases go into NEW unprotected suite files (no human-copy needed) instead of human-copy edits to the protected suites named in the issues? | Human | yes |
| 2 | ADR-0010 (`docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`), which #125 is required to align with (INV-015), is itself still `Status: Proposed(人間承認待ち)` (line 3) — not yet approved. Should #125's task planning wait for ADR-0010 approval, or proceed on the assumption it will be approved as-is? | Human | yes |
| 3 | `tests/scenario.tests.sh` (INV-013) already occupies the "scenario" name with different scope (no greenfield/brownfield vocabulary). Should `tests/workflow-scenarios/` be a clean new namespace, should the existing 3 scenarios (A/B1/E) be migrated into it, or should the two coexist with an explicit cross-reference comment to avoid discoverability confusion? | Human | no |
| 4 | Both `quality-loop-fixes` (via its open OQ-5) and epic-136-phase3 (via #123/#124/#125's likely new CI steps and #126's job-split) may stage concurrent edits to the same protected `.github/workflows/test.yml` human-copy area (INV-029). Should these two features be sequenced (one merges before the other starts its `test.yml` edit), or should a single coordinated human-copy staging pass cover both? | Human | yes |
| 5 | #126's premise ("現状 test.yml が両者を明確に分離していない") assumes a mixing risk that this investigation did not find evidence for today (INV-020: zero LLM-invoking steps exist in `test.yml`; the one real LLM workflow is already isolated, INV-021). Should #126 be scoped as (a) a preventive/structural reorganization of the existing single `test` job into named lanes for future-proofing, or (b) deferred until an actual LLM-invoking eval step is proposed for `test.yml`? | Human | no |
| 6 | Issue #125's scenario class 5 ("prompt injection issue body") — the only existing test with matching keywords (`tests/model-freshness-check.tests.sh` TEST-021, INV-018) covers OUTBOUND escaping (script-authored issue body), not INBOUND injection (an attacker's issue body consumed as agent context, e.g. via `gh issue view --json body` as this very investigation task did). Should #125's scenario 5 target the inbound direction specifically, and if so, which entry point(s) in `plugins/sdd-bootstrap`/`plugins/sdd-quality-loop` are in scope? | Human | no |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| New #123/#124/#125/#126 test suites land without being wired into `tests/run-all.sh`/`run-all.ps1`/`.github/workflows/test.yml`, repeating the exact registration gap already found for `guard-parity.tests.sh`, `constant-parity.tests.sh`, and `guard-cwd-bypass.tests.sh` (INV-006) | high (established pattern in this repo) | high | Make CI-registration an explicit Done condition of every task in this feature's `tasks.md`; verify with a fresh `grep` against all three registration files before marking any task complete |
| Concurrent human-copy staging of `.github/workflows/test.yml` by both `quality-loop-fixes` and epic-136-phase3 (INV-029) produces a divergent/conflicting staged diff | medium | high | Resolve OQ-4 (sequencing) before either feature's `tasks.md` schedules a `test.yml` edit |
| #125 proceeds with an invented fixture-profile vocabulary before ADR-0010 (still `Proposed`) is approved, creating exactly the dual-vocabulary problem the ADR itself warns against (INV-015) | medium | high | Resolve OQ-2 before scenario-schema design |
| #123/#124's new negative-case tests are written directly into the protected `tests/guard-parity.tests.sh`/`tests/gates.tests.sh` via human-copy when the established, lower-friction pattern (`guard-cwd-bypass.tests.sh`, INV-025) would have avoided the human-copy step entirely, adding unnecessary process overhead | medium | low-medium | Resolve OQ-1 before task planning |
| #124's cross-runtime corpus is written only against `.py`/`.js` (mirroring `guard-parity.tests.sh`'s existing scope) and never actually drives the `.sh` dispatcher or `.ps1` twin, silently missing the "全ランタイム" requirement in its own issue text and its runtime-対応 addendum (INV-031) | medium | medium | Explicitly require all 4 runtime surfaces (`.py`, `.js`, `.ps1`, `.sh` dispatcher) plus both tool-name shapes in the task's acceptance criteria |
| #126 reorganizes the single `test` job into multiple jobs/lanes without preserving `required-checks`' `needs: [test, cli-hook-enforcement]` gate (`test.yml:573`), silently weakening branch protection | low-medium | high | Any job-split task must update `required-checks.needs` to list every new job name, and this must be verified against GitHub's actual required-status-check configuration, not just the YAML |

## Recommended Next Steps

1. Resolve OQ-1 (new unprotected suite vs. protected-suite human-copy edit)
   and OQ-4 (`test.yml` staging sequencing against `quality-loop-fixes`)
   with the human approver before drafting `requirements.md`/`tasks.md`,
   since both change task sequencing and file-touch lists materially.
2. Resolve OQ-2 (ADR-0010 approval dependency) before scoping #125's
   scenario-schema design work, to avoid inventing a vocabulary that later
   needs to be retrofitted to match an approved ADR.
3. For #123, scope the task around `sdd-hook-guard.sh`'s actual fallback
   chain (INV-002: `python3` → `pwsh`/`powershell.exe`/`powershell`, no
   `node` branch) using the `PATH="/usr/bin:/bin"` subshell-override
   technique already established in `tests/collection-layer.tests.sh`
   (INV-005), placed in a new unprotected suite file pending OQ-1.
4. For #124, build the negative-case corpus against all 4 runtime surfaces
   (`.py`, `.js`, `.ps1`, `.sh` dispatcher) and both Claude/Codex `tool_name`
   shapes explicitly, reusing the RED/GREEN staged-guard parameterization
   pattern from `tests/guard-cwd-bypass.tests.sh` (INV-007, INV-025).
5. For #125, adopt `loop-inventory.json`'s `greenfield`/`brownfield`
   vocabulary verbatim (INV-014/INV-015), reuse `tests/lib/loop-driver.sh`'s
   helper functions where the target stage is `"spec"` (its only fully
   implemented stage today, INV-016), and resolve OQ-3 (naming vs.
   `tests/scenario.tests.sh`) before creating `tests/workflow-scenarios/`.
   Prioritize closing the two genuinely-uncovered classes first: scenario 3
   (refactor baseline missing — INV-017 row 3) and scenario 5 (inbound
   prompt-injection — INV-018, pending OQ-6).
6. For #126, since no LLM-invoking step exists in `test.yml` today
   (INV-020), scope the task as a forward-looking structural
   reorganization (named job/lane boundaries preserving all `required-checks`
   dependencies, INV-023) rather than a fix for an existing mixed-lane
   defect, pending OQ-5.
7. Make "wire the new suite into `run-all.sh`/`run-all.ps1`/`test.yml`" an
   explicit, checked Done condition for every task, given the established
   registration-gap pattern (INV-006).

---

## Baseline Behavior (narrow — CI job-graph surface only)

Per the task's mode guidance, this feature is additive test/CI work, not a
bugfix/refactor of application behavior, so no full baseline-behavior
document is warranted. One narrow surface genuinely needs a preserved-
behavior baseline because #126 proposes restructuring an existing,
currently-passing CI job graph:

### BL-001: `required-checks` job gate — current passing contract

**File**: `.github/workflows/test.yml:570-587`

```yaml
required-checks:
  name: required-checks
  if: always()
  needs: [test, cli-hook-enforcement]
  runs-on: ubuntu-latest
  steps:
    - name: Check all required tests passed
      run: |
        if [ "${{ needs.test.result }}" != "success" ]; then
          echo "test job failed"; exit 1
        fi
        if [ "${{ needs.cli-hook-enforcement.result }}" != "success" ]; then
          echo "cli-hook-enforcement job failed"; exit 1
        fi
        echo "all required checks passed"
```
**Current behavior to preserve**: `required-checks` passes if and only if
both the `test` job (all ~50+ steps across `[windows-latest, macos-latest,
ubuntu-latest]`, line 18) and `cli-hook-enforcement` job (line 540) succeed
on every matrix leg. `mcp-tests`, `local-env-mcp-tests`, `ci-mcp-tests` are
**not** in `required-checks`' `needs` list today (confirmed by the exact
`needs: [test, cli-hook-enforcement]` array — no third or fourth entry) —
i.e. they currently run in CI but do not gate the branch-protection
required-check as coded here (branch-protection ruleset configuration
itself, outside this repo's tracked files, may separately require them —
out of scope for source-only investigation). Any #126 job-split MUST keep
this pass/fail semantics equivalent: every step currently inside the `test`
job must remain reachable by some job listed in `required-checks.needs`
(directly or via a job-dependency chain), or `required-checks` will
silently stop gating on suites it used to gate on.

---

**File paths referenced in this investigation** (all absolute,
repository-relative for evidence):

- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/hooks/claude-hooks.json`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/hooks/hooks.json`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/hooks/copilot-hooks.json`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/guard-parity.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/constant-parity.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/guard-cwd-bypass.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/guard-r10-port.tests.ps1`
- `/Users/jrmag/Projects/active/sdd-forge/tests/guards.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/gates.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/prepare-panelist.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/loop-escalation.tests.sh` / `.ps1`
- `/Users/jrmag/Projects/active/sdd-forge/tests/quality-gate-cycle-limit.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/collection-layer.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/scenario.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/tests/loops/loop-inventory.json`
- `/Users/jrmag/Projects/active/sdd-forge/tests/lib/loop-driver.sh` / `.ps1`
- `/Users/jrmag/Projects/active/sdd-forge/docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`
- `/Users/jrmag/Projects/active/sdd-forge/tests/phase2-guard-invariants.tests.sh` / `.ps1`
- `/Users/jrmag/Projects/active/sdd-forge/tests/model-freshness-check.tests.sh`
- `/Users/jrmag/Projects/active/sdd-forge/.github/workflows/test.yml`
- `/Users/jrmag/Projects/active/sdd-forge/.github/workflows/self-improvement.yml`
- `/Users/jrmag/Projects/active/sdd-forge/.github/workflows/model-freshness-check.yml`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts` / `deep-verify-tool.test.ts` / `deep-verify-error-paths.test.ts`
- `/Users/jrmag/Projects/active/sdd-forge/mcp/ci-mcp/tests/error-paths/bounded-tail-read.test.ts` / `tools/get-job-log.test.ts`
- `/Users/jrmag/Projects/active/sdd-forge/plugins/sdd-quality-loop/references/quality-gate-calibration.md`
- `/Users/jrmag/Projects/active/sdd-forge/reports/review-context/identity-ledger.json`
- `/Users/jrmag/Projects/active/sdd-forge/specs/quality-loop-fixes/investigation.md`
