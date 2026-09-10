# RT004 acquisition design review disposition

Date: 2026-09-10. Independent advisory result; no formal gate PASS.
Reviewer: `/root/rt004_check_contract_review`.

## Reviewed boundary and result

The existing independent reviewer read ADR0034, the anchored-read design,
and the LINKID, direct-directory-attribute and open-by-ID investigations.
It found no constructed ordinary-process Darwin backend satisfying the
present contract across mount/firmlink boundaries. This is not a proof that
every possible platform API is incapable. It is a concrete design blocker,
not a CI process waiting to complete.

The missing primitive associates an exact entry under the held parent with
the child reached across the boundary, with resistance to the demonstrated
name/lookup ABA. Normal same-domain directory-entry identity comparison does
not provide that mapping. Mount rejection, repeated equal observations,
cooperative locks, or copying after an unsafe original acquisition do not
satisfy the requirement. No alternate executor or private entitlement is
authorized as an implementation shortcut.

## Requirement provenance

`docs/review-tickets/RT-20260908-004.yml` requires canonical referenced ADRs,
wrong-filename-case and symlink-component rejection, hash binding, parity,
and preservation of historical evidence. Proposed ADR0034 additionally
specifies exact-name/held-child association for every ancestor from the OS
root, with ordinary mount/firmlink support. The added guarantee must not be
silently erased or treated as proved merely because the ticket's stationary
negative fixtures pass.

Local source inspection reconfirmed that existing implementations are not
drop-in solutions: `validate-task-input-manifest.sh:128` and `:142` use
optional flag fallback and no nonblocking leaf open; the Windows protected
copy helper at `apply-protected-files.ps1:414` requests creation rights and
disposes earlier ancestors, while `:462` uses case-insensitive lookup.
No changes to these other implementations were made or authorized here.

## Required next decision

Maintain the existing safety claim while identifying either a platform
mechanism providing the missing binding or a trusted acquisition environment
that prevents adversarial namespace changes during acquisition. The latter
would be an explicit execution/trust-boundary design change, not a test-only
exception or a private snapshot taken after unsafe reads. Its feasibility,
deployment requirements, and tests must be established before implementation.
No specific such environment has yet been verified; do not offer guessed
human installation commands or claim this decision already solved.

Minimum evidence for a next candidate remains deterministic ABA rejection,
logical `/Users` and physical Data-path positives, ordinary mount positives,
and exact-name hardlink positives, in addition to existing no-follow, byte
binding, cleanup and ledger invariants. Windows drive/UNC remains separate.

After the review, the main agent tested reduced getdirentriesattr bitmaps;
all twelve calls returned ENOTSUP. Details are appended to the existing
capability report. This changes the remaining investigation choices, not
the reviewer verdict or formal evidence. The partial DATA candidate remains
ineligible for human application, publication, or merge. The full issue/PR
goal is unchanged and incomplete.

## Subsequent human clarification (2026-09-10)

After this advisory review, the user explicitly limited the attacker to
non-administrator file modification/replacement and excluded administrator
mount-topology changes. ADR0034's new threat-scope section is authoritative
for subsequent work. The earlier unrestricted reading is superseded, not
retroactively passed. Reassess stable OS-managed boundaries under that scope;
retain non-administrator rename/content races, exact-case and no-follow checks.
No source candidate or test result changed with this clarification.

Read-only host inspection after that decision:

- `rtk proxy mount` reports `/` as APFS sealed/read-only and the Data volume
  mounted at `/System/Volumes/Data` as APFS read-write. Command exit 0.
- `rtk proxy ls -ldeO / /Users /System /System/Volumes
  /System/Volumes/Data /System/Volumes/Data/Users /Volumes` reports mode 0755
  and root ownership for all seven paths, with no listed ACL entries.
  `/Users` and its physical counterpart have group admin; neither is
  group-writable. Command exit 0.

These are current-host observations supporting re-evaluation of OS-managed
boundary stability, not a general runtime authorization predicate. They do not
prove all non-administrator mount operations impossible, remote-filesystem
behavior, or stability of user-owned descendants. The independent reviewer
has been asked for an actionable design under the clarified actor scope.

## Independent re-evaluation outcome

The same independent reviewer completed its read-only re-evaluation. It
withdraws the prior global atomic-ID-bridge blocker for demonstrably stable
OS-managed boundaries: the in-scope actor cannot produce the association ABA
there. It retains the ordinary dirent identity path for mutable directories.
For a boundary exception it requires held-object mode/ownership/ACL evidence,
target deletion and permission-change analysis, physical destination-parent
verification for firmlinks, and descriptor-derived mount identification.
Non-administrator-controlled mounts remain in scope. No broad path-prefix,
root-UID or mode-only exception was approved.

ADR0034 now records this two-path design and its pending stability predicate.
The next implementation work is to specify and verify that predicate, not to
continue searching for an atomic bridge under the superseded administrator
threat model. The result is advisory design progress, not executable backend
verification, formal PASS, protected-apply clearance, or permission to merge.
