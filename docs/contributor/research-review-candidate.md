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

The combined main candidate supersedes the earlier split PR description. It
preserves the integrated review-launch behavior and restores research admission
to the workflow-state owners. The [integration verification](../../reports/verification/research-workflow-integration-20261031/README.md)
records the 20 expanded conditional cases and 10 bounded-session cases. This
is not evidence of A9 activation, promotion or release acceptance.
