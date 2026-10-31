| TEST-ID | `.ps1` operator(s) (this task's narrow scope: `-match`/`-notmatch`/`Select-String` only) | `.sh` counterpart mechanism | Verdict |
|---|---|---|---|
| TEST-001 | `-match` x2 (inline) | `grep -Eiq` x2 | insensitive/insensitive — match |
| TEST-002 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-003 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-004 | `-match` x1 (inline, negative half only — positive half is `-cmatch`, out of this table's scope) | `grep -Eiq` (negative half) | match |
| TEST-005 | `-match` x3 (inline) | `grep -Eiq` x3 | match |
| TEST-006 | `-match` x2 (inline; `claude.ai/design` half uses `.Contains()`, out of scope) | `grep -Eiq` x2 | match |
| TEST-007 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-008 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-009 | `-match` x1 (inline; `finalize_plan` half uses `.Contains()`, out of scope) | `grep -Eiq` x1 | match |
| TEST-010 | `-match` (via `Get-FirstLineIndex`, x4 calls) | `loop_line_of()` -> `grep -n -iE` (via helper) | match (Category B2, correct branch of a shared helper) |
| TEST-011 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-012 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-013 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-014 | none in this table's scope (both halves `-cmatch`) | `grep -Eq` x2 (sensitive) | out of narrow scope, spot-checked correct |
| TEST-015 | none (`.Contains()` x5) | `grep -Fq` x5 | out of scope |
| TEST-016 | none (`.Contains()`) | `grep -Fq` | out of scope |
| TEST-017 | none (`.Contains()`) | `grep -Fq` | out of scope |
| TEST-018 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-019 | `-match` x1 (inline; other half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-020 | `-match` x1 (inline; other half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-021 | `-match` x1 (inline, negative half; other half `.Contains()`) | `grep -Eiq` x1 (negated) | match |
| TEST-022 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-023 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-024 | none (`.Contains()` x2) | `grep -Fq` x2 | out of scope |
| TEST-025 | `-match` (via `Get-FirstLineIndex`, x2 calls; `.Contains()` for the mockups/ half) | `loop_line_of()` -> `grep -n -iE` (via helper) | match (Category B2, correct branch) |
| TEST-026 | none in this table's scope (`-cmatch` only) | `grep -n -E` (sensitive) | out of scope, spot-checked correct (also T-001's own load-bearing log) |
| TEST-027 | `-match` x1 (inline; other half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-028 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-029 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-030 | `-match` x3 (inline) | `grep -Eiq` x3 | match |
| TEST-031 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-032 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-033 | `-match` x1 (inline, positive half; negative half `.Contains()`; setup line uses `-cmatch`, out of this table) | `grep -Eiq` x1 | match |
| TEST-034 | `-match` x1 (inline; negative half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-035 | `-match` x1 (inline; negative half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-036 | none (`.Contains()` x2) | `grep -Fq` x2 | out of scope |
| TEST-037 | `-match` (via `Get-FirstLineIndex`, x1 call — the anchor search) | inline `grep -n 'design-sync-loop\`'` (sensitive, **not** via `loop_line_of()`) | **MISMATCH (Category B2)** — see finding F-2 |
| TEST-038 | none in this table's scope (`-cmatch` only) | `grep -Eq` (sensitive) | out of scope, spot-checked correct |
| TEST-039 | none (`.Contains()` x2) | `grep -q` x2 | out of scope |
| TEST-040 | none in this table's scope (`-cmatch` + `.Contains()` x5) | `grep -Eq` + `grep -Fq` x5 | out of scope, spot-checked correct |
| TEST-041 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-042 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-043 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-044 | `-match` x1 (inline; other half `.Contains()`) | `grep -Eiq` x1 | match |
| TEST-045 | `-match` x1 (inline) | `grep -Eiq` x1 | match |
| TEST-046 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-047 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-048 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-049 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-050 | `-match` x2 (inline) | `grep -Eiq` x2 | match |
| TEST-051 | `-match` x4 (inline) | `grep -Eiq` x4 | match |

Plus the two section-scoping helper definitions that underlie `$loopFlat`,
`$boundariesFlat`, `$capFlat`, `$bsiUiBulletFlat`, `$wfgSectionFlat` (read by
nearly every row above): `Get-SectionBetween` (`:249-266`, `-match` at
`:254`, `-match`+`-notmatch` at `:260`) vs `.sh`'s `section_between()`
(`:179-185`, awk `$0 ~ start` / `$0 ~ end`, unconditionally case-sensitive
for all 5 of its call-sites) — **MISMATCH (Category B1)**, see finding F-1.
