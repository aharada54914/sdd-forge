# Independent review of launch-codex-review.py

Reviewer: sqlite_session; 2026-11-07. Source inspected independently from lite_session implementation. Existing ten launcher tests passed. This is bounded code review plus a concrete path-control reproduction, not an exhaustive security claim.

Confirmed preconditions and ordering: native thread allocation requires idle status, no turns, named active permission profile; parent preflight and genuine reservation precede the first model turn. Input pins are checked before reservation, after it and after completion. Candidate identity/schema/manifest checks are performed and canonical-stage-validator adoption is still required. Child external apps/plugins/hooks/multi-agent/web capabilities are disabled; configured MCP servers are discovered without logging config and disabled before the review process. Native probes verify inside-read success and outside-read/write/network denial. Dynamic data is passed through subprocess argv and JSON, not interpolated into shell commands. Deadline/error paths close native host and temporary directory.

Finding sent to implementer: output=args.output.absolute() retains '..'; lexical is_relative_to(root) therefore accepts ROOT/../outside-new. The existing ancestor loop reaches ROOT and mkdir creates outside it. Reproduced with the exact path-check statements in a temporary directory: accepted=true, resolved-inside=false, outside-created=true. Needs traversal rejection and tests before use.

Scope concern sent to implementer: runtime read grant cli.parent includes all siblings of a caller-selected CLI. A trusted /opt/codex/bin assumption is narrower than arbitrary CLI location. Prefer exact binary read if native runtime works, or explicitly bound trusted runtime root; sibling read is not detected by the current temp-outside probe. No secret read attempted.

Output JSON check is deliberately candidate-level; it does not fully validate each stage check schema/verdict derivation. Consumers must retain canonical stage validation. Process cleanup kills the app-server process; descendant lifecycle remains the native host responsibility.

Follow-up: implementer added explicit parent-traversal rejection and restricted runtime read scope to the resolved CLI file. Independent source reinspection confirmed both changes; launcher suite now ran 12 tests with 1 native-probe environment skip (no failures). Implementer separately reports native permission probes passed. Environment identity/local working-directory checks were also added.

Final independent check: SDD_TEST_CODEX_PERMISSIONS=1 with the isolated Codex home ran all 12 tests PASS, zero skips, including the four actual native permission probes.
