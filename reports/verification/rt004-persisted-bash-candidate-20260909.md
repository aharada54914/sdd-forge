# RT004 persisted Bash consumer — partial candidate

Date: 2026-09-09
Status: incomplete; no formal verdict, product application, commit, push or merge.

Candidate: `adr-persisted-bash-candidate-20260909.patch`
SHA-256: `0432bc8486bca2e54ff0e0f819795462bafcd9389d930e7f93a86c0702d5fe0d`

The actual shared consumer `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh`
has an independent allowed-input predicate at line 113, with its calibration
branch at line 136. Admission changes alone do not authorize declared ADR inputs
in this predecessor check.

The patch-data candidate connects the impl predecessor check to paired
precheck/contract extension validation. It requires matching core and layer
pins, canonical identity, both reviewer manifests, complete design-derived ADR
sets and current ADR hashes before adding paths to the existing allowlist.
The absent-extension path does not authorize ADR inputs. The helper is only for
current PASS evidence; it must not be reused for historical NEEDS_WORK evidence.
Removed an unused copied collection helper and declared sha256_stream as a
dependency of the including scripts.

## Checks and unresolved findings

- Five patch hunk counts/cumulative offsets and all removed source anchors
  matched the freshly read shared library. This is data-level verification,
  not application or execution of protected code.
- Review identified missing precheck/contract identity and core/layer equality;
  these conditions were added to the candidate before ADR file reads.
- Runtime regressions, formal independent review and native parity were NOT run.
- Warning: legacy compatibility of the earlier safe-file checks needs tests.
- Warning: duplicate JSON object keys and concurrent evidence replacement remain
  review/test concerns; no tamper-proof or TOCTOU-proof claim is made.
- Warning: Bash Windows reparse handling is unresolved.
- The separate Bash generation candidate has stale line anchors relative to
  current metadata (shared-source comment now line 51, design hash now line 214).
  Do not treat it as an applicable human package without authorized re-anchoring.
- PowerShell persisted consumers, workflow-state consumers, ADR-only next-round
  behavior and their actual-consumer regressions remain incomplete.

No copied, renamed or extracted validator was executed. Existing failed evidence
is retained. This is not a complete RT004 fix or a human-ready application bundle.
