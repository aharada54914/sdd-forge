# Issue #423 T-002 limited additional correction

Date: 2026-09-28
Run ID: sdd423-t002-nested-state-extra1-20260928
Task Attempt Count: 1
Prior Correction Count: 3/3
Additional Correction: extra1 (one scoped correction and one independent review)

## Authorization

The human user granted the limited additional correction in the user channel:
「A9復旧計画の3タスクを承認した　追加修正の限定承認する」.
The preceding proposed scope included Issue #423's nested credential/state
boundary correction in the shared validator. The root coordinator matched
this grant to that proposal on 2026-09-28. No exact time or message ID was
available; neither is inferred here. The earlier 3/3 correction history and
Task Attempt Count remain unchanged.

## Scope and root cause

`contracts/provider-bindings.schema.json` owns the exact keys `credentials`
and `state_authority`; ADR-0018 section 4 defers their inner vocabulary.
REQ-002 excludes provider credentials and state from Capability data.
The existing Registry predicate schema allows arbitrary `value` objects.
The shared validator's check (g) recursively inspects dictionary values but
does not inspect keys, so empty or provider-neutral values under these keys
escape the boundary. POSIX/PowerShell dispatchers and the project resolver
already call this same Python validator.

The correction rejects those two exact keys anywhere in the existing
recursive check (g), preserving its diagnostic ID and provider-name scan.
No schema, vocabulary, approval, task status, frozen spec, or formal review
verdict changes are part of this correction. T-001 is Implementation Complete,
not Done; downstream task execution and formal quality verification remain
pending.

## Verification

Actual command output is preserved in `nested-state-extra1-evidence.json`.

- RED: the new focused suite ran 5 methods with 12 failing subtests. Each
  forbidden-key fixture was accepted without diagnostics before the repair.
- GREEN: the same focused suite passed 5/5 methods; the full ownership suite
  passed 28/28 methods. The regression covers trigger and conditional-facet
  predicates through all/not/any, dictionaries and arrays, and empty/null/false
  forbidden-key values. Provider-neutral nested values and non-exact key names
  remain accepted.
- Existing POSIX and PowerShell validator suites each passed all 27 checks,
  including clean input for all nine validator checks. PowerShell ran on this
  local host, not native Windows.
- `check-sdd-structure.sh` and `git diff --check` passed. The nine frozen feature
  artifacts retain their pre-correction hashes; schemas and wrappers are
  unchanged.
- Optional real-registry validation through both dispatchers returned exit 1
  with the same existing catalog/inventory diagnostics: missing
  `check-update-migration.py` and unregistered `check-component-coverage.py`,
  `check-contract.py`, `check-criterion-freeze.py`, and
  `check-hook-activation-handshake.py`. No provider-contamination diagnostic
  occurred. These registration surfaces are unchanged by this correction.
- A read-only attempt to re-execute the HEAD validator baseline was refused by
  the deterministic PreToolUse gate before execution. No alternate execution
  path or tool was attempted. Runtime baseline equivalence is unverified;
  the refusal and current dispatcher output are recorded separately.

## Remaining boundaries

The root coordinator independently reviewed the shared recursive check, its
callers and the exact-key negative/neutral-value positive regressions. The
coordinator also executed the full boundary suite: 28/28 passed, exit 0, with
no scoped diff findings. This is an independent code-diff review, not formal
quality-gate verification.

This addendum is not a quality-gate PASS or a Done decision. No task approval,
execution status or formal review verdict was changed. The
previous whole-vendoring-check refusal remains unresolved; it was not retried
or bypassed. Native Windows, formal quality-gate, and downstream-task evidence
are not supplied by these local checks.
