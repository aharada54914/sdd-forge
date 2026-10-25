# ADR-0044: Research evidence extends existing owners

Status: Accepted (implementation ownership)

Issues #605–612 require primary-source acquisition, reproducible quotations and
review references. Bootstrap owns bounded public discovery and acquisition;
quality owns the canonical metadata, fresh quotation checks and small evidence
graph. Existing spec/implementation review manifests optionally admit the pinned
research envelope, and the existing contract gate consumes source-evidence checks.
No second review verdict, task authority or approval system is added.

Fetched instructions are data, never executable plugin instructions. Public
queries may be sent; secrets and private originals may not. Originals stay in a
runtime-selected external store, while repository records contain hashes and
storage identities without private cache paths. Acquisition and deterministic
extraction are bound together; unknown extraction recipes cannot claim verified
quotations. Unsupported subtitle conversion, remote shared stores and proxy
transport fail explicitly rather than bypassing their boundary. PDF extraction
uses the bounded optional adapter below.

HTML is escaped and shows original quotations and separate optional translations.
Translations are labeled meaning-unverified and cannot establish evidence validity.
Updates report changed feeds separately from changed pinned source content;
small-graph impact is navigational evidence, not an inferred acceptance verdict.


## Optional PDF parser

Acquisition and original verification use the same existing extraction module.
The caller remains `research-acquire.py --url ... --allow-host ...`; reference-only
is still the default, and the source-evidence checker re-extracts actual PDF bytes.
The recipe records pypdf's installed version, copied source-file digest and the
layout algorithm version. A different recipe cannot silently replay old evidence.

Considered shapes were an external pdftotext command, an in-process library, and
an isolated optional library. The isolated library reuses installed pypdf without
introducing a converter CLI or dependency download. Direct in-process parsing
would not bound memory/CPU; a converter command would require a separate approved
executable adapter. The implementation currently requires Linux user namespaces,
bubblewrap, pypdf and the existing project process supervisor. Other environments
fail explicitly; no macOS/Windows PDF execution is claimed.

The parser receives only source-only pypdf copies, trusted Python runtime/library
files and the two extraction modules. Home, repository and credentials are absent;
its environment is cleared. Mounts are read-only, network is isolated, capabilities
are dropped, and a non-root namespace identity plus CPU/address-space/file/FD/process
limits applies. Output is an anonymous, bounded regular file, not an unbounded
parent pipe buffer. No PDF actions, attachments, passwords, OCR or external
instructions are executed. Empty/image-only, encrypted, malformed, excessive-page
and oversized inputs fail without replacing previous stored evidence.

The existing project-skill process subreaper supervises parser and Linux fetch
workers. Optional stdin inheritance and output-size limits leave its original
project-runner defaults unchanged. It kills and reaps descendants before reporting
ordinary timeout cleanup. Fetch timeout also owns the nested PDF subtree. If the
calling application itself is forcibly killed, reaping its final controller is the
host init's responsibility; a non-reaping PID 1 cannot be promised zero zombies.

## Local group sharing

The licensed_shared Source contract already represents shared-store / named-group;
it needs no new source schema or verdict. An optional `--shared-gid` on the
existing cache save/purge caller selects the Linux local-group profile. A separate
cloud-provider uploader would introduce credentials, network storage and a new
service boundary; a new storage command would duplicate cache lifecycle. Reusing
the existing operations keeps local_cache unchanged and reference_only default.

The shared root must be preconfigured by its owner with mode 0750 and the named
existing GID. Publishing requires membership in that group. Snapshot directories
are 0750 and regular, single-link files 0640. Named/default POSIX ACLs, symlinks,
third-party-writable ancestors and unsupported mounts fail closed. The supported
Linux filesystem types are ext4, xfs, btrfs, tmpfs and overlay; remote stores and
macOS/Windows need their own adapter. Publisher/root-controlled ancestors are a
trust assumption: the owner and host administrator can always copy originals or
change permissions. Group readers cannot mutate the stored snapshot.

research-shared-cache/v1 receipts bind publisher UID, reader GID, permission basis,
expiry and both hashes. The Source scope label binds numeric UID/GID without a
private path. Fresh shared verification checks current filesystem permissions and
the receipt against the Source before reading bytes, then follows the existing
hash/extraction/quote checks. Expiry immediately prevents fresh verification;
explicit purge/revoke removes stored originals. No background cleanup, revocation
of already-read copies/open descriptors, or absolute protection against the
publisher/host administrator is promised.
