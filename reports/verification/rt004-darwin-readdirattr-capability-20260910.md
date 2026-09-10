# RT004 Darwin direct directory-attribute capability

Date: 2026-09-10. Read-only metadata probe; not candidate execution or PASS.

## Decision question

Could `getdirentriesattr` supply the name/identity coupling needed at the
macOS mount/firmlink boundary without `getattrlistbulk`'s previously identified
generic fallback? This is a different API from the rejected LINKID and bulk
hypotheses. No filesystem content, protected implementation or ledger was
modified by the probe.

## Source and ABI check

Apple's [XNU implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_syscalls.c#L10631)
calls VNOP_READDIRATTR and returns its error. This makes capability availability
an immediate question before considering any identity guarantee. The archived
[Apple manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getdirentriesattr.2.html)
documents ENOTSUP for unsupported volumes. Neither observation proves coupling
under concurrency or mount traversal.

The installed SDK at
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/unistd.h:766`
declares the LP64 count/base/state parameters as unsigned-int pointers. The
probe used those 32-bit types, not the archived manual's unsigned-long types.
Attribute constants were checked in the installed `sys/attr.h:409` and `:445`.
RETURNED_ATTRS was not requested: the header limits it to other attribute APIs.

## Actual local result

An inline Python ctypes probe called libSystem's documented entry with held
read-only directory descriptors and NAME, DEVID, FSID, OBJTYPE and FILEID.
The buffer was 65536 bytes, requested count 64, options 0. It bounded record
and name parsing if a call succeeded, and closed each descriptor in finally.
It did not create files or execute an extracted admission implementation.
The command itself completed with exit 0; all three API calls failed:

```json
{"base":0,"count":64,"entries":[],"errno":45,"path":"/","rc":-1,"state":0}
{"base":0,"count":64,"entries":[],"errno":45,"path":"/Users","rc":-1,"state":0}
{"base":0,"count":64,"entries":[],"errno":45,"path":"/System","rc":-1,"state":0}
```

Count/state values on failed calls are not valid returned enumeration evidence.
No claim about every macOS filesystem or Windows follows from this observation.

## Disposition and next work

Do not select this API as the solution for the current host. A candidate that
requires it would reject ordinary supported local placement. Do not substitute
the unsafe bulk fallback, truncate identifiers, or ignore mount boundaries.
The next Darwin design still needs a supported, coupled entry/held-object
identity mechanism. Windows drive/UNC backend completion also remains open.

This investigation used the architecture skill's capability/trade-off check;
it changed the candidate selection evidence, not the implementation contract.
Keep RT004 open and the partial DATA candidate ineligible for application.
The independent observer tests are now applied and verified (140 workflow
cases including the three new observers); they are not evidence for the
unimplemented acquisition backend.

GitHub was refreshed: all 11 open PR heads are unchanged; 245/403/405 conflict;
other recorded failing required checks remain. Both queued and in-progress
Actions queries returned empty arrays. No live CI handle is being waited on.
No commit, push, PR creation, merge, closure or task Done transition occurred.

## Minimal attribute follow-up

The original compound bitmap could not distinguish whole-API unavailability
from rejection of one requested attribute. A second read-only native probe
therefore tested four smaller masks, independently reopening each directory:
NAME (0x1), NAME+OBJID (0x21), NAME+FILEID (0x02000001), and
NAME+OBJTYPE+OBJID (0x29). Paths were `/`, `/Users`, and `/System`.
All twelve calls returned -1 with errno 45 (ENOTSUP). The command exited 0;
this means the probe completed, not that any API call succeeded.

The SDK's LP64 declaration was rechecked. Each call used a fresh 65536-byte
buffer, count 16, zero base/state/options, and a held read-only no-follow
directory descriptor closed in finally. Failed-call counts were reported as
null, not parsed as valid enumeration data. No output directory records were
interpreted and no filesystem content was read or changed. This closes the
specific smaller-bitmap alternative on this host, not every filesystem/API.
