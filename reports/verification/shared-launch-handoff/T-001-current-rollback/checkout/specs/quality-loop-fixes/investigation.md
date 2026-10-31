# Investigation: quality-loop-fixes

| Field | Value |
|-------|-------|
| Feature | quality-loop-fixes |
| Mode | bugfix |
| Date | 2026-07-19 |
| Investigator | sdd-investigator (read-only) |

Source: 4 approved fix streams (#167/RT-20260712-001, #176/WFI-010, #166/WFI-009,
#179) against `feature/quality-loop-fixes` @ `e8cdd74` (working tree clean,
identical to `main` lineage through epic-159 Pillar D `#186`). Read-only survey
with `file:line` evidence. All paths are repository-relative unless given as
absolute.

## Scope

Four independent, already-approved defect-fix streams inside
`plugins/sdd-quality-loop/` (and one `sdd-ship` prose reference):

1. **#167 / RT-20260712-001** — `check-quality-gate-cycle-limit.{sh,ps1}` count
   gate reports repo-wide instead of per-feature, causing false
   `Escalate-Human` once ≥3 features share a task id.
2. **#176 / WFI-010** — `emit-run-record.{sh,ps1}` blocked-count uses an
   unanchored whole-file `BLOCKED` keyword scan instead of reading the gate
   report's own `VERDICT:` field. Scope narrowed by a recorded human decision
   (remedy b) to this ONE field.
3. **#166 / WFI-009** — `prepare-panelist-input.{sh,ps1}` does not verify the
   sanitized bundle against the implementation report's declared-outputs
   table (and does not recurse into subdirectories); `cross-model-verify/SKILL.md`
   has no deterministic pre-panel readiness/coverage-manifest step.
4. **#179** — `validate-review-context-set.sh`'s record-hash recomputation
   reads `jq -r` output that carries a trailing `\r` on Windows Git Bash
   (`jq.exe`), corrupting the byte-exact hash comparison.

Cross-cutting scope: determine the authoritative R-10 protected-file list,
classify each of the 8 target script/skill files as directly editable vs.
human-copy-required, and document current test/CI registration state and the
identity-ledger tail.

## Summary

All 4 streams have upstream approval records (1 open review ticket, 2
Approved WFIs; #179 has neither a ticket nor a WFI yet — see OQ-6). Evidence
for every stream's defective logic is quoted below at the exact `file:line`.
The authoritative machine-enforced protected-file list
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`) shows only
**one** of the named target files —
`plugins/sdd-ship/skills/ship/SKILL.md` (a stream-1 reference target, not one
of the 8) — is genuinely R-10-protected today; the other 8 files
(`check-quality-gate-cycle-limit.{sh,ps1}`, `emit-run-record.{sh,ps1}`,
`prepare-panelist-input.{sh,ps1}`, `cross-model-verify/SKILL.md`,
`validate-review-context-set.sh`) are **not** in the enforced suffix list, so
`sdd-hook-guard` would not block a direct `Edit`/`Write` on them. This
contradicts stream 4's framing that `validate-review-context-set.sh` needs
human-copy staging — flagged as OQ-1, requiring a human decision before task
planning.

---

## Findings

### Stream 1 — #167 / RT-20260712-001 (cycle-limit feature scoping)

#### INV-001: RT-20260712-001 ticket contents (open, major, design-gap)

**File**: `docs/review-tickets/RT-20260712-001.yml:1-49`

- `status: open` (line 2), `severity: major` (line 4), `auto_fix_allowed: false` /
  `requires_human_decision: true` (lines 47-48).
- `target.files` (lines 8-11): `plugins/sdd-ship/skills/ship/SKILL.md`,
  `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh`,
  `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1`.
- `problem` (lines 13-32): counts task-id references across ALL features'
  gate reports; measured 2026-07-12 the script returned `Escalate-Human` for
  T-003..T-006 in `epic-136-phase1-guards` even though that feature's
  own scoped count was 0 for each.
- `expected_fix` (lines 33-42): "scope the count to the current feature, e.g.
  count only reports that reference BOTH the task id and the feature slug
  (`grep -lw "$task"` over `grep -l "$feature"` matches), or move per-feature
  gate reports under `reports/quality-gate/<feature>/`." Notes `ship/SKILL.md
  is a protected file`.
- `references` (lines 43-46) link to issue `#167` (filed 2026-07-13).

#### INV-002: check-quality-gate-cycle-limit.sh — current (unscoped) counting logic

**File**: `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:39-59`

```
39  count=0
40  if [ -d "$reports_dir" ]; then
41      set +e
42      matches="$(grep -rlwF -e "$task_id" "$reports_dir" 2>/dev/null)"
43      rc=$?
...
49      if [ -n "$matches" ]; then
50          count="$(printf '%s\n' "$matches" | wc -l | tr -d '[:space:]')"
51      fi
52  fi
53
54  if [ "$count" -ge 3 ]; then
55      echo "Escalate-Human"
56      exit 1
57  fi
```

Line 42's `grep -rlwF -e "$task_id" "$reports_dir"` matches ANY file whose
content contains the word-bounded task id, with no feature-slug filter —
this is the exact defect. Contract comment at lines 10-15 documents the
current (unscoped) semantics as intended behavior.

#### INV-003: check-quality-gate-cycle-limit.ps1 — parity twin, same defect

**File**: `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1:36-43`

```
36  $count = 0
37  if (Test-Path -LiteralPath $ReportsDir -PathType Container) {
38      $pattern = "\b" + [regex]::Escape($TaskId) + "\b"
39      $count = @(Get-ChildItem -LiteralPath $ReportsDir -File -Recurse -ErrorAction SilentlyContinue |
40          Where-Object { Select-String -LiteralPath $_.FullName -Pattern $pattern -CaseSensitive -Quiet }).Count
41  }
```

Identical unscoped semantics (byte-for-byte behavioral parity requirement
per repo convention — see INV-020/026).

#### INV-004: ship/SKILL.md Step 4 prose describes the same unscoped rule (protected)

**File**: `plugins/sdd-ship/skills/ship/SKILL.md:191-218`

Line 205-207: "The script counts this task's existing gate reports under
`reports/quality-gate/` (word-boundary match on the task id so `T-001` does
not match `T-0010`; an absent directory counts zero)" — no feature dimension
is mentioned. If the fix adds a feature-slug filter, this prose (and the
invocation examples at lines 196/202, which pass only `T-NNN`, no feature
arg) needs a matching update. `ship/SKILL.md` IS R-10-protected (INV-020) —
any edit here requires human-copy staging.

#### INV-005: quality-gate-cycle-limit.tests.sh — coverage and registration state

**File**: `tests/quality-gate-cycle-limit.tests.sh:1-270`

- 270-line TDD suite (`QGCL-001`..`QGCL-012`) covers 0/1/2/3/4-report
  boundaries, prefix collision (`T-0010` vs `T-001`), absent directory,
  invalid task-id usage errors, punctuation-adjacent vs embedded
  word-boundary cases, default `reports-dir`, sh/ps1 output+exit parity, and
  `.ps1` ASCII/BOM checks (lines 126-260). **No test exercises cross-feature
  collision** (two features both referencing the same task id) — consistent
  with the unscoped design being intentional at the time this suite was
  written.
- **Registration state** (precise, as of this investigation):
  - `tests/run-all.sh:45` lists `tests/quality-gate-cycle-limit.tests.sh`.
  - `tests/run-all.ps1:7-40` ($tests array) does **not** list this suite (or
    any `.ps1` twin of it) — grep of the array found zero matches.
  - `.github/workflows/test.yml` (586 lines) does **not** reference
    `quality-gate-cycle-limit` anywhere; CI registers every suite as an
    individual named step (e.g. `tests/loop-driver.tests.sh` at line 95,
    `tests/model-freshness-check.tests.sh` at line 210) rather than
    delegating to `run-all.sh` (no `run-all` string appears in the workflow
    at all). **This suite therefore does not run in the actual 3-OS CI
    matrix (`windows-latest, macos-latest, ubuntu-latest`,
    `.github/workflows/test.yml:18`) today — only via a local/manual
    `bash tests/run-all.sh`.** Its own internal sh/ps1 parity check
    (`QGCL-011`, lines 211-228) is self-skipping when `pwsh` is absent.

### Stream 2 — #176 / WFI-010 (emit-run-record blocked-count)

#### INV-006: WFI-010 status and human-decided scope narrowing

**File**: `docs/workflow-improvements/WFI-010.md:1-199`

- `Status: Approved` (line 9), `Category: plugin-improvement` (line 17).
- Lines 116-128 (original GitHub-Issue Lane) proposed TWO fixes: change the
  per-task gate-report header-association grep AND the blocked-count
  keyword scan.
- Lines 130-150 (Cycle-2 audit note) flag a conflict with WFI-003 (Status:
  Verified) over whether gate reports must carry `Task:`/`Run ID:` lines.
- Lines 152-170: **"Human decision (recorded 2026-07-15): remedy (b) was
  chosen — restore AGENTS.md/WFI-003 compliance in gate-report
  authoring."** Verification run
  (`reports/runs/RUN-20260715T130411Z-epic-159-pillar-a.json`) confirmed
  `gate_reports.total` 0→4 (true) with **no emitter change**, but
  `gate_reports.blocked` still read 1 (true 0) — proving the header
  association was an authoring defect (already fixed by adding `Task:`/`Run
  ID:` lines to reports) while **the unanchored whole-file `BLOCKED`
  keyword scan remains a genuine plugin-side defect**. Line 164: "This
  WFI's remaining scope is therefore narrowed to the blocked-count fix
  only (read the report's own verdict field instead of a whole-file keyword
  scan)."

#### INV-007: emit-run-record.sh — current blocked-count logic (target of the fix)

**File**: `plugins/sdd-quality-loop/scripts/emit-run-record.sh:117-140`

```
117  gate_total=0
118  gate_blocked=0
...
124  if [ -d "reports/quality-gate" ]; then
125    feature_gate_files="$(grep -rlE "^Feature:[[:space:]]*${feature_re}[[:space:]]*$" reports/quality-gate 2>/dev/null || true)"
126    for tid in $task_ids; do
...
137    for gf in $feature_gate_files; do
138      grep -q 'BLOCKED' "$gf" 2>/dev/null && gate_blocked=$((gate_blocked + 1))
139    done
140  fi
```

Line 125 already correctly scopes `feature_gate_files` to this feature
(a prior, already-landed fix — see commit `339c748` "scope run-record
gate/ticket counts to the target feature"). Line 138 is the current bug: an
unanchored `grep -q 'BLOCKED'` over the ENTIRE report body — any report
whose free-text prose mentions "BLOCKED" (e.g. describing a different
blocked task, quoting another report, or explaining why something is NOT
blocked) is miscounted, independent of the report's own `VERDICT:` line.

#### INV-008: emit-run-record.ps1 — parity twin, same logic

**File**: `plugins/sdd-quality-loop/scripts/emit-run-record.ps1:133-152`

```
137  if (Test-Path "reports/quality-gate") {
138      $featureGateFiles = @(Get-ChildItem "reports/quality-gate" -File -Recurse | Where-Object {
139          (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "(?m)^Feature:\s*$([regex]::Escape($Feature))\s*$"
140      })
...
149      $gateBlocked = @($featureGateFiles | Where-Object {
150          (Get-Content -Raw -Encoding Utf8 $_.FullName) -match "BLOCKED"
151      }).Count
152  }
```

Lines 149-151: identical unanchored whole-content `-match "BLOCKED"` check.

#### INV-009: Gate-report VERDICT header convention (confirmed against recent reports)

**File**: `reports/quality-gate/*.md` (121 files total; 120 carry a
`^VERDICT:` header line, 1 does not)

- `reports/quality-gate/20260719T101749Z-epic-159-pillar-d-T-001.md:8` →
  `VERDICT: PASS`
- `reports/quality-gate/20260719T104424Z-epic-159-pillar-d-T-002.md:8` →
  `VERDICT: PASS`
- `reports/quality-gate/20260719T105921Z-epic-159-pillar-d-T-003.md:8` →
  `VERDICT: PASS`
- `reports/quality-gate/T-008.md:8` → `VERDICT: BLOCKED` (real BLOCKED
  example, feature `sdd-domain`, but its own body prose at line 15 also
  discusses being "blocked" — this single file demonstrates why an
  anchored `^VERDICT:` read is required instead of a body-text scan).
- Distribution across all reports: `120 VERDICT: PASS`, `1 VERDICT: BLOCKED`
  (`T-008.md`), `1 VERDICT: NEEDS_WORK`. One file has no `VERDICT:` line at
  all (pre-dates the convention) — the fix must decide a fail-open/closed
  default for that case (see OQ-4).

#### INV-010: emit-run-record-feature-scope.tests.sh — existing coverage does not exercise the WFI-010 defect

**File**: `tests/emit-run-record-feature-scope.tests.sh:1-104`

- Header comment (lines 2-8) states its purpose: "emit-run-record.sh must
  scope gate_reports and review_tickets to the target feature," citing the
  cross-feature miscount seen in
  `reports/runs/RUN-20260705T171721Z-local-env-mcp.json`.
- Fixture (lines 33-57): feat-a's 3 reports are ALL `VERDICT: PASS` with no
  "BLOCKED" substring anywhere in their bodies (lines 34-48); only feat-b's
  report (excluded by feature scope) contains `BLOCKED` (lines 52-57,
  appearing on both the `VERDICT:` line and a bare second line).
- Assertion `assert_eq '.metrics.gate_reports.blocked' 0 "feat-b's BLOCKED
  report is not counted for feat-a"` (line 103) only proves cross-feature
  exclusion — it does **not** cover the actual WFI-010 regression (a
  same-feature report with `VERDICT: PASS`/`NEEDS_WORK` whose body text
  independently contains the literal word "BLOCKED", which is exactly what
  produced the 0→1 false count for `epic-159-pillar-a` per INV-006). This
  is a genuine **test coverage gap** that the fix task should close.

### Stream 3 — #166 / WFI-009 (panelist-input completeness + pre-panel readiness)

#### INV-011: WFI-009 status, problem evidence, and proposed change

**File**: `docs/workflow-improvements/WFI-009.md:1-173`

- `Status: Approved` (line 14), `GitHub-Issue: .../issues/166` (line 45),
  `Audit-Status: Human-Pending` (line 49).
- Problem Evidence (lines 51-92): the `epic-136-phase1-guards` retrospective
  recorded two blind-panel NEEDS_WORK failures purely from evidence
  completeness gaps: (1) "the bundle collector does not recurse and nothing
  verified the bundle against the implementation report's declared
  outputs" (line 61-62); (2) a parity corpus exercised only ~7 of 30+3
  required protected-suffix entries with no deterministic coverage check
  (lines 66-70), remediated only via review ticket `RT-20260712-002` and a
  second implementation attempt.
- Proposed Change (lines 115-120, two-row table):
  - `prepare-panelist-input.sh` (+`.ps1`): "verify it contains an artifact
    section for every path listed in the implementation report's
    declared-outputs table (path and content hash must match); on any
    missing or hash-mismatched artifact, fail closed with the list of gaps
    and do not print an input digest."
  - `cross-model-verify/SKILL.md`: "Add a deterministic pre-panel readiness
    step: when the task's specification flags an enumerable coverage
    requirement..., require the bundle to include a machine-checkable
    coverage manifest... and fail the readiness step when any element is
    unmapped, BEFORE any panelist is invoked."

#### INV-012: prepare-panelist-input.sh — current collection logic (non-recursive) and digest emission

**File**: `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:269-411`

Collection (no completeness verification against any declared-outputs
table; no recursion into subdirectories):

```
269  if [ -d "$input_path" ]; then
270      # Concatenate all text files in the directory
271      raw_content=""
272      for f in "$input_path"/*; do
273          [ -f "$f" ] || continue
274          raw_content="${raw_content}$(cat "$f")
275  "
276      done
277  else
278      raw_content="$(cat "$input_path")"
279  fi
```

`for f in "$input_path"/*` (line 272) is a single-level glob — it does not
descend into subdirectories, matching WFI-009's stated root cause ("the
bundle collector does not recurse," INV-011).

Digest computation and emission:
- sha256 computed inside the embedded Python heredoc:
  `digest = hashlib.sha256(text.encode("utf-8")).hexdigest()` (line 361),
  written as the bundle's first stdout line (line 363).
- `input_digest=$(printf '%s\n' "$sanitized_and_digest" | head -1)`
  (line 377) — extracted from the Python subprocess output.
- Written into the bundle header: `printf '# input_digest: %s\n'
  "$input_digest"` (line 393).
- Printed to the caller: `printf '%s\n' "$input_digest"` (line 406) — this
  is the exact print statement WFI-009 requires to be suppressed on a
  completeness gap ("do not print an input digest").
- No grep/search anywhere in the file for "Outputs" or "declared" table
  parsing exists — confirmed via full-file search.

#### INV-013: prepare-panelist-input.ps1 — parity twin, same gaps

**File**: `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1:200-314`

- `foreach ($f in (Get-ChildItem $InputPath -File))` (line 210) — no
  `-Recurse` flag, same non-recursive defect.
- Digest computed via `.NET SHA256` (lines 280-283), printed via
  `Write-Host $inputDigest` (line 312) with the same "no completeness
  check before printing" gap.

#### INV-014: cross-model-verify/SKILL.md — current steps have no pre-panel readiness check

**File**: `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md:40-148`

Steps 1-5 (lines 42-148): Consent+Sanitize → Detect available panelists →
Invoke panelists blind in parallel → Verify verdict files present → Prompt
user to run the gate. There is no step between "Consent+Sanitize" (Step 1)
and "Detect available panelists" (Step 2) that checks bundle completeness
or an enumerable coverage manifest — confirmed absent by reading the full
167-line file. This is the exact gap WFI-009's second proposed-change row
(INV-011) targets.

#### INV-015: Implementation-report Outputs table format (recent example) and protected status of the two WFI-009 target files

**File**: `reports/implementation/epic-159-pillar-d/T-001.md:113-131`

```
113 ## Outputs
...
121 | Path | SHA-256 |
122 |---|---|
123 | `docs/contributor/workflow-detail.md` | `702dd35e...` |
...
```

Two-column, backtick-quoted `| Path | SHA-256 |` table; line 116-119 states
paths "MUST be canonical repository-relative paths" and that this table
authorizes the independent evaluator's launch boundary — i.e. this table's
shape is already load-bearing elsewhere in the loop (see
`path_is_authorized`/`evaluator_output_is_declared` in
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:63-74`,
which parses the SAME `## Outputs` heading + `| \`path\` | \`hash\` |` row
format for `quality:sdd-evaluator` launches). A WFI-009 fix should reuse
this exact parser shape for consistency.

Protected-file check (against `PROTECTED_GATE_SUFFIXES`/
`PHASE2_HUMAN_COPY_TARGETS`, quoted in full at INV-020): neither
`prepare-panelist-input.sh`/`.ps1` nor
`plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` appear in
either list. **Both files are directly editable** (not R-10-protected) —
no human-copy staging is required for stream 3.

### Stream 4 — #179 (validate-review-context-set.sh CRLF/jq contamination)

#### INV-016: validate-review-context-set.sh — jq -r consumption sites in the record-hash recomputation path

**File**: `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:178-187,241-258,307`

Manifest field reads (single-value `jq -r`, no `\r` strip):
```
178  stage=$(jq -r '.stage' "$manifest")
179  role=$(jq -r '.role' "$manifest")
180  feature=$(jq -r '.feature' "$manifest")
181  run_id=$(jq -r '.run_id' "$manifest")
182  host_session_id=$(jq -r '.host_session_id' "$manifest")
183  sequence=$(jq -r '.sequence' "$manifest")
184  previous_record_sha256=$(jq -r '.previous_record_sha256' "$manifest")
185  bound_ledger_sha256=$(jq -r '.identity_ledger_sha256' "$manifest")
```

Ledger batch read feeding the record-hash recomputation loop:
```
241  while IFS=$'\t' read -r record_sequence record_stage record_role record_run record_session record_previous record_hash; do
...
245    computed_hash=$(printf '%s' "$record_sequence|$record_stage|$record_role|$record_run|$record_session|$record_previous" | sha256_text)
246    [[ "$computed_hash" == "$record_hash" ]] ||
247      fail IDENTITY 'canonical identity ledger record hash is invalid'
...
250  done < <(jq -r '.records[] | [
251    .sequence,
252    .stage,
253    .role,
254    .run_id,
255    .host_session_id,
256    (if .previous_record_sha256 == "" then "-" else .previous_record_sha256 end),
257    .record_sha256
258  ] | @tsv' "$ledger")
```

The `jq -r ... | @tsv` output at line 250-258 is piped directly into the
`read` loop at line 241 with no `tr -d '\r'`. On Windows Git Bash with
`jq.exe`, a trailing `\r` on the last TSV field (`record_hash`) survives
`read` (which strips only the `\n` delimiter, not embedded `\r`), so
`record_hash` becomes e.g. `1a4bfe...caa441\r`, which never equals the
freshly computed `computed_hash` — producing exactly the observed
`"canonical identity ledger record hash is invalid"` error at line 247.
The same untreated pattern reconstructs the NEW record hash for the
current invocation at line 307:
```
307  record_hash=$(printf '%s' "$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256" | sha256_text)
```
using values read at lines 178-185 — so a `\r`-contaminated
`previous_record_sha256` (line 184) would also corrupt the chain-continuity
comparison at line 260 (`[[ "$sequence" -eq "$expected_sequence" &&
"$previous_record_sha256" == "$expected_previous" ]]`).

Two further `jq -r` sites exist in the file that are outside the
record-hash path proper but share the same defect class: line 275
(`jq -r '.allowed_input_manifest[].path' "$manifest"`) and line 305
(`jq -r '.allowed_input_manifest[] | [.path, .sha256] | @tsv' "$manifest"`).

#### INV-017: Proven fix pattern — commit c756a5a in tests/lib/loop-driver.sh

**File**: `tests/lib/loop-driver.sh` (fixed by commit `c756a5aeac64fd267a7fb021c581065cb6b1c663`)

Commit message: "fix(tests): cross-OS CI fixes for loop suites (CRLF-safe
jq reads, bash-3.2-safe task fixture)" — "Windows (Git Bash) lane: jq.exe
can emit CRLF-terminated raw output, so values read via jq -r into bash
(paths, ids, hashes, round numbers) carried a trailing \r that broke
exact-match comparisons... Pipe every jq -r consumption point... through
`tr -d '\r'` (unconditional, no host branching)." Example diff hunks:
```
- jq -r --arg id "$id" '...' "$LOOP_INVENTORY_PATH"
+ jq -r --arg id "$id" '...' "$LOOP_INVENTORY_PATH" | tr -d '\r'
...
- jq -r '(.records | length) + 1' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
+ jq -r '(.records | length) + 1' "${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json" | tr -d '\r'
```
The pattern is: append `| tr -d '\r'` unconditionally to every `jq -r`
invocation whose output is consumed by bash, with no `uname`/OS branching.

#### INV-018: Capability-probe named SKIP that auto-recovers once the validator is fixed

**File**: `tests/lib/loop-driver.sh:460-519`

```
481  LOOP_VALIDATOR_SKIP_REASON="real validator rejects a canonically-valid genesis ledger on this runtime (upstream Windows CRLF defect in validate-review-context-set.sh record-hash recomputation; issue #179)"
482  loop_validator_capability_probe() {
483    if [[ -n "${LOOP_VALIDATOR_CAPABILITY:-}" ]]; then
484      [[ "$LOOP_VALIDATOR_CAPABILITY" == ok ]]
485      return
486    fi
...
498    if probe_out="$(_loop_review_context_call spec spec-reviewer-a "$feature" "$entries" check 2>&1)"; then
...
507    if [[ "$probe_out" == *REVIEW_CONTEXT_IDENTITY* ]] && _loop_genesis_formula_valid "$ledger"; then
508      LOOP_VALIDATOR_CAPABILITY=degraded
509      return 1
510    fi
511    LOOP_VALIDATOR_CAPABILITY=ok
512    return 0
513  }
...
517  loop_validator_skip() {
518    printf 'SKIP: %s: %s\n' "$1" "$LOOP_VALIDATOR_SKIP_REASON"
519  }
```

The probe's doc comment (lines 460-476) explicitly names the defect
mechanism: "its while-IFS=tab-read loop consumes `jq -r ... | @tsv` output
whose trailing CR lands in the final record_sha256 field, so a
byte-exact hash comparison fails on a canonically valid ledger; tracked as
issue #179." When `loop_validator_capability_probe` returns 1 (degraded),
callers emit named `SKIP:` lines via `loop_validator_skip` instead of
failing — used at `tests/loop-driver.tests.sh:144-147` (6 skip ids:
`TEST-006.1`..`TEST-006.6`), 7 call sites in
`tests/loop-consistency.tests.sh` (lines 116, 146, 194, 224, 294, 315,
372), and `tests/loop-escalation.tests.sh:482`. Once `#179` is fixed on a
given runtime, `_loop_review_context_call` will succeed (`probe_rc == 0`,
line 503-506) and every gated block re-enables automatically — no test
file edits are needed to "recover" these suites.

#### INV-019: validate-review-context-set.ps1 does not share the defect

**File**: `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:148,221`

The PowerShell twin parses JSON via native
`ConvertFrom-Json -AsHashtable` (lines 148, 221), not `jq` — it is not
subject to the `jq.exe` CRLF emission behavior. No `.ps1`-side fix is
required for #179.

### Protected-File Analysis (R-10)

#### INV-020: Authoritative protected-gate-suffix source

**File**: `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-19`
(generated from `plugins/sdd-quality-loop/references/guard-invariants.json`,
consumed by `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:891-990`)

`sdd-hook-guard.py:976-990` (`_is_protected_gate_file`) does an
exact-suffix, case-insensitive match against `_PROTECTED_GATE_SUFFIXES`
(loaded from the generated module) — no prefix/directory-wide rule exists.
Full `PROTECTED_GATE_SUFFIXES` tuple (`guard_invariants.py:4`):

```
'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
'plugins/sdd-quality-loop/scripts/kill-switch.js',
'plugins/sdd-quality-loop/scripts/kill-switch.sh',
'plugins/sdd-quality-loop/scripts/kill-switch.ps1',
'plugins/sdd-quality-loop/hooks/claude-hooks.json',
'plugins/sdd-quality-loop/hooks/hooks.json',
'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
'plugins/sdd-quality-loop/scripts/check-contract.sh',
'plugins/sdd-quality-loop/scripts/check-contract.ps1',
'plugins/sdd-quality-loop/scripts/check-contract.py',
'plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh',
'plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1',
'plugins/sdd-quality-loop/scripts/check-evidence-bundle.py',
'plugins/sdd-quality-loop/scripts/validate_path.py',
'.claude/settings.json', '.claude/settings.local.json',
'tests/gates.tests.sh', 'tests/eval.tests.sh',
'tests/guard-parity.tests.sh', 'tests/constant-parity.tests.sh',
'plugins/sdd-review-loop/agents/impl-reviewer-a.md',
'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
'plugins/sdd-review-loop/agents/task-reviewer-a.md',
'plugins/sdd-review-loop/agents/task-reviewer-b.md',
'plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md',
'plugins/sdd-review-loop/skills/task-review-loop/SKILL.md',
'plugins/sdd-ship/skills/ship/SKILL.md',
'plugins/sdd-lite/references/risk-upgrade-policy.md',
'plugins/sdd-lite/scripts/check-risk-upgrade.sh',
'plugins/sdd-lite/scripts/check-risk-upgrade.ps1',
'plugins/sdd-lite/skills/lite-spec/SKILL.md',
'plugins/sdd-quality-loop/references/guard-invariants.json',
'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py',
'plugins/sdd-quality-loop/scripts/generated/guard_invariants.py',
'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js',
'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1',
'plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh',
'.github/workflows/test.yml',
'specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1',
```

`PHASE2_HUMAN_COPY_TARGETS` (`guard_invariants.py:18`) is a subset of the
above (`sdd-hook-guard.*`, `check-contract.ps1`, `risk-upgrade-policy.md`,
`check-risk-upgrade.{sh,ps1}`, `lite-spec/SKILL.md`, `ship/SKILL.md`,
guard-invariants generation files, `.github/workflows/test.yml`, and the
apply script itself).

#### INV-021: Classification of the named target files

| File | In `PROTECTED_GATE_SUFFIXES`? | In `PHASE2_HUMAN_COPY_TARGETS`? | Classification |
|---|---|---|---|
| `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1` | No | No | Directly editable |
| `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` | No | No | Directly editable |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | No | No | **Directly editable per current source** (see INV-022) |
| *(reference)* `plugins/sdd-ship/skills/ship/SKILL.md` | **Yes** | **Yes** | **R-10 protected — human-copy required if prose changes** |

Basis: exact-suffix match against `PROTECTED_GATE_SUFFIXES`
(`sdd-hook-guard.py:976-990`), quoted in full at INV-020. Only
`ship/SKILL.md` — a stream-1 reference file named in RT-20260712-001's
`target.files` (INV-001) but not one of the "8 target files" enumerated in
the task brief — matches.

#### INV-022: Discrepancy — stream 4's "protected gate script" framing is not supported by current source

**File**: `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`;
`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:976-990`

Issue #179's text states the validator is a protected file needing
human-copy, but neither `PROTECTED_GATE_SUFFIXES` nor
`PHASE2_HUMAN_COPY_TARGETS` (quoted in full, INV-020) contains
`validate-review-context-set.sh` or `.ps1`. No other mechanism in
`sdd-hook-guard.py` extends protection by directory, prefix, or "gate
script" role — protection is exclusively the fixed suffix list.
`AGENTS.md` and `docs/*.md` contain no independent "protected files" list
(both searched, zero matches). **This is a real, evidence-based
discrepancy** — recorded as OQ-1; a human must confirm whether (a) the
enforced list is stale and should be updated to add
`validate-review-context-set.sh` before the fix lands (making it
protected retroactively), or (b) the fix should proceed as a direct edit
since the guard does not currently block it.

#### INV-023: Human-copy staging precedent (epic-159-pillar-c, -d)

**File**: `specs/epic-159-pillar-d/human-copy/MANIFEST.sha256:1`;
`specs/epic-159-pillar-c/human-copy/MANIFEST.sha256:1-5`

Pillar-d staged exactly one protected file:
`specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml` (mirrors
the real repo-relative path under `human-copy/`), with
`specs/epic-159-pillar-d/human-copy/MANIFEST.sha256` containing one line:
`3fe8466c...86f4  .github/workflows/test.yml`. Pillar-c staged five files
the same way (`.github/workflows/test.yml` plus the four
`impl-reviewer-{a,b}.md`/`task-reviewer-{a,b}.md` review-loop agents),
each MANIFEST line formatted `<sha256>  <relative/path>`. If any of the
target files in this feature end up genuinely protected (pending OQ-1),
the same pattern applies: stage the edited copy at
`specs/quality-loop-fixes/human-copy/<real-relative-path>`, then write
`specs/quality-loop-fixes/human-copy/MANIFEST.sha256` with one
`sha256  path` line per staged file, and hand off for a human to apply.

### Cross-Cutting: CI, Identity Ledger, Conventions, Open Tickets

#### INV-024: Identity-ledger tail

**File**: `reports/review-context/identity-ledger.json` (schema
`review-identity-ledger/v1`, 319 records)

Last record: `{sequence: 319, stage: "quality", role: "sdd-evaluator",
run_id: "RUN-epic-159-pillar-d-qg-T-003-seq0319", host_session_id:
"SESS-qg-epic-159-pillar-d-T-003-0319", previous_record_sha256:
"960602481525f5edfa235574b26f24be0121217ef6730d3ce5db5377ed29e6a1",
record_sha256:
"1a4bfebc4c72e911ac823f24f39d74262e21520552ccde320567357b6fcaa441"}`.
Any regression test for stream 4 that reserves a new record (`--reserve`)
must extend from `sequence 320`, `previous_record_sha256 =
1a4bfebc...aa441`.

#### INV-025: CI registers each suite as an individual step, not via run-all.sh

**File**: `.github/workflows/test.yml:1-586`

3-OS matrix at line 18: `os: [windows-latest, macos-latest, ubuntu-latest]`.
No occurrence of the string `run-all` anywhere in the file (confirmed by
full-file search) — CI enumerates every suite as its own named step (e.g.
`tests/loop-driver.tests.sh` line 95, `tests/prepare-panelist.tests.sh`
line 314, `tests/cross-model.tests.sh` line 340). The `required-checks` job
(lines 570-586) only checks the `test`/`cli-hook-enforcement` job *results*,
not per-suite registration — there is no automated completeness check that
every `tests/run-all.sh` entry has a matching CI step. This is the
mechanism behind INV-005's finding (`quality-gate-cycle-limit.tests.sh` is
absent from CI).

#### INV-026: Shell/PowerShell portability conventions relevant to all four fixes

**File**: `install.sh:82-83,419-420`;
`plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1:49`

- `install.sh:82-83`: "bash 3.2 treats the zero-element array produced by
  `read -ra` on an empty string as unset under `set -u`, so reject an empty
  list before the read." — macOS CI's default `/bin/bash` is 3.2; avoid
  `declare -A` and guard empty-array expansions (`"${arr[@]}"` under
  `set -u`) in any `.sh` fix.
- `.ps1` scripts in this plugin consistently end with an explicit `exit`
  (e.g. `check-quality-gate-cycle-limit.ps1:49` → `exit 0`); by contrast
  `emit-run-record.ps1` (lines 241-242) has no trailing explicit exit —
  worth normalizing if that file is touched for stream 2.

#### INV-027: Open review-ticket/WFI inventory touching these files

- **Open review tickets in the entire repository: exactly 1** —
  `docs/review-tickets/RT-20260712-001.yml` (stream 1). Confirmed by
  `grep -l "^status: open" docs/review-tickets/*.yml` returning a single
  file.
- `docs/workflow-improvements/WFI-009.md` (stream 3, Approved) and
  `WFI-010.md` (stream 2, Approved) are the only WFIs directly proposing
  changes to these files.
- `docs/workflow-improvements/WFI-005.md:51` and `WFI-007.md:45-46,77,103`
  (both `Status: Verified`, i.e. already closed) mention
  `validate-review-context-set.sh:265` incidentally (evaluator launch
  boundary context) — not open work, no overlap risk.
- **#179 has neither an open review ticket nor a WFI record** — the only
  tracking artifact found is the inline comment/`SKIP` reason string in
  `tests/lib/loop-driver.sh:460-481` (INV-018), which names issue `#179`
  directly. Recorded as OQ-6.

#### INV-028: specs/quality-loop-fixes did not yet exist at investigation time; branch state was clean

**File**: repository root (`git status --short` on
`feature/quality-loop-fixes`)

`specs/quality-loop-fixes/` did not exist at investigation time. `git log
-1` showed HEAD `e8cdd74` = "feat: epic-159 Pillar D... (#186)"; working
tree clean. No prior work on this feature had begun.

---

## Open Questions

| # | Question | Owner | Blocking |
|---|----------|-------|---------|
| 1 | Is `validate-review-context-set.sh` genuinely R-10 protected? Current `guard_invariants.py` (INV-020) does NOT list it, contradicting the fix-stream's "protected gate script → human-copy" framing (INV-022). Should the guard's suffix list be extended to include it (and if so, is that itself an R-10-protected edit requiring human-copy), or should the fix proceed as a direct edit? | Human | yes |
| 2 | Should stream 1's fix also edit the protected `plugins/sdd-ship/skills/ship/SKILL.md` prose (Step 4, INV-004) to describe the new feature-scoped rule, or leave the prose generic and only change script behavior/tests? RT-20260712-001's `target.files` (INV-001) names `ship/SKILL.md` explicitly. | Human | yes |
| 3 | Which feature-scoping mechanism should stream 1 use — "match BOTH task id and feature slug in report contents" or "move per-feature gate reports under `reports/quality-gate/<feature>/`" (both offered as options in `expected_fix`, INV-001, lines 36-39)? The latter would also require migrating/renaming ~121 existing report files and updating every consumer that globs `reports/quality-gate/` (e.g. `emit-run-record.sh:125`, INV-007) — a much larger blast radius than the former. | Human | yes |
| 4 | For stream 2 (INV-009): 1 of 121 existing gate reports has no `^VERDICT:` line at all (pre-dates the convention). Should the fixed `emit-run-record.sh`/`.ps1` treat a missing `VERDICT:` field as `blocked+=0` (fail-open, current de-facto behavior for that file) or as a hard error / distinct counter? | Human | no |
| 5 | Should `tests/quality-gate-cycle-limit.tests.sh` also be added to `tests/run-all.ps1` and wired as an individual step in `.github/workflows/test.yml` as part of this feature (INV-005/INV-025), or is that tracked separately (matching the note about a possibly-concurrent session already registering it)? | Human | no |
| 6 | #179 has no open review ticket or WFI record (INV-027) — only a `tests/lib/loop-driver.sh` comment naming it. Should this feature's `tasks.md` cite the issue directly, or should a WFI/RT first be filed to match the other 3 streams' approval-record convention? | Human | no |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Editing `validate-review-context-set.sh` without resolving OQ-1 could either (a) trip an as-yet-unwritten guard update mid-implementation, or (b) skip a human-copy step a reviewer expects, stalling the quality gate | medium | medium | Resolve OQ-1 before task planning; if guard-invariants.json is updated to add this file, that edit is itself in `PROTECTED_GATE_SUFFIXES` (INV-020) and needs its own human-copy staging |
| Stream 1's `expected_fix` offers two structurally different remedies (grep-both vs. directory move); picking the directory-move option late would invalidate work already done on the grep-both option | medium | high | Resolve OQ-3 first; scope requirements.md to one remedy before task decomposition |
| `emit-run-record-feature-scope.tests.sh` (INV-010) does not exercise the actual WFI-010 regression scenario; a fix could pass all existing tests while leaving the false-positive intact | high | medium | New test task must add a same-feature fixture report with `VERDICT: PASS`/`NEEDS_WORK` plus a body-text "BLOCKED" substring, asserting `gate_reports.blocked == 0` |
| `.sh`/`.ps1` parity drift on any of the 4 streams (bash 3.2 empty-array / `set -u` traps per INV-026, or PowerShell explicit-exit inconsistency) could pass macOS/Linux CI locally but fail Windows CI, or vice versa | medium | medium | Follow the `tr -d '\r'`/no-branching pattern from commit `c756a5a` (INV-017) and the `install.sh` bash-3.2 guard idiom (INV-026) for every new `.sh` line; keep explicit `exit N` in every `.ps1` |
| `check-quality-gate-cycle-limit.tests.sh` is not in CI (INV-005/INV-025); a stream-1 regression could land without CI catching it | medium | high | Add the suite to `.github/workflows/test.yml` as an individual step (subject to OQ-5) as part of this feature's Done conditions |

## Recommended Next Steps

1. Resolve OQ-1 (protected-file status of `validate-review-context-set.sh`)
   and OQ-2 (whether `ship/SKILL.md` prose needs a matching edit for
   stream 1) with the human approver before writing `requirements.md`,
   since both change task sequencing and human-copy staging needs.
2. Resolve OQ-3 (grep-both vs. per-feature-directory remedy for stream 1)
   to bound the blast radius before task decomposition.
3. Draft `requirements.md`/`tasks.md` as 4 independently shippable task
   groups (one per stream), each closing its stream's existing approval
   artifact (RT-20260712-001 / WFI-010 / WFI-009) and, for #179, either
   citing issue `#179` directly or first filing a matching WFI/RT (OQ-6).
4. For stream 2, add the missing same-feature-body-text-"BLOCKED" test
   case to close the coverage gap identified in INV-010 before or
   alongside the fix.
5. For stream 4, use commit `c756a5a`'s `tr -d '\r'` pattern verbatim
   (INV-017) across all 4+ `jq -r` sites in the record-hash recomputation
   path (INV-016), then confirm `loop_validator_capability_probe`
   (INV-018) flips to `ok` on the fixed runtime as the acceptance signal —
   no test-file edits should be needed for the dependent loop suites to
   recover.
