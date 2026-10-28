# Research review candidate

This candidate connects a validated, hash-pinned research packet to the existing
review input resolver and adds an optional fresh source-evidence check to the
existing contract owner. It does not grant approval or rewrite historical review
evidence. The existing reviewer identity and gate owners remain authoritative.

The four current protected consumer scripts differ from their frozen staged
predecessors. `tests/fixtures/research-consumer-current-publication.json`
binds both exact sets of bytes for the coverage regression; its mutation controls
detect drift. The fixture is a test input, not a reviewer signature or an
approval of the current candidate. Frozen human-copy files and their manifest
are unchanged. Fresh review of these current scripts is required.

The A9 interrupted-review recovery change is being composed separately in
PR #658. This main-based research candidate does not contain that recovery
change; integration must preserve both changes and revalidate the combined bytes.
