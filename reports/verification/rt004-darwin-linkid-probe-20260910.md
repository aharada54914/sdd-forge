# RT004 Darwin LINKID probe

Status: rejected implementation hypothesis; not a gate PASS.
Scope: read-only OS metadata observation, not candidate execution or protected-source modification.

## Question

Can `fgetattrlist(ATTR_CMNEXT_LINKID)` associate an opened firmlink target with
the exact directory entry of its held parent, without a pathname reopen?

The local macOS SDK `sys/attr.h:561` defines LINKID as `0x10`, in the extended
forkattr bitmap. Apple's public kernel source packs `va_linkid` when supported
and otherwise `va_fileid` (vfs_attrlist.c:2321-2330):
<https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/vfs/vfs_attrlist.c>.
This fallback does not establish a source-entry identity guarantee.

## Native observation

A standalone Python ctypes metadata probe held `/`, enumerated its entries,
opened each component with `openat` semantics and `O_DIRECTORY|O_NOFOLLOW`, and
queried the held descriptor. It requested RETURNED_ATTRS, FILEID and extended
LINKID. Returned bitmaps and the 40-byte layout were checked before unpacking.
All descriptors and the directory iterator were closed with finally/context
management. No files were created, written, copied, or executed by the probe.
Command exit: 0.

| Component | Exact parent entry inode | Held inode / FILEID / LINKID | Held device |
|---|---:|---:|---:|
| Users | 1152921500312571350 | 18471 | 16777233 |
| users | no exact entry | 18471 | 16777233 |
| System | 1152921500311879703 | 1152921500311879703 | 16777233 |

## Decision

Do not substitute LINKID for fstat inode in the candidate's cross-boundary
binding check. On this host it still rejects the legitimate Users firmlink,
and the wrong-case open returns the same target identifiers. The System
control shows the requested attributes were not universally unusable.

This observation disproves this proposed fix on the current machine; it is
not a race test, a claim about every filesystem, or evidence for native Windows.
Do not relax exact spelling or remove mount/firmlink support to make the test
pass. The next backend design needs an actual parent-entry/held-target binding
mechanism, not an alternate identifier with the same observed limitation.

No protected application, formal review, CI, commit, push, merge, or issue
closure occurred. RT004 remains open.

## Follow-up: parent/name and bulk enumeration

Additional native metadata-only probes completed with exit 0. Held-fd
`fgetattrlist` requested NAME, FSID, FILEID and PARENTID, checking returned
bitmaps and variable-name bounds. Default `/` reports FSID `[16777233,26]`,
FILEID 2; default `/Users` reports NAME Users, FILEID 18471, PARENTID 2.
Wrong-case `/users` returns the same attributes. Physical
`/System/Volumes/Data` reports default FILEID 1152921500311879682, whereas
its child Users reports PARENTID 2. REALDEV changes the Data FILEID to 2,
but is not a general proof of firmlink source-parent correspondence.

Independent advisory reviewer `/root/rt004_check_contract_review` rejected
NAME+PARENTID as a general binding mechanism. Besides the physical-path
mismatch, it identified a static counterexample in the kernel's separate
parent/name fallback processing: acquire PARENTID while a child is P/a, move
it to Q/A, then acquire NAME A. The composite does not prove P/A existed.
This is a source-level fallback-path counterexample, not a reproduced APFS
race. No formal review verdict was issued.

A separate `getattrlistbulk` probe enumerated held `/` using
RETURNED_ATTRS|NAME|FILEID. It bounded pages (10), records, returned bitmaps,
name offsets and NUL termination, and closed its descriptor. Observations:

| Exact bulk name | Bulk FILEID |
|---|---:|
| System | 1152921500311879703 |
| Users | 18471 |
| Volumes | 18481 |

Unlike scandir's source inode, bulk Users FILEID matches the opened target.
This changes the next investigation: evaluate whether bulk entry name and
target identity, including filesystem identity, are safely coupled under
rename and mount traversal. Native versus fallback implementations must both
be considered. Stationary equality is not enough to adopt this backend.
Independent advisory review of this primitive is requested; candidate remains
unchanged and no protected execution or application occurred.

### Bulk advisory result

The independent reviewer found that this request omits OBJTYPE. Upstream XNU
selects the readdirattr fallback for that request rather than trying the native
filesystem bulk operation (vfs_attrlist.c:4110-4120). In the fallback, a prior
dirent name and a later namei result are combined (3795-3861); a same-filesystem
case-substitution race can therefore mix the old exact name with a different
opened identity. This is a static counterexample, not a reproduced race here.
Adding OBJTYPE alone does not prevent filesystem ENOTSUP from selecting the
fallback. NOCROSSMOUNT also prevents generalizing the observed firmlink result
to ordinary mount targets. Do not adopt bulk enumeration on this evidence.
"Native observation" above means a real OS syscall, not proof of the native
filesystem bulk backend. A usable primitive must expose or guarantee the
required backend semantics without silently falling back.
