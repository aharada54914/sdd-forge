# RT004 descriptor-name alternative: rejected replacement

Status: design investigation, not formal review PASS or executed race test.

The independently reviewed candidate is
`adr-runtime-lexical-candidate-20260909.patch`, SHA256
`87ceef22901e3915d37e502affb23fae6a93858397fb200aa817a9f3c108f399`.

## Result that determines the next implementation step

Do not replace held-parent dirent name/identity association with separately
queried parent and child descriptor path strings. It does not meet the retained
association guarantee. The next implementation must retain ordinary dirent
association and implement the bounded Darwin crossing support, not introduce
a pathname-string fallback. No new threat scope or formal verdict is adopted.

Independent reviewer `/root/rt004_check_contract_review` supplied this concrete
counterexample, entirely inside a user-owned directory. It is an execution
schedule for a regression, not a claim it was run:

1. Hold parent P. It contains lowercase `a`; case-insensitive open of requested
   uppercase `A` returns that child's descriptor.
2. Query the parent descriptor's path, obtaining `.../P`.
3. Rename P to Q and create a different directory named P.
4. Move the held child from Q/a to the new P/A.
5. Query the child's descriptor path: `.../P/A` matches the saved parent path
   plus requested name, yet the held parent (now Q) never contained `A`.

Holding the old parent's identity does not connect it to the later path
string. Independent NAME and parent-identity observations have the same
association problem. No assumed administrator operation is needed.

The current dirent algorithm is itself an observation-time guarantee, not an
open-time spelling guarantee: if the same child is renamed from `a` to `A`
inside the held parent before the exact-name/inode observation, it can pass.
That is distinct from the different-parent substitution above. Tests and
documentation must not claim the stronger open-time guarantee.

## Primary-source check

Apple XNU revision `f6217f891ac0bb64f3d375211650a4c1ff8ca1ea` was retrieved
through the read-only GitHub API. This is published source inspection, not
identification of the exact installed kernel revision.

- [fgetattrlist implementation](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/vfs/vfs_attrlist.c#L3486)
  obtains the vnode from the descriptor. This supports object-bound metadata
  acquisition; it does not add a caller-held parent/name relation.
- [Name handling](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/vfs/vfs_attrlist.c#L3398)
  distinguishes an authoritative bulk-enumeration name from the name requested
  from the filesystem. A descriptor name must not be assumed to be an
  authoritative dirent from the separately held parent.
- [Apple fcntl manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fcntl.2.html)
  documents F_GETPATH as retrieving a descriptor path, not a joint atomic
  parent/child association check.

Existing native ABI evidence for the proposed crossing remains in
`rt004-darwin-acl-metadata-20260910.md`. The installed SDK's mount.h lines
105–123 were rechecked for STATFS64 layout and lines 102, 194, 224 for Data,
read-only and root-filesystem flags. Those definitions support implementing
descriptor-derived mount classification; flags alone are not permission
stability proof.

## External state observation

Read-only GitHub inspection still reports eleven open PRs and no active
CheckRun. PR400 has 25 successful CheckRuns; PR405/403/245 conflict and have
no CheckRuns; the other seven PRs have failures. This is terminal CI state,
not an active CI wait. Recovery and formal gate prerequisites remain separate
from green CheckRuns. No merge, close, rerun or branch write was performed.
