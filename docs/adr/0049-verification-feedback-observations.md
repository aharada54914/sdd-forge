# ADR 0049: Verification feedback remains observational

Status: Proposed
Date: 2026-11-15

## Context

The user requested interpreter consistency, per-feature execution visibility and
regression links for repeated corrections. Existing project-skill observations,
feature maps, retention Markdown and the verification catalog already own these
inputs. See the [specification](../contributor/verification-feedback.md).

## Decision

Extend those owners instead of adding a registry or gate. Trial receipts and
maintenance results expose conservative feature summaries. A shared check cannot
prove separate features. `complete` covers declared mapped checks only.

Observation v4 binds the effective child environment, including the selected
`SDD_PROJECT_SKILL_CHECK_ID`, while v3 keeps its exact historical semantics.
The version change avoids interpreting an old caller-environment hash as a hash
of a newly overridden environment. V1/v2 remain historical only. Existing runtime
file identity, source modes, admission and task/trial boundaries stay enforced.

Retention Markdown names only suites already owned by the catalog. The existing
runner resolves and executes them; no executable command comes from Markdown.
Incomplete and judgment-only conditions remain visible. Neither report mutates
WFI status, approval, obligations or Done decisions.

## Alternatives and consequences

Normalizing executable identities in the evidence validator would hide real
environment differences; repair fixtures and same-directory aliases instead.
A separate feature-result registry would duplicate the map; aggregate current
check receipts conservatively instead. A new WFI execution engine would duplicate
catalog execution; add a bounded selection mode to the existing runner instead.

Recheck `docs/adr/` and its index for 0049 ownership before integration. This
branch owns this new file only; renumber it if concurrent work takes the number.
