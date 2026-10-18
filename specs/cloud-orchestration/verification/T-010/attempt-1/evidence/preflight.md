# T-010 pre-production preflight constraint

Run/session/agent: `01a14f33-2447-79d0-8195-087bbe42669c`.
Classification: synthetic protocol diagnostics; no live evidence or new authority.

## Decision and chronology

No production file was edited. The requested preflight is **incomplete**.
The caller specifically requires reporting a mandatory preflight body that cannot
be exercised before the proposed production change. This is that report, not a
waiver. Task status and approval remain root-owned and unchanged.

1. Read the task first; canonical T-010 report was absent. Read required specs,
   local Ponytail full, ECC coding/security/verification and blast-radius guidance.
2. Snapshot existing dirty candidate bytes, create and validate the input manifest.
3. Exercise existing callable primitives with an urllib network sentinel.
   The first diagnostic fixtures lacked directly referenced files and stopped at
   `UNSAFE_OR_UNAVAILABLE_FILE`. Retain `probe-initial.json` and
   `probe-setup-error.json`; neither is mismatch-validation evidence.
4. Fix the diagnostic fixture references (not production), then execute all 40
   provider/stage/variant bodies in `probe.py`. `probe.json` records actual
   stopping points. Empty-predecessor controls perform one synthetic callback per
   provider/stage. No cloud call is made. Nonempty cases perform zero callbacks.
5. Run 14 existing control/mismatch tests before and after the diagnostic changes.
   Existing T-009 in-process collector tests produce PASS only through mocked
   native-class transports; the saved-file consumer still returns BLOCKED.
6. Exercise a valid original apply completion and a verify-job-shaped record
   through the existing completed-job primitive. The latter stops at
   `ORIGINAL_APPLY_JOB_REQUIRED`, before verify-specific job/step provenance.
7. Stop before production edits, actual implementation Red commit, or any claim
   that predecessor admission fields have been validated. No component-absence,
   fixture-setup failure, or blanket denial is relabeled as field-guard execution.

## Field / counterpart / failing mismatch preflight

The table includes intended receipt consumption and orchestration claims; it is
not a new wire schema. No new runtime evidence fields were persisted this turn.

| Field or claim | Counterpart | Executed mismatch / exact limit |
|---|---|---|
| Predecessor `path`, `sha256` | Exact contained receipt bytes | `tamper` reaches `DIGEST_MISMATCH`; `missing` reaches `UNSAFE_OR_UNAVAILABLE_FILE`; local-pass passes these integrity checks. Both providers/stages. |
| Predecessor `unit_id` | Referenced verification `unit_id` | `wrong-unit` reaches `PREDECESSOR_MISMATCH`; local-pass passes that comparison. Not producer authentication. |
| Verification `run_id` | Receipt evidence path and configured original request/run | `wrong-run` reaches `PREDECESSOR_PATH_MISMATCH` only. No configured authenticated expected predecessor run exists at this boundary yet. A coherent wrong-run/path substitution remains untested. |
| Verification `provider` | Protected predecessor provider/scope configuration | `wrong-provider` and local-pass both stop at `DEPENDENCY_ADMISSION_REQUIRED`. No executed provider counterpart guard. |
| Profile id/version/digest, selected checks, registry hash | Protected cloud-compute v2, verification-contract/v3, selected-verification-plan/v2 | `wrong-profile` and local-pass both stop at the blanket seam. Existing collector/profile controls pass, but cannot authenticate a later receipt reader. No predecessor profile guard execution. |
| `overall_result`, `evidence_complete`, operation state/result | Genuine verified producer output and reducer result | `failed`, `incomplete`, and locally asserted PASS all stop at the blanket seam. This is safe default denial, not outcome sensitivity. |
| Classification / collector provenance | Authenticated successful protected verify workflow/run/job/code + acquisition | Existing in-process native-class protocol double passes and saved consumer blocks. Completed-job primitive's apply control passes; verify-shaped job fails at `ORIGINAL_APPLY_JOB_REQUIRED`. No matching verify-producer admission control is reachable. |
| Artifact ID/digest/run and exact request digest | Authenticated immutable GitHub artifact + protected original verify producer | Existing governed acquisition is reusable, but artifact existence/digest cannot prove successful verification. New consumer is absent; no integrated producer/acquisition mismatch body executed. Nullable artifact digest is not proof. |
| Completion/collection/sample times and max age | Protected profile freshness and producer completion window | Existing reducer freshness/window tests pass. Dependency receipt carries no timestamp itself; there is no authenticated predecessor context admission path to exercise before implementation. |
| Scope, dependency lock, policy, native operation/principal, observation/result digests | Bound original request, collection context and native producer evidence | Existing reducer mismatch tests pass. Not evidence of a new cross-run consumer comparing those fields to external trust pins. |
| Required units/edges and deterministic ordering | Validated graph (duplicates, self, missing, cycles, transitive failures) | No dependency ordering callable exists. No graph guard body/control executed. No missing-import Red invented. |
| A bytes preserved; B failure; C zero prepare/apply; aggregate not VERIFIED | Three actual adapter/dispatcher unit outcomes | Mandatory scenario not executed; no orchestration implementation or acceptance claim. The diagnostic callbacks are not adapter-unit acceptance. |
| UNKNOWN and original operation IDs | Provider reconciliation journals and no write retry | Existing behavior not changed. No new dependency-order/reconciliation acceptance executed. |
| Every shared write revalidates predecessors | Immediate pre-submit boundary on every prepare/apply native mutation | Every nonempty request currently stops before authentication. Revalidation/sensitivity tests against an admitted predecessor cannot run before replacing that seam. |

## Concrete constraint for root

`cloud_authorization.py:Policy` has no protected predecessor configuration and
`WriteBoundary.write` rejects every nonempty set at `DEPENDENCY_ADMISSION_REQUIRED`.
The existing `cloud_verification.saved_profile_plan` intentionally rebuilds a
BLOCKED plan (`fresh=False`); its result cannot be overridden as a provenance flag.
`azure_observation.original_apply_completion` authenticates only the original
**apply** job. Reusing it as a verify proof would change its meaning and must not
be done in a test or called a valid matched control.

Thus the complete mandatory verify-producer field/counterpart/matched-control
preflight cannot currently be executed at the intended dependency admission
boundary before production edits. The limited integrity mismatches above are
real, but do not satisfy that missing provenance preflight. Root needs to resolve
how the new callable is to be introduced while preserving the requested
preflight chronology, then resume implementation. Do not weaken receipt
acceptance or treat local PASS/native labels as authorization to resolve it.

## T-008 configuration addendum (not implemented)

No new configuration fields were introduced. Current request predecessors are
strictly `{unit_id, path, sha256}`; the current external Policy does not carry
foreign verify-workflow/scope pins. A future consumer must use explicitly
protected configuration for the expected producer workflow/code, original run/job,
artifact acquisition and exact request/profile/provider binding wherever these
cannot be authenticated from existing policy. This note deliberately does not
invent field names or owner pins. Each provider must remain installable alone
with the shared modules; importing the other provider for acquisition is not an
acceptable implementation shortcut.

OQ-001 still blocks live acceptance: owner scope, federation/IAM, bootstrap,
images, health/backup, budget and retention are absent. No cloud actions,
destruction, automatic rollback, release action or independent review occurred.
