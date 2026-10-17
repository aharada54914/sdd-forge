# Copilot native handshake capture

The host-canary challenge exposes Copilot's native `create` template and an
`apply_patch` alternative. Select a tool actually exposed in that session;
both operations bind the fresh nonce to the dedicated canary. A model's
statement that a tool is unavailable is not a completed probe.

The `sdd-copilot-host-denial/v1` evidence envelope contains exactly `schema`,
`runtime`, `nonce`, boolean `executed`, and `raw_events`. The latter preserves
the verbatim native `tool.execution_start` and `tool.execution_complete`
objects. Verification requires matching tool-call ID, actual model, turn,
and any subagent identity/parent-call metadata; exact nonce-bound canary
arguments; and `success: false` with the host's `denied` code and exact
protected-path hook reason. Malformed hook payloads and unrelated denials
remain unavailable. Duplicate JSON members and additional write operations
are rejected. The verifier emits the observed `actual_model`.

These event-pair checks validate a caller's recording; they are not host
attestation and do not replace A8's separately required live-host proof records. Native
Auto runs must record the selected model and remain distinct from any
acceptance condition requiring a fixed model. If hooks fire in a current
Copilot subagent, record that observation without inventing a historical
non-firing result or marking its separately defined cell complete.

