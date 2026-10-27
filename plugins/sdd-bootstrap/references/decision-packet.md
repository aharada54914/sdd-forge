# Passive decision packets

`scripts/workflow-playbook.py --request request.json` reads a
`workflow-playbook-request/v1` and returns one `workflow-playbook-route/v1` to
stdout. It does not execute work. Unknown fields/flags/purposes, effects exceeding
the selected purpose and unbounded run/time budgets exit 2. The request contains
the track already selected by existing routing; no playbook can downgrade it.
Only read the returned playbook. Requests without a playbook keep existing behavior.

`scripts/decision-packet.py --root ROOT --packet relative.json --feature FEATURE
--task T-NNN --run-id RUN --packet-sha256 DIGEST [--format json|markdown]
[--decision-id ID --choice-sha256 SHA]`
validates `decision-packet/v1` and prints a passive display. DIGEST is SHA-256 of
UTF-8 canonical JSON (sorted keys, no extra whitespace, Unicode unescaped), fixed
by the consuming parent when selecting the packet, not taken from the packet.
Duplicate JSON keys, nonregular/symlinked paths, changed source hashes, changed
packet bytes after selection, wrong targets and more than three options fail.
All paths are repository-relative; no preview is executed or fetched.

Each option has preview/diff pins and observations with explicit outcomes:
success, failure, timeout, cancelled, not-run or unknown. Observations report the
referenced source and are not newly certified run results. Missing execution
evidence is allowed only for not-run/unknown with a reason. Executed observations
also require `measurement: {directory, span_id, run_id, records}`. `records` pins
the complete measurement JSON inventory; reduction consumes a private snapshot of
the admitted bytes. The existing measurement reducer rechecks original artifacts.
Its feature/task/run, parent run, variant and selected input/preview/diff/task pins
must match this packet; the declared outcome must equal the measured span outcome,
and the displayed evidence must be one of that span's logs. This checks provenance
consistency of passive observations, not host authenticity or gate success.
Recommendations,
initial hypotheses, counterevidence, unknowns and residual risks are separate.
Text is escaped for display; artifact paths and hashes are shown without executing
HTML or untrusted Markdown links.

`approval` pins the current `specs/FEATURE/tasks.md`; this is freshness binding,
not approval validation. Existing task/sidecar/gate checks still own authority.
For concept decisions set `concept_test: true`: the renderer delegates to the
existing concept-test validator, including its signature and approver checks.
Concept outcomes are displayed separately from alternative choice. Without a signed
choice, the alternative human decision stays `pending`; packet-supplied human,
approval or Done fields are rejected.

For adopt/reject/hold, a human prepares immutable
`specs/FEATURE/decisions/ID/decision-choice.json` using `decision-choice/v1`:
`decision_id`, `feature`, `task`, `run_id`, `packet_sha256`, `alternative`, `choice`,
`reason`, `valid_until` (timezone-bearing timestamp), and `previous` (null or pinned
`record`/`approval` references). The existing **human/CI-only**
`generate-approval-sidecar` issuer accepts schema
`sdd-decision-choice-approval/v1`, `--repo ROOT --feature FEATURE --decision-id ID`
and this canonical `--content` location, with its usual approver/status/staging
arguments. Existing Bash/PowerShell wrappers dispatch the same implementation.
The existing human publisher installs `decision-choice.approval.json` and
`decision-choice.approved.json`. It does not turn this choice into task approval.
The signer refuses an ID with existing signed companions; changes use a new ID
and signed history references. The first record has null previous; later records
must pin the sole current signed head for the same feature/task. Disconnected
successors, changed history and replay of a superseded choice fail. Live publication
journals block reading choices until publication completes. Keys remain under the existing human authority;
never invoke the issuer or fabricate human input from an agent product flow.
Each retained signed choice requires its content, approval and byte-identical
approved snapshot; missing companions block selection. Removing both signed
companions leaves no local evidence that a draft was once signed, so repository
retention and access controls remain necessary.

The packet reader optionally accepts the caller-selected ID and byte SHA-256 of
that choice. It reuses existing HMAC/schema/registered-approver validation, checks
expiry and packet/target/run/option bindings, retains signed rejection/hold reasons,
and rejects selection of a record with a signed successor. History validation is
bounded to 32 predecessors and 128 retained records per feature; larger histories
require an explicit design change, not silent truncation. Human-owned choice,
signature and approved snapshots must be retained. This is a signed display record,
not another task approval or execution engine. A concept rejection cannot be
overridden by an alternative's adopt choice.

History uses a hash-pinned previous packet with the same feature/task. Its original
inputs are not required to match today's state; old rationale remains inspectable
but cannot authorize continuation. Write new immutable packet files, then select
their digest explicitly. The tool writes only temporary private reduction snapshots,
never project files, approvals, notifications or task status. Measurement spans for
packet preparation, review and wait remain
separate `sdd-run-measurement/v1` observations owned by the existing measurement
helper; do not treat rendering duration as human confirmation time.

`scripts/factory-adapter-readiness.py --root ROOT` prints a read-only
`factory-adapter-readiness/v1` capability inventory with pinned existing executor
sources. Missing durable admission, restart/lease, reservation, cancellation and
budget guarantees remain `not-demonstrated`; this probe cannot admit work or grant
parallel execution. See ADR 0043 for the adapter stop condition.
