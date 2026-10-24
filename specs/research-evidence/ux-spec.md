# UX specification: Research evidence foundation

DRAFT. REQ-007, REQ-011, REQ-013; AC-005, AC-008, AC-010, AC-012.

## Scope and User Journeys

Author prepares record metadata → runs file validation → fixes the named
field → runs repository/history validation when those inputs are available →
submits the draft through existing review. Validation never fetches material,
asks for credentials, authorizes storage, or advances approval/Done.

## Output and recovery

Design's exact CLI output is authoritative. Success includes `scope` and
`history`: `file` does not establish inheritance/placement, and `unchecked`
does not establish append-only history. The user sees VALID, never a quality
PASS claim. Counts include revisions, not unique sources/claims.

Invalid input returns a stable code and JSON pointer; repair the referenced
metadata, keep previous revisions, then rerun. Diagnostics never include quote
text, query values, private paths, or the contents of a rejected secret. Usage
errors exit 2. Missing source/rights evidence remains explicitly unknown even
when structural validation succeeds. A blocked external consumer states the
reason and owner; it does not relabel missing evidence as success.

## Views and accessibility

Plain UTF-8 CLI text, no color-only meaning, interactive widget, animation or
browser. Empty source/claim arrays are a valid new unsearched set, not a
positive research conclusion. No UI screenshots are needed for this feature.
#610 owns future HTML excerpt interaction.
