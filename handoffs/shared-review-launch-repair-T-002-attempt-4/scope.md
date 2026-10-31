Task: shared-review-launch-repair T-002, native implementation admission attempt 4.
Owner: shared-review-launch-integration/sdd-forge; HEAD 9ce19abe90df0cb83e385f96855e4843318a8807. Existing 110 dirty/untracked entries preserved.
Risk: high; existing manifest, independence, input and evidence contracts unchanged.
Attempt 3 remains historical: its manifest location fails the canonical handoffs path contract. This is a fresh native execution, not a relocation or identity rewrite of that evidence.
Reuse only the prior explicit input inventory; recompute current hashes and obtain a fresh native session. Preserve snapshot, permissions and MCP isolation checks.
Required: snapshot/input admission, four task suites, native report validation, deterministic bundle and independent quality gate. No current PASS, reservation, Done, CI or merge is claimed.
