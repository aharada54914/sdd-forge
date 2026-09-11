# RT004 incremental POSIX reader: independent review

Date: 2026-09-10
Status: NEEDS_WORK. DATA candidate only; no protected application or execution.

## Change and actual checks

Updated `adr-runtime-lexical-candidate-20260909.patch` in this directory, from
SHA256 `1ffcc69c527fd0ed2a6db47670bb988bb4756a2ad3fd6a5b1e8a1363dd6fdb14`
to `996420a98e09d305538e8b446188c16a41a7a8d9b5c9c3f14492d52e54ffe577`.
The existing stationary-root RED baseline remains 24 passed / 20 failed,
documented in `rt004-root-transport-regression-20260910.md`; no unchanged suite
was rerun and no race test result is claimed.

The Bash candidate replaces check-then-pathname-read operations for precheck,
design and ADR inputs with an embedded Python POSIX descriptor walk. It holds
the filesystem root and ancestors, requests no-follow and directory flags,
opens the leaf nonblocking, checks regular-file type before reading, closes all
held descriptors, and hashes private snapshots instead of reopening ADR paths.
Missing required capabilities reject without a weaker fallback. This is an
incremental implementation, not a completed cross-platform backend.

Actual checks, all exit 0:

- `rtk proxy git apply --check --unidiff-zero reports/verification/adr-runtime-lexical-candidate-20260909.patch`
- Python `ast.parse` of the embedded reader text (no execution).
- SHA256 readback of candidate and both originals.

Protected original SHA256 values are unchanged:

- Bash: `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`
- PowerShell: `832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`

## Independent finding: Major, not resolved

Existing reviewer `/root/rt004_check_contract_review` independently read the
candidate, confirmed its SHA256, and found a spelling/identity race at DATA
lines 120–125. On a case-insensitive filesystem:

1. Open a wrong-case entry with inode A.
2. During `listdir(parent)`, replace it with an exact-name entry with inode B.
3. Before `stat(name)`, restore the wrong-case entry with inode A.

The exact-name observation then concerns B while identity validation concerns
A. Separate name enumeration and pathname stat do not bind the exact name to
the opened child as ADR-0034 requires. Repeating these checks is not a fix.
This is a static counterexample, not a reproduced runtime result.

Correction must associate name and identity from the same directory-entry
record or a proven native equivalent. A naive captured-dirent-inode comparison
can reject normal mount boundaries because a mountpoint entry and mounted root
can have different inode identities. Preserve ADR-0034's mount support; do not
silently reject mounts to obtain a smaller passing implementation.

No independent formal gate PASS was issued. Existing early root normalization,
PowerShell native backend, deterministic substitution/cleanup tests and native
Windows drive/UNC evidence also remain incomplete. Do not offer this partial
candidate for human application. Do not execute it via renamed targets or an
alternate executor to bypass protection.

## Remote state and next work

A fresh GitHub query found 11 open PRs and no live PR check jobs. PRs 245, 403,
405 are DIRTY; 371, 381, 390, 401, 402, 404 are BEHIND; 394 and 400 are BLOCKED.
These are GitHub merge-state observations, not a complete eligibility verdict.
PR 400 has no failed reported checks but that does not resolve its other gates.
No commit, push, CI dispatch, merge, issue closure or branch deletion occurred.

Next: resolve the independently identified entry-identity counterexample,
retain ordinary mount support, and add deterministic boundary tests before
claiming the acquisition mechanism complete. Continue the full cross-platform
candidate, independent review and original-path verification prerequisites.

## Native macOS investigation: mount identity and name-cache limits

Read-only probes on 2026-09-10, macOS 26.6.2, exited 0. No fixture was
created, protected code executed through an alternate path, or candidate applied.
An opened `/` descriptor was used for `os.scandir` and relative
`os.open(name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)`; every descriptor was
closed in `finally`. Results:

| Requested component | Exact dirent inode | Opened inode | Opened device | F_GETPATH | F_GETPATH_NOFIRMLINK |
| --- | --- | --- | --- | --- | --- |
| `Users` | 1152921500312571350 | 18471 | 16777233 | `/Users` | `/System/Volumes/Data/Users` |
| `users` | absent | 18471 | 16777233 | `/Users` | `/System/Volumes/Data/Users` |

This verifies a concrete compatibility failure for a proposed naive
dirent-inode-equals-opened-inode fix, and stationary wrong-case behavior. It
does not reproduce the independent review's concurrent substitution schedule.
The candidate hash remains
`996420a98e09d305538e8b446188c16a41a7a8d9b5c9c3f14492d52e54ffe577`.

Primary-source investigation (upstream source, not a claim that this exact
revision is the running kernel):

- `F_GETPATH` starts from the FD's vnode and calls `vn_getpath_ext` without a
  parent vnode. [Apple kern_descrip.c, lines 3613–3636](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_descrip.c#L3613).
- Flags 0 select `BUILDPATH_NO_FS_ENTER` in the wrapper.
  [Apple vfs_subr.c, lines 3470–3518](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_subr.c#L3470).
- Path reconstruction translates firmlink targets, crosses mount roots, and
  stabilizes cached parent chains under the name-cache lock. However, the
  hardlink correction is disabled by `BUILDPATH_NO_FS_ENTER`; the source
  explicitly identifies potentially stale hardlink names.
  [Apple vfs_cache.c, lines 530–600](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_cache.c#L530).
- The emulated bulk-attribute path first reads a dirent, then performs a
  separate `namei` with `NOCROSSMOUNT`, and passes the enumerated name to
  attribute packing. A single userspace syscall must therefore not be assumed
  to provide an atomic name/identity record on every backend.
  [Apple vfs_attrlist.c, lines 3800–3862](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_attrlist.c#L3800).

Next-action refinement: do not replace the current race with either a universal
raw-dirent inode comparison or an unproven `F_GETPATH` equality check. Separate
ordinary entry verification from mount/firmlink identity translation, and
require evidence that each selected native operation binds the held parent,
exact name and opened identity. Include hardlink aliases and stale-name behavior
in that proof/test design. The backend choice remains unresolved; no production
fix, formal PASS, Windows proof or new regression PASS is claimed here.

A fresh PR check-rollup query still reports 11 open PRs and no `IN_PROGRESS` or
`QUEUED` entries. This is not a live-job wait and does not authorize merging
the conflicted, behind, failing or otherwise blocked PRs. No remote mutation
occurred during this investigation.

## FD attribute probe: exact name, identity and parent (2026-09-10)

A read-only native `fgetattrlist` probe exited 0 using Python ctypes and
`/usr/lib/libSystem.B.dylib`. It requested `ATTR_CMN_RETURNED_ATTRS`,
`ATTR_CMN_NAME`, `ATTR_CMN_DEVID`, `ATTR_CMN_FILEID` and
`ATTR_CMN_PARENTID` (common mask `0x86000003`). Each returned mask was
checked for exact equality; packed length, name offset, name length and NUL
termination were checked before decoding. Each opened directory FD used
`O_RDONLY | O_DIRECTORY | O_NOFOLLOW` and was closed in `finally`.

| Requested path | Returned name | FILEID / fstat inode | PARENTID | Lexical parent stat inode | DEVID |
| --- | --- | --- | --- | --- | --- |
| `/Users` | `Users` | 18471 / 18471 | 2 | 2 | 16777233 |
| `/users` | `Users` | 18471 / 18471 | 2 | 2 | 16777233 |
| `/Users/jrmag` | `jrmag` | 443951 / 443951 | 18471 | 18471 | 16777233 |

This is stationary observation only. The lexical-parent stat is a diagnostic
comparison, not the proposed security primitive. Matching inode numbers alone
do not establish parent identity across volumes or firmlinks. No concurrent
rename, hardlink fixture, candidate execution or protected mutation occurred.

The current upstream Apple manual says `fgetattrlist` operates on the provided
FD, exposes a returned-attributes mask, and defines FILEID as equivalent to
`st_ino`. It warns about hardlink inconsistencies for full/relative/no-firmlink
paths. LINKID distinguishes hardlinks on HFS+/APFS, but no relationship with
FILEID may be inferred. These are API constraints, not an atomicity guarantee
for a name/parent/identity tuple under concurrent renames.
[Apple getattrlist(2), lines 39–60, 389–400, 703–729, 1244–1268](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/man/man2/getattrlist.2).

Decision: retain `fgetattrlist` as an investigated option, not an accepted
replacement. Do not derive dirent/FILEID correspondence from LINKID or claim
the independent ABA finding resolved. A selected algorithm must establish
held-parent membership and exact entry identity, preserve ordinary mount and
hardlink support, and pass deterministic substitution tests. The existing
DATA candidate remains unchanged and unsuitable for human application.

## Independent algorithm follow-up and live recovery recheck

On 2026-09-10 the existing independent reviewer
`/root/rt004_check_contract_review` completed a bounded architectural follow-up.
For ordinary same-filesystem entries, the proposed correction is: keep parent
and no-follow child FDs, validate type, enumerate the held parent, and compare
the exact name and inode from ONE dirent record to the child's fstat inode.
Hardlink aliases need not be banned. This binds an observation of that exact
entry to the held object; it does not promise subsequent name immutability.

The unresolved boundary is narrower and concrete: a mount/firmlink requires
an operation that establishes the correspondence between the held parent's
exact source entry and the opened mounted/translated child. The observed
`PARENTID == 2` is not such proof: unrelated volume roots can have inode 2.
The reviewer distinguished this missing proof from a reproduced native-API
race. It did not certify any native replacement or issue a formal PASS.

Required deterministic tests identified by the reviewer:

1. Synchronize wrong-case A / exact-name B / wrong-case A around enumeration
   and identity comparison; require rejection.
2. Accept an exact-name hardlink after another alias is opened or renamed;
   reject a wrong-case request.
3. Accept ordinary mounts and `/Users` firmlink spelling, reject case variants.
4. Substitute the boundary parent; never accept a matching inode/PARENTID
   number from another volume as parent correspondence.

The original-path recovery entry was also rechecked, not assumed from history:

```text
rtk proxy python3 plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py --emit-challenge
```

The host PreToolUse hook rejected this command before execution with its SDD
deterministic-gate protected-file diagnostic. No script exit code or challenge
was produced. No alternate executor, wrapper or renamed path was tried. This
is evidence that this launch remains denied, not a nonce-bound activation
response and not HOOK_ACTIVE. Ordinary file reads still succeed. The current
handshake source hash remains
`d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.

Next implementation work must preserve the whole transport scope; the
ordinary-entry algorithm alone is not completion. Recovery still needs its
reviewed adapter and permitted application before a fresh actual activation
attempt can satisfy the exit contract. Do not request human file reads or
present another diagnostic-only run as a way to complete recovery.

## Partial same-dirent candidate and patch integrity follow-through

Candidate SHA-256 is now
`5d296d5adf9bbf4b404f3b0c906c2edcf83909a91b3c82f22a0c7d20f5f082af`.
The ordinary-entry section now obtains spelling and inode from one
`os.scandir(parent)` entry instead of separate name enumeration and pathname
stat. This is a partial correction, not runtime proof or a new formal verdict.
The mount/firmlink mapping remains explicitly incomplete: the staged reader
rejects differing device/inode bindings and must not be offered for application
as complete ADR-0034 transport support. Early normalization and the native
PowerShell backend remain unresolved, as do the four deterministic tests above.

The partial edit left stale unified-diff counts: normal
`git apply --check --unidiff-zero` failed with `corrupt patch at line 290`.
The long Bash hunk now records 282 output lines (formerly 276); subsequent
output offsets were advanced by six. The same check, without `--recount`,
then exited 0. This verifies patch applicability only. No protected source
was applied, copied for execution, or executed by this check.

Original source hashes remain:

- Bash: `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`.
- PowerShell: `832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`.

Remote recheck on 2026-09-10 found 11 open PRs and no live CheckRun in their
latest rollups. PR #400 head `8fa3eb8561d6f59b692ec574900f87e181145928`
has all 25 listed CI checks successful, including required-checks, but remains
REVIEW_REQUIRED/BLOCKED. This is not proof that its outstanding local evidence
conditions or the recovery-entry exit contract are satisfied. No admin merge
was attempted; no other failed or absent CI was treated as successful.
# Follow-through: defer Bash root normalization (2026-09-10)

Current DATA candidate SHA256:
`7c1751633bb55758e2fe2186b6f293ffe3fe3866525f31524178dd903555f9c6`.
This supersedes the preceding candidate hashes for future application only;
historical results remain bound to their recorded hashes.

Removed the unconditional root existence check and `cd`/`pwd -P` resolution
at original Bash lines 22–25. After the validated stage/role selection and
before ledger construction, impl keeps its supplied root and checks lexical
syntax; other stages retain the original existence and normalization steps.
Original lines 27–209 are function definitions, then manifest parsing and
identity checks run through line 293. The root references at lines 133,
176 and 179 occur inside functions, not early top-level calls. This was
confirmed by the main agent's ordinary source reads, not candidate execution.

Verification:

- Before editing, a DATA assertion requiring removal of the unconditional
  normalization failed for the intended reason; after editing it passed.
- `git apply --check --unidiff-zero` passed without recount; scoped
  `git diff --check` passed. These establish patch structure, not runtime safety.
- An additional read-only Python in-memory reconstruction check was denied
  by PreToolUse before execution. It produced no test result and was not
  retried through another route.
- Independent reviewer `/root/rt004_check_contract_review` checked the exact
  candidate hash and found no new Critical/Major in this delta. Its original
  source access was unavailable, so absence of earlier top-level root consumers
  is the main agent's inspection, not independent verification.
- Original Bash SHA256 remains
  `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`.

No protected application, candidate execution, formal PASS, commit, push or
merge occurred. The candidate is still incomplete: ordinary mount/firmlink
mapping, native Windows backend, premature pathname consumers, deterministic
race tests and full runtime verification remain required. Do not apply this
partial candidate to unblock a real review.

Live GitHub recheck found 11 open PRs and no running/queued CheckRuns. PR400
head `8fa3eb8561d6f59b692ec574900f87e181145928` has 25 successful Actions
checks but unresolved formal gates. PR245/403/405 have no Actions checks and
conflicts. Other open PRs retain failures; waiting alone will not fix them.
