# Actual repository advisory observation — 2026-10-17

The source and target commits in `observation.json` identify the real repository
change, including owned plugin code. The existing Resolver ran with the unpublished
candidate Context and completed its normal publication and post-publication recheck
in an isolated checkout. Both independent Manifest and Evidence validators accepted
the generated artifacts. These files are copied byte-for-byte from that run.

Four plugin components were affected. The two approved capabilities selected their
two facets, zero new gates, and no advisory diagnostics. This is a Resolver and
consumer observation, not an independent Pack review or complete capability Gate
result. The absence of a diagnostic does not establish a release-cycle PASS.

The repository has no live `sdd/project-context.yaml` or approver registry. This
run did not activate a Context, create a signature, authenticate a human, or publish
a release. At observation time, GitHub Releases and Git tags were both empty.
The open-PR inventory is a starting observation; each capability Gate remains
explicitly unverified. A complete cycle needs an authenticated Phase-1 activation,
usable A7/A8 native integration, explicit start/end releases, and advisory Gate
results for every PR between those boundaries. Required promotion, a real
post-promotion feature and field rollback evidence remain separate unmet criteria.

Reproduce the analysis at the recorded target commit using the recorded source
commit and `resolve-project-context.py --config
specs/epic-197-a9-dogfood/candidate/project-context.yaml --source-rev <source>
--target-rev <target> --feature epic-197-a9-dogfood`, then run the existing Manifest
and Resolver Evidence validators on the generated files. Use the Manifest as the
Evidence validator's affected-component provenance; the full Context Projection
contains every configured component and is not that subset.
