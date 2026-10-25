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
quotations. Unsupported subtitle conversion, licensed shared stores and proxy
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
