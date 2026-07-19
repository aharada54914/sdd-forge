# Baseline Behavior: quality-loop-fixes

| Field | Value |
|-------|-------|
| Feature | quality-loop-fixes |
| Date | 2026-07-19 |
| Investigator | sdd-investigator (read-only) |

## Behaviors

| BL-ID | Trigger | Observable Behavior | Evidence | Must Preserve | Verification Hint |
|-------|---------|---------------------|----------|---------------|-------------------|
| BL-001 | `check-quality-gate-cycle-limit.sh T-NNN` on a task id with word-boundary-collision-prone reports (e.g. `T-001` vs `T-0010`) | Prefix collisions are excluded from the count via `grep -rlwF` | `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:42` | yes | `tests/quality-gate-cycle-limit.tests.sh` QGCL-006 |
| BL-002 | Same script, exactly 3+ reports (post-fix: 3+ *feature-scoped* reports) for a task | Prints `Escalate-Human`, exits 1 | `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:54-56` | yes | QGCL-004/005 |
| BL-003 | Same script, 0/1/2 reports | Prints `continue`, exits 0 | `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:59-60` | yes | QGCL-001..003 |
| BL-004 | `check-quality-gate-cycle-limit.sh`/`.ps1` with a malformed task id (`T-1`, `T-0010`, `t-001`, `foo`, empty) | Usage error, exit 2 | `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:29-32` | yes | QGCL-008a-e |
| BL-005 | `emit-run-record.sh` for a feature whose task ids collide with another feature's | `gate_total`/`max_gate_runs`/`first_pass_tasks` are already scoped via the `Feature:` header grep | `plugins/sdd-quality-loop/scripts/emit-run-record.sh:123-136` | yes | `tests/emit-run-record-feature-scope.tests.sh` |
| BL-006 | `emit-run-record.sh` review-ticket severity counts | Already anchored to `^severity:` top-level field and scoped by `target.feature` (WFI-010's original header-association concern was resolved by remedy (b), INV-006) | `plugins/sdd-quality-loop/scripts/emit-run-record.sh:142-` (review-tickets section) | yes | existing suite |
| BL-007 | `prepare-panelist-input.sh` with no `Cross-Model: enabled` tasks.md flag and no valid `SDD_SUDO` token | Fail-closed: exit 1, no output file written | `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:256-260` | yes | `tests/prepare-panelist.tests.sh` |
| BL-008 | `prepare-panelist-input.sh` sanitization | Redacts credential-assignment lines, AWS/GitHub/`sk-` tokens, absolute Unix/Windows paths, and private/RFC-1918/internal URLs before hashing | `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:320-359` | yes | `tests/prepare-panelist.tests.sh` |
| BL-009 | `prepare-panelist-input.sh --effort <e>` | Effort value threaded through verbatim on a second stdout line `effort=<e>`; omitted entirely when `--effort` is not passed (single-line output preserved) | `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:406-409` | yes | AC-036 |
| BL-010 | `validate-review-context-set.sh` on a genuinely tampered/discontinuous identity ledger (wrong sequence, wrong previous hash, symlink traversal, duplicate run/session id) | Fails closed with a `REVIEW_CONTEXT_IDENTITY`/`REVIEW_CONTEXT_PATH`/etc. coded error | `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:241-265` | yes | `tests/loop-*.tests.sh` (non-degraded runtimes) |
| BL-011 | `validate-review-context-set.sh --reserve` on a valid call | Appends a new record to `reports/review-context/identity-ledger.json` via an atomic `mktemp`+`mv`, guarded by a `mkdir`-based lock directory | `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:308-337` | yes | loop-driver reservation tests |
| BL-012 | `validate-review-context-set.ps1` (any platform) | Parses JSON via `ConvertFrom-Json -AsHashtable`, not `jq` — not subject to the CRLF defect | `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:148,221` | yes | n/a (out of scope for #179) |

## Known Defects

Behaviors that are intentionally **not** preserved — these are exactly what
the 4 approved fix streams change.

| BL-ID | Defect Description | Evidence | Replacement Behavior |
|-------|-------------------|----------|---------------------|
| BL-101 | `check-quality-gate-cycle-limit.sh`/`.ps1` counts gate reports for a task id across ALL features, not just the current feature, causing false `Escalate-Human` once ≥3 features share a task id | `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:42`; `check-quality-gate-cycle-limit.ps1:39-40`; `docs/review-tickets/RT-20260712-001.yml:12-32` | Count only reports matching BOTH the task id and the current feature slug (or move to per-feature report subdirectories) — exact mechanism pending OQ-3 |
| BL-102 | `emit-run-record.sh`/`.ps1` `gate_reports.blocked` counts any feature-scoped gate report whose BODY contains the literal substring `BLOCKED` anywhere, not just reports whose own `VERDICT:` header says `BLOCKED` | `plugins/sdd-quality-loop/scripts/emit-run-record.sh:138`; `emit-run-record.ps1:149-151`; `docs/workflow-improvements/WFI-010.md:162-170` (confirmed false-positive: baseline 1, true 0, epic-159-pillar-a) | Read the report's own `^VERDICT:` header line (anchored) instead of an unanchored whole-file keyword scan |
| BL-103 | `prepare-panelist-input.sh`/`.ps1` collects only top-level files of `--input` (no recursion) and never verifies the collected bundle against the implementation report's declared-outputs table before printing a digest | `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:272` (`for f in "$input_path"/*`); `.ps1:210` (`Get-ChildItem $InputPath -File`, no `-Recurse`); `docs/workflow-improvements/WFI-009.md:58-65,119` | Verify every path in the implementation report's `## Outputs` table (INV-015 format) is present in the bundle with a matching content hash; on any gap, fail closed, print the missing list, and do NOT print an input digest |
| BL-104 | `cross-model-verify/SKILL.md` invokes panelists with no deterministic pre-panel readiness step for specification-enumerated coverage requirements | `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md:40-148` (no such step present); `docs/workflow-improvements/WFI-009.md:66-70,120` | Add a fail-closed readiness step (before Step 3, panelist invocation) that requires a machine-checkable coverage manifest (required element → exercising fixture) and fails when any element is unmapped |
| BL-105 | `validate-review-context-set.sh`'s record-hash recomputation reads `jq -r ... \| @tsv` output without stripping `\r`, so on Windows Git Bash (`jq.exe`) a trailing CR on the final TSV field corrupts the byte-exact hash comparison, producing `"canonical identity ledger record hash is invalid"` on a canonically valid ledger | `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:241-258,307` (all consumption sites); `tests/lib/loop-driver.sh:460-481` (documents the exact mechanism and cites issue #179) | Append `\| tr -d '\r'` unconditionally to every `jq -r` invocation in the file (both single-value manifest reads and the `@tsv` ledger batch read), following the proven pattern from commit `c756a5a` in `tests/lib/loop-driver.sh` |

## Environment Notes

- macOS CI's default `/bin/bash` is version 3.2: avoid `declare -A` and
  guard against empty-array expansion under `set -u`
  (`install.sh:82-83,419-420`).
- Windows CI (`windows-latest`) runs both a Git-Bash `.sh` lane
  (`jq.exe`-based) and a native `pwsh` `.ps1` lane
  (`.github/workflows/test.yml:18,27-30`); only the `.sh`/`jq` lane is
  subject to the CRLF defect underlying stream 4 (INV-019).
- `tests/run-all.sh`/`tests/run-all.ps1` are local convenience runners; the
  actual CI enforcement surface is `.github/workflows/test.yml`'s
  per-file step list, which currently diverges from both `run-all`
  scripts' contents (INV-005, INV-025) — a suite's presence in
  `run-all.sh` does not guarantee CI coverage.
- The identity ledger (`reports/review-context/identity-ledger.json`) is
  at `sequence 319` as of this investigation (INV-024); any fixture or
  regression test that reserves new records must not collide with that
  tail.
