# Candidate: same-checkout historical scratch declaration recovery

Status: proposed contract addendum, not adopted or independently approved.
Intended insertion: `plugins/sdd-review-loop/references/review-context-boundary.md`, after Feature-wide scratch reservations.

A historical implementation report containing a relative Scratch Root may be
resolved only against its independently established, canonical owning checkout,
and only when that checkout equals the current invocation owner. This recovers
a declared location, not evidence of historical execution or isolation. The old
report and ledger remain byte-for-byte unchanged. Current invocation scratch
roots and ordinary absolute historical roots retain their existing rules.

Before admission, the recovery reviewer must inspect the contemporaneous native
owner/run observation and confirm its association with the exact report. A
transcription or its SHA-256 does not authenticate that observation. Missing or
ambiguous source evidence blocks recovery. Do not export full private session
transcripts as review artifacts. A minimal locally retained observation may be
admitted only after this source inspection, with the inspection recorded in the
existing recovery declaration; it is not a signature or new approval authority.

The inspector is the independent reviewer of this authorized limited recovery,
not merely the receipt author. Inspect the native session's recorded working
directory and its tool request/result associating that owner with creation of
the exact historical report and run. Record the source session identifier and
event timestamps, the historical report digest, the three recovery-artifact
digests, the observed owner, and the review outcome in the existing recovery
review evidence. Do not claim that an observed tool result is a cryptographic
signature. The current cycle's `gate_report_declaration` must cite that completed
independent recovery review and pin its exact artifact bytes through the existing
`## Post-Fix Artifacts` mechanism alongside the report, receipt and observation.
The normal launch caller verifies that this is the authorized current-cycle
declaration before constructing admitted inputs. Missing review, an unrelated
cycle, or a review that did not inspect the native source blocks this procedure.
The deterministic validators verify byte/identity/path consistency only; they
cannot establish source authenticity from a self-authored JSON document. These
are additional admission duties, not a new review verdict or signature schema.

Use existing exact path-plus-SHA admission, including the quality declaration's
Post-Fix Artifacts channel where applicable; do not broaden role path allowlists.
Admit all three artifacts: the unchanged historical report, its deterministic
adjacent `<report-stem>.scratch-owner.json` receipt, and the minimal owner
observation. The invocation's allowed_input_manifest must bind every artifact.

The receipt has exactly these fields: report, report_sha256, raw_root, run,
session, attempt, owner, owner_observation, owner_observation_sha256. Strings
must be nonempty; attempt is a positive integer, not boolean. Duplicate JSON
keys and extra fields are rejected. The observation contains exactly owner,
run, report_sha256 and must match the receipt. Every declared digest must match
both the admitted digest and current bytes. The report has exactly one matching
Run ID, Task Attempt Count, Session ID and Scratch Root. The owner is an existing
canonical directory equal to the current owning checkout; report, receipt and
observation use existing safe-path containment checks.

The relative root permits one trailing slash, but no absolute prefix, empty,
dot or parent component, backslash, colon, CR or LF. Resolve it under the bound
owner through existing path-safety checks before existing canonical overlap
validation. Equal, ancestor and descendant roots still reject; prefix siblings
remain distinct. The historical scratch directory itself may be absent because
this check preserves the declared location, not proof that the directory ran.
Never create the old directory to manufacture evidence. All existing snapshot,
under-lock recheck, ledger identity, missing-history and altered-root rejection
rules remain unchanged. No receipt grants permission to reserve an otherwise
inadmissible reviewer.
