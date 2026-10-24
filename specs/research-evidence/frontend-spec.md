# Frontend specification: Research evidence foundation

DRAFT. REQ-001, REQ-012, REQ-014; AC-001, AC-011, AC-013.

No browser frontend, new frontend dependency, route, rendering component or
client state is introduced. The public surface is the passive CLI described
in design.md and ux-spec.md. Source/quote text is treated as data and is not
rendered as executable markup. #610 owns HTML escaping, permissions and
excerpt display; this packet does not implement or claim that behavior.
Existing MCP tools and host projections retain their own contracts.
