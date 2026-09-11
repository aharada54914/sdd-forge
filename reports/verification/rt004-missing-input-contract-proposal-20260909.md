# RT004 required-input failure contract proposal

Status: blanket Critical and new failure-schema proposals rejected for this ticket; fail-closed candidate clarification prepared. NOT applied or formally approved.
Ticket: RT-20260908-004. Historical evidence remains unchanged.

## Human evidence received

The user supplied an original workflow-only suite summary of 14 passed,
96 failed, exit 1. The supplied PowerShell B mutations returned 0 when 1 was
required, with baseline=true. This is corroborating RED evidence, not a new
candidate GREEN, a full retained raw log, or native Windows verification.

The first human comparison did not execute because rg was unavailable. The
replacement /usr/bin/grep comparison completed with exit 0. Its output cites:

- Bash candidate lines 195 and 260: Critical selects BLOCKED for reviewer
  and integrated verdicts.
- PowerShell candidate lines 113 and 118: the same Critical-based selection.
- Reviewer A lines 326 and 343-344: BLOCKED requires Critical, but an unreadable
  required input mandates BLOCKED without explicitly assigning severity.
- Reviewer B lines 323 and 337-338: the corresponding pair of rules.

These are human-collected source excerpts, not proof of patch applicability,
current source hashes, or successful execution of any candidate. They resolve
the pending comparison-data request; do not repeat the unchanged RED suite.

## Rejected interpretation — historical proposal, do not implement

For NEW ADR-extension rounds only, failure to read an already admitted,
required input is a Critical review-execution finding. The reviewer emits
BLOCKED and explicitly records that this classification concerns inability
to complete the review, not a demonstrated Critical defect in the product.
Do not infer absence merely because an input is outside the allowlist.
Missing authorization must stop at admission, without expanding that list.

Preserve Critical-based verdict derivation and complete ordered check IDs;
do not introduce a free-form BLOCKED override, infer severity from a message
substring, or accept incomplete outputs. The unreadable-input finding must
attach to the actual affected check under the existing output schema. Checks
whose prerequisites could not be read must not claim PASS. Determining the
schema-valid representation for unevaluable checks is a prerequisite to
applying this proposal, not permission to manufacture check results.

Keep no-extension historical semantics unchanged. Never retrofit severity,
checks, manifests or verdicts into prior reviews. Preserve their FAILs.

## Rejected proposal's validation plan — not current instructions

1. Confirm this execution-severity clarification is compatible with calibration
   and both complete output schemas. If not, reject this proposal and design
   a versioned execution-failure representation rather than weakening checks.
2. Cover A and B separately: an admitted unreadable input produces complete,
   schema-valid Critical/BLOCKED evidence accepted by all relevant consumers.
3. Negative controls: Major-only BLOCKED; Critical with PASS/NEEDS_WORK;
   arbitrary BLOCKED prose; missing, duplicate, reordered and unknown IDs;
   missing finding; stale summary or integrated counts; unadmitted input.
4. Confirm one-round summaries, integrated verdict/counts and downstream task
   validation agree in Bash and PowerShell. Preserve legacy positive fixtures.
5. Independent security/contract review precedes protected human application;
   original-path GREEN and native Windows results remain separately required.

No role file, runtime validator, candidate patch, historical review, task state
or ticket status was changed by this proposal. RT004 is still open. CI and
main integration remain incomplete.

## Independent advisory disposition

Reviewer: /root/rt004_check_contract_review, existing independent agent,
read-only review of this proposal only. No previously denied source reread.
Outcome: direction plausible, NOT application-ready or formally approved.

The reviewer identified unresolved calibration compatibility: execution
Critical may contaminate product-defect counts if the existing calibration
does not admit that meaning. Also, a single unreadable input may prevent
several checks; neither arbitrary SKIP nor unsupported PASS is acceptable.
These issues must be resolved from the actual schema/calibration contract,
not from the word BLOCKED alone.

Clarification adopted: validating the structure of saved execution-failure
evidence does not authorize a launch with missing or changed live inputs.
Current admission and hash freshness must still fail closed independently.
Extend regression requirements to loss of readability after precheck,
multiple checks depending on one unavailable input, and preservation of
checks genuinely evaluated from still-available inputs. No production
severity rule is changed until these compatibility questions are resolved.

## Calibration inspection and disposition

The local calibration was read in full. Its Precheck Separation section
(`plugins/sdd-review-loop/references/reviewer-calibration.md:77`) assigns
invocation validity and mechanical failures to prechecks and prohibits
duplicate substantive findings for precheck-owned failures (line 82).
Cannot-Verify Handling limits SKIP to explicit applicability conditions
(line 92) and explicitly allows BLOCKED for missing required inputs or invalid
invocation context (line 101). Severity Calibration (line 105) does not make
every input-read failure a Critical product finding.

Therefore the initial interpretation above is NOT adopted. Missing input
alone does not justify Critical, fabricated FAIL entries, or SKIP entries for
otherwise applicable checks. The source excerpts expose a contract ambiguity;
they do not establish that either alternative is already implemented.

### Deferred separate design option — not required or authorized by this ticket

Separate review execution failure from a completed substantive review using
an explicitly versioned, tagged failure record. A failure record must bind
the same round, reviewer identity, admitted manifest and expected input hash,
and identify the admitted path and failure phase (before review or after
successful precheck). It records an execution failure, not a product finding.
Paths not admitted by the contract must never become authorized by this record.

Completed review outputs retain their exact ordered check set, existing
severity rules and computed verdicts. Partial observations, if retained, are
diagnostic only: they cannot satisfy check completeness or contribute invented
product counts. Failure-record structural acceptance must be distinguishable
from gate success: it always prevents stage PASS and downstream admission.
An independent admission failure remains a failure even when a saved failure
record is structurally valid. Unknown versions and mixed success/failure
shapes must be rejected, not silently interpreted as legacy review output.

No existing historical output is converted. Define the exact schema and all
consumer transitions together before implementation. Required additional
negative fixtures include forged/unbound failure records, mixed shapes,
unknown versions, failure plus integrated PASS, and partial observations
masquerading as a complete review. Existing ID-mutation failures still need
their own GREEN verification; this design issue does not excuse them.

This amendment only updates a non-frozen diagnostic proposal. No validator,
role, candidate patch, test expectation or review verdict has been changed.

## Final scoped disposition after independent advisory review

The existing independent reviewer /root/rt004_check_contract_review read this
proposal, RT004 and the calibration, and recommended against requiring the
replacement schema above. RT004 requires complete ADR binding and safe
rejection, not formally consumable interrupted reviews. The replacement-schema
section is therefore a deferred separate design option, NOT a prerequisite
or implementation instruction for this ticket.

Adopt the smaller fail-closed boundary: retain interruption diagnostics and
actual BLOCKED outputs without accepting them as completed review evidence.
No manufactured Critical, PASS, FAIL or SKIP, no stage PASS or downstream
admission, and no automatic reset/reuse/deletion of old reservations. A valid
completed extension review still requires fixed A11/B11 ordered checks and
all manifest/summary/verdict bindings. Old no-extension behavior is unchanged.
The general historical BLOCKED/Critical wording conflict is not claimed fixed.

The boundary and orchestration sections of the unapplied DATA patch
adr-contract-docs-candidate-20260908.patch now express this distinction.
No production file was modified. Existing missing-ID tests keep their expected
rejection. Additional interruption tests must assert fail-closed behavior,
not acceptance of an invented failure envelope. Full consumer coverage,
independent bundle review, human protected application and runtime GREEN
remain necessary. This advisory review is not a formal gate result.

The same independent reviewer subsequently read the actual changed patch DATA
and found no added schema, weakened checks, recovery authority or contradiction
with completed-review requirements in these new paragraphs. Its minor heading
clarification is incorporated above so rejected plans cannot be mistaken for
current instructions. This was a limited textual review, not hash verification,
execution, full consumer consistency review or formal gate approval.
