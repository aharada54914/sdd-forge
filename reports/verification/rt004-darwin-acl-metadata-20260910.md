# RT004: descriptor-bound Darwin ACL metadata observation

Date: 2026-09-10
Status: read-only capability evidence; not implementation, formal review or PASS.

## Purpose and scope

Under the human-confirmed non-administrator threat model in ADR 0034,
distinguish absent ACL metadata from a failed metadata read before permitting
separated observations at an OS-managed stable boundary. No protected source,
test, permissions, mount configuration or installed cache was changed.

## Actual observations

Host: Darwin 25.6.0 arm64 (`uname -a`). Two inline Python ctypes probes called
the native `/usr/lib/libSystem.B.dylib` read-only APIs. Each directory was
opened with O_RDONLY | O_DIRECTORY | O_NOFOLLOW. Handles and allocated
filesec objects were released in finally blocks. These independent pathname
opens are capability observations, NOT the proposed anchored acquisition
algorithm or proof against ancestor substitution.

For each of `/`, `/Users`, `/System`, `/System/Volumes`,
`/System/Volumes/Data`, and `/System/Volumes/Data/Users`:

- `acl_get_fd_np(fd, ACL_TYPE_EXTENDED)` returned NULL and errno 2.
- A fresh `filesec_init()` followed by `fstatx_np(fd, &stat, filesec)`
  returned 0.
- `filesec_query_property(filesec, FILESEC_ACL, &present)` returned 0,
  with `present == 0` and errno 0 after resetting errno before the call.
- Stat ownership was uid 0 and mode 0755. Native stat dev, inode, uid and
  mode matched Python's `os.fstat` on the same held FD. The ctypes stat
  layout was derived from the installed SDK's sys/stat.h STAT64 definition.

Both probes exited 0. The second observation distinguishes a successful
metadata acquisition with absent ACL property from the first API's ambiguous
NULL result. It does not certify a mount, its operator, or an entire path.

## Primary implementation evidence

Apple Libc revision `71bbe350ab79eef58113991d817ccc6165061a64`, retrieved
read-only through the GitHub API:

- [acl_file.c](https://github.com/apple-oss-distributions/Libc/blob/71bbe350ab79eef58113991d817ccc6165061a64/posix1e/acl_file.c):
  `acl_get_fd_np` wraps `fstatx_np` and `filesec_get_property`; a NULL result
  alone does not expose which step failed.
- [filesec.c](https://github.com/apple-oss-distributions/Libc/blob/71bbe350ab79eef58113991d817ccc6165061a64/gen/filesec.c):
  absent FILESEC_ACL makes `filesec_get_property` fail with ENOENT;
  `filesec_query_property` instead returns success and the validity flag.
- [statx_np.c](https://github.com/apple-oss-distributions/Libc/blob/71bbe350ab79eef58113991d817ccc6165061a64/sys/statx_np.c):
  `fstatx_np` populates filesec metadata from the descriptor; the ACL property
  is only populated when ACL data is present.

The published revision is explanatory source, not a claim that the installed
binary was built from that exact commit. Native results above are separate.

## Proposed metadata rule for boundary stability

Use a fresh filesec object for each held object, require successful native
metadata acquisition, require nonzero OWNER/GROUP/MODE presence and successful
value retrieval matching the stat result from that same acquisition, then
require successful ACL-property query. Presence is nonzero, not exactly one.
Reject an unpopulated filesec even when the acquisition returned zero. Never
translate generic NULL, ENOENT, EACCES, ENOTSUP, missing API, failed allocation,
or malformed ACL into a trusted boundary. An absent ACL property after a
successful supported-filesystem metadata read is a distinct outcome.

The complete stability predicate must combine root ownership, absence of
group/other mode write, ACL mutation rights, source parent, target DELETE
rights, physical destination ancestry, and descriptor-derived mount identity.
The source and destination associations must already be non-administrator
immutable; repeated equal metadata is not a substitute for that proof.
Nonempty ACLs need explicit entry validation and rights evaluation; this
observation does not implement or approve that branch.

Required regressions for the metadata branch: successful absent ACL;
successful nonempty read-only ACL; non-administrator mutation grant; native
read failure; query failure; allocation failure; unsupported filesystem;
malformed ACL. Each error must deny the stability exception, not authorize
it. Ordinary mutable directory acquisition remains on its exact-name/inode
path and does not depend on proving root ownership.

## Independent advisory finding and correction

Reviewer `/root/rt004_check_contract_review` found a Major-equivalent hole in
the initial proposed rule: the pinned `statx_np.c` realloc-failure branch
sets errno to ENOMEM but can return the preceding successful syscall result
0 before populating filesec. This is a source-level counterexample, not a
reproduction of that allocation failure in the installed binary. The initial
two-call rule alone was insufficient and must not be reused.

The rule above now also requires OWNER/GROUP/MODE presence and values from
the fresh filesec. A third native read-only probe exited 0 and observed:

- Before any acquisition, a fresh filesec returned successful queries with
  presence flags `[0, 0, 0, 0]` for OWNER/GROUP/MODE/ACL. Requiring the first
  three properties rejects this unpopulated object.
- After successful acquisition on all six listed directories, the first
  three properties were present and matched the same acquisition's stat
  values; ACL presence was 0. Owners were 0, groups were 80 for the two
  Users routes and 0 otherwise, and full directory mode was 16877 (0755).
- Same-FD Python stat additionally matched dev, inode, uid, gid and mode.

This exercises real unpopulated and populated filesec objects. It is NOT an
injected realloc failure or a regression run of production candidate code.
The candidate suite must still inject a successful return with unpopulated
filesec, reject each missing/mismatched required property individually, and
accept presence bitmasks other than one. The original finding is preserved;
this correction does not retroactively turn it into PASS.

Next: independently review this metadata rule as one part of the stability
predicate, then implement and test the complete scoped candidate. No request
for human application is justified by this capability evidence alone.

## Nonempty ACL API observation and proposed rights filter

A further native in-memory probe allocated ACL objects with `acl_init`,
created entries in those objects, and read them using `acl_valid`,
`acl_get_entry`, `acl_get_tag_type`, and `acl_get_permset_mask_np`.
It never applied an ACL to a filesystem object. All allocated ACLs were freed.
The command exited 0 and round-tripped five cases:

| Case | Ordered (tag, permission mask) results |
| --- | --- |
| Empty | [] |
| Read-only allow | [(1, 2)] |
| Delete allow | [(1, 16)] |
| Delete deny | [(2, 16)] |
| Deny followed by read-only allow | [(2, 16), (1, 2)] |

Successful entry reads returned 0. End of enumeration returned -1/EINVAL
in every case, including FIRST on an empty ACL. These semantics match
[acl_entry.c](https://github.com/apple-oss-distributions/Libc/blob/71bbe350ab79eef58113991d817ccc6165061a64/posix1e/acl_entry.c).
Do not port Linux's return-value convention. EINVAL may only signify the
end of this iterator over a successfully validated, privately held native
ACL, using the valid FIRST/NEXT sequence; other operation failures reject.

Proposed sufficient rights filter for the stability exception: require uid 0
and no group/other mode write, plus no ALLOW entry granting WRITE_DATA /
ADD_FILE, APPEND_DATA / ADD_SUBDIRECTORY, DELETE, DELETE_CHILD,
WRITE_ATTRIBUTES, WRITE_EXTATTRIBUTES, WRITE_SECURITY, or CHANGE_OWNER.
Check every entry, including target DELETE rights. Accept well-formed
read-only ALLOW and DENY entries; reject unknown tags, unsupported permission
bits, malformed entries and failed reads. Do not apply this filter to ordinary
mutable traversal, which retains its name/identity binding instead.

This filter intentionally does not resolve principals or use a DENY entry to
cancel a mutating ALLOW: it proves a sufficient condition, not a full effective
permissions calculation. A root-only or inheritance-only mutating ALLOW may
therefore decline the exception even if a more complex evaluator could prove
it harmless. That compatibility limitation must be diagnosed explicitly and
must not be hidden as successful acquisition. It is not approval to remove
required mounted-repository support. The filter still needs independent
review and original-path regression tests; the five API cases do not execute
the proposed filter or prove filesystem enforcement.

## Descriptor-derived root/Data volume observation

A separate read-only `fstatfs` probe used held O_NOFOLLOW directory FDs and
the installed SDK's STATFS64 layout. It exited 0 with:

| Path | fsid | Mount owner | Flags | Extended flags | Type | Mounted on |
| --- | --- | --- | --- | --- | --- | --- |
| / | [16777235, 26] | 0 | 0x4480d001 | 0 | apfs | / |
| /Users | [16777233, 26] | 0 | 0x04909080 | 1 | apfs | /System/Volumes/Data |
| /System/Volumes/Data | [16777233, 26] | 0 | 0x04909080 | 1 | apfs | /System/Volumes/Data |
| /System/Volumes/Data/Users | [16777233, 26] | 0 | 0x04909080 | 1 | apfs | /System/Volumes/Data |

The root has MNT_ROOTFS and MNT_RDONLY. Extended flag 1 is
MNT_EXT_ROOT_DATA_VOL, explicitly defined as the Data volume of the root
volume group in the installed SDK and pinned
[XNU mount.h](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/sys/mount.h#L107).
The OS `/usr/share/firmlinks` file contains the `/Users` to `Users` mapping.
This pathname read is discovery evidence only, not authenticated candidate
input. A candidate must acquire and verify any mapping it relies on.

These results identify the current root/Data crossing from descriptors rather
than pathname text or synthetic stat device IDs. They do not establish that
an arbitrary root-mounted filesystem cannot be controlled by a nonadmin:
mount owner 0 alone is insufficient. The root/Data route and other supported
mount routes still need explicit association/stability predicates and tests.

## Follow-up independent disposition

Reviewer `/root/rt004_check_contract_review` re-read the corrected metadata
rule and rights filter. No new Major-equivalent hole was identified in the
permission-only rule. The review requires rejection of unknown ACL flags as
well as bits/tags and restricts reliance on permission metadata to filesystems
that actually enforce it. These requirements are carried into ADR 0034.

The review supplied the root/Data bridge algorithm now recorded in ADR 0034:
authenticate the mapping on the read-only root, authenticate Data by held
descriptor mount metadata, traverse its mapped relative path with ordinary
checks, verify physical association permissions, and compare held logical
and physical identities. It does not authorize a generic mount fallback or
remove the remaining mounted-repository requirements. This is an advisory
design disposition, not candidate execution or a formal SDD PASS.
