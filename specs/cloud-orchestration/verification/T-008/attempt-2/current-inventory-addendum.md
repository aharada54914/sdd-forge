# Cloud release integration addendum — 2026-10-18

This current-tree registration update supersedes no historical gate verdict.
The frozen A9 nine-component design/report describes its original tree; the
UNACTIVATED candidate now retains those exact nine component records and adds
`sdd-azure-cloud` and `sdd-aws-cloud`, each owning only its exact plugin subtree.
Both use the established plugin_package / host_cli_plugin / github_release +
multi_runtime_plugin_install / repository_content + workflow_evidence +
credential_material tuple. This reflects existing token consumption in
azure_governed.py:303–304, aws_governed.py:381–382 and aws_control.py:76,
not a new credential grant. Per-cloud-component missing/wrong credential
classification negatives explicitly check the classification diagnostic.
`templates/cloud/**` is SHARED_BOUNDED to those exact two providers, not excluded
or globally cross-cutting. No arbitrary plugin/templates/root catchall is added.
The strict current inventory is eleven. No live project Context, approval,
sidecar, promotion or required/advisory policy change is performed. Negative
controls remove every component, mutate every classification and owner, remove
or broaden cloud template ownership, and introduce unknown plugin/template roots.

Current model documentation is registry-driven, not GPT-5.2-only. The two precise
shell documentation assertions now match that approved wording; both real
selectors exercise registered gpt-6-astra as a strong/high evaluator. Existing
legacy fallback, availability, effort floors and matrix controls remain intact.

T011 protection delta is exactly the five paths in T011-protection-delta.patch,
compared between f0f269ef and 9210c080. The explicit test-only addition list now
admits those five plus the eleven earlier approved additions; UNRELATED_SHA256
remains unchanged. The five-only run failed before mutation bodies due to those
earlier cloud protections. Caller then authorized that exact earlier delta as documented in
host-complete-authorization.md; both Git deltas and the failed run are retained.
Count/remove/duplicate controls cover all sixteen, with arbitrary-extra and
unrelated-field negatives and the immutable original baseline hash. No hook guard
source or projection is modified.

Ticket aliases are exact in ticket-id-aliases.json: the twelve existing filenames
are preserved, IDs 901–912 were unused in ticket-id-sweep-before.json, and only
ticket_id lines change. Status, approval scope, severity and resolutions do not.
Frozen reports and old evidence refer to the retained historical paths/aliases.
Ticket900 is left open and untouched.
