# Symphony Local Hardening Tasks

Baseline: `openai/symphony@8001b52e3062495a16e520e4ceaf8f9de868c4d0`  
Candidate root: `/Users/jrmag/.local/share/openai-symphony-hardening-minimal-8001b52e`  
Production state: **BLOCKED**

## H-001 — Dependency and config compatibility evidence

Acceptance criteria:

- `mix hex.audit`, format, Credo, Dialyzer, and full test suite pass under the pinned mise runtime.
- Adapter, HTTP, LiveView/dashboard, workspace, and app-server suites pass after the framework dependency updates.
- Missing command uses the documented default, explicit empty/whitespace atom-key input fails, explicit empty/whitespace string-key input fails, and a nonblank command is preserved.
- Binary and lockfile digests are recorded after the last change.

## H-002 — Fail-closed workspace cleanup

Acceptance criteria:

- A failing or timed-out local `before_remove` hook preserves the entire workspace and returns an error.
- A failing or timed-out remote `before_remove` hook never executes `rm -rf` and returns an error.
- Successful/no-op hook paths retain current removal behavior.
- Canonical root/path validation still occurs before any hook or removal.
- Startup and terminal reconciliation log the preservation failure without converting it to success.

### H-002R — Remote containment repair

Status: **COMPLETE (independently reviewed); production remains BLOCKED**

H-002 is reopened because implementation review proved that the remote overload
accepts an arbitrary nonblank path. H-002R remains an independent production
gate and must pass before H-003B integration may begin:

- in one quoted remote script, resolve the configured root with `cd` + `pwd -P`;
  reject a candidate symlink, split the candidate into parent/basename, reject
  empty/`.`/`..` basenames, resolve the existing parent with `cd` + `pwd -P`,
  and reconstruct the physical candidate path without local-host expansion;
- require the candidate to be a strict child of that root (never the root
  itself) using an exact `canonical_root/` prefix boundary before invoking a
  hook or `rm -rf`; unreadable root, missing parent, symlink candidate/escape,
  root drift, and malformed paths fail closed;
- perform validation, the successful `before_remove` hook, and removal in the
  same remote command so no second unchecked destructive command is emitted;
- prove with command-capture tests that `/`, the configured root, sibling paths,
  traversal, symlink escape, and stale recorded paths never reach the hook or
  removal, while a canonical child retains the success/failure semantics above.
- require Bash 5.1 or newer for remote timed-hook coordination; reject older
  shells before hook/removal state, and terminate timed-out hook descendants as
  one process group before returning while preserving the workspace.

Evidence: focused workspace/SSH tests 68/68, full `make all` exit 0, independent
security review PASS (0 Critical, 0 Major, 0 Minor). H-003B/C and H-004 remain
mandatory before any real tracker or repository dispatch.

## H-003 — Durable claims and single-instance ownership

Acceptance criteria:

- An atomic, versioned claim record stores tracker scope, issue ID, owner instance, baseline SHA, canonical workspace, generation, state, and checkpoint path outside workspace root.
- A process-level filesystem lock prevents two Symphony instances from owning the same ledger.
- Startup refuses automatic redispatch of an unresolved claim; explicit recovery resumes the same canonical workspace or stops safely.
- Claim transitions are fsynced/atomically renamed and tolerate truncated/corrupt records by failing closed.
- Kill/restart tests prove no duplicate worker, workspace, or branch identity.

### H-003 staged implementation contract

H-003 is split into three independently reviewed tasks. Completion of an early
task does not imply that claims are durable in production. The production gate
stays closed until H-003C passes its quality gate.

#### H-003A — Standalone locked ledger core

Scope:

- add a standalone claim-store owner and a versioned v1 ledger codec;
- reserve a configured claim root that is canonical, absolute, and disjoint
  from every configured workspace root; reject equality or containment in
  either direction before opening a lock or ledger;
- hold an exclusive OS lock for the owner's entire lifetime by starting
  `/usr/bin/lockf -k -s -t 0 <lock-path> /bin/cat` through
  `Port.open({:spawn_executable, ...})` with an argument vector (never a shell)
  and keeping its stdin/Port alive; `-k` prevents `lockf` itself from unlinking
  the persistent lock name, while pre/post-acquisition `lstat` identity checks
  reject symlinks and substitution during acquisition. Startup succeeds only
  after a random nonce written to stdin is echoed by `cat`, proving the command
  started after `lockf` acquired the lock;
- treat Port exit, handshake timeout, unexpected output, or a second owner as a
  fatal claim-store error; verify that OS ownership is released after normal
  stop, owner kill, and BEAM-process crash, without relying on a PID file or
  directory marker;
- while the lock is held, treat an absent ledger as a valid first run and write
  an empty v1 ledger using a temporary file in the same directory, complete
  write, file `fsync`, close, atomic rename, and parent-directory `fsync`, in
  that order;
- after every rename, reopen and decode the committed ledger before reporting
  success; an empty, truncated, malformed, unsupported-version, duplicate-ID,
  or schema-inconsistent ledger fails closed and is never silently replaced;
- encode records with tracker scope, issue ID, owner instance, baseline SHA,
  canonical workspace, generation, state, and checkpoint path outside all
  workspace roots.

Integration boundary:

- H-003A is test-only/standalone: it is not added to
  `AgentRuntimeSupervisor`, not called by `Orchestrator`, and does not alter
  eligibility, polling, dispatch, retry, cleanup, or redispatch behavior;
- "complete" means only that the codec, atomic persistence, lifetime lock, path
  separation, and crash/reacquire behavior pass focused tests and independent
  review;
- tests must prove that paths computed or accepted by `Workspace.remove*` cannot
  resolve to the claim root, lock file, ledger, or checkpoints. H-003A does not
  claim to sandbox arbitrary user-authored shell hook contents; write denial for
  those processes is an explicit H-004 acceptance criterion.

Threat boundary:

- **H-003A detects lock-path replacement but does not defend against a hostile
  process running as the Symphony UID; that write-deny boundary belongs to
  H-004.**
- H-003A assumes no hostile process with the Symphony account's UID mutates the
  claim directory after acquisition. It detects lock-path identity changes
  before ledger operations but cannot make a pathname immutable against its own
  UID; H-004 must deny hook/agent writes to that directory before production;
- the claim directory, lock, transaction marker, ledger, and temporary files
  must be owner-only, and symlink/non-regular reserved paths fail closed.

Required failure-injection tests:

- kill before file sync, after file sync but before rename, and after rename but
  before directory sync/re-read; the previous committed ledger remains valid
  or startup fails closed—never an accepted partial state;
- owner crash followed by reacquisition reads the last committed empty ledger;
- a competing owner is rejected while the first owner is alive and succeeds
  only after the first owner's OS lock is demonstrably released;
- a pre-existing zero-byte ledger is corruption, while a genuinely absent
  ledger is bootstrapped once under the lock.

#### H-003B — Supervision and startup integration

Status: **COMPLETE (independently reviewed); production remains BLOCKED**

Scope:

- add the H-003A owner to `AgentRuntimeSupervisor` before the Orchestrator and
  use a supervision strategy whose failure semantics prevent an Orchestrator
  from living without the claim-store owner;
- make Orchestrator startup wait for a successfully locked, decoded ledger;
- prove lock loss or claim-store death tears down the complete old scheduler
  generation, and that a replacement generation cannot poll or dispatch until
  it has acquired and decoded the ledger;
- retain existing in-memory claim decisions; no durable state transitions are
  wired in this task.

Evidence: focused ClaimStore/Core tests 77/77, production-profile compilation
with warnings-as-errors, production hook/fault-disable probe, Dialyzer with 0
errors, full `make all` exit 0, `git diff --check`, and independent final review
PASS (0 Critical, 0 Major, 0 Minor). The full gate exposed one pre-existing SSH
trace timeout on its first attempt; the isolated SSH test and the complete retry
both passed. H-003C and H-004 remain mandatory before any real tracker or
repository dispatch.

Proposed implementation contract (must receive independent PASS before code):

- require an explicit absolute claim root at the runtime boundary. Resolution
  order is: an explicit per-runtime option, then a test-only application
  override when `Mix.env() == :test`, then production
  `SYMPHONY_CLAIM_ROOT`; missing/blank values fail startup. The test default is
  unique per BEAM/OS process, and every concurrently started custom runtime
  receives a unique root as well as unique registered names;
  do not infer a repository- or workspace-owned state directory. Derive the
  local workspace root from the already loaded workflow and let H-003A reject
  equality or containment. Remote claim transitions remain blocked until
  H-003C defines their canonical identity;
- give every runtime explicit, independently injectable ClaimStore,
  TaskSupervisor, and Orchestrator names. Start them in that order under
  `:one_for_all`, and pass the exact ClaimStore name into Orchestrator. Sequential
  child startup plus an Orchestrator live-health/readiness call must prove that
  the v1 ledger was locked and decoded before cleanup or the first tick is
  scheduled. Add a dedicated ClaimStore call which verifies that the lock Port
  is still open and the current regular lock path has the acquired inode
  identity; cached `snapshot/1` alone is not a readiness proof. A failed health
  check stops the ClaimStore fail-closed;
- treat a ClaimStore start/readiness failure as a runtime start failure. On a
  running ClaimStore exit, `:one_for_all` must terminate the old Orchestrator and
  all old workers before starting the replacement generation; the replacement
  Orchestrator must perform the same locked-ledger readiness handshake. This
  task does not claim that the empty H-003A ledger prevents redispatch after a
  restart; production stays disabled until H-003C makes persisted claims
  authoritative;
- put the live-health check at every path that can enter a new poll/retry
  dispatch and immediately before `Task.Supervisor.start_child/2`. A failed
  check stops the Orchestrator instead of polling or starting work. The check
  and `start_child/2` are not atomic: a task that wins that narrow race may
  start only under the old TaskSupervisor, and must be terminated with the
  complete old generation before any replacement-generation poll. Atomic
  claim-before-dispatch and the stronger zero-race-start guarantee remain
  H-003C scope;
- test corrupt/unsupported/locked ledgers, unsafe roots, child start order,
  exact-name/root isolation, initial cleanup/tick suppression on readiness
  failure, missing/closed Port detection, and unlink/symlink/regular-inode lock
  replacement. Add a test-only deterministic barrier after the final health
  check and before worker start: kill the ClaimStore while blocked, permit the
  old-generation race task to start if scheduling wins, and prove it and every
  old worker are dead before the replacement generation can poll. Also prove
  successful reacquisition and decoded-ledger readiness before that replacement
  poll. The barrier is an isolated test dependency, not workflow/application
  configuration. Keep all real tracker,
  repository, credentials, remote execution, branch mutation, and durable
  transition tests disabled in this slice;
- run focused tests first, then formatting, warnings-as-errors, Credo strict,
  Dialyzer, coverage, the complete `make all` gate in a non-interactive terminal,
  and `git diff --check`; obtain independent implementation review and tester
  verification before marking H-003B complete.

#### H-003C — Claim transitions and explicit recovery

Status: **PLANNING; code is forbidden until this contract receives an
independent PASS**

Safety invariants:

- the locked ledger, not Orchestrator memory, is the sole dispatch authority;
  every scheduler mutation is a ClaimStore compare-and-swap over
  `{claim_key, claim_revision, generation, owner_instance, expected_state}`.
  `claim_revision` is a persisted, monotonically increasing integer and every
  successful transition returns the complete next token; a token from before a
  process restart or transition is invalid;
- `owner_instance` is generated inside each successful `ClaimStore.init/1`
  after lock acquisition, never in `AgentRuntimeSupervisor.init/1`. Therefore
  a `:one_for_all` child restart receives a new authority identity even when
  the supervisor PID survives. Readiness returns that identity and the decoded
  ledger generation; Orchestrator stores only the returned token;
- a durable claim is committed and acknowledged before `Task.Supervisor` may
  start a worker. Every later ledger/checkpoint transition is committed before
  its corresponding in-memory update, timer, worker acknowledgement, cleanup,
  or release side effect;
- one claim owns one scheduler issue identity, one `{worker_identity,
  canonical_workspace}` identity, and—once attested—one
  globally unique `{canonical_repository_identity, full_symbolic_ref}`.
  These resources are unique across all live and recovery-required claims;
- `claim_key` is exactly `{tracker_identity_digest, stable_issue_id}`. Every claim,
  checkpoint, transition marker, recovery command, terminal lookup, cleanup
  no-op proof, and release CAS persists and compares both elements;
  `stable_issue_id` is the immutable tracker-returned nonempty UTF-8 identifier
  byte string with no display-name fallback or Unicode normalization. Its
  canonical encoding is `u64(32) <> raw_tracker_identity_digest <>
  u64(byte_length(issue_id)) <> issue_id`, using unsigned big-endian lengths;
  `full_claim_key_digest` is
  `sha256("symphony-claim-key-v1\\0" <> canonical_claim_key)`;
- scheduler restart never converts `claimed`, `running`, `retrying`, `blocked`,
  or a partly consumed recovery into a fresh dispatch. The old generation is
  first dead by H-003B; the surviving record becomes recovery-required and can
  only be released for a verified terminal issue or resumed by a new explicit
  operator authorization;
- a failure to lock, validate, compare-and-swap, write a checkpoint, or commit
  the ledger kills the ClaimStore and therefore the whole scheduler generation.
  There is no best-effort fallback to the in-memory `claimed` set.

Implementation slices (review and test each slice before the next):

1. **H-003C1 — versioned ledger and transition API.** Replace unrestricted
   production `replace/2` with explicit `claim/2`, `transition/3`, `release/2`,
   and recovery-authorization operations. Use an explicit v2 schema containing
   the tracker-identity digest, eligibility-policy fingerprint, and their
   canonical non-secret source fields, stable issue
   identifier, stable physical-worker identity and attestation, planned workspace
   identity, `planned_repository_identity`, `planned_full_ref`, nullable
   attested canonical workspace/`attested_repository_identity`/
   `attested_full_ref`, planned provider baseline/object format, provider
   reservation ID/hash/control-ref/exact object bytes/hash/object ID/receipt,
   tracker-global fence backend/ID/control-ref/exact request or tag-object
   bytes/hash/object ID/receipt, append-only registry identity/keys/record
   hashes/receipts, workspace-fence key/ID/path/receipt, the
   nullable `current_local_execution_id`, corresponding nullable
   `active_local_execution`, append-only `terminated_local_execution_history`,
   nullable `current_lease_id`, its corresponding nullable `active_lease`, plus
   the append-only `terminated_lease_history` model defined below,
   `baseline_sha`, `observed_head_sha`, worktree-content digest,
   generation, owner instance, claim revision, retry attempt,
   `execution_attempt_id`, state, transition ID, and checkpoint path/hash. Only an empty v1 ledger may be
   migrated automatically under the lock; any non-empty v1 or unknown version
   fails closed. The claim key is exactly the persisted tracker-identity digest plus stable
   issue ID. Initial `claimed_unprepared` records have read-only-attested tracker
   fence-backend and target-repository identities, their respective object
   formats and baseline SHAs, every exact precomputed fence object/request/file,
   and all random fence IDs, but no bound receipts, created workspace, or
   attested workspace repository/ref/baseline. They may make exactly one
   preparation attempt; `claimed_preparing` proves all three ordered fence
   receipts were durably bound before creation.
   Validate legal edges explicitly, including
   `claimed_unprepared -> claimed_preparing`,
   `claimed_preparing -> running|blocked`, normal running/retry/block edges,
   recovery edges, and—only with a never-created history proof—
   `terminal_verified -> cleanup_complete_noop -> released`; reject every unlisted edge and stale
   owner/generation/revision/state token.
   The only fence-loss edges are remote `fence_lease -> recovery_required` and
   startup-only local `record_local_fence_loss -> recovery_required` with the
   exact death proofs defined below.
   The only same-parent persistence operations are the separately typed
   `bind_tracker_fence`, `bind_provider_reservation`, and
   `bind_workspace_fence` on `claimed_unprepared`, `renew_lease` on any live
   remote `bound|provision_authorized|provision_open_observed|
   execution_authorized|execution_open_observed` lease under its unchanged
   `claimed_preparing|retrying|recovery_reserved|running` parent,
   higher-revision recovery inspection, and these
   remote-only lease operations: `start_retry_lease` installs a matching
   `current_lease_id` and `pending` active lease only on live-generation
   `retrying` with both fields null and complete terminated
   history;
   `bind_lease` changes only `pending -> bound`; `authorize_provision_gate`
   changes only `bound -> provision_authorized`; `observe_provision_gate`
   changes only `provision_authorized -> provision_open_observed`;
   `prepare_remote_execution_gate` atomically binds the attestation, changes the
   parent to `running`, and changes only `provision_open_observed ->
   execution_authorized`; `observe_remote_execution_gate` changes only
   `execution_authorized -> execution_open_observed`; and `fence_lease` appends only the
   exact active attempt as `terminated`, clears both `current_lease_id` and
   `active_lease`, and moves any
   nonterminal parent to `recovery_required`. Each operation requires the
   complete current claim token and expected lease ID/phase, may change only the
   named lease/receipt fields plus revision/transition/checkpoint metadata,
   increments revision, assigns a transition ID, and uses the complete
   transaction protocol. `renew_lease` additionally requires the expected
   renewal epoch and receipt; generic state or lease self-edges remain forbidden.

   Local execution uses separately typed operations over the local-control
   fields defined below. `begin_local_preparation`, `reserve_local_recovery`,
   and `start_local_retry`
   atomically install a matching fresh `current_local_execution_id` plus
   `active_local_execution.phase=pending` while entering or retaining the
   corresponding parent. `bind_local_watchdog`, `authorize_local_gate`, and
   `observe_local_gate` advance only the named provisioning phase;
   `prepare_local_execution_gate` and `observe_local_execution_gate` advance
   only the two post-attestation execution-gate phases.
   `renew_local_heartbeat(expected_claim_token, local_execution_id,
   expected_epoch, heartbeat_receipt)` is the sole local same-parent self-edge.
   It is legal for `watchdog_bound|gate_authorized|gate_open_observed|
   execution_authorized|execution_open_observed` only in the parent/phase
   combinations defined below; it byte-verifies the exact next epoch, deadline,
   attempt binding and receipt, changes only heartbeat epoch/deadline/hash plus
   revision/transition/checkpoint metadata, and uses the complete transaction.
   Stale, skipped, replayed with different bytes, wrong-phase, or remote
   heartbeats fail closed. A helper-ahead heartbeat after a lost response is
   never silently adopted during startup: exact receipt readback identifies the
   mismatch and the attempt is fenced before takeover.
   `complete_local_execution(destination, death_receipt)` is the only normal
   close; `record_local_fence_loss(death_receipt)` is the startup-only abnormal
   close. Both append the exact terminated local-control record, clear both
   active local-control fields, and perform the allowed parent transition in
   one complete claim transaction. They require the exact current token,
   execution ID, phase, and privileged receipt and cannot synthesize death.

   Remote parent-entry operations are indivisible parent-plus-lease
   transactions: `begin_remote_preparation` performs
   `claimed_unprepared -> claimed_preparing` while installing a matching fresh
   `current_lease_id` and initial `pending` active lease, and
   `reserve_remote_recovery` performs token consumption
   `recovery_authorized -> recovery_reserved` while installing a matching fresh
   `current_lease_id` and `pending` active lease. No committed
   `claimed_preparing` or `recovery_reserved` remote record may have either
   field null. `complete_lease(destination, death_receipt)` is
   the only normal close: after exact supervisor/process-group reap proof it
   atomically appends the terminated attempt, clears both `current_lease_id`
   and `active_lease`, and moves
   the source only according to this exhaustive table:
   `claimed_preparing -> retrying|blocked|recovery_required`;
   `running -> retrying|blocked|terminal_verified|recovery_required`;
   active `retrying -> retrying|blocked|terminal_verified|recovery_required`;
   and `recovery_reserved -> blocked|recovery_required`. Entry to
   `terminal_verified` additionally requires the fresh terminal tracker proof
   defined below. `retrying -> retrying` is specifically the atomic close into
   null-lease live-generation backoff. The subsequent `start_retry_lease`
   rotates `execution_attempt_id` and installs the new lease before any worker
   side effect. `retrying` with both fields null represents only a committed
   live-generation backoff timer; `start_retry_lease` must run before its worker
   side effect. `fence_lease` is the abnormal equivalent and always selects
   `recovery_required`. Both require exact active ID/phase/current claim token;
   neither can synthesize a death receipt or leave append/clear half-committed.

   Every transition has a random `transition_id` and immutable versioned
   checkpoint filename. The checkpoint contains the complete next claim plus
   `{claim_revision, transition_id}` and its SHA-256 is recorded in both the
   marker and next ledger. The transaction marker contains the exact previous
   ledger SHA-256, next ledger SHA-256, checkpoint path/SHA-256, claim key and
   transition ID. Commit ordering is: write/fsync/rename/fsync-directory marker;
   write/fsync/rename/fsync-directory checkpoint; write/fsync/rename/
   fsync-directory ledger; reread and verify all hashes; remove marker and
   fsync its directory. Startup with a marker is deterministic: if the ledger
   matches the next hash and checkpoint matches, finish roll-forward and remove
   the marker; if the ledger matches the previous hash, delete only the
   marker-named, hash-matching unreferenced checkpoint/temp artifacts and roll
   back; any other hash, malformed/symlinked file, reference conflict, or failed
   directory sync fails closed. Without a marker, unreferenced immutable
   checkpoints are quarantined/ignored but never selected as authority; a
   referenced missing or mismatched checkpoint blocks startup. Test concurrent
   callers, stale tokens, duplicate identities, migration, and injected death
   at every marker/checkpoint/ledger write, rename, sync, verification and
   marker-removal boundary.
2. **H-003C2 — claim-before-dispatch and attestation.** Generate a random
   scheduler `owner_instance` per ClaimStore child initialization as specified
   above. Define `tracker_identity_digest` as
   `sha256("symphony-tracker-identity-v1\\0" <> canonical_tracker_tuple)`, where
   the tuple is exactly `u64(byte_length(kind)) <> kind <>
   u64(byte_length(origin)) <> origin <> u64(byte_length(project_id)) <>
   project_id`, with unsigned big-endian lengths. `kind` is a fixed lowercase
   ASCII adapter enum. Production tracker and repository origins must parse as
   absolute HTTPS URIs with no userinfo, query, fragment, or path other than
   empty or `/`; scheme and ASCII host are folded to lowercase, explicit port
   443 is omitted, and any other valid port is retained as minimal decimal.
   Unicode host input, malformed A-labels, IPvFuture, ambiguous numeric hosts,
   and percent-encoding are rejected; IPv4 is canonical dotted decimal and
   IPv6 is bracketed RFC 5952 form. The result is `https://<host>` plus the
   optional non-default port. Immutable project IDs must be nonempty valid
   UTF-8 already in NFC, with no NUL or control scalar; normalization is
   validated, never silently applied. Tracker and repository identities use
   the identical origin/ID/framing rules under their own domain separators.
   Clone URLs, SSH aliases, scp syntax, configured display names, and local
   paths never enter either identity. Golden vectors prove default-port/case
   aliases collapse, non-default ports remain distinct, clone aliases collapse
   to the same identity, and every rejected spelling fails before claim
   creation.
   Define a separate
   `eligibility_policy_fingerprint` over the exact canonicalized eligibility
   query/filter AST, terminal-state IDs, and query schema version. Persist both
   sets of source fields beside their digests and verify recomputation on every
   load. Policy is never part of claim identity or branch/control-ref naming.
   If any unresolved claim for a tracker identity has a different persisted
   policy fingerprint from current configuration, readiness fails closed; a
   second workflow/query still collides on the same project/issue claim key.
   Refuse trackers that cannot return the immutable project ID; pin it for the
   scheduler generation and fail closed if a fresh lookup resolves to another
   identity. Never include tokens, userinfo, query secrets, or mutable display
   names.

   Define `worker_identity` from a durable physical-root attestation, not a
   display name, workflow name, claim-root installation UUID, or mutable
   configuration path. A local identity is
   `sha256("symphony-physical-worker-v1\\0" <> u8(platform) <>
   bytes(canonical_physical_root) <> platform_physical_id)`, where
   `bytes(x)=u64(byte_length(x))<>x`, u64 is unsigned big-endian, and
   `darwin_u32_bits(x)` is the exact 32-bit two's-complement bit pattern of the
   signed C value emitted as unsigned big-endian u32. Platform `0x01` is Darwin
   and uses physical `realpath(3)` bytes plus
   `platform_physical_id = darwin_u32_bits(statfs.f_fsid.val[0]) <>
   darwin_u32_bits(statfs.f_fsid.val[1]) <> u64(stat.st_dev) <>
   u64(stat.st_ino)` in exactly that index order. Platform `0x02` is Linux and
   uses physical `realpath(3)` plus
   `platform_physical_id = u64(statx.stx_mnt_id) <>
   u64(statx.stx_dev_major) <> u64(statx.stx_dev_minor) <>
   u64(statx.stx_ino)`. Values outside those exact widths are rejected. A
   remote identity is instead the same encoding under
   domain `symphony-physical-remote-worker-v1\\0` with
   `bytes(pinned_ssh_host_key_sha256)` immediately after the platform byte.
   If these fields cannot be obtained, or the root is a network/shared
   filesystem, production dispatch is refused. Persist the full attestation in
   every claim, re-attest it at each scheduler generation and before recovery/
   cleanup, and fail closed on change. Host aliases resolving to the same
   attestation collapse to one identity; an alias resolving to a different
   attestation is rejected. Configuration rename or another claim root never
   creates a second identity for an existing physical root. The install UUID is
   audit metadata only.

   Require trusted workflow configuration to supply a stable, non-secret
   repository identity, computed as
   `sha256("symphony-repository-v1\\0" <> length-prefixed(provider kind,
   canonical provider origin, immutable provider repository ID))`, using the
   exact origin/ID/framing rules above; refuse
   production dispatch when any source field is unavailable.

   All production schedulers in H-003C are scoped to one attested control host
   and must use its single privileged append-only `FenceRegistry`; multi-control-
   host scheduling is unsupported until an equivalently reviewed shared
   linearizable registry adapter exists. Its location is not configurable:
   `/var/db/openai-symphony/fence-registry-v1` on Darwin and
   `/var/lib/openai-symphony/fence-registry-v1` on Linux. One OS service/helper
   identity owns that registry. For each domain/key digest it atomically creates
   and fsyncs one immutable record binding the random fence ID and exact request
   hash. Domain tags are tracker issue `0x01` and target repository/full-ref
   `0x02`; workspace fencing belongs only to the per-worker helper defined
   below. A record path is exactly
   `<registry>/<two-lowercase-hex-domain>/<64-lowercase-hex-key-digest>`, and
   its bytes are `"symphony-fence-registry-record-v1\\0" <> u8(domain) <>
   u64(32) <> key_digest <> u64(32) <> fence_id <> u64(32) <> request_sha256`.
   All lengths are unsigned big-endian and the file plus parent directories are
   no-follow opened, fsynced, and identity-revalidated. Records are never
   updated, deleted, reused, or garbage-collected by
   H-003C. An existing identical record permits exact lost-response recovery;
   an existing different ID/hash permanently blocks the contender. The helper
   rejects alternate roots, mount namespaces, service identities, symlinks, and
   non-owner metadata. H-004 must make registry records and helper state
   unreadable and immutable to Symphony workers, hooks, credentials, and other
   unprivileged processes. This registry is a local defense and audit cache,
   not the cross-host authority.

   Cross-host authority requires the tracker/provider adapter to attest a
   linearizable, project-scoped **non-recreatable create-once namespace**. Its
   service retains an internal immutable key tombstone after visible-object
   deletion and rejects every later create for that key; the guarantee applies
   to all API principals and cleanup jobs, including administrators, with no
   bypass identity available to Symphony. The capability descriptor, namespace
   immutable ID, retention-policy ID/version/hash, and attestation receipt are
   persisted before the local registry record. Every claim/renewal/recovery
   re-attests them. For GitHub, merely observing atomic Git ref creation is not
   sufficient: the adapter is production-disabled unless the organization/
   repository policy API proves an enforced matching tag ruleset with update
   and deletion denied to every actor, no bypass list, and retention of the
   create-once key. If GitHub cannot prove the internal non-recreatable
   tombstone semantics, H-003C must refuse GitHub production dispatch. A future
   shared coordinator may satisfy this interface, but a configured host-local
   substitute may not. Fake-provider tests model the interface; no real
   credential is used in H-003C.

   Before any target-repository or workspace action, require a linearizable
   **tracker-global issue fence** whose namespace is intrinsically bound to the
   immutable tracker project and is independent of target repository, worker,
   workflow, and claim root. The tracker adapter, not arbitrary workflow
   configuration, returns the fence backend descriptor. For GitHub Issues the
   backend is the tracker repository identified by that same immutable project
   ID, and the create-only control ref is
   `refs/tags/symphony-issues/<full_claim_key_digest_hex>`. Other adapters must
   provide a native project-scoped atomic create-if-absent/read primitive with
   a normative byte protocol; an adapter without one is unsupported in
   production. Before mutation, `claim/2` persists a random 256-bit
   `tracker_fence_id`, backend identity, read-only-attested tracker-repository
   baseline SHA and Git object format, exact request/tag bytes, SHA-256,
   `tracker_registry_key = sha256("symphony-tracker-registry-key-v1\\0" <>
   raw_full_claim_key_digest)`, exact registry record bytes/hash/receipt,
   expected object ID, and expected receipt. For GitHub, the exact tag body is
   ASCII with LF separators and one final LF:

   ```text
   object <tracker_repository_baseline_sha>
   type commit
   tag symphony-issue-<full_claim_key_digest_hex>
   tagger Symphony Claim Broker <symphony-claim@invalid> 0 +0000

   symphony-issue-fence-v1
   tracker <tracker_identity_digest_hex>
   claim-key <full_claim_key_digest_hex>
   fence-id <tracker_fence_id_hex>
   ```

   Hex, object-format, byte-length, and Git object-ID rules are exactly those
   defined for the provider tag below. Only create success or exact byte-for-
   byte readback of the already-persisted object and fence ID grants ownership;
   conflict or indeterminate identity blocks. The ref is never repointed or
   deleted in H-003C. The shared create-once authority, not the host registry,
   guarantees that visible-ref loss can never let another fence ID acquire the
   issue. Before every lease start, gate authorization, execution
   acknowledgement, renewal, retry, and state transition, the claimant
   revalidates the exact registry record and provider-ref payload. Missing or
   changed evidence closes readiness, fences any active lease, and requires a
   new explicit recovery inspection even if the external ref is later restored.
   `fence_lease` is the sole transition allowed on failed external-evidence
   validation; it records that failure and termination receipt but cannot start
   or acknowledge execution. For local transport, which has no remote lease,
   ClaimStore owns the sole client endpoint of the durable attempt-bound local
   control/watchdog protocol defined below and sends its monotonic evidence
   heartbeat with a fixed maximum interval of one second while any local
   preparation or execution task exists. A
   failed heartbeat synchronously closes readiness and exits ClaimStore;
   H-003B `:one_for_all` teardown kills and joins the old TaskSupervisor, while
   the H-004 local process-group watchdog kills/reaps hook or Codex descendants
   within the same five-second TTL when its protected control channel closes.
   Replacement startup must prove the old TaskSupervisor and exact PID/start-
   time/process group are dead before the typed
   `record_local_fence_loss` transition may atomically append the exact
   terminated local-control record, clear its current pair, and move a
   null-remote-lease local claim from
   `claimed_preparing|running|retrying|recovery_reserved` to
   `recovery_required`.
   That operation is startup-only, records heartbeat failure plus privileged
   watchdog death/join receipts, cannot acknowledge work, and uses the complete
   transaction. Until
   it commits, global readiness remains closed.
   Thus the same tracker issue aimed by split schedulers at
   different repositories still has one winner. Lost-response recovery may
   bind only that persisted fence through `bind_tracker_fence`; it cannot mint
   a new fence ID.

   Derive the exact planned full ref before claiming as
   `refs/heads/symphony/` plus the first 32 lowercase base32 characters of
   `sha256("symphony-claim-ref-v1\0" <> canonical_length_prefixed_claim_key)`;
   no display name or worker name participates. Before `claim/2`, the read-only
   provider broker resolves the trusted configured base ref to an immutable
   commit `planned_baseline_sha`, reports the repository Git object format, and
   proves the planned full ref absent. The claim persists that result; an
   existing planned ref is
   accepted only by the separately authorized recovery path when its persisted
   repository/ref identity matches exactly. Hash collision or any duplicate
   planned/attested `{repository_identity, full_ref}` anywhere in the ledger is
   rejected globally, regardless of worker. Because separate claim roots cannot
   share that ledger invariant, every production claim also persists a random
   256-bit `provider_reservation_id`, its hash, and
   `provider_ref_lock_digest = sha256("symphony-provider-ref-lock-v2\\0" <>
   u64(byte_length(planned_full_ref)) <> planned_full_ref)`, with unsigned
   big-endian lengths. This lock is created inside the selected target
   repository, so that repository supplies the namespace and the stored object
   payload binds its canonical identity; no independently normalized repository
   digest is redundantly folded into the lock key. Its deterministic
   control ref is `refs/tags/symphony-claims/` plus the full lowercase hex lock
   digest, so any claims resolving to the same exact repository/full-ref pair
   contend on the same provider key even when their claim keys or local roots
   differ. The local append-only key is
   `sha256("symphony-provider-registry-key-v1\\0" <> u64(32) <>
   raw_repository_identity <> u64(byte_length(planned_full_ref)) <>
   planned_full_ref)`; its domain-`0x02` record binds the same reservation ID
   and tag-body SHA-256. Before any provider mutation, `claim/2` persists all of
   these fields plus the exact registry record, annotated-tag body, its
   SHA-256, and expected Git object ID.
   The tag body is ASCII with LF separators and one final LF, exactly the UTF-8
   bytes of this template after bracket substitution:

   ```text
   object <planned_baseline_sha>
   type commit
   tag symphony-claim-<provider_ref_lock_digest>
   tagger Symphony Claim Broker <symphony-claim@invalid> 0 +0000

   symphony-reservation-v1
   repository <repository_identity_hex>
   full-ref <planned_full_ref>
   claim-key <full_claim_key_digest_hex>
   reservation-id <provider_reservation_id_hex>
   baseline <planned_baseline_sha>
   ```

   Every substituted field is lowercase ASCII hex except the generated full
   ref, which is restricted to `[a-z0-9/-]+`; spaces shown above are one byte.
   The expected object ID is the repository-declared SHA-1 or SHA-256 Git object
   hash of `"tag " <> decimal_byte_length(tag_body) <> "\0" <> tag_body`.
   Any other object format is unsupported. The reservation ID is a non-secret
   fence identifier, not an authorization token. Through the H-004 fixed
   provider broker, fixed-argv Git plumbing uploads exactly those stored bytes,
   verifies the returned object ID, then performs
   the provider's atomic create-ref-if-absent CAS for that control ref. Only a
   caller receiving success, or recovering a lost response by reading the ref
   and byte-comparing its object/payload to its already-persisted reservation
   ID and bindings, owns the global reservation. Existing-with-different-object,
   inability to prove atomic create semantics, or an unsupported provider
   durably blocks the local claim and starts no workspace or worker. The control
   ref is never repointed or deleted by H-003C. Its global create-once key and
   local registry record have the same mandatory continuous revalidation as the
   tracker fence. Thus processes with different
   claim roots and workers still contend on one target-repository/full-ref key
   before the planned branch is created or checked out. The strict external
   ordering is tracker-global issue fence, target-repository/full-ref fence,
   workspace fence, then provisioning; every receipt is committed to the local
   claim before attempting the next fence.
   `claim/2` atomically reserves the issue key,
   `{worker_identity, planned_workspace}`, and
   the globally unique `{repository_identity, planned_full_ref}` before any
   workspace, Git, hook, or worker side effect. SSH/HTTPS/scp-style URLs and
   worktree paths are never themselves repository identities. A production
   claim remains `claimed_unprepared` while its three ordered fence operations
   run. The tracker-fence, provider-reservation, and workspace-fence receipts
   are committed through their separately typed bind operations before
   `claimed_preparing` or any workspace/branch/worker action. A crash before an
   external CAS has no such side effect; a crash after success but before local
   receipt commit may only exact-readback and bind the already-persisted ID and
   bytes, never create a new ID or proceed on a mismatch. An orphan annotated
   object that lost a create-ref race grants no authority.
   After creation, a
   read-only provider API lookup through the later H-004 credential broker must
   return the same immutable provider repository ID and canonical origin, and
   local Git object format/origin must also match; equal origins with different
   provider IDs are rejected. The fixed-argv provisioning primitive returns a
   receipt containing those values for the attestation transaction. Before
   claiming, calculate and validate the only permitted planned workspace as
   `<canonical_physical_root>/symphony-<full_claim_key_digest_hex>`; the ASCII
   child must be a strict physical descendant and its path must not yet exist.
   Persist it only inside the same atomic `claim/2` transaction; the canonical
   workspace remains null until attested.

   Every physical worker host has exactly one fixed privileged
   `WorkerFenceHelper`, at `/var/db/openai-symphony/worker-registry-v1` on
   Darwin or `/var/lib/openai-symphony/worker-registry-v1` on Linux. Neither
   root nor service identity is configurable. A remote worker must attest this
   same fixed helper over the protected channel; an absent/second helper is
   unsupported. Linux additionally requires the helper and worker root to be
   in PID 1's mount namespace and rejects bind mounts, overlay aliases, and
   alternate namespaces by comparing mount IDs, filesystem IDs, and the
   resolved root handle. Darwin rejects firmlinks or alternate volume views
   that do not return one stable filesystem ID plus directory handle.

   Workspace exclusion converges on the underlying parent directory, not its
   spelling or `worker_identity`. Let `parent_backing_identity` be the helper-
   returned exact framed platform tuple of filesystem/mount ID, device, and
   inode for an open no-follow handle to the planned parent; the child basename
   is exactly `symphony-<full_claim_key_digest_hex>`. Derive
   `workspace_fence_key = sha256("symphony-workspace-fence-v2\\0" <>
   u64(byte_length(parent_backing_identity)) <> parent_backing_identity <>
   u64(byte_length(child_basename)) <> child_basename)`. The fence pathname is
   exactly `<fixed-worker-registry>/03/<workspace_fence_key_hex>`. Before
   provisioning, persist a random 256-bit `workspace_fence_id` and the exact
   expected file bytes
   `"symphony-workspace-fence-v2\\0" <>
   u64(byte_length(parent_backing_identity)) <> parent_backing_identity <>
   u64(byte_length(child_basename)) <> child_basename <> u64(32) <>
   raw_full_claim_key_digest <> u64(32) <> raw_workspace_fence_id <>
   u64(byte_length(root_attestation_bytes)) <> root_attestation_bytes`, plus its
   SHA-256, in the claim. `root_attestation_bytes` is the exact worker-identity
   preimage after its domain separator. Under the helper's exclusive registry
   lock, atomically create with no-follow/O_EXCL semantics and fsync the fence
   file and parent; keep the parent handle open through the later child mkdir so
   path remapping cannot intervene. Create success or exact lost-response
   readback is committed by `bind_workspace_fence`; an existing mismatch,
   symlink, root/mount/namespace drift, or inability to protect the one fixed
   registry blocks. The fence persists and is never deleted by H-003C. Two
   claim roots, installation policies, or path aliases therefore converge on
   the same backing-parent/basename exclusion point. H-004 must keep the helper,
   registry, lock, and fence unreadable and immutable to hooks and workers.
   Local paths must pass `PathSafety`; hardened SSH mode requires an absolute
   physical remote root. Persist `claimed_unprepared` before worker start and
   `claimed_preparing` before permitting the single creation attempt. Production
   H-003C rejects arbitrary `after_create` hooks. Provisioning uses only a
   built-in fixed-argv primitive which checks the reserved provider repository
   identity and creates/checks out only the reserved full ref; no user shell is
   run before attestation. The two exact control-ref CAS operations and the
   privileged workspace-fence file creation are the only mutations permitted
   after local claim persistence but before provisioning; every workspace or
   planned-branch mutation occurs only after all three receipts are durably
   bound. A restart
   from either state never creates a workspace automatically: absent workspace
   and null branch remain a valid recovery-required identity, while any
   discovered partial path is preserved for explicit recovery inspection.

   Split worker startup into preparation and
   execution: after built-in workspace provisioning, obtain canonical path,
   `git rev-parse HEAD`, canonical repository identity, and a full symbolic ref
   under `refs/heads/`, send that attestation with the
   claim token, and wait. ClaimStore must atomically bind/validate the exact
   workspace, baseline SHA and branch before Orchestrator acknowledges the
   worker to run `before_run` or Codex. Mismatch, detached/non-Git workspaces,
   duplicate `{repository identity, full ref}` on the same or any other worker, missing
   acknowledgement, or a stale token stops
   the worker without Codex execution and durably blocks the claim. Initial
   claim/preparation creates and persists an `execution_attempt_id`; every
   normal retry CAS rotates it before child start, and every worker entry must
   present it. Persist
   `retrying` before scheduling a live-generation retry and persist `running`
   before acknowledging a retry worker. Persist `blocked` before exposing an
   input-required block. The attested `baseline_sha` must byte-equal the
   pre-claim `planned_baseline_sha`; either value changing or the base ref
   moving during preparation fails closed. `baseline_sha` never changes. At every clean worker
   acknowledgement, block, retry, or exit boundary, a constrained observer
   records `observed_head_sha` and a canonical digest of index plus tracked,
   untracked, ignored, submodule, and Git-layout status before committing the
   state transition. Recovery compares the latest observed values; if a crash
   left newer unobserved content, it is preserved and a fresh operator
   authorization must explicitly bind the newly observed digest rather than
   pretending it equals baseline. The only path for this is a separate
   `claims inspect-recovery` operation after old-process death confirmation. It
   uses the H-004 read-only worker/provider broker, performs no workspace/Git/
   tracker mutation, and commits one of two tagged `recovery_candidate` forms.
   `workspace_snapshot` contains the old claim token plus freshly observed
   repository/ref/HEAD/content digest. `external_fences_only` is permitted only
   when canonical workspace/ref/HEAD/content fields remain null. Inspection
   reads the deterministic tracker fence, optional provider control ref, and
   optional privileged workspace fence in their required order, verifies every
   present receipt against the stored exact bytes/IDs/bindings, verifies later
   fences are absent when an earlier one is absent, and commits those receipts
   with explicit null workspace fields. A missing required or mismatched fence
   cannot produce that candidate; an exact prefix of successfully created
   fences may. Recovery authorization may continue only the remaining suffix,
   using the persisted IDs and bytes, before its one workspace creation attempt.
   The
   offline authorization CAS must name that exact candidate revision/digest;
   reservation re-observes and byte-compares it before any side effect.
   The recovery snapshot digest has one normative byte encoding:
   `sha256("symphony-recovery-snapshot-v1\0" <> u64(record_count) <>
   concat(u64(record_body_length) <> record_body))`, with all integers unsigned
   big-endian. A record body is exactly `u8(namespace) <> u8(type) <>
   bytes(root_key) <> bytes(relative_path) <> u32(mode) <> bytes(link_target)
   <> bytes(content)`, where `bytes(x) = u64(byte_length(x)) <> x`. Namespace
   tags are fixed: workspace `0x01`, primary git-dir `0x02`, common git-dir
   `0x03`, submodule git-dir `0x04`, and LFS object root `0x05`. Type tags are
   directory `0x01`, regular file `0x02`, and symlink `0x03`. Workspace
   `root_key` is empty; every Git/LFS root key is its attested canonical absolute
   raw path. Relative paths use raw filesystem bytes, `/` separators, no leading
   slash, and empty only for the namespace root. Directory records require
   empty target/content, regular records require empty target and exact file
   bytes as content, and symlinks require exact target bytes and empty content.
   Records are sorted bytewise by `{namespace, root_key, relative_path, type}`;
   no locale, text normalization, platform separator conversion, implicit
   field, or map iteration order is permitted.

   The workspace namespace includes its root and every descendant. When a
   directory entry whose raw basename is exactly `.git` is encountered at any
   depth, its directory record is included but its subtree is excluded from the
   workspace namespace and must instead be represented by a discovered Git
   namespace; a regular `.git` pointer file is included verbatim, and a symlink
   `.git` entry is rejected. Separate Git namespaces cover every directory,
   regular file, and symlink below the resolved `git_dir` and `git_common_dir`,
   including HEAD, index, loose and packed refs, reflogs, reachable and
   unreachable objects, worktree administration, discovered submodule gitdirs,
   and LFS objects. When roots overlap, assign each physical entry to the
   longest matching root, breaking equal-length ties by the lowest namespace
   tag, so it appears exactly once. Resolved roots and every entry must remain
   inside the attested repository/control roots. Alternates, special files,
   transient lock files, path escapes, unsupported object stores, or an entry
   whose namespace cannot be assigned uniquely are rejected, not omitted. Two
   complete passes must produce identical ordered records, resolved HEAD/ref,
   and index; otherwise inspection fails as unstable. Tests must pin complete
   byte strings and SHA-256 literals for empty, one-file, symlink, linked
   worktree/common-dir, submodule, LFS, non-UTF-8 path, and overlap fixtures.
   The empty vector bytes are
   `73796d70686f6e792d7265636f766572792d736e617073686f742d7631000000000000000000`
   and its digest is
   `f6db31048fc3d19b498ce7bb90739653d963cb28306cfa51ad06831792269ec3`.

   Cleanup must target only the recorded identity and a
   terminal claim moves first to `terminal_verified` after a fresh, fail-closed
   tracker read under the pinned identity and policy fingerprint. H-003C never deletes a created
   workspace and provides no cleanup authorization for one; it remains
   `terminal_verified` until a later, separately reviewed complete-preservation
   workflow exists. Only a claim whose durable history proves
   `claimed_preparing` was never entered may take the explicit
   `terminal_verified -> cleanup_complete_noop -> released` edge, with no
   filesystem/hook/ref/PR/tracker side effect. A missing path in any other state
   is ambiguous and blocks. Thus `before_remove`, created-workspace deletion,
   ref deletion, PR closure, and content-archive sufficiency are all outside
   H-003C.
3. **H-003C3 — restart and explicit recovery.** Seed Orchestrator's exclusion
   and blocked views from the ledger before startup cleanup or polling.
   ClaimStore has distinct `scheduler` and `offline_control` modes. An offline
   command may run only after exclusive acquisition of the same OS lock proves
   that the scheduler is absent. It validates the complete ledger and performs
   a CAS against the persisted current token, including the existing
   `owner_instance` as an opaque expected value, but never adopts or changes
   that owner or the global generation. Its only write operations are
   `inspect-recovery` (`recovery_required|recovery_candidate ->
   recovery_candidate`, only after old local and remote process death is
   proved) and `authorize-recovery` (`recovery_candidate ->
   recovery_authorized`, the never-prepared null-attestation exception below,
   or expiry normalization `expired recovery_authorized -> recovery_required`
   which emits no new token and requires later inspection and authorization).
   Each increments claim revision and commits through the same
   checkpoint/marker/ledger transaction. `claims list` is read-only; no other
   offline edge or side effect exists. Scheduler startup acquires the lock,
   generates its owner instance, atomically increments the persisted global
   scheduler generation exactly once, and in the same ledger transaction
   applies the following exhaustive takeover table before readiness is exposed.
   Every retained claim receives the new owner/generation and `revision + 1`,
   making every prior CAS token stale; recovery-token hashes are separate from
   CAS tokens. No catch-all state is accepted.

   | Persisted input | Startup output | Required retained evidence |
   |---|---|---|
   | `claimed_unprepared|claimed_preparing|running|retrying|blocked` | `recovery_required` | last execution/preparation attempt and observation |
   | `recovery_required|recovery_candidate` | same state | candidate and inspection revision, if any |
   | unexpired `recovery_authorized` | `recovery_authorized` | token hash/expiry/candidate; hash remains usable |
   | expired `recovery_authorized` | `recovery_required` | expiry audit; token hash cleared |
   | `recovery_reserved` | `recovery_required` | consumed hash remains cleared; attempt marked spent |
   | `terminal_verified` | `terminal_verified` | complete history proof |
   | `cleanup_complete_noop` | `cleanup_complete_noop` | never-created proof |

   `released` is never a live claim state: explicit release atomically removes
   the claim and writes an immutable, owner-independent tombstone containing
   claim key, final revision, release reason, final checkpoint hash, and
   transition ID. Startup validates tombstones and they prevent stale
   checkpoint resurrection while freeing workspace/ref resource reservations.
   The primary-state table applies only after every active local control and
   remote lease from the previous generation has been fenced as specified
   below. Until all such attempts are provably terminated, readiness remains closed and the whole
   scheduler performs no polling or dispatch. After that global barrier it may
   continue polling unrelated issues, but never dispatch
   the claimed issue or create another workspace/branch. Add an offline
   `bin/symphony claims list`, `bin/symphony claims inspect-recovery`, and
   `bin/symphony claims authorize-recovery`
   control path which acquires the same OS lock, requires the exact claim key,
   generation, revision and the recorded identity (including explicit `null`
   attestation fields for pre-creation crashes), and writes a random token hash
   plus an expiry as `recovery_authorized`. Authorization requires an exact
   current matching candidate when any external fence or workspace attempt
   occurred: `external_fences_only` before workspace creation, otherwise
   `workspace_snapshot`. A current,
   unexpired authorization is rejected. For an expired authorization the
   command performs only the explicit expiry-normalization edge, retains the
   prior candidate digest as audit evidence, emits no token, and exits; the
   operator must run a new stable `inspect-recovery` to create a higher
   candidate revision and then invoke authorization again whenever any
   external fence or workspace preparation attempt occurred. A durable never-prepared
   claim with null attestation has nothing local to inspect and may instead take
   the already-declared direct
   `recovery_required -> recovery_authorized` exception after normalization.
   That exception additionally requires the brokers to prove the deterministic
   tracker and provider control refs and the privileged workspace fence absent;
   a matching or conflicting fence requires the inspection/recovery path.
   Neither path can revive a reserved or spent token. The plaintext token is displayed
   once and never stored. On the next start, the operator supplies that token
   through a one-shot owner-only file descriptor or protected TTY prompt; it is
   forbidden in argv, environment, workflow files, crash reports, and logs.
   At reservation time ClaimStore constant-time compares its hash and evaluates
   expiry against the persisted wall-clock deadline; an expired authorization
   transitions back to `recovery_required` without a side effect. ClaimStore
   first durably CAS-reserves a valid token into `recovery_reserved`, binding it
   to the already-current scheduler generation/owner and a new
   revision/transition, `recovery_attempt_id`, and
   `execution_attempt_id`, and clears the reusable token hash. Only that
   reservation may perform one reconciliation attempt. For a pre-creation
   claim it may either attest an already present exact planned path or, only
   when the record proves no prior creation attempt reached
   `claimed_preparing`, authorize one new creation. An `external_fences_only`
   candidate must reuse every exact bound receipt/object/file, may acquire only
   its ordered missing fence suffix, and may then take this one creation path;
   it never creates or replaces an already-present fence. For an attested claim it
   fetches and revalidates the exact issue, workspace, repository/ref/SHA. A
   successful attestation is durably committed before resume acknowledgement.

   A local attempt has no remote lease, but it has an independent durable
   privileged control record. Its deterministic path is derived from the raw
   claim-key digest plus `execution_attempt_id` beneath the fixed local
   worker-control root: `/var/db/openai-symphony/local-control-v1` on Darwin or
   `/var/lib/openai-symphony/local-control-v1` on Linux. The root, helper
   service identity, and control-lock path are not configurable; the root is
   never under a workspace or claim directory. A
   v2 local claim persists nullable `current_local_execution_id`, corresponding
   nullable `active_local_execution`, and ordered append-only
   `terminated_local_execution_history`. The two current fields are both null
   or both present with the same ID. An active record binds its unique control
   ID/path and backing identity, worker fingerprint, claim key, attempt owner/
   generation, `attempt_start_revision`, execution-attempt ID, phase,
   `launch_nonce_hash`, privileged helper/service identity,
   service-manager backend identity, deterministic unit identity, fixed launch-
   registry path/hash, deterministic child-launch ID, watchdog/child PID-start
   identities, process group, sole control-channel generation,
   heartbeat epoch/monotonic deadline, provision-gate nonce hash/state/epoch,
   execution-gate nonce hash/state/epoch, and these explicit receipt-hash
   fields: `control_create_receipt_hash`,
   `provision_gate_consumed_receipt_hash`, `spawn_receipt_hash`,
   `last_heartbeat_receipt_hash`, `execution_gate_prepare_receipt_hash`,
   `execution_gate_consumed_receipt_hash`, `terminal_receipt_kind`, and
   `terminal_receipt_hash`. Active
   phases are exactly `pending|watchdog_bound|gate_authorized|
   gate_open_observed|execution_authorized|execution_open_observed`; only
   terminated records occur in
   history. Remote claims require both local current fields null and local
   history empty; local claims require both remote lease fields null and remote
   history empty.

   Every local privileged receipt is the exact byte string
   `"symphony-local-control-receipt-v1\\0" <> u8(kind) <> common <> suffix`,
   where `common = bytes(raw_claim_key_digest) <>
   bytes(local_execution_id) <> bytes(attempt_owner) <>
   u64(attempt_generation) <> u64(attempt_start_revision) <>
   bytes(execution_attempt_id) <> bytes(launch_nonce_hash) <>
   bytes(worker_fingerprint) <> bytes(canonical_control_path) <>
   bytes(backing_path_identity) <> bytes(helper_service_identity) <>
   bytes(control_channel_generation) <> bytes(child_launch_id)`. `bytes` is unsigned-big-endian u64
   length framing; `maybe(x)` is `u8(0x00)` for null or
   `u8(0x01) <> bytes(x)` for present and no other tag is legal. The exhaustive
   kind/suffix table is:

   | Kind | Name | Exact suffix |
   |---:|---|---|
   | `0x01` | control created/watchdog bound | `bytes(watchdog_pid_start_identity) <> bytes(empty_process_group_identity) <> u64(initial_deadline_ns) <> bytes(watchdog_bound_state_sha256)` |
   | `0x02` | provision gate consumed | `bytes(provision_gate_nonce_hash) <> u64(1) <> bytes(watchdog_pid_start_identity)` |
   | `0x03` | child spawned | `bytes(child_pid_start_identity) <> bytes(process_group_identity) <> bytes(spawn_record_sha256)` |
   | `0x04` | heartbeat | `u64(heartbeat_epoch) <> u64(deadline_ns) <> bytes(watchdog_pid_start_identity) <> bytes(process_group_identity) <> bytes(heartbeat_state_sha256)` |
   | `0x05` | execution gate prepared | `bytes(execution_gate_nonce_hash) <> u64(0) <> bytes(attestation_checkpoint_sha256)` |
   | `0x06` | execution gate consumed | `bytes(execution_gate_nonce_hash) <> u64(1) <> bytes(process_group_identity)` |
   | `0x07` | terminated/reaped | `u8(termination_reason) <> u8(last_nonterminal_substate) <> bytes(watchdog_pid_start_identity) <> maybe(child_pid_start_identity) <> maybe(process_group_identity) <> bytes(reap_observation_sha256)` |
   | `0x08` | no local watchdog created | `bytes(absence_observation_sha256)` |
   | `0x09` | aborted before bind | `u8(last_nonterminal_substate) <> maybe(watchdog_pid_start_identity) <> bytes(reap_observation_sha256)` |

   Helper state is an append-only sequence, not an in-place file. Sequence `n`
   is exclusively created at
   `<fixed-local-control-root>/<claim-key-hex>/<execution-attempt-hex>/states/<20-digit-n>`;
   gaps, alternate spellings, replacement, or more than one successor fail
   closed. Its exact bytes are
   `"symphony-local-control-state-v1\\0" <> common <> u64(n) <>
   bytes(previous_state_sha256_or_32_zero_bytes) <> u8(substate) <>
   bytes(service_manager_backend_identity) <> bytes(deterministic_unit_identity) <>
   maybe(watchdog_pid_start_identity) <>
   maybe(child_pid_start_identity) <> maybe(process_group_identity) <>
   u8(provision_gate_state) <> u64(provision_gate_epoch) <>
   maybe(provision_gate_nonce_hash) <> u64(heartbeat_epoch) <>
   u64(deadline_ns) <> maybe(previous_heartbeat_receipt_sha256) <>
   u8(execution_gate_state) <>
   u64(execution_gate_epoch) <> maybe(execution_gate_nonce_hash) <>
   maybe(attestation_checkpoint_sha256) <> maybe(termination_reason_bytes) <>
   maybe(reap_observation_sha256)`. Substates are intent `0x01`, launch
   registered `0x02`, watchdog started `0x03`, watchdog bound `0x04`, provision
   gate consumed `0x05`, child launch registered `0x06`, child spawned `0x07`,
   execution gate prepared `0x08`, execution gate consumed `0x09`, terminated
   `0x0a`, or pre-bind aborted `0x0b`. Gate states are absent
   `0x00`, closed `0x01`, and consumed `0x02`. A fixed validator defines the
   only legal non-null fields and predecessor for every substate; notably intent
   and launch-registered have no PID/group, watchdog-started has the watchdog
   identity but no child/group, child-launch-registered has its deterministic
   launch ID but no child PID, child-spawned has all exact identities, and
   terminal states add only reason/reap evidence. Each record is chmod 0600, fsynced, directory-fsynced,
   reread and hashed under the helper lock before any receipt is returned.
   Receipt suffix state hashes, including `spawn_record_sha256`, are hashes of
   these canonical records. Privileged observation hashes use exactly the
   canonical codecs below; no implementation-defined process-table text,
   timestamp, or serialization is accepted.

   The absence observation is exactly
   `"symphony-local-control-observation-v1\\0" <> u8(0x01) <> common <>
   bytes(expected_state_zero_path) <> bytes(launch_registry_path) <>
   bytes(service_manager_backend_identity) <>
   bytes(deterministic_unit_identity) <> u8(0x00) <> u8(0x00) <> u8(0x00)`,
   where the final values prove state, registry entry, and unit all absent while
   holding the attempt lock. The reap observation is exactly the same prefix
   with kind `0x02`, followed by `common <> bytes(last_state_sha256) <>
   u8(last_nonterminal_substate) <> bytes(deterministic_unit_identity) <>
   maybe(watchdog_pid_start_identity) <> maybe(child_pid_start_identity) <>
   maybe(process_group_identity) <> u8(term_result) <> u8(kill_result) <>
   u8(wait_result) <> maybe(wait_status_bytes) <> u8(unit_inactive) <>
   u8(group_empty)`. The fixed validator defines the exhaustive one-byte
   result enums and canonical wait-status bytes per supported platform; unknown
   values fail closed. For `intent|launch registered|watchdog started`, receipt
   `0x09` binds this observation and child/group must be null. For `watchdog
   bound|provision gate consumed`, receipt `0x07` permits child/group null; from
   `child spawned` onward both are required. In all `0x07` cases the unit must
   be inactive and any present group empty; the PID/start handle must be reaped
   or be proven never started by the service manager. Receipt `0x08` is legal
   only with the exact all-absent observation.

   The create-once absence tombstone path is
   `<fixed-local-control-root>/<claim-key-hex>/<execution-attempt-hex>/absence`.
   Its exact bytes are
   `"symphony-local-absence-tombstone-v1\\0" <> common <>
   bytes(absence_observation_sha256) <> bytes(receipt_0x08_sha256)`. While
   holding the attempt lock, the helper first proves the state directory,
   launch-registry record, and service-manager unit absent, constructs the
   canonical observation and receipt, creates this pathname with
   `O_CREAT|O_EXCL|O_NOFOLLOW` mode 0600, writes/fsyncs it, fsyncs the parent,
   and rereads/verifies every byte before returning. A partial or mismatched
   file fails closed. State 0 creation performs the inverse check under the same
   lock and is forbidden whenever this path exists; absence creation is
   forbidden whenever any state or registry entry exists. Exact tombstone
   readback is the sole lost-response result and permanently prevents launch.

   IDs, nonces, hashes, PID/start identities, group identities, deadlines, and
   reason codes have one versioned validator with fixed widths/ranges; invalid
   or non-minimal encodings fail closed. Receipt SHA-256 is persisted in the
   correspondingly named ledger field. Active phase nullability is exhaustive:
   `pending` already has the attempt-start revision, launch nonce hash,
   canonical control/registry paths, backend/unit identities, and a preallocated
   channel generation, but has no PID/group or receipt hash; `watchdog_bound` and
   `gate_authorized` require only create; `gate_open_observed` additionally
   requires provision-gate-consumed and spawn; `execution_authorized`
   additionally requires execution-gate-prepare;
   `execution_open_observed` additionally requires execution-gate-consumed.
   From `watchdog_bound` onward heartbeat epoch/hash may be null only before the
   initial create-receipt deadline and otherwise must advance together; a stale
   deadline cannot be committed. All terminal fields are null in active state.
   A history entry requires exactly one terminal receipt: `0x07`, or `0x09` for
   a partial launch, or `0x08` only for an absent `pending` control. Every typed
   CAS byte-verifies the complete receipt, common binding, suffix, current
   phase, required earlier hashes and exact allowed newly non-null fields; it
   cannot carry forward an omitted field or populate a later-phase field.

   `begin_local_preparation` atomically changes
   `claimed_unprepared -> claimed_preparing` while installing `pending`;
   `reserve_local_recovery` atomically consumes authorization into
   `recovery_reserved` while installing `pending`; `start_local_retry` retains
   `retrying`, rotates `execution_attempt_id`, and installs `pending`. Each
   operation stores its committed next claim revision as immutable
   `attempt_start_revision`; every receipt and later history entry retains it.
   Before
   any hook, provisioner, or Codex child can exist, the fixed privileged helper
   holds its fixed control lock and first commits state 0 (`intent`) with the
   launch nonce and both gates closed, before requesting any process. It next
   create-once writes, fsyncs, directory-fsyncs, and rereads
   `<fixed-local-control-root>/launch-registry/<deterministic-unit-hex>.record`.
   The exact registry bytes are
   `"symphony-local-launch-registry-v1\\0" <> common <>
   bytes(service_manager_backend_identity) <> bytes(deterministic_unit_identity)
   <> bytes(intent_state_sha256) <> u8(0x00)`; the final byte means registered,
   and replacement or a second record is forbidden. It then appends `launch
   registered`. Only the privileged OS service manager named by the fixed
   backend may create the watchdog unit, using the pre-registered deterministic
   unit identity as the lookup key and a private pre-bind death channel owned by
   the helper. Raw `fork`, `exec`, or an unregistered unit is forbidden. The
   helper queries the service manager for the exact PID/start handle, appends
   and verifies `watchdog started`, establishes the sole channel generation,
   and appends and verifies `watchdog bound` before returning the create
   receipt. Until the bound record is durable, the watchdog cannot spawn or
   detach any child and must exit when that private channel closes. The helper
   retains the lock throughout; exact byte readback and deterministic
   service-manager lookup are the only lost-response recovery. The create receipt binds
   every active field and the still-empty process group. ClaimStore commits
   `watchdog_bound`, then `gate_authorized`, before
   sending the one-time gate nonce. The deterministic service-manager unit is
   an outer containment object that can enumerate and kill every descendant
   independently of watchdog memory; its backend must attest kill-on-unit/
   watchdog-death plus postmortem unit-empty queries, or local production is
   disabled. The watchdog durably consumes the gate, creates/fsyncs a
   deterministic child-launch record, and appends `child launch registered`
   before asking the service manager to create the provisioner inside that same
   unit. Raw child spawn is forbidden. It then records the returned exact child
   PID/start identity and process group, appends `child spawned`, fsyncs the
   spawn receipt, and returns it before ClaimStore commits
   `gate_open_observed`. After provisioning-only attestation, the helper first
   creates/fsyncs a distinct execution gate in the closed state and returns its
   nonce-hash receipt. ClaimStore atomically commits the attestation, parent
   `running`, and `execution_authorized`; only then does it send that nonce.
   The helper durably consumes the execution gate before releasing hooks or
   Codex and returns the receipt, which ClaimStore commits as
   `execution_open_observed`. A lost response never re-executes the gate, and a
   crash in this window is fenced by the startup protocol rather than adopted.

   The child-launch record path is
   `<attempt-root>/child-launches/<deterministic-child-launch-id-hex>` and its
   exact create-once bytes are
   `"symphony-local-child-launch-v1\\0" <> common <>
   bytes(deterministic_unit_identity) <> bytes(child_launch_id) <>
   bytes(provision_gate_consumed_state_sha256) <> u8(0x00)`. The helper creates
   it with `O_CREAT|O_EXCL|O_NOFOLLOW`, fsyncs, parent-directory-fsyncs, and
   rereads it before the service-manager launch request. The manager accepts a
   child request only when that exact record is readable through its protected
   channel and attaches the child to the pre-existing unit before it can run.
   A lost launch response is recovered only by enumerating that unit; zero or
   one exact child is legal, duplicates fail closed, and termination always
   kills/reaps the entire unit before a terminal receipt is returned.

   Local helper creation is a total crash protocol. No process may exist before
   durable `intent` plus the registry record and `launch registered`. If
   ClaimStore has `pending` and the locked helper observes no state, it verifies
   the create-once launch registry and deterministic service-manager unit are absent,
   appends the terminal absence observation, and returns only receipt `0x08`.
   `intent` without the registry proves that no launch request was legal and
   takes the same `0x09` abort path with a never-started reap observation. For
   `launch registered`, including a lost service-manager response, the helper
   closes the private channel and queries/stops the exact deterministic unit;
   no unit or the exact unit PID/start handle are the only legal results. It
   TERM/KILL/reaps any exact candidate, appends `pre-bind aborted`, and returns
   only receipt `0x09`. `watchdog started` takes the same path using both the
   persisted unit identity and exact PID/start handle. `watchdog bound` or any later nonterminal substate takes the normal
   receipt `0x07` termination path. An internal helper failure cannot release
   the control lock until one of those terminal records is durable. If the
   helper request handler or helper service itself dies, the kernel closes the
   private channel; the separately supervised OS service manager retains the
   deterministic unit identity and exact PID/start handle. The next helper
   generation may acquire the lock only after the prior lock owner is gone and
   queries/reaps that registered unit. It completes `0x09` for pre-bind states
   and `0x07` for bound-or-later states. The latter may use null child/group
   fields only when the exact unit query proves that no descendant is alive;
   unit enumeration, not the missing spawn record, is authoritative. After any
   `0x07|0x09` terminal record for which the registry record exists, the helper
   create-once writes
   `<registry-path>.terminal` as
   `"symphony-local-launch-terminal-v1\\0" <> bytes(registry_record_sha256) <>
   bytes(terminal_state_sha256) <> bytes(terminal_receipt_sha256)`, then fsyncs,
   directory-fsyncs, and rereads it before unlock; the original registry record
   is never removed and the unit identity can never be reused. A process
   without durable intent, duplicate process, still-open prior-generation
   channel, or unverifiable launch/PID/start identity is corruption and keeps
   readiness closed.

   ClaimStore is the sole holder of the protected local control-channel client
   endpoint. While any local preparation/execution child exists it sends a
   monotonic heartbeat at least once per second; the fixed watchdog deadline is
   at most five seconds and each epoch receipt is bound to the complete attempt
   identity. Channel close, stale/wrong epoch, ClaimStore death, or deadline
   expiry makes the privileged watchdog synchronously TERM, then KILL and reap
   the exact PID/start-time/process group, fsync a create-once terminal receipt,
   and permanently refuse gate reopen. The worker cannot inherit, duplicate,
   inspect, or replace either channel endpoint. Normal child exit is handled by
   `complete_local_execution`, whose exhaustive source table is the same as
   `complete_lease`: preparing may close to retrying/blocked/recovery-required;
   running to retrying/blocked/terminal-verified/recovery-required; active
   retrying to null-control retrying/blocked/terminal-verified/recovery-required;
   and recovery-reserved to blocked/recovery-required. Terminal verification
   still requires fresh tracker proof. Every close appends the exact terminated
   record, including the privileged death receipt, and atomically clears the
   current pair; no half-commit is legal.

   The helper-side heartbeat operation is exact and replay-safe. While holding
   the attempt lock it accepts only the complete current binding, channel
   generation, and expected epoch for a `watchdog bound` or later nonterminal
   helper substate. It rereads the unique state head and makes exactly one of
   three decisions: if head epoch equals the expected epoch, it computes the
   successor deadline as the lesser of helper-monotonic-now plus five seconds
   and the fixed policy maximum and appends the one legal successor; if head
   epoch equals expected plus one and its predecessor, deadline, channel,
   complete receipt bytes, and all unchanged fields match the deterministic
   result of that request, it returns the exact existing receipt or creates only
   that missing receipt; every other epoch or byte mismatch fails closed. The
   new same-substate successor changes only heartbeat epoch/deadline and
   `previous_heartbeat_receipt_sha256`. The latter names the preceding epoch's
   receipt or is null only for the first heartbeat. It then constructs receipt
   `0x04`, whose suffix binds the new state hash, and creates
   `<attempt-root>/receipts/heartbeat/<20-digit-new-epoch>` with
   `O_CREAT|O_EXCL|O_NOFOLLOW` mode 0600, full write/fsync, parent-directory
   fsync, and exact byte reread before reply. A byte-identical existing receipt
   is the sole replay result, and the expected-plus-one branch is the sole legal
   helper-ahead case; no second state successor is legal. ClaimStore may
   finish only the same live-generation `renew_local_heartbeat` CAS from that
   exact receipt. Startup or a different generation never adopts helper-ahead
   liveness and instead fences the attempt. Any gap, changed deadline, stale
   channel, mismatched predecessor receipt, or alternate path fails closed.

   On startup, before the primary takeover table, the new ClaimStore handles
   every active local control under the same privileged control lock. For
   `pending` with no control record, the helper issues a create-once
   `no_local_watchdog_created` absence receipt binding the complete attempt and
   canonical control-path identity and permanently refuses later creation for
   that ID. Live `complete_local_execution` uses the identical locked operation
   when a pending attempt ends before helper creation. An `intent`, `launch
   registered`, or `watchdog started` partial state is closed by the exact pre-bind-abort
   protocol above and receipt `0x09`. For `watchdog bound` or any later
   nonterminal state, startup validates the exact control record, channel generation,
   watchdog and group identities, then TERM/KILL/reaps every member and fsyncs
   the terminal receipt. Exact absence or death receipt readback is idempotent;
   missing, mismatched, PID-reuse-ambiguous, unkillable, or unverifiable state
   keeps readiness closed. Only then may startup atomically append the
   terminated record, clear the local pair, and execute
   `record_local_fence_loss -> recovery_required`. Terminated local history is
   immutable, ordered by attempt-start revision, uniquely binds every control/
   execution-attempt ID, and is hashed by every checkpoint.

   Each remote attempt derives its lease path deterministically from claim-key
   hash plus `execution_attempt_id` under a fixed out-of-workspace worker-control
   root. A v2 claim persists `execution_transport=local|remote`, exactly one
   nullable `current_lease_id`, the corresponding `active_lease` record, and an
   ordered append-only `terminated_lease_history`. A lease attempt contains its unique deterministic
   `lease_id`, control path, remote backing-path identity, worker fingerprint,
   claim key, `attempt_owner`,
   `attempt_generation`, `attempt_start_revision`, execution-attempt binding,
   phase, launch-nonce hash, fixed service-manager backend identity,
   deterministic outer-unit identity, intent/attempt-registry/host-unit-registry
   hashes, receipt hash,
   supervisor PID/start-time/process-group, renewal epoch, fixed TTL, remote
   monotonic deadline, last renewal-receipt hash, provision-gate nonce hash,
   state, epoch and consumed/spawn-receipt hashes, execution-gate nonce hash,
   state, epoch and prepare/consumed-receipt hashes, and termination-receipt
   hash. Plaintext gate and renewal secrets are never persisted locally. Active phases are exactly
   `pending|bound|provision_authorized|provision_open_observed|
   execution_authorized|execution_open_observed`; `terminated` is legal
   only in history. Starting a remote attempt atomically installs a fresh
   `current_lease_id` plus `active_lease` whose ID occurs nowhere in active or
   history, and stores that transaction's committed next claim revision as
   immutable `attempt_start_revision`. Phase and renewal CASes replace only that active record under the
   complete claim transaction. Normal completion or fencing atomically appends
   the exact final record with `phase=terminated` and its terminal receipt to
   history and clears `current_lease_id` and `active_lease`; neither half may
   commit alone. Once appended, every byte of a history entry is immutable.

   `current_lease_id` and `active_lease` are either both null or both present;
   when present, the current ID must equal the active record's `lease_id`.
   Startup and every transaction reject a one-sided or mismatched pair.

   A local transport requires `current_lease_id=null`, `active_lease=null`, and
   empty remote lease history in every lifecycle state. Its local-control pair
   is null in `claimed_unprepared|recovery_required|recovery_candidate|
   recovery_authorized|blocked|terminal_verified|cleanup_complete_noop`;
   present in `claimed_preparing|recovery_reserved`; either null during backoff
   or present after `start_local_retry` in `retrying`; and present at
   `execution_authorized|execution_open_observed` in `running`. Only
   `execution_open_observed` permits hooks or Codex. A null pair plus empty local history
   proves no local watchdog was ever created; a null pair plus nonempty complete
   history proves every earlier local attempt terminated. Transport is pinned
   at claim creation and cannot change. A
   remote transport permits `claimed_unprepared` with both lease fields null before
   its first attempt; `claimed_preparing|recovery_reserved` with an active phase;
   `retrying` with both lease fields null during live-generation backoff or with
   both fields present and the active record in any active phase after
   `start_retry_lease`, while its gated runner is
   preparation/reattestation-only;
   `running` only with `execution_authorized|execution_open_observed`, and only
   `execution_open_observed` permits `before_run` or Codex; `recovery_required|
   recovery_candidate|recovery_authorized|blocked|terminal_verified|
   cleanup_complete_noop` only with both lease fields null. Both null plus empty history
   proves no remote lease was ever created; null plus nonempty history proves
   all earlier attempts terminated. Worker attestation kind must equal
   `execution_transport`. Every phase change uses the same owner/generation/
   revision CAS and checkpoint/marker/ledger transaction as a parent
   transition; every unlisted combination fails startup.

   For every active lease, `attempt_owner` and `attempt_generation` equal the
   current claim token. Terminated history deliberately retains its old attempt
   bindings while later parent takeover changes only the claim token. History
   is sorted by strictly increasing attempt-start claim revision; lease IDs and
   execution-attempt IDs are unique across active and history. Each checkpoint
   hashes the complete history. Startup rejects missing, duplicated, reordered,
   altered, non-terminated, or terminal-receipt-less history entries, and a
   transaction marker resolves a crash at append/clear exactly as any other
   indivisible next-ledger commit.

   The remote privileged control root is immutable and not configurable:
   `/var/db/openai-symphony/remote-control-v2` on Darwin and
   `/var/lib/openai-symphony/remote-control-v2` on Linux. Unsupported systems
   and a root whose physical device/inode/owner/mode differs from the installed
   helper manifest fail readiness. For worker fingerprint `W`, claim hex `C`,
   and lease hex `L`, the sole attempt-artifact lock is
   `<root>/locks/W/C/L.lock` and the attempt
   root is `<root>/leases/W/C/L`. Exact descendants are `states/<20-digit-n>`,
   `provision-gate/<20-digit-epoch>`, `execution-gate/<20-digit-epoch>`,
   `spawn/00000000000000000000`, `receipts/<two-lowercase-hex-kind>/<20-digit-epoch>`,
   `intent`, `launch-registry`, `launch-terminal`, `observations/reap`,
   `observations/prebind-reap`, and `absence`. No alternate root, spelling, symlink,
   mount alias, or caller-supplied path is legal; the helper opens every
   component by descriptor with no-follow checks and revalidates physical
   identity while holding the required ordered locks.

   `remote_backing_path_identity` always identifies the already-open fixed
   remote control root itself, never an attempt parent or not-yet-created
   attempt root. Its exact bytes are
   `"symphony-remote-backing-path-v1\\0" <> u8(platform) <>
   bytes(canonical_physical_root) <> platform_physical_id`, using the exact
   shared Darwin/Linux `platform_physical_id` encoder above, including indexed
   fsid u32 bit patterns on Darwin and four ordered u64 fields on Linux. All
   byte strings use the canonical u64 length frame; unavailable, overflowing,
   alternate, or non-minimal values fail closed. The scheduler obtains this
   value from the fixed helper and persists it in `active_lease` as part of the
   atomic parent-plus-`pending` transaction before any remote side effect. The
   helper independently recomputes it from its open no-follow root descriptor
   for intent/absence creation and every bind, renewal, termination, and startup
   operation; exact mismatch, root drift, or alias drift closes readiness.

   The helper independently derives
   `unit_digest = SHA256("symphony-remote-unit-identity-v1\\0" <>
   bytes(worker_fingerprint) <> bytes(raw_claim_key_digest) <>
   bytes(lease_id) <> bytes(execution_attempt_id))`; caller-supplied unit names
   are forbidden. The sole canonical service-manager identity is
   `openai.symphony.remote.<64-lowercase-hex-unit-digest>` on Darwin or
   `openai-symphony-remote-<64-lowercase-hex-unit-digest>.service` on Linux.
   The host-global unit lock is `<root>/unit-locks/<64-lowercase-hex-unit-digest>.lock`
   and is always acquired before the attempt lock; no code path may reverse or
   omit that order when inspecting, creating, stopping, or certifying absence
   of a unit.

   Before a remote supervisor can exist, the helper uses
   `remote_intent_common = bytes(raw_claim_key_digest) <> bytes(lease_id) <>
   bytes(attempt_owner) <> u64(attempt_generation) <>
   u64(attempt_start_revision) <> bytes(execution_attempt_id) <>
   bytes(worker_fingerprint) <> bytes(canonical_lease_path) <>
   bytes(remote_backing_path_identity) <> bytes(service_manager_backend_identity) <>
   bytes(deterministic_unit_identity) <> bytes(launch_nonce_hash)`. The exact
   intent bytes are `"symphony-remote-launch-intent-v1\\0" <>
   remote_intent_common`; the exact registry bytes are
   `"symphony-remote-launch-registry-v1\\0" <> remote_intent_common <>
   bytes(intent_sha256) <> u8(0x00)`. Before launch the helper also creates the
   host-global `<root>/unit-registry/<64-lowercase-hex-unit-digest>.record` as
   `"symphony-remote-unit-registry-v1\\0" <> remote_intent_common <>
   bytes(intent_sha256) <> bytes(attempt_launch_registry_sha256) <> u8(0x00)`.
   Each record is create-once with mode 0600,
   `O_CREAT|O_EXCL|O_NOFOLLOW`, full write/fsync, parent-directory fsync, and
   exact byte reread under both ordered locks. An existing byte-identical
   host-global record is usable only to recover that same attempt; any different
   binding at the same digest is a fatal collision, and the helper must neither
   query nor stop that differently bound unit. Only the fixed OS service-manager
   backend may start the pre-registered deterministic outer-containment unit;
   raw fork/exec is forbidden. The unit remains queryable across helper death,
   kills all descendants on supervisor/helper death, and supplies exact
   supervisor PID/start and group identities before a bound lease state may be
   written. If the backend cannot attest these properties, remote production is
   disabled. After a pre-bind abort, the helper creates `launch-terminal` as
   `"symphony-remote-launch-terminal-v1\\0" <> maybe(registry_sha256) <>
   maybe(host_unit_registry_sha256) <>
   bytes(remote_prebind_reap_observation_sha256) <>
   bytes(receipt_0x07_sha256)` with the same create/fsync/directory-fsync/reread
   discipline; intent, registry, and terminal records are never removed or
   reused.

   Every remote privileged receipt of kind `0x01` through `0x06` is exactly
   `"symphony-remote-control-receipt-v2\\0" <> u8(kind) <> remote_common <>
   suffix`, where `remote_common = bytes(raw_claim_key_digest) <>
   bytes(lease_id) <> bytes(attempt_owner) <> u64(attempt_generation) <>
   u64(attempt_start_revision) <> bytes(execution_attempt_id) <>
   bytes(worker_fingerprint) <> bytes(canonical_lease_path) <>
   bytes(remote_backing_path_identity) <> bytes(service_manager_backend_identity) <>
   bytes(deterministic_unit_identity) <> bytes(launch_nonce_hash) <>
   bytes(intent_sha256) <> bytes(registry_sha256) <>
   bytes(host_unit_registry_sha256) <>
   bytes(supervisor_pid_start_identity) <>
   bytes(process_group_identity)`. The exhaustive kinds are: bind `0x01` with
   `bytes(lease_record_sha256) <> bytes(provision_gate_nonce_hash) <> u64(0)`;
   provision consumed/spawned `0x02` with
   `bytes(provision_gate_nonce_hash) <> u64(1) <>
   bytes(child_pid_start_identity) <> bytes(spawn_record_sha256)`; execution
   prepared `0x03` with `bytes(execution_gate_nonce_hash) <> u64(0) <>
   bytes(attestation_checkpoint_sha256) <>
   bytes(closed_execution_gate_record_sha256)`; execution consumed `0x04` with
   `bytes(execution_gate_nonce_hash) <> u64(1) <>
   bytes(attestation_checkpoint_sha256) <>
   bytes(consumed_execution_gate_record_sha256)`; renewal `0x05` with
   `u64(previous_renewal_epoch) <> u64(new_renewal_epoch) <>
   u64(remote_deadline_ns) <> bytes(lease_record_sha256)`; and termination
   `0x06` with `u8(last_lifecycle_substate) <> bytes(reap_observation_sha256)`.
   Pre-bind abort receipt `0x07` instead uses
   `"symphony-remote-control-receipt-v2\\0" <> u8(0x07) <>
   remote_intent_common <> maybe(supervisor_pid_start_identity) <>
   maybe(process_group_identity) <>
   bytes(remote_prebind_reap_observation_sha256)`. Receipt paths and epochs are
   exhaustive: bind `0x01/00000000000000000000`, provision
   `0x02/00000000000000000001`, execution prepared
   `0x03/00000000000000000000`, execution consumed
   `0x04/00000000000000000001`, renewal `0x05/<20-digit-new-renewal-epoch>`,
   termination `0x06/00000000000000000000`, and pre-bind abort
   `0x07/00000000000000000000`, each beneath `receipts/<two-lowercase-hex-kind>/`.
   Every receipt uses mode 0600, `O_CREAT|O_EXCL|O_NOFOLLOW`, full write/fsync,
   parent-directory fsync, and exact byte reread under the remote lock. Only a
   byte-identical record at that exact path is a legal lost-response replay;
   partial, mismatched, duplicated, or alternate-path content fails closed.
   `bytes` and all fixed-width values use the same canonical framing rules as
   the local codec; unknown kinds, phases, or enum values fail closed.

   The remote execution-gate records are exactly
   `"symphony-remote-execution-gate-v1\\0" <> remote_common <>
   bytes(previous_gate_record_sha256_or_32_zero_bytes) <>
   bytes(execution_gate_nonce_hash) <> u64(execution_gate_epoch) <>
   u8(execution_gate_state) <> bytes(attestation_checkpoint_sha256)`, with state
   closed `0x01` or consumed `0x02`. They are create-once/append-only under the
   remote control lock; the consumed record names the closed-record hash as its
   predecessor in the enclosing canonical lease record. Active-field
   nullability is exhaustive: `pending` requires launch nonce plus fixed
   backend/unit identities but has null intent/registry/receipt/gate hashes;
   `bound` and `provision_authorized` require durable intent/attempt-registry/
   host-unit-registry hashes, bind, and a closed provision gate;
   `provision_open_observed` additionally requires provision-consumed and spawn
   receipts; `execution_authorized` additionally requires attestation plus the
   execution-prepare receipt and closed execution gate; and
   `execution_open_observed` additionally requires its consumed record and
   receipt. Each typed CAS byte-verifies `remote_common`, the exact suffix,
   predecessor record and the only newly legal fields.

   All remote control evidence lives below
   `<root>/leases/<worker-fingerprint>/<claim-key-hex>/<lease-id-hex>/`.
   Lease state sequence `n` is create-once at `states/<20-digit-n>` and is
   exactly `"symphony-remote-lease-state-v2\\0" <> u64(n) <>
   bytes(previous_state_sha256_or_32_zero_bytes) <> remote_common <>
   u8(lifecycle_substate) <> maybe(child_pid_start_identity) <>
   u8(provision_gate_state) <> u64(provision_gate_epoch) <>
   bytes(provision_gate_nonce_hash) <> maybe(provision_gate_receipt_sha256) <>
   maybe(spawn_record_sha256) <> u8(execution_gate_state) <>
   u64(execution_gate_epoch) <> maybe(execution_gate_nonce_hash) <>
   maybe(attestation_checkpoint_sha256) <>
   maybe(execution_prepare_receipt_sha256) <>
   maybe(execution_consumed_receipt_sha256) <> u64(renewal_epoch) <>
   u64(remote_deadline_ns) <> maybe(previous_renewal_receipt_sha256) <>
   maybe(reap_observation_sha256)`. Provision gate records at
   `provision-gate/<20-digit-epoch>` are exactly
   `"symphony-remote-provision-gate-v1\\0" <> remote_common <>
   bytes(previous_gate_record_sha256_or_32_zero_bytes) <>
   bytes(provision_gate_nonce_hash) <> u64(provision_gate_epoch) <>
   u8(provision_gate_state)`, where closed is `0x01` and consumed is `0x02`.
   The spawn record at `spawn/00000000000000000000` is exactly
   `"symphony-remote-spawn-v1\\0" <> remote_common <>
   bytes(consumed_provision_gate_record_sha256) <>
   bytes(child_pid_start_identity) <> bytes(process_group_identity)`.

   The remote reap observation at `observations/reap` is exactly
   `"symphony-remote-reap-observation-v1\\0" <> remote_common <>
   bytes(last_lease_state_sha256) <> u8(last_lifecycle_substate) <>
   maybe(child_pid_start_identity) <> u8(term_result) <> u8(kill_result) <>
   u8(wait_result) <> maybe(wait_status_bytes) <> u8(supervisor_inactive) <>
   u8(group_empty)`. The same fixed result enums/canonical wait-status rules as
   local apply; a valid terminal observation requires inactive supervisor and
   empty group. The pre-bind reap observation at `observations/prebind-reap` is
   exactly `"symphony-remote-prebind-reap-observation-v1\\0" <>
   remote_intent_common <> maybe(registry_sha256) <>
   maybe(host_unit_registry_sha256) <>
   maybe(supervisor_pid_start_identity) <> maybe(process_group_identity) <>
   u8(term_result) <> u8(kill_result) <> u8(wait_result) <>
   maybe(wait_status_bytes) <> u8(unit_inactive) <> u8(group_empty)`; it is
   valid only when the deterministic unit is inactive and empty and every
   present PID/start identity has been reaped. Every intent/registry/state/gate/
   spawn/observation/receipt file is mode 0600,
   `O_CREAT|O_EXCL|O_NOFOLLOW`, fully written and fsynced, parent-directory-
   fsynced, then byte-reread and hash-verified under the remote lock before the
   next side effect or receipt. Gaps, replacement, extra successors, wrong
   predecessors, alternate paths, or impossible nullability fail closed. Golden
   fixtures pin every codec and receipt hash.

   Remote lifecycle substates are exactly bound `0x01`, provision-gate-
   consumed `0x02`, child-spawned `0x03`, execution-gate-prepared `0x04`,
   execution-gate-consumed `0x05`, and terminated `0x06`. The only base
   successors are `0x01 -> 0x02 -> 0x03 -> 0x04 -> 0x05 -> 0x06`, plus a
   termination successor from any nonterminal substate. A renewal is a new
   sequence record that retains the same nonterminal substate and all gate/
   spawn fields, increments only renewal epoch and deadline, and stores the
   prior renewal receipt hash; the newly returned renewal receipt hashes that
   new state record, so no state/receipt hash is circular. Termination first
   writes the reap observation, then appends `0x06` containing its hash, then
   writes receipt `0x06` from the last nonterminal substate and that same reap
   hash; only the local terminated-history record stores the terminal receipt
   hash. Thus no remote state/receipt hash cycle exists. Recovery may complete
   those exact missing suffix steps but can never return to a nonterminal
   substate.

   The exhaustive remote disk-prefix decisions under the lock are: no attempt
   files permits only the `pending` absence protocol; intent without the
   attempt registry, or attempt registry without the host-unit registry, proves
   no launch was legal and completes only pre-bind abort `0x07`; a byte-exact
   host-unit registry with a missing, present, or response-unknown deterministic unit is
   resolved only by querying that exact service-manager unit, closing its
   private pre-bind channel, TERM/KILL/reaping any exact PID/start/group,
   writing the pre-bind reap observation and `0x07`, and then writing
   `launch-terminal`. A process without intent, an unregistered or duplicate
   unit, or an unverifiable identity is corruption and closes readiness. For a
   pre-bind attempt, the sole complete terminal suffix is pre-bind observation,
   receipt `0x07`, then `launch-terminal`; that terminal file is authoritative
   on restart, no lease-state record is legal, and recovery may create only a
   byte-identical missing suffix in that order. A bound state with no provision
   gate permits recovery to create/fsync/reread only the deterministic closed/0
   gate whose nonce hash and predecessor are already fixed by that bound state;
   it then follows the ordinary bound prefix and never launches or consumes a
   gate. A bound state with its closed provision gate but no bind receipt recreates only that deterministic
   receipt, and startup then fences unless the still-live creation call can
   complete the exact local `pending -> bound` CAS. Bound state plus closed
   provision gate permits no spawn without a fresh locally committed provision
   authorization; consumed provision gate with no `0x02` state appends only
   that state then fences; `0x02` with no child/spawn record terminates the
   outer group and fences; a spawn record with no `0x03` state appends only the
   matching state then fences; `0x03` with no provision receipt recreates only
   the deterministic receipt then fences; a closed execution gate with no
   `0x04` state/prepare receipt completes only those deterministic records then
   fences; a consumed execution gate with no `0x05` state/receipt completes
   only those records, never releases execution, then fences; `0x05` may
   continue only for the live generation after the exact local
   `execution_open_observed` CAS, otherwise it fences. A renewal state without
   its receipt recreates only that receipt; any remote epoch ahead of the local
   ledger fences. Reap observation, terminated state, or terminal receipt
   prefixes complete only the remaining terminal suffix. Every other prefix,
   duplicate, gap, impossible non-null field, or local/remote phase mismatch
   keeps readiness closed. Startup never respawns, reconsumes, or re-releases a
   gate while completing a prefix.

   Cross-host ordering is: commit the parent plus `active_lease.phase=pending`;
   acquire the host-unit lock and then remote attempt lock; reject an existing
   absence; create, fsync, directory-fsync, and reread intent, attempt registry,
   then host-unit registry; ask only the fixed
   service manager to launch the registered outer-containment unit; query and
   bind its exact supervisor PID/start and process group; then exclusively
   create/fsync the bound lease state and closed provision gate; receive a
   random-nonce receipt containing all identity bindings, lease path/file hash,
   supervisor PID/start-time and process-group ID. The provision gate starts as
   `closed/0`; commit `bound`, then `provision_authorized`, before sending its
   nonce. Under the remote control lock the supervisor constant-time verifies
   that nonce and every claim/owner/generation/attempt binding, durably CASes
   and fsyncs `closed/0 -> consumed/1` before any child spawn, and rejects every
   other nonce or epoch. It spawns at most one child into the recorded group and
   fsyncs its PID/start-time and spawn receipt before replying. Same-nonce replay
   returns only the byte-identical stored receipt and never spawns; consumed
   without a spawn receipt terminates/reaps and requires recovery. A different
   nonce or any replay after termination is rejected. ClaimStore commits that
   receipt only as `provision_open_observed`, without changing the preparation,
   recovery, or retry parent. The gated child may run only the fixed provisioning
   primitive for an initial or authorized recovery-create attempt, or read-only
   reattestation for an existing/retry workspace; it must then wait.

   After validating the canonical workspace, provider reservation, repository/
   full ref, baseline/current SHA, and content evidence, the remote helper
   create-once writes and fsyncs a distinct execution gate in `closed/0` and
   returns a prepare receipt binding the full lease identity, attestation
   checkpoint hash, execution nonce hash, and exact gate-record hash.
   ClaimStore byte-verifies it and atomically binds the attestation, transitions
   the parent to `running`, and advances the lease to `execution_authorized`;
   only then does it send the one-time execution nonce. The supervisor verifies
   the nonce and exact lease/owner/generation/attempt/attestation bindings,
   durably CASes and fsyncs the execution gate `closed/0 -> consumed/1` before
   releasing `before_run` or Codex, and returns a consumed receipt bound to the
   exact group. Same-nonce replay returns only the byte-identical stored receipt
   and never releases execution twice; another nonce/epoch is rejected. If
   consumption is durable but the receipt is absent, it permanently refuses
   release, terminates/reaps, and requires recovery. ClaimStore commits the
   receipt only as `execution_open_observed`; that is the sole phase permitting
   general execution. Stale or mismatched attestation terminates the group and
   blocks or requires recovery without authorization. The watchdog kills the
   group if its supervisor dies in either consume/spawn/receipt window. A crash
   at any boundary leaves both gate states durable and startup never adopts an
   indeterminate or merely authorized execution.

   The TTL is a bounded trusted configuration value (default 30 seconds), and
   renewal begins no later than one third of the TTL. The remote supervisor uses
   only its monotonic clock. A renewal request names the claim key, lease ID,
   owner, generation, execution attempt, current epoch, and a high-entropy
   control secret available only through the protected channel. Under its
   control lock the supervisor compare-and-swaps the exact bindings and epoch,
   increments the epoch, sets a deadline no later than remote-now plus TTL,
   fsyncs the lease and receipt, and returns the new epoch, deadline, and receipt
   hash. ClaimStore exposes only a dedicated
   `renew_lease(expected_claim_token, lease_id, expected_epoch, receipt)` CAS;
   it permits exactly a parent self-edge with the same active phase for any
   live `bound|provision_authorized|provision_open_observed|
   execution_authorized|execution_open_observed` remote lease under
   `claimed_preparing|retrying|recovery_reserved|running` only in the legal
   parent/active combinations above, increments claim revision, assigns a new
   transition ID, and commits the complete checkpoint/marker/ledger transaction.
   A stale epoch, token, phase, receipt, or non-remote transport is rejected.
   ClaimStore commits those values locally before treating renewal as healthy.
   A crash before the remote CAS creates no extension; a crash after
   the remote CAS but before the local commit is detected as a higher remote
   epoch during startup and fenced before takeover. An invalid or missed
   renewal, or a transport disconnect reaching the deadline, makes the watchdog
   TERM, then KILL and reap the exact process group, persist a termination
   receipt, and permanently refuse gate reopen. Any renewal error closes
   scheduler readiness and starts no new attempt until exact death and the
   termination receipt are verified.

   On restart, before the primary-state takeover table is applied, the new
   scheduler exhaustively handles every active `pending|bound|
   provision_authorized|provision_open_observed|execution_authorized|
   execution_open_observed` lease. It acquires the same remote control lock before
   interpreting the record; it first acquires the host-unit lock, and acquiring
   both in canonical order proves any old lease-creation command has ended. It
   inspects the deterministic path: absence is accepted only for `pending`
   while holding both locks. For that sole boundary the privileged
   helper must create an append-only `no_remote_lease_created` tombstone at the
   exact `<attempt-root>/absence` path before releasing the lock. The tombstone
   bytes are also the exact versioned receipt bytes:
   `"symphony-no-remote-lease-created-v1\\0" <>
   remote_intent_common <> u8(0x00) <> u8(0x00) <> u8(0x00) <>
   u8(0x00) <> u8(0x00)`, where the five zeroes canonically prove no intent, no
   attempt registry, no host-unit registry, no deterministic service-manager
   unit, and no other attempt artifact; `bytes` uses unsigned-big-endian u64
   lengths. Under both ordered locks the helper proves every intent/registry/
   state/gate/spawn/receipt/observation path and the derived host-unit registry
   path absent, and queries the fixed service-manager backend to prove the
   deterministic unit absent. It then creates `absence` with
   `O_CREAT|O_EXCL|O_NOFOLLOW` mode
   0600, fully writes and fsyncs it, fsyncs the attempt directory, and rereads
   every byte before returning its SHA-256. Partial/mismatched content fails
   closed. Intent, attempt/host registry, lease-state, and service-manager launch
   creation perform the inverse check under both locks and refuse any existing
   `absence`; absence creation refuses any other attempt child or existing
   unit. Creation is create-once; exact readback is the only
   lost-response recovery, and once it exists the helper permanently refuses
   lease creation for that lease ID. Live `complete_lease` must use this same
   locked operation when a `pending` attempt ends before remote creation. Its
   SHA-256 is a valid terminal receipt
   only for a `pending` lease whose deterministic path was absent under this
   lock, and is persisted in the terminated history entry during the atomic
   append/pair-clear transaction. A missing, different, or unverifiable receipt
   blocks startup; neither ClaimStore nor the caller may construct it.
   Presence is hash/identity/epoch checked
   and the exact group/watchdog is terminated and reaped. Thus crashes before
   or after remote creation, receipt commit, gate authorization, gate opening,
   or renewal acknowledgement all converge without an unknown process. Before
   recovery reservation, the scheduler must re-attest the worker, issue TERM
   then KILL to the exact old group if present, and confirm by PID/start-time
   plus process-group inspection that no member is alive. Network loss,
   unverifiable identity, PID reuse ambiguity, or failed kill confirmation
   leaves the claim recovery-required, starts nothing, and prevents global
   readiness. Successful fencing commits the parent as `recovery_required`,
   appends the immutable terminated lease to history, and clears both
   `current_lease_id` and `active_lease` in one transaction before the ordinary
   startup table is evaluated. A record with both lease fields null follows
   that table directly after complete history validation.
   A new lease must again
   reach `bound` before its worker may run.
   A crash after reservation is classified at the next locked startup directly
   as `recovery_required` with immutable spent-attempt audit fields; an observed
   live failure commits that same transition directly. There is no durable
   `recovery_spent` state. It can never reuse the token or silently retry. The
   complete recovery graph is `recovery_required -> recovery_candidate ->
   recovery_authorized -> recovery_reserved -> running|blocked|recovery_required`;
   a never-prepared claim may take `recovery_required -> recovery_authorized`
   directly with explicit null attestation fields,
   plus expired `recovery_authorized -> recovery_required`; inspection may
   replace `recovery_candidate` only with a higher revision after a new stable
   observation. No other recovery edge exists and no edge restores a consumed
   hash. A crash
   before reservation leaves the authorization unused because no recovery side
   effect was permitted. Expired, missing,
   changed, non-active, non-routable, or ambiguous identity remains stopped.
   `claims release` is not included: non-terminal abandonment requires a later
   separately reviewed operator workflow so this slice cannot silently discard
   work.

Required verification:

- deterministic barriers and kill/restart tests cover before/after every
  durable transition, worker start, preparation attestation, acknowledgement,
  retry scheduling, block, each cleanup state, authorization reservation and
  recovery side effect; at each
  restart assert zero duplicate worker PID, workspace identity, branch identity,
  or Codex invocation;
- table-driven crash tests prove the exact marker algorithm for every possible
  previous/next ledger and checkpoint presence/hash combination. State-machine
  property tests prove no path reaches worker execution without a current
  claim token, no cleanup path releases before durable
  `cleanup_complete_noop`, and
  no recovery reservation permits more than one side-effect attempt;
- the execution oracle keys worker preparation and Codex entry by persisted
  `execution_attempt_id`: initial preparation, every normal retry, and recovery
  each persist a fresh ID before child start; at most one PID may execute an ID; a restart never
  starts an attempt without fresh authorization/reservation; an intentional
  resume receives a new ID and is distinguished from forbidden concurrent or
  automatic duplicate execution. Test dead `recovery_reserved`, retained spent
  audit fields, expiry normalization followed by mandatory reinspection, wrong
  hashes, and rejected repeated authorization. Golden identity vectors cover
  endpoint case/default-port aliases, non-default ports, IPv4/IPv6, invalid
  Unicode/userinfo/path/percent encodings, and SSH/HTTPS clone aliases that
  must not affect immutable provider identity. The same vectors and digests
  must agree across two independently configured claim roots. Across two worker identities,
  property tests prove one global repository/full-ref reservation and reject a
  synthetic ref-hash collision. A two-process fake-provider race uses distinct
  claim roots and workers: exactly one atomic control-ref creator may proceed,
  the loser and wrong reservation ID start no workspace/worker, and a lost
  success response is recovered only by exact object/payload readback. A second
  race uses different claim keys forced to the same truncated planned full ref
  and proves they contend on the same repository/ref-derived control tag.
  A tracker-fence race aims the same immutable tracker issue from split claim
  roots at two different target repositories and proves exactly one fence ID
  wins and only that claimant may attempt its repository fence. Lost responses,
  wrong backend identity, wrong exact tag/request bytes, and unsupported tracker
  CAS semantics start nothing. Attempts to update/delete/recreate each control
  key through every modeled API principal, administrator, bypass, and cleanup
  path must be denied by the shared authority. A fault-injected disappearance
  of only its visible ref projection while the first worker is active must be
  detected within the relevant heartbeat, fence that worker, and still leave
  the internal tombstone rejecting every new fence ID on a second physical
  control host. Registry loss/tamper or an alternate local registry path fails
  readiness rather than replacing the global authority.
  Configuration policy drift, overlapping queries, and distinct claim roots all
  retain one immutable project/issue claim identity and cannot redispatch it.
  Workspace-fence races use two claim roots, attempted alternate control roots,
  and configuration/bind-mount aliases for the same physical worker root/path;
  aliases are rejected or exactly one backing-parent/basename O_EXCL fence wins.
  Kill before and after file creation/fsync/receipt binding, symlink and mount
  replacement, network/shared filesystems, alternate mount namespaces, and
  forged or deleted fence content all fail closed without provisioning, while
  exact lost-response readback recovers the single persisted fence ID.
  Golden fixtures pin the exact annotated-tag body, SHA-1/SHA-256 object IDs,
  pre-mutation claim record, and baseline equality. Crash after tag CAS but
  before receipt binding yields only a null-workspace
  `external_fences_only` candidate; exact authorization can create once,
  while wrong/missing object bytes cannot proceed. Matrix
  tests require `current_lease_id=null` plus `active_lease=null` plus empty
  remote history for every local lifecycle state, exercise the exhaustive local
  current-control pair/state matrix and immutable terminated-local-history
  rules, and reject one-sided or mismatched local pairs. They reject either
  null lease field or a mismatched ID for remote active
  parents, and accept remote
  stopped parents only after complete terminated-history validation. Mutation,
  deletion, reordering, duplicate lease/execution IDs, missing terminal receipt,
  and crashes on either side of atomic append-and-clear all fail closed. Local
  long-running fake Codex tests remove or alter external evidence between normal
  events, prove detection within five seconds, old TaskSupervisor and exact
  child process-group death, and only then the typed null-lease recovery edge.
  Kill before/after local parent-plus-pending commit, privileged control-record
  creation/fsync/readback, watchdog bind, gate authorization/consumption, spawn
  receipt, attestation, execution acknowledgement, every heartbeat epoch,
  TERM/KILL/reap receipt, history append, and pair clear. Prove no hook/Codex
  child exists before the committed acknowledgements, and prove
  `no_local_watchdog_created` exact lost-response readback closes only an absent
  pending attempt while permanently preventing later creation for that ID.
  Kill before/after absence tombstone create, full write, fsync, directory
  fsync, reread, receipt return, and ClaimStore history CAS; exact readback must
  return the same `0x08`, and every later state/registry/unit creation must fail.
  Separately stop after durable `intent`, after `launch registered` before the
  service-manager response, and after `watchdog started`; each restart must
  close the private channel, resolve only the deterministic registered unit,
  identify/reap at most its exact PID/start handle, append the
  canonical pre-bind-aborted state, and recover only by exact `0x09` readback.
  Process-without-intent, duplicate, unverifiable, and prior-generation-open-
  channel fixtures must keep readiness closed. An active local
  `recovery_reserved` fixture must take only
  `record_local_fence_loss -> recovery_required` after an exact terminal
  receipt, retaining the spent authorization audit and starting no side effect;
  kill the watchdog/unit immediately after the service manager creates the
  provisioner but before child PID/group/spawn-state fsync; the outer unit must
  still enumerate, kill, and reap every descendant, and no null-identity receipt
  may pass unless the unit is proved inactive and empty;
  exercise `renew_local_heartbeat` in every legal parent/phase pair, including
  exact lost-response readback, helper-ahead epoch, stale/skipped epoch, wrong
  deadline/receipt, and crash on both sides of its complete ClaimStore CAS;
- fake-SSH tests leave an old remote process group alive across disconnect,
  then prove recovery cannot reserve/start until exact-group death is confirmed;
  inject death before/after every remote lease phase and renewal CAS, remote
  receipt fsync, acknowledgement, and local receipt commit. Prove stale epoch,
  wrong owner/generation/attempt, PID reuse, lease expiry, host-fingerprint
  change, disconnect, and unreachable-host cases all fail closed without a
  second execution attempt, while a remote-ahead renewal epoch is fenced rather
  than adopted. Lose the response after gate consumption, child spawn, and
  spawn-receipt fsync; replay the same and different nonce and prove exactly one
  child maximum, byte-identical idempotent receipt, and recovery for consumed
  gates without a receipt. For pending-before-create, lose the response before
  and after `no_remote_lease_created` receipt fsync and local history commit;
  prove exact readback is idempotent, a mismatch blocks, and the helper can
  never create that lease ID afterward. Kill before/after remote absence O_EXCL,
  partial/full write, file fsync, directory fsync, reread, return, and local
  history CAS; every later intent/registry/unit/state/gate/spawn creation must
  be refused. Kill after remote intent, after registry, after service-manager
  unit launch, and after its response but before bound state; restart must
  resolve only the deterministic unit, prove it inactive and empty, persist the
  canonical pre-bind observation/`0x07`/launch-terminal suffix, and never
  certify absence. Kill after bound-state fsync but before closed-gate O_EXCL
  and at every subsequent gate durability boundary; recovery may add only the
  exact closed/0 gate and ordinary bound suffix. Concurrent attempts and forced
  digest-collision fixtures must prove the host-unit lock/registry admits one
  exact binding, never stops a differently bound unit, and rejects reuse across
  claim, lease, and execution-attempt IDs. Literal golden vectors for both
  worker identity and remote backing identity pin Darwin fsid values such as
  `[-1, 0x01020304]` to bytes `ff ff ff ff 01 02 03 04` and pin every ordered
  Linux u64 field. Golden Darwin/Linux backing-path fixtures verify the exact
  complete frame and persisted pending value; root inode/mount
  drift, alias views, overflow/non-minimal encoding, and lost-response replay
  must fail before absence, bind, renewal, termination, or startup acceptance.
  For first preparation, retry, and recovery-create,
  kill at every provision-gate/provision/attestation/parent-transition/
  execution-gate boundary and prove no hook/Codex invocation before a committed
  attestation and `execution_open_observed`. Lose the response before and after
  remote execution-gate consumption and receipt fsync; same-nonce replay must
  return one byte-identical receipt without a second release, while another
  nonce/epoch and consumed-without-receipt must start nothing and fence the
  group.
  Golden and crash fixtures cover every remote intent, launch-registry,
  launch-terminal, lease-state, provision-gate, spawn, execution-gate, renewal,
  reap/pre-bind observation, and receipt byte codec, predecessor, O_EXCL,
  partial/full write, file fsync, directory fsync, and readback boundary for
  every receipt kind/path epoch. A long provisioning fixture renews in each
  legal bound-or-later pre-execution phase without enabling execution; stale or
  wrong-phase renewal still fences and starts nothing.
  Exercise every legal normal `complete_lease` destination from
  `claimed_preparing`, `running`, active `retrying`, and `recovery_reserved`,
  including pre-running retry failure/attestation mismatch, and prove exact reap
  receipt, atomic history append/active clear, plus `retrying` null-backoff and
  later `start_retry_lease`; no crash snapshot may contain a remote
  `claimed_preparing` or `recovery_reserved` parent with either lease field null
  or with a mismatched current and active lease ID.
  Takeover tests prove a terminated lease retains old immutable attempt owner/
  generation evidence while the parent receives the new token, and a new lease
  cannot reuse or rewrite that evidence;
- use only memory/fake trackers and disposable local Git repositories. Exercise
  remote identity validation with a fake SSH transport only; never contact a
  real host, tracker, repository, credential helper, active branch, or PR;
- focused state-machine/property tests, production compilation with all test
  hooks disabled, formatting, warnings-as-errors, Credo strict, Dialyzer,
  coverage, complete `make all`, and `git diff --check` must pass. Independent
  implementation review and tester verification are mandatory for C1, C2 and
  C3, followed by a separate H-003 security review.

Out of scope for all H-003 tasks:

- branch deletion or cleanup automation;
- host credential isolation (H-004);
- execution against `sdd-forge` or any real tracker.

Gate:

- each task requires its own implementation review and focused/full test pass;
- H-003A/B alone do not make production dispatch eligible;
- H-003 remains open until H-003C passes and an independent security reviewer
  closes the durable-claims finding.

## H-004 — Host credential and execution isolation

Acceptance criteria:

- A launcher uses an isolated `HOME`, an empty environment allowlist, no `GH_*`/`GITHUB_*`/`GITLAB_*` aliases, no Git credential helper, and no `SSH_AUTH_SOCK`.
- Provider credentials exist only inside a fixed-argv broker. Its sole H-003C
  write capabilities are creation of the exact persisted immutable annotated
  objects and atomic create-if-absent of the tracker-scoped
  `refs/tags/symphony-issues/<full-claim-key-digest>` ref and the target-repository
  `refs/tags/symphony-claims/<repository-full-ref-lock-digest>` ref; readback is
  read-only. It cannot update/delete either ref or write issue/PR state, planned
  branch refs, working content, or any other object type. All other provider operations in
  H-003C are read-only, and no credential or response secret reaches a hook,
  worker, environment, argv, log, or workspace.
- Production credentials and provider configuration must expose the attested
  non-recreatable create-once namespace required by H-003C. H-004 independently
  probes its policy ID/version/hash, no-bypass actor set, update/delete denial,
  and cross-host tombstone behavior; ordinary Git atomic ref creation or a
  host-local registry alone is insufficient and leaves production disabled.
- A separately installed, fixed-path privileged fence helper is the only writer
  to the append-only control-host and worker-host registries. Its service
  identity, Darwin/Linux path, mount namespace, no-follow handle checks, file
  format, and create-only operation are fixed by H-003C; it exposes no update,
  delete, truncate, rename, alternate-root, or garbage-collection operation.
  Negative tests run different claim roots and attempted helper configurations
  and prove they reach the same registry or fail closed.
- macOS `sandbox-exec` denies network and reads outside the pinned binary/runtime, workflow, isolated workspace, claim/checkpoint/log roots, and minimum Codex authentication input.
- Hooks execute with a stricter sanitized environment and cannot read host GitHub CLI, Git credential, SSH, active-clone, or worktree data.
- Local hooks and agent processes run under a write-deny boundary for the claim, checkpoint, binary,
  workflow, active-clone, and worktree roots; negative tests invoke an otherwise
  valid workspace hook that attempts absolute-path deletion and overwrite of
  every reserved claim file and prove that all remain byte-identical.
- The local and remote worker-control roots, append-only registries, workspace fences, locks and
  lease/receipt files, and the
  supervisor/watchdog executable and live process are a privileged control
  plane outside the workspace. They run under a separate OS identity or an
  equivalently reviewed privileged helper. Codex, hooks, and provisioned worker
  children cannot read gate/renewal secrets, write/rename/unlink control files,
  acquire the control lock, signal/trace/inspect the supervisor, join its
  identity, or replace its executable. Negative fake-SSH tests attempt each
  read, tamper, lock, signal, `ptrace`, PID-kill, and executable-swap operation
  and prove denial plus byte-identical control state and a still-live watchdog.
- The fixed local control helper is the sole creator/reader of local attempt,
  gate, heartbeat, absence, spawn, execution-ack, and termination records. It
  exposes only the H-003C typed fixed-root operations, owns the sole watchdog
  control-channel server endpoint, validates the caller service identity, and
  never returns a writable descriptor or secret to ClaimStore, hooks, or Codex.
  H-004 tests the exact bind-before-gate and ack-before-execution ordering,
  deterministic restart lookup, PID/start-time/group anti-reuse checks, channel
  close/host-crash cleanup, and create-once receipt behavior across a fresh BEAM
  generation.
- Negative tests demonstrate denied tracker writes, credential lookup, SSH agent access, path escape, and active-clone reads.
- Docker is not treated as an available isolation boundary while its daemon is absent.

## H-005 — Independent re-review and rollback drill

Acceptance criteria:

- A separate security reviewer returns PASS with zero Critical/Major findings for H-001 through H-004.
- The final patch stream, source tree, lockfile, and binary SHA-256 values are recorded.
- A scratch-only pilot uses a synthetic/memory tracker and disposable repository; no production issue or repository credentials are present.
- Rollback stops the service, preserves claims/checkpoints/logs, verifies the pinned upstream digest, and removes only canonical clean scratch workspaces after manual confirmation.

No H-task authorizes execution against `sdd-forge`, GitHub mutations, commits, pushes, merges, or branch deletion.
