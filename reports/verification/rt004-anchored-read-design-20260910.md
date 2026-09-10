# RT-20260908-004: anchored admission input reads

Status: Proposed; NOT implementation complete, independent PASS, or permission to apply a partial candidate.

## Scope and evidence

This proposal completes the initial-open part of the existing RT004 input
contract. It does not change review verdicts, historical evidence, ledger
identity rules, or mandatory CI. At this report's initial observation the DATA
candidate was `0cfa88d533f22b4940bd90626329846411e09e494b92533fdccd80504e2b9ba1`;
the later candidate identity and disposition are recorded below.
The original-path JSON suite remains 20 passed / 32 failed; stationary path
tests are 24 passed / 0 failed. Neither result executes this proposal.

Existing reusable principles, not drop-in implementations:

- `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:121`
  walks parent descriptors and checks the final descriptor type. Its optional
  flags default to zero, and its leaf open has no nonblocking flag. RT004 must
  not silently inherit these capability and special-file assumptions.
- `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1:394`
  uses handle-relative Windows opens. Directory access at line 414 includes
  creation rights; object attributes at line 462 use case-insensitive lookup.
  Neither is suitable verbatim for the read-only, exact-case admission contract.
- `docs/adr/0011-phase2-handle-relative-protected-copy.md` describes protected
  publication. Only its anchored-read principle is relevant; publication,
  rename, deletion and destination creation are out of scope.

## Recommended implementation boundary

Keep the reader embedded in existing protected admission consumers. Do not
introduce an arbitrary writable helper, alternate validator entry point, or
path-based fallback. Read each precheck/design input once into private bytes;
derive its digest and parsed content from those same bytes. Apply equivalent
safe acquisition to ADR contents consumed by the admission contract. Failure
must occur before ledger reservation and emit a bounded, non-content diagnostic.

Use OS-specific acquisition, not a PowerShell-versus-Bash distinction:

1. POSIX: require descriptor-relative open, directory and no-follow flags.
   Walk one validated component at a time from a held repository directory.
   Reject dot segments and separators in a component. Check exact-case names
   relative to the held directory and validate the opened object. Open the
   leaf nonblocking, no-follow and read-only; require a regular file by fstat
   before reading. Close every descriptor on success and failure. Never replace
   a missing required flag with zero.
2. Windows: adapt the native handle-relative pattern to read-only access and
   existing objects only. Open each component with reparse-point semantics,
   then reject reparse attributes and wrong object types on the resulting
   handle. Require exact-case object identity, not merely an earlier path
   enumeration. Retain the necessary handles through acquisition and close
   them on all outcomes. No creation, rename or write rights are needed.
3. PowerShell on macOS needs the POSIX guarantees. Bash on Windows needs
   Windows guarantees. Neither may claim protection from its shell name alone.
   Select a backend using tested capabilities; unsupported acquisition rejects
   with a specific capability diagnostic, not a weaker reader.

Python documents platform-dependent descriptor-relative support; its presence
must be probed rather than assumed from a Python version. See the
[Python os documentation](https://docs.python.org/3/library/os.html#files-and-directories).
On Windows, opening a reparse point is not itself rejecting one: handle
validation remains necessary. See
[Microsoft NtCreateFile](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile).

## Root acquisition: review decision still required

The root cannot be trusted merely because a path check preceded its open.
Define a stable repository-root handle as the trust anchor and verify its
identity before consuming descendants. The implementation design must specify
how that initial handle is acquired without following attacker-controlled
components, including Windows drive/volume roots and macOS system aliases.
Do not silently canonicalize away a prohibited repository-root symlink; do not
reject every macOS system alias without checking supported installation paths.
The exact root bootstrap and exact-case handle checks remain design blockers,
not an already solved portability detail.

POSIX descriptors do not make concurrently writable file contents immutable.
The claim is bounded: acquisition does not follow substituted symlinks, and
the bytes parsed are exactly the bytes hashed against the authorized pin.
Do not claim protection against an attacker rewriting every authorization
artifact or an immutable namespace after a successful read.

## Alternatives rejected

- Check path, read by pathname, then check path again: may detect a change but
  does not prevent an unauthorized initial open/read.
- Copy the current helper verbatim: retains unverified fallback, case and
  special-file behavior noted above.
- Add a separately writable reader or execute a renamed candidate: enlarges
  the trust boundary or circumvents the existing protected application path.
- Declare macOS PowerShell a Windows test: does not exercise Windows handles,
  sharing, reparse points, or native filesystem behavior.

## Required implementation and verification sequence

1. Resolve the two root/case design blockers and runtime dependencies in an
   independent bounded security review. Preserve NEEDS_WORK until resolved.
2. Add deterministic original-path fixtures that replace an input/parent at
   the actual acquisition boundary, without a production bypass switch.
   Confirm a relevant RED before changing the implementation candidate.
3. Cover leaf symlink, parent replacement, root replacement, wrong case,
   FIFO/nonregular input, failed open/read/allocation and cleanup. Rejections
   must preserve the ledger; private data must never reach diagnostics.
4. Update the DATA candidate; perform static review and applicability checks.
   Only a complete independently reviewed candidate may be offered for human
   protected application. Never execute it through a copy or alternate path.
5. After authorized application, run the original full suite, including all
   existing JSON cases and positive/legacy controls, with Bash and PowerShell.
   Obtain native Windows coverage separately. Re-run affected formal gates
   and every required CI check before publication/merge eligibility.

This is a design addendum, not an accepted ADR. If review selects an
architecture change requiring a new ADR, allocate its identifier only after
checking the current shared `docs/adr/` namespace. No frozen input is amended
by this report.

## 2026-09-10 root-policy decision supersession

The proposed decision is now recorded in
`docs/adr/0034-review-input-acquisition-before-dispatch.md`. It supersedes this
report's unresolved root-policy alternatives, but not the remaining concrete
reader implementation/proof obligations. No formal gate PASS is asserted.

Source inspection confirmed Bash canonicalization at
`validate-review-context-set.sh:22-25` and the missing PowerShell root reparse
rejection at `validate-review-context-set.ps1:170-174`. The subsequent focused
root fixture result is 24 passed / 4 failed, documented in
`rt004-admission-root-link-red-20260910.md`; the earlier 24/0 slice above predates
that additional case.

Independent advisory review explicitly corrected the earlier idea of applying
safe root acquisition only after detecting the extension: a legacy-compatible
unsafe pre-probe cannot prove safe initial acquisition. Safe precheck acquisition
therefore becomes a common transport prerequisite. Legacy content/verdict rules
are preserved only for JSON satisfying common framing/ambiguity requirements;
duplicate decoded keys previously accepted by a parser are now rejected.
Historical evidence remains unchanged, while legacy alias-root calls must
use physical absolute paths. POSIX, Windows drive and UNC share trust anchors
are specified separately. Rejecting UNC merely to simplify the implementation
was considered and rejected. This explicit compatibility decision uses the
user's standing design-change authorization; it does not bypass protected apply.

## Local capability observation

Read-only probes on 2026-09-10 found Python 3.14.5 (`os.name=posix`),
`os.open` in `os.supports_dir_fd`, `os.listdir` in `os.supports_fd`, and
`O_DIRECTORY`, `O_NOFOLLOW`, `O_NONBLOCK` all available. PowerShell reports
7.6.2, Core, Unix, macOS 26.6.2. Both probes exited 0. This establishes local
API availability only, not an implemented safe reader or Windows support.
No package installation was necessary. Whole-worktree `git diff --check`
exited 0; untracked report content was reviewed separately.

## Independent bounded review disposition

Reviewer: `/root/rt004_check_contract_review`, 2026-09-10, read-only advisory
review; not a formal gate. Direction accepted as appropriate, but neither
root bootstrap nor exact-case identity is resolved. Retain NEEDS_WORK.

The trust point must be either an already trusted repository handle or an
explicitly validated walk from an OS root. A pathname alone cannot distinguish
a different regular directory substituted before acquisition from the intended
repository; post-acquisition replacement resistance is a separate claim.
Exact-case evidence must associate a name under the held parent with the opened
child identity. Rename timing, hardlinks, mounts and case-insensitive filesystems
must not be claimed solved by handle use alone.

Do not add a general alias resolver or filesystem abstraction. Select and test
the supported root forms/backends first; record any new rejection of a formerly
supported environment as a compatibility change. Keep unsupported cases explicit
and fail closed. The next implementation input must resolve these details before
the DATA candidate is called complete or offered for human application.

## 2026-09-10 Windows/UNC backend feasibility check

Read-only source and primary-documentation investigation; no native Windows
execution, production edit, protected candidate execution or formal PASS.
The architecture skill's trade-off check was used to test the proposed reuse
against the complete drive/UNC requirement, rather than assuming that a native
API name proves the contract.

The existing copy helper is not a drop-in reader:

- `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1:462`
  passes `OBJ_CASE_INSENSITIVE` to `NtCreateFile`.
- Its directory walk at lines 414-417 requests creation rights and disposes
  the previous owned directory handle after opening the next one. A reader
  relying on ancestor sharing restrictions cannot copy that lifetime policy
  without proving the remaining ancestry guarantee.
- `ValidateHandle` at lines 481-490 rejects reparse attributes and checks
  directory versus non-directory. This is useful but is not independently a
  proof that every non-directory is an ordinary data file.

Microsoft documents relative `RootDirectory` opens, existing-only `FILE_OPEN`,
and `FILE_OPEN_REPARSE_POINT`. The latter opens the reparse object rather than
rejecting it; inspect the acquired handle before any read. The documented
non-directory option also permits devices/volumes, so a reader needs its own
ordinary-file predicate. See
[NtCreateFile](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile).

**Rejected shortcut:** clearing `OBJ_CASE_INSENSITIVE` and declaring all
Windows drive/UNC exact-case checks solved. SMB2's default string handling is
not case-sensitive, and Microsoft explicitly documents Windows SMB2 server
creates with `IsCaseInsensitive = TRUE`. Therefore the local API flag alone
does not establish UNC exact-name acquisition. This is an inference from the
protocol contract, not an observed failing Windows run. See
[SMB2 message syntax](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/6eaf6e75-9c23-4eda-be99-c9223c60b181)
and [Windows SMB2 product behavior](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/a64e55aa-1152-48e4-8206-edd96444e7f7).

An identity comparison must not use a naked numeric file ID across volumes.
Microsoft's documented handle identity combines the volume serial and 128-bit
file ID, with a single-computer scope. It does not by itself prove a global
identity across unrelated remote servers, nor an exact name beneath a parent.
See [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info).

### Next implementation proof obligations

Keep drive and UNC support in scope. Investigate a held-parent directory-entry
record that couples exact spelling with child identity, paired with the opened
child under the same acquired share/volume domain. Retaining handles and
restricting delete sharing is a candidate stabilization mechanism, not yet a
proved solution: verify ancestor rename, pre-existing delete access, replacement,
hardlinks and remote-server behavior before relying on it. Do not add a
pathname-enumeration-then-independent-open fallback.

The native matrix must separately exercise drive and ordinary Windows SMB UNC:
exact spelling accepted; wrong-case spelling rejected on a case-insensitive
server; exact-name hardlink accepted; wrong-name hardlink rejected; parent/leaf
replacement and reparse substitution rejected before reading; same numeric ID
from a different identity domain not accepted as proof; failed acquisition and
read close all held handles without ledger mutation. These are pending tests,
not added executable fixtures or measured results. A failed capability probe
must reject but cannot count as the required positive UNC result.

No scope narrowing or new human approval is requested. The next candidate must
resolve these concrete API/identity obligations; the incomplete DATA reader is
still not suitable for human application. Existing observer-test application is
independent and does not satisfy these backend obligations.

## Windows sharing prerequisite and unsupported identity handling

Further primary-source inspection on 2026-09-10 rules out a metadata-only
handle as sufficient evidence for the proposed delete-sharing stabilization.
The [MS-FSA sharing algorithm](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsa/8c0e3f4f-0729-49f4-a14d-7f7add593819)
enters its conflicting-open checks only when desired access includes data
read/execute/write/append or DELETE. Inside that branch, omitting delete
sharing conflicts both with a pre-existing DELETE grant and with a later
DELETE open while the reader remains held. Consequently, requesting only
READ_ATTRIBUTES and SYNCHRONIZE must not be treated as a namespace lock.
This is a protocol-derived constraint, not a native race-test result.

The proposed reader must retain data-read access for the leaf and directory
listing access for held directories, without delete sharing. Microsoft assigns
both FILE_READ_DATA and FILE_LIST_DIRECTORY the value 1; listing is a read
permission, not a reason to inherit the copy helper's creation rights. See
[file access constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-access-rights-constants).
Keep every ancestor handle until acquisition and identity verification finish.
An incompatible pre-existing open must fail acquisition before content reads
or ledger reservation, rather than trigger a weaker sharing-mode retry.

Directory enumeration also requires an explicit unavailable-identity branch.
[FileIdFullDirectoryInformation](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/ab8e7558-899c-4be1-a7c5-3a9ae8ab76a0)
specifies zero, to be ignored, for filesystems without 64-bit IDs. Comparing
two such zeros is not identity proof. Its names are byte-length-delimited and
its multiple entries are 8-byte aligned: a parser must validate bounds and
offsets, not assume null termination or cast an unchecked buffer.

Additional required native cases: a pre-existing DELETE handle prevents
acquisition; a later DELETE open conflicts while relevant handles are held;
all holds are released after failed acquisition; metadata-only access is not
accepted as equivalent evidence; an unavailable/zero directory ID rejects
without pathname fallback; malformed enumeration offsets and name lengths
reject without reading content. These remain test obligations, not results.

This narrows the next implementation choice but does not prove complete
namespace stability. Extended rename/delete semantics, hardlink changes,
matching enumeration/handle identity classes and remote-server behavior still
require analysis and native verification. The incomplete candidate remains
ineligible for protected application, formal PASS or merge.

The [native rename structure documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_rename_information)
explicitly permits replacement with existing target handles under
FILE_RENAME_POSIX_SEMANTICS plus FILE_RENAME_REPLACE_IF_EXISTS. It requires
DELETE on the source, but that statement alone does not prove the target's
sharing behavior. Add a separate target-replacement test using these flags;
ordinary DeleteFile or source-rename rejection cannot substitute for it.
Do not infer either a demonstrated bypass or a complete defense from this
documentation alone.

## Bounded independent review: next Windows implementation boundary

On 2026-09-10 the existing independent reviewer
`/root/rt004_check_contract_review` completed a read-only advisory review.
The proposed API pair is held-parent
`GetFileInformationByHandleEx(FileIdExtdDirectoryInfo)` and held-child
`GetFileInformationByHandleEx(FileIdInfo)`: compare the exact long name and
full 128-bit identity in the same acquired share/volume domain. Never truncate
an ID to match a different information class. The primary documentation
confirms the [128-bit enumeration structure](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_extd_dir_info)
and [information classes](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex).
Driver/OS capability and native UNC success still require actual validation.

The reviewer retained three obligations: extended target replacement must not
cause a false exact-name/identity acceptance; enumeration and child identity
must use matching classes and domains; drive and UNC sharing/cleanup must be
tested separately. Replacement of a name does not itself redirect an already
held handle, so tests must assert the actual binding and bytes, not assume
every successful attacker rename implies a reader failure. No formal PASS.

Current DATA patch `adr-runtime-lexical-candidate-20260909.patch` was re-hashed
as `8af353703ed532f2b6e9f6a7211db4f4435a03cd0c3117a2be67ad65588dab66`.
Inspection found the following concrete integration gaps in that patch:

- Lines 450 and 463: PowerShell snapshot reads by pathname after a separate
  component check; replace this transport with held-handle acquisition.
- Lines 644-645: ADR payloads use separate path validation and Get-FileHash;
  route these through the same byte snapshot transport, not only prechecks.
- Lines 124-135: the POSIX name/inode check still lacks mount/firmlink
  mapping; the proposed Windows API pair does not resolve this gap.

At the preceding observation the separate observer test patches passed normal
`git apply --check` together but were unapplied. That application status is
superseded: the human applied them with backup `/tmp/sdd-rt004-observer.PUui0f`,
and original-path focused 7/0 and workflow-history 140/0 runs completed.
See `rt004-pwsh-boundary-execution-20260910.md` for exact hashes and scope.
These measurements do not establish production admission-reader safety.

A further native metadata-only capability probe rejected `getdirentriesattr`
as the solution on this host: all three selected directories returned ENOTSUP.
See `rt004-darwin-readdirattr-capability-20260910.md`; no weaker fallback was
adopted. GitHub refresh found neither queued nor in-progress Actions and
unchanged open PR heads. No merge readiness claim is made.
