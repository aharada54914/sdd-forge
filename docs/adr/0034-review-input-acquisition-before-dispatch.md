# ADR-0034: Review input acquisition before schema dispatch

Status: Proposed; scope correction below awaiting independent review; not a formal PASS.
Date: 2026-09-10
Scope: RT-20260908-004 implementation-review admission input acquisition.

## Scope correction — 2026-09-11

This section supersedes the proposed concurrent-replacement requirements below
for RT004 integration; the earlier text is retained as design history, not
implemented protection or an acceptance claim. The user challenged the necessity
of the special replacement scenario and its conflation with duplicate agent
assignment. Under the user's standing authorization for design decisions, the
implementer withdraws that expansion from this ticket, subject to independent
contract review. The user did not approve a false PASS or deletion of evidence.

RT004 retains exact role authorization, canonical/exact-case paths, rejection
of observed symlink components and non-regular files, strict unambiguous JSON,
and hashing/interpreting the same captured bytes. The exact design-declared ADR
set must match the precheck and invocation pins before reservation. All existing
JSON, stationary-path, history, boundary, native-platform and CI requirements
remain. No guarantee of atomic no-follow acquisition under concurrent parent
replacement is claimed. No macOS ACL/firmlink bridge or Windows handle backend
is added solely to provide that withdrawn guarantee.

The new `--initial-open-only` diagnostic records four accepted substitutions
with unchanged content, not acceptance of malicious unpinned bytes or an
observed production attack. Its failures remain failures under that stronger
diagnostic, and are retained in `rt004-initial-open-red-20260911.md`. It was added
locally on 2026-09-11, not inherited from a mandatory CI requirement. Once this
correction is reviewed, retain it as an explicit opt-in diagnostic outside the
default suite; do not turn its rejection expectation into an acceptance check.

Duplicate task assignment is an orchestration concern (named owner, isolated
worktree, integration review), not evidence for hostile filesystem substitution.
Concurrent replacement remains a disclosed transport limitation. Reopening that
hardening requires a separately justified task, threat/cost assessment and tests.
This correction does not resolve RT004, rewrite old review verdicts, authorize
protected-apply bypass, or waive independent review of the ADR-binding change.

Independent advisory review by `rt004_snapshot_static_review` on 2026-09-11
found no static blocker to this scope correction or diagnostic separation.
It explicitly retained re-verification immediately before launch, downstream
consumer verification, and rejection of ADR changes after precheck. These are
still mandatory; reservation-time checking alone is insufficient. This is a
limited contract review, not formal gate PASS. Implementation reports must
state the stationary/observed-path limit of symlink checking consistently.

## Context

The original Bash admission entry canonicalizes the supplied repository root
with `pwd -P` before checking descendants
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:22-25`).
The PowerShell entry checks for a container and resolves the path without
rejecting a root reparse point
(`plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:170-174`).
Original-path regression evidence in
`reports/verification/rt004-admission-root-link-red-20260910.md` records four
accepted root-symlink cases, alongside 24 passing controls/negative cases.
This is stationary-path evidence, not proof of a race or native Windows behavior.

Whether a precheck has the ADR extension cannot be known before reading it.
Therefore preserving legacy symlink traversal while promising no-follow on the
first precheck read is impossible. Reading insecurely, then reading securely
and comparing hashes does not undo the first open. Independent advisory review
by `/root/rt004_check_contract_review` identified this conflict on 2026-09-10.

## Decision for implementation

Make safe acquisition a common transport prerequisite for implementation-review
precheck reads, before legacy/new JSON dispatch. Preserve existing legacy content
validation and verdict rules for inputs satisfying common safe acquisition,
single-object framing and unambiguous JSON requirements. Duplicate decoded keys
and other ambiguous JSON previously accepted by a parser are now rejected by
common admission requirements. Preserve frozen evidence; do not preserve unsafe
path transport or ambiguous-parser acceptance.
This explicitly changes legacy calls that pass alias/symlink roots. It does not
reinterpret old reviews or change verdicts, identity rules or mandatory CI.
The user's standing instruction authorizing remaining design/implementation
decisions is carried forward; it is not a formal gate PASS or protected-apply
permission. Protected changes still follow the existing human application path.

1. Preserve the original root string before resolution. Require an absolute
   physical path. Reject dot/dotdot components and ambiguous root syntax rather
   than normalizing away evidence. Define platform separators explicitly;
   Windows drive-relative and device-namespace strings are not ordinary roots.
2. Hold the appropriate trust anchor and acquire each named descendant relative
   to its held parent. Do not follow symlinks/reparse points. Validate directory
   types, and require a regular leaf before reading. POSIX leaf acquisition must
   be nonblocking so a FIFO cannot hang before type validation.
3. Associate exact component spelling with the opened child identity under the
   held parent; reject if this cannot be established. Pathname checks followed
   by independent pathname opens are not sufficient. Keep descriptors/handles
   until the acquisition they protect is complete; close them on all outcomes.
4. Read each input once into private bytes, hash those bytes against its pin,
   and parse those same bytes. No pre-probe or pathname reread chooses a weaker
   branch. Invalid JSON, duplicate decoded members, and failed acquisition are
   rejection, never extension absence. `adr_inputs: []` is extension presence.
5. Only then dispatch to legacy content rules or the explicit ADR-bound rules.
   Acquire design and declared ADR bytes through the same safe mechanism.
   Failure must precede ledger mutation and produce bounded content-free errors.

## Trust anchors and limits

### Clarified guarantee and complexity limit (2026-09-10)

This paragraph governs the interpretation of the proposals below following
the user's objection to an unspecified non-administrator attack scenario.
No actual hostile replacement has been demonstrated. The path regression
failures are observed validation defects, not evidence of an attack.

The trusted computing base includes the running validator, its runtime, the
authorization policy and the independently bound expected hashes. A process
that can replace all of those is not contained by an input-reading routine.
Do not describe this routine as a same-user process security sandbox.

The integrity guarantee is about the bytes admitted for review: calculate
their hash and interpret the same captured bytes, rejecting a mismatch before
admission. It is not a promise to detect every intervening edit. A writer may
change and restore contents between observations; matching pinned bytes alone
neither proves that no edit occurred nor constitutes an integrity failure.
Conversely, a valid hash does not excuse an unsafe or role-unlisted path.
Existing exact-name, no-follow and regular-file requirements remain distinct.

The previously proposed Darwin ACL/firmlink bridge below is a design option,
not an automatic implementation prerequisite. Before implementing it, identify
the concrete in-scope operation that a simpler acquisition approach would
accept incorrectly and the exact preserved contract it violates. Administrator
mount manipulation is not such a justification. Ordinary macOS root/Data
acceptance remains required; rejecting it is not a successful hardening result.
This clarification does not approve a split-check race or a generic identity
mismatch fallback. If no simpler approach meets the retained contract, record
that specific conflict rather than silently weakening the contract or adding
more native machinery. No test expectation, historical verdict, protected
source or formal review status is changed by this proposed design clarification.

### Human-confirmed threat scope (2026-09-10)

The user explicitly selected protection against file modification and
replacement by non-administrator processes, not concurrent mount-topology
changes by an OS administrator. This clarification governs the decision
above and supersedes any broader interpretation in earlier RT004 advisory
design notes. Those observations and review outcomes remain historical;
this clarification is neither an implementation result nor a gate PASS.

In scope: unprivileged processes, including another process of the invoking
user, changing content or replacing/renaming entries wherever their actual
filesystem permissions permit. Ordinary editor/agent concurrency and
deliberate substitution need different diagnostics but the same integrity
checks. Do not assume a same-user process is cooperative.

Out of scope: an attacker exercising OS-administrator privileges to change
mount topology or OS-managed firmlink configuration. This does not turn all
ancestors into trusted directories: root ownership alone is not proof of
non-writability, and unprivileged entry replacement remains in scope even
near a mount boundary. An implementation relying on an OS-managed stable
boundary must establish why that boundary is not mutable by the in-scope
actor; a pathname prefix or repeated equal observations is insufficient.

Re-evaluate the mount/firmlink acquisition design under this scope instead
of requiring protection against administrator remounts. Preserve exact-case,
no-follow, regular-file, same-bytes hash/parse, and cleanup requirements for
unprivileged mutable entries. Native-platform evidence is still required.

The earlier independent advisory re-evaluation described the following bridge
option. Its second path and native permission details below are conditional
requirements if this option is selected, not an instruction to select it:

1. Ordinary entries retain exact name plus identity from one parent dirent
   record, compared with the no-follow opened child. This remains mandatory
   for mutable ordinary ancestors and does not ban exact-name hardlinks.
2. An identified mount/firmlink crossing may use separated exact-name
   observation and parent-relative open only after establishing that the
   association is not mutable by the in-scope actor. ID mismatch alone never
   selects this exception. Determine mount identity from held descriptors,
   not pathname prefixes or device-ID difference alone. Check both the
   source entry and, for firmlinks, the physical destination parent. Any
   physical pathname is a discovery hint: validate that route from held
   parents and compare final opened identity; never authorize by its text.

The second path needs a separately reviewed stability predicate over held
object ownership, mode and ACL permissions, including entry creation/removal,
rename, target deletion and permission/ownership changes. Unknown or mutable
boundaries cannot use this exception. In particular, root ownership or mode
0755 alone is insufficient, and non-administrator-controlled mounts are not
excluded by the user's clarification. This predicate is a pending design
artifact, not implemented authority.

For Darwin ACL absence, use successful descriptor-bound metadata acquisition
followed by successful OWNER/GROUP/MODE property presence and value checks
against the stat result from that acquisition, then a successful ACL-property
presence query on a fresh filesec object. Presence means nonzero, not exactly
one. A successful return with an unpopulated filesec object is rejected; a
NULL ACL pointer or ENOENT alone is not an absence certificate.
Native read/query/allocation failures never authorize the stability exception.
The native observation and pinned Apple source rationale are recorded in
`reports/verification/rt004-darwin-acl-metadata-20260910.md`; nonempty ACL
evaluation and the complete mount predicate still require review and tests.

The independently reviewed implementation direction for the macOS root/Data
case is the following bounded bridge (not a general mismatch fallback):

1. Confirm the held `/` belongs to APFS with MNT_ROOTFS and MNT_RDONLY.
2. Acquire `usr/share/firmlinks` relative to that held root with no-follow
   and exact-name/identity checks, verifying every held object remains on
   that read-only root filesystem. Parse the same regular-file bytes into
   unique, unambiguous source-to-Data-relative mappings. Reject unsafe or
   ambiguous mapping records; do not execute their content.
3. Acquire `System/Volumes` from the root using the ordinary route. Only
   at its stable held parent may separated exact-name observation of `Data`
   and relative open be bridged. Require descriptor-derived APFS mount
   identity, MNT_EXT_ROOT_DATA_VOL and the permission stability predicate.
4. From the held Data root, acquire the mapped relative destination through
   ordinary exact-name/identity checks. Require permission stability for
   physical parents protecting the association and for target DELETE rights.
5. Compare the held logical child and physical child using device/inode in
   the same identity domain; retain both handles until acquisition completes.
6. Return to ordinary traversal below the bridge. Its exception never makes
   user-writable descendants trusted. No special acceptance of the literal
   `/Users` spelling or generic metadata fallback is permitted.

The permission-only sufficient predicate rejects group/other mode write and
any ACL ALLOW granting mutation, deletion, security or ownership changes;
unknown ACL permission bits, flags or tags reject as well. Apply it only to
filesystems known to enforce these permissions, not merely report root-owned
metadata. Its conservative treatment of principal-specific and inherit-only
ALLOW entries is documented in the native-observation report. This root/Data
bridge remains a candidate, not the mandated next implementation unit or
completion of other supported mount transports; those transport requirements
remain outstanding, not removed.

Common regressions retain normal logical `/Users` and physical Data path
acceptance, wrong-case rejection, and deterministic ABA rejection for mutable
ordinary directories. If the stability-exception option is selected, also
test refusal to apply it to an ACL-mutable boundary. Existing platform,
no-follow, regular-file and byte-binding tests remain mandatory.

- POSIX: a held `/` descriptor. Normal mount boundaries are allowed; every named
  path component thereafter is checked. Callers using macOS `/tmp` or `/var`
  aliases must deliberately supply their physical paths. The validator must not
  automatically resolve an untrusted alias to make a rejected call succeed.
- Windows drive: the filesystem root handle selected by the drive mapping at
  acquisition. Hold it while opening descendants relative to it.
- UNC: the explicitly named `\\server\share` share-root handle. Name resolution,
  authenticated connection, share-root provision and DFS referral selection
  belong to the transport trust boundary at anchor acquisition. Descendants
  must still reject reparse traversal. Do not remove UNC support for convenience,
  or claim the reader authenticates the remote server or prevents replacement
  of the transport's selected endpoint.

The selected root identifies the repository at acquisition. The reader does not
detect replacement by another ordinary directory before that trust point, make
writable file contents immutable, or defeat replacement of every authorization
pin. Its claims are no-follow acquisition and hash/parse byte identity. Exact
name/identity checks and native backends require implementation evidence; merely
using a handle is not proof. An unavailable capability must reject without a
weaker fallback, and is not a successful platform test.

## Alternatives and consequences

- Rejected: legacy-first unsafe probe followed by secure reread; violates the
  initial-open guarantee.
- Rejected: retaining alias transport by silently canonicalizing the root;
  loses the very property the root regression checks.
- Rejected: banning UNC solely to simplify implementation; narrows existing
  transport scope without addressing the required Windows backend.
- Cost: callers/fixtures must pass physical absolute roots, including legacy
  JSON callers. Legacy JSON must also meet the common framing/ambiguity rules.
  Tests must retain explicit alias-rejection cases rather than
  canonicalizing those negative inputs away. Historical evidence is unchanged.

## Verification and next artifact

Implement the embedded protected reader in the existing DATA candidate, not a
renamed executable or writable helper. Add positive physical-root legacy/new
controls and negatives for alias roots, root/parent/leaf substitution, wrong
case, special files, failed open/read/allocation and cleanup. Preserve all JSON,
boundary, round-2 and downstream workflow tests. Require independent security
review before protected application, original-path tests after application, and
native Windows drive/UNC evidence before claiming those backends verified.

Related: `docs/adr/0011-phase2-handle-relative-protected-copy.md` provides the
handle-relative principle, not its publication/write rights for this reader.

Number allocation: current worktree listing includes 0033, and locally available
all-ref history contains no 0034 at creation. Recheck the shared namespace after
fetch and immediately before review/publication; this local observation is not
a permanent claim about other branches.
