# Issue 289: both shipped validators reject the shipped template

Date: 2026-09-08
Checkout HEAD: 8fa3eb8561d6f59b692ec574900f87e181145928
Result: diagnostic reproduction, not implementation acceptance.

The three inspected paths have no working-tree changes (git status tool
459f0f):

- plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md
- plugins/sdd-review-loop/scripts/validate-layer-traceability.py
- plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1

Both validators were invoked directly against the shipped template. The same
template supplied the required-ID input: the validators only extract REQ IDs
from that argument, so this diagnostic needs no synthetic requirements file.
This does not validate a complete specification or establish missing-ID behavior.

Python invocation (37e1c6), exit 1:

```text
rtk proxy python3 -B plugins/sdd-review-loop/scripts/validate-layer-traceability.py plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md
invalid Layer Spec for REQ-001: design.md#architecture
```

PowerShell invocation (13b958), exit 1, on macOS (not native Windows):

```text
rtk proxy pwsh -NoProfile -File plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1 -Path plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md -RequirementsPath plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md
invalid Layer Spec for REQ-001: design.md#architecture
```

Source inspection f92d2a shows both validators select requirement-keyed rows
without table-header scoping and read cells[2]. The shipped template places
Layer Spec at index 3. The PowerShell implementation is independently written,
not a dispatcher to Python; fixing Python alone cannot resolve the shipped
behavior. A repair must cover both implementations plus the template/drift
contract, including unrelated requirement-keyed tables and existing six-column
documents. No choice to drop the template's extra information is inferred from
this diagnostic. No production files, review state, issues or PRs were changed.
