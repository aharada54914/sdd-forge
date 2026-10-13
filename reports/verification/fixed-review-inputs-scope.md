# Fixed review inputs: successor scope

Status: opt-in fixed-input materialization, diagnostic/formal launcher binding,
and authenticated detached review approval/progress consumers are implemented.
Canonical Bash precheck integration passed its seven focused tests. Detached review
progress does not grant task approval or mark a task Done.

## Integration update (2026-10-13)

The following supersedes the earlier implementation-status statements below,
without changing historical evidence. The fixed source map is now consumed by
the Bash and PowerShell specification, implementation-policy and task prechecks.
Selected specification inputs come from the authenticated Git snapshot;
generated review evidence remains live and hash-bound. Current regression results
are recorded below; platform equivalence and native model delivery are not implied.

`fixed-review-state.py` records authenticated review progress separately and
verifies its approval, inventory and scope. Its `completed` value records review
progress only; existing task lifecycle and quality-gate authority remain intact.
Migration of legacy task approval/Done writers is not claimed. No frozen review
artifact or historical verdict was rewritten.

## Current verification (2026-10-14)

The owner ran the following suites successfully (147 tests, all exit 0):

| Suite in tests/ | Passed |
| --- | ---: |
| fixed-review-inputs.tests.py | 33 |
| fixed-review-state.tests.py | 7 |
| fixed-review-launch.tests.py | 44 |
| unified-task-launch.tests.py | 9 |
| fixed-review-precheck-bash.tests.py | 7 |
| host-review-preflight.tests.py | 21 |
| review-conditional-inputs.tests.py | 17 |
| unified-launch-order.tests.py | 9 |

Fixed approval/state verification and actual canonical Bash precheck consumers
are connected. Selected documents are read from the Git snapshot, not required
to match mutable working-tree documents. Generated evidence is still live and
hash-bound; stage dependencies are explicitly selected. Reviewers receive Read
permissions, not hash-only Bash work. The independent reviewer reran all 44
launch tests after two findings were repaired and returned PASS. See the adjacent
independent-review record for the limits of that result.

The user waived Windows/macOS equivalence validation: NOT RUN, not PASS.
Native model delivery, latest-head CI, commit/push/merge and full task lifecycle
migration are not established by these tests. Existing lifecycle writers retain
their authority; detached progress cannot grant Approved, PASS or Done.

## Historical verification (2026-10-13; superseded implementation status)

The following records the earlier incomplete slice, not the current implementation.

Owner reran `python3 -B tests/fixed-review-inputs.tests.py`: 27 tests passed,
exit 0. Owner reran `python3 -B tests/fixed-review-launch.tests.py`: 36 tests
passed, exit 0. `git diff --check` passed. Both drivers are registered in
`tests/run-all.sh` and the shared contract CI job; CI has not been run.
The launch tests cover matching diagnostic/formal arguments and permission
policy, rejection before reservation, and refusal of added Bash permissions.
The real Node session guard admits selected snapshot and invocation reads, and
rejects live/outside reads, writes, hash/compound Bash commands, malformed events,
and changed policy bytes or pins. Structured output remains allowed. These are
local process tests, not a claim that a real model obeyed the launch contract.
The normalized-task admission test mocks canonical precheck success; it is not
end-to-end evidence for that precheck.
Fresh-context independent integration review completed for the fixed-input and
launcher slice, with no must-fix findings. See
`fixed-review-inputs-independent-review.md`; this does not approve the still
unimplemented detached approval/progress contract. Intermediate failing launch tests during
editing are superseded by these reruns, not erased.

The user waived Windows/macOS equivalence validation for this work. Those
cross-platform checks are NOT RUN, not PASS. Local tests do not establish real
CLI delivery. No new approval, reservation, Done status, commit or merge is
claimed by this record.

Fixed mode still requires selected canonical bytes to match the snapshot for
legacy prechecks. Fixed mode now pins explicit stage dependencies rather than
both entire plugin trees; legacy mode retains its existing dependency selection.
Therefore separate
state and narrowly scoped invalidation are still unfinished, even though fixed
reviewer reads and launcher-side identity verification are connected.

## Historical local regression evidence (2026-10-12)

Pending statements in this section describe that earlier slice; current caller
integration and regression results are recorded in Current verification above.

Independent review follow-up (2026-10-13): running Git from a nested checkout
directory selected that directory's blob while recording a repository-relative
path. A fixture with different root/nested `spec.md` bytes reproduced this
(18 tests, one failure). Adding `ls-tree --full-tree` corrected the shared reader;
all 18 tests passed (exit 0), including revision verification from both locations.
This does not establish caller integration or approval authentication.

Follow-up: three revision-binding tests first failed because `verify_revision`
was absent (17 total, three errors). Extracting the existing Git reader and
comparing the selected inventory against the caller-supplied commit and required
paths produced 17 successes, zero failures. This rejects a self-consistent
replacement of both snapshot bytes and inventory, a different commit with the
same contents, and missing required inputs. Inventory verification alone is not
approval authentication. Actual launcher integration remains pending.

`python3 -B tests/fixed-review-inputs.tests.py` first produced five successes
and one error: inherited `GIT_DIR` redirected lookup despite the explicit `-C`
repository. Removing inherited `GIT_*` selectors from the materializer subprocess
environment produced six successes, zero failures (exit 0). The fixture uses a
separate empty Git repository; no credentials or reviewer ledger are involved.
The existing fixed-commit, dirty-checkout, replacement-object, invalid-path and
destination-preservation cases also passed. This is prototype evidence, not
formal delivery or product-hook activation. Additional gitlink rejection and
nested executable byte/mode/inventory cases passed: eight tests, zero failures,
exit 0. Actual caller regressions are still required.

## Authorization and initial implementation scope (2026-10-12)

The user explicitly permits independent Codex review in a fresh context with
evidence outside the legacy formal ledger, and does not require product hook
activation for repository development. These exceptions supersede the entry
blocker below, not its historical observations. Authentication may be copied
into the isolated validation host, but absence of usable credentials blocks only
that native-host experiment, not local implementation or independent review.

The first implementation slice began with Git input materialization. Its persisted
inventory fields are commit, relative path, blob SHA-256 and executable mode;
their counterparts are the selected commit's tree and materialized bytes/modes.
Regression cases must reject missing inputs, path aliases, symlinks and gitlinks,
and demonstrate that dirty working-tree bytes cannot replace selected blobs.
The helper grants no approval and performs no reservation. Opt-in launcher
connection retains existing admission and reservation checks; it does not
introduce a new approval type. Remaining preflight rows below must be satisfied
before admitting separate authenticated state. That initial restriction is now
satisfied for review observations by the fixed-state and launch regressions;
task lifecycle migration remains outside the implemented observation contract.

## Authority and ownership

The user approved the four-point successor architecture and instructed that
Claude evaluation is not required. This does not authorize fabricated review
identities, retrospective reservations, altered historical evidence or removal
of required protection. The predecessor task plan explicitly excludes this work
(`specs/shared-review-launch-repair/tasks.md`, Scope boundaries).

- Owner branch: `codex/fixed-review-inputs`.
- Owning checkout: `/tmp/sdd-shared-launch-public-20261011`.
- Baseline commit: `9b16ffba39a090cd3cf2305e986341e24096b835`.
- Initial worktree: clean; no other worktree is modified.
- Classification: high risk (approval binding, evidence identity and launch).
- No installation, global permissions or trust changes are part of this work.

## Proposed migration contract

1. Resolve a supplied Git revision to a full commit ID. Admit an explicit,
   canonical, duplicate-free relative path set from that commit. Reject missing
   required dependencies, symlinks, submodules, traversal and case aliases.
   Materialize those Git blobs into a new read-only snapshot; do not copy working
   tree bytes or switch the user's checkout. Preserve original repository-relative
   paths in the snapshot. Bind commit, selected paths and content hashes.
2. Store new progress, authenticated approvals and review results outside the
   snapshot. Preserve the existing canonical identity ledger and all historical
   records. Existing documents remain readable through the legacy path; no bulk
   rewriting or automatic conversion of historical approvals is allowed.
3. Use one launcher-side admission operation for diagnosis and formal delivery.
   It verifies selected inputs, required dependencies, permission boundaries and
   reviewer identity before the existing reservation step. The reviewer receives
   the admitted read-only snapshot, not a Bash hash-verification assignment.
   Launcher delivery validation must still prove use of the admitted input set;
   removing the old reviewer command must not remove that check.
4. New approval evidence must authenticate the exact commit, reviewed path set
   and stage using the established approval authority. A commit ID alone is not
   sufficient authorization. Unrelated working-tree changes and result writes do
   not invalidate the selected snapshot. Selected content changes require new
   approval; no automatic inheritance to another revision is implied.

Generated summaries and evidence consumed by the next reviewer remain separately
hash-bound at admission. Stage-specific required-input selection, authentic
approval, reviewer isolation and ledger uniqueness/locking remain mandatory.
Snapshots are never a replacement for those checks. Missing admission evidence
must stop before reservation, without consuming an identity.

## Required connection points

- `plugins/sdd-review-loop/scripts/launch-impl-review.py`: real launch ordering,
  scoped identity checks and reservation boundary.
- `plugins/sdd-review-loop/scripts/preflight-host-review.py`: shared admission.
- `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`: delivery
  prompt, permissions, transcript validation and legacy control-command path.
- `plugins/sdd-review-loop/scripts/probe-nontty-review.py`: diagnosis uses the
  same admission and permission assembly as delivery.
- Context validators and review prechecks: explicit new binding contract, with
  unchanged legacy interpretation; no silent v2 schema widening.
- Spec, implementation-policy, task and quality-gate callers: choose the admitted
  snapshot and separate output root consistently.
- Approval verifier: authenticate revision/path binding rather than accepting an
  unsigned state file. Existing sidecar types are not a generic review approval.
- Permanent tests and CI: exercise diagnosis and actual launch ordering, not only
  a snapshot helper.

## Required RED/GREEN and persisted-field preflight

Before implementation, record and execute a failing mismatch test for each row.
Inventory/revision and launch mismatch tests have been executed as recorded
above. Authenticated review approval and observation rejection cases are covered
by the current fixed-input/state/launch suites. The original task-lifecycle row
below is not implemented: observations deliberately cannot grant Approved or
Done, and existing task lifecycle authority remains unchanged.

| Persisted field | Counterpart | Required mismatch rejection |
| --- | --- | --- |
| commit and path/blob inventory | Git tree and materialized snapshot | changed/missing blob, wrong revision, duplicate or escaping path |
| authenticated approval binding | admitted commit, paths and stage | replay against changed selection, invalid signer, unsigned approval |
| generated dependency digest | next reviewer's admitted dependency | substituted summary or evidence |
| admission receipt | formal delivery inputs and permissions | diagnosis succeeds but launch selects different inputs or rights |
| run/session identity | canonical ledger and host receipt | duplicate identity, stale tip, concurrent reservation |
| separate progress record | fixed task identity and legal transition | unapproved transition or modified task body |

Positive coverage must include unchanged selected inputs with unrelated changes,
result-only writes, legacy invocation parity, and required stages on both Bash
and PowerShell where not covered by the explicit OS-equivalence waiver above.
Negative coverage includes unsupported CLI options, missing
dependencies, outside reads, compound commands, and mutation between admission
and reservation. Run isolated rollback and an independent diff review before CI.

## Historical formal-review launch capability and entry blocker (2026-10-12)

`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`, Independent reviewer
sequence, requires non-Claude hosts to allocate an empty idle context, obtain a
host-issued identity, reserve it, and only then start its first model turn. It
explicitly stops hosts unable to separate allocation from execution.

The currently exposed collaboration `spawn_agent` API starts an agent with its
initial task; it provides no allocate-idle operation or pre-start host identity
receipt. A normal spawned review therefore cannot be claimed as that formal
review. No reviewer has been spawned or retrospectively reserved here. Claude
evaluation is excluded by the user's latest instruction.

The Codex app-server diagnostic subsequently allocated an empty ephemeral
read-only context with approvalPolicy=never and no model turn. This demonstrates
an allocate-before-execute mechanism, not a formal identity receipt or review.
The diagnostic context was terminated; a formal invocation needs a fresh context
and the existing admission/ledger binding. Claude remains excluded.

The earlier bootstrap entry check is currently blocking. The bootstrap skill
at lines 194–208 requires a real canary denial and stops on any outcome other
than HOOK_ACTIVE. A real apply_patch call created the canary in this checkout;
ls confirmed a one-byte regular file. Only that probe-created file was removed.
The raw tool result is retained in fixed-review-inputs-canary-result.json.
Passing that raw object directly first returned exit 62 (missing evidence nonce);
the explicit observed-result envelope in fixed-review-inputs-canary-observation.json
then returned exit 63, CAPABILITY_RUNTIME_UNAVAILABLE / WRITE_EXECUTED.
Neither result is a successful activation or a formal review. This is consistent
with the user's removal of the installed plugin, not a reason to reinstall it.

Proceeding through this mandatory entry requires a scoped repository-development
contract decision separating product activation from this development workflow,
or an explicitly authorized verified runtime installation. Neither is performed
or inferred here. No reservation, approval, frozen artifact or task state changed.

## Remaining decisions and delivery status

The exact authenticated approval schema and migration of its consumers must be
settled in the successor design before code; an agent-written Approved flag is
not acceptable. No frozen artifacts, approvals, task statuses or ledger entries
were changed. Partial implementation and behavioral regressions are recorded
above. The new signed approval type and its consumers remain a contract decision;
existing two sidecar types cannot authenticate a review revision implicitly.
The implemented fixed-input/launcher slice has independent review evidence.
Whole-successor review, real delivery, CI, commit, push and merge remain
unperformed. Owner reruns on 2026-10-13 passed 27 materialization tests and 36
launcher tests (exit 0 each); no approval or progress authority was inferred.
