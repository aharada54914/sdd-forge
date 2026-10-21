Harbor model router

select(request, catalog, observation) returns one model ID or raises ValueError.
Request: role (nonempty string), floor (integer >= 0, bool forbidden), optional preferred/pinned (nonempty strings). Unknown request keys are ignored for compatibility.
Catalog: list of unique entries {id: nonempty string, tier: integer >= 0, roles: list of nonempty strings}; all entries must validate even if unselected.
Observation: {fresh: bool, available: list of nonempty strings}. A stale observation cannot authorize selection.
Eligible IDs must exist in catalog, be currently available, support the role, and meet the floor. Unknown available IDs do not authorize unknown catalog entries.
Pinned is mandatory when provided: reject an ineligible pin. Preferred is a hint: use if eligible, otherwise select the first eligible catalog entry. If pinned and preferred differ, pinned wins. Reject malformed supported fields before choosing, including malformed shadowed fields. Extra keys in entries/observation are ignored. Do not mutate input values.
