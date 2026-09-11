# RT004: root/Data metadata predicate candidate

State: test matrix and DATA patch only; no production application or runtime PASS.

Scope: complete the mount-identification prerequisite of ADR 0034's bounded
root/Data bridge. This is not the association or permission-stability proof.
The existing original-path admission run remains RED (52 pass, 8 wrong-case
failures); no new predicate-specific execution is claimed.

## Required predicate tests (specified before candidate edit)

Exercise the actual embedded reader after authorized original-path application;
do not execute a renamed or extracted protected implementation.

| Input mutation / control | Required predicate result |
| --- | --- |
| Observed APFS root flags 0x4480d001/ext 0 and Data flags 0x04909080/ext 1, owner 0 and distinct fsids | Identified only; still cannot authorize traversal |
| Root lacks RDONLY or ROOTFS, independently | Reject |
| Either filesystem is non-APFS, non-local, or has a nonzero mount owner | Reject each independently |
| Either has IGNORE_OWNERSHIP or UNION | Reject each flag on each mount |
| Either contains any unknown visible-flag bit | Reject each unknown bit |
| Root has any extended flag; Data lacks ROOT_DATA_VOL or has any additional extended flag | Reject each independently, including FSKIT |
| Data is marked ROOTFS | Reject |
| Either fsid is zero, or fsids are equal | Reject |
| Either native descriptor query fails | Reject, no pathname fallback |
| Identification succeeds but mapping/stability/physical identity is absent | Reject crossing before input read or ledger mutation |

Native constants: installed macOS SDK `usr/include/sys/mount.h:194–258`
defines RDONLY=0x1, LOCAL=0x1000, ROOTFS=0x4000, UNION=0x20,
IGNORE_OWNERSHIP=0x00200000 and MNT_VISFLAGMASK. Its explicit visible-flag
union is 0xdff0f7ff; command flags at lines 265–268 are not accepted states.
Lines 102–103 define ROOT_DATA_VOL=1 and FSKIT=2. Recheck these definitions
against the supported SDK before extending the recognized mask.

An identified Data filesystem is not proof of the exact requested Data entry,
its association with the source root, or immutable physical ancestry. The
caller must still authenticate the root-owned mapping and hold/validate both
routes, including ACL stability. No literal `/Users` exception is permitted.

The candidate remains incomplete and must not be offered for human application.
Predicate-specific negative tests, full native traversal tests, PowerShell and
Windows backends, formal review, recovery activation and CI remain pending.
