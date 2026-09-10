# Issue289 / Issue291 closure refresh

Main: `9dd531f94882eb18fe7f783de395cd1c7a8ee208`.
Status: both incomplete; no closure or implementation PASS.

## Issue289

Primary fetched the live issue body (no comments) and read both complete files
using `git show origin/main:<path>`:

- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md:7`
  has ten columns, Layer Spec at zero-based index3. The REQ001 example at line9
  puts `design.md#architecture` at index2.
- `plugins/sdd-review-loop/scripts/validate-layer-traceability.py:30-36`
  inspects every requirement-keyed row, reads cells[2], and validates that as
  Layer Spec. It does not select a table by its header.

The two reported defects remain in current main: wrong-column interpretation
of the shipped template, and unrelated requirement-keyed tables interpreted as
traceability. Merely updating documentation or noticing an old task is Done
does not satisfy the requested template/validator/drift-lock repair. The
independent investigator did not establish a matching approved repair task;
this is a bounded search result, not proof no such artifact exists anywhere.

## Issue291

Primary fetched the live issue body (no comments) and directly inspected
`origin/main:install.sh`: line20 VALID_PLUGINS omits sdd-domain. The issue
explicitly leaves two choices open: installer support or deliberate exclusion
with a formal alternate installation contract. Historical README annotations
are explicitly not that decision.

A non-blocking human question requests the recommended installer-support
decision: Bash and PowerShell install/uninstall support with explicit opt-in,
not adding it to default installation. This is an unresolved design choice,
not another request for blanket integration permission. Dependency PR work
continues while awaiting the answer. If approved, trace the dependency closure,
uninstall semantics and four-platform-script tests through the required SDD
workflow; do not treat approval as permission to bypass protected-file hooks.
