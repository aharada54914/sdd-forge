# A9 candidate operator entry points

This directory is a reviewable candidate. It is not the live Context or evidence
of approval, promotion, a release observation, or a completed rollback rehearsal.

`project-context-formal-verification.yaml` is an unapproved successor of the
retained `project-context.yaml`: it adds ownership for the repository's formal
reservation verification skill. The unsigned
`project-context-restored-cloud.yaml` adds the two cloud components, their
bounded template ownership, and the exact installer-owned `install-payload.txt`
path. The unsigned `project-context-dashboard.yaml` adds only the exact root
`dashboard-labels.json` path with MCP ownership. The unsigned
`project-context-session-hub.yaml` appends six exact cross-cutting paths covering
the project-local question-hub verification skill and its four feature-map files,
and `scripts/merge-readiness.py`. No wildcard expands ownership of other agent
skills or root scripts. The current default is the unsigned `project-context-core.yaml`.

The owner approved the ten-component inventory for the Core candidate on 2026-11-26. It carries
forward the session-hub components except for the retired `sdd-lite` package
([Core consolidation](../../../docs/adr/0051-lightweight-guardrails-and-sdd-core.md)).
The following eight exact rules supplement the inherited paths.

| Files | Ownership and basis |
|---|---|
| `scripts/vendor-shell-parser/{build.py,go.mod,go.sum,main.go,zsh-loops.patch,zsh_loops.go.in}` | Six separate paths bounded to `sdd-quality-loop`. The build script consumes them to produce the plug-in's runtime. [Build inputs and output](../../../scripts/vendor-shell-parser/build.py) |
| `sdd/approved-test-retirements.json` | Cross-cutting. Repository-wide test retirement requires a human-approved record protected by CODEOWNERS. [ADR-0054](../../../docs/adr/0054-verification-first-and-agentic-factory.md) |
| `sdd/guardrails.example.yaml` | Bounded to `installer` and `sdd-quality-loop`. The installer distributes the example and the guardrail CLI directs users to it. [Payload](../../../install-payload.txt) · [CLI](../../../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs) |

The public validator checks the current candidate against every path in the Git
index. The historical regression tests check each earlier candidate against the
complete `git ls-tree -rz --name-only <commit>` inventory for its revision.
The [archived path lists](../../../tests/fixtures/a9-candidate/tracked-paths.tar.xz)
are keyed by commit and hashed by the test, so the tests also work in shallow
offline checkouts. Existing signed Context and observation bytes retain their
original meaning. A future promotion requires independent approval of the
specific successor bytes.

For a future approved `required` → `advisory` rollback, use the
[bound rollback admission and application procedure](../../../docs/adr/0035-a9-bound-rollback-admission.md).
Its default mode validates the actual supplied HMAC approval and Ed25519 receipt
without applying them. The explicit `--apply` route invokes the existing safe
publisher only after admission. A separately signed applied attestation and
current-file verification are required for the signed rehearsal result.

For Phase-2 promotion, the [bound admission contract](../verification/promotion-admission-contract.md)
connects the release preflight, original findings and WFI artifacts, three-OS
compatibility, signed live-host proof, and a completed signed rollback rehearsal
to the real Phase-2 HMAC approval and an operator-signed decision.
`scripts/validate-a9-promotion.py` validates by default; its explicit `--apply`
route rechecks the evidence before using the existing three-file publisher.
An `ADMISSIBLE` result does not publish, and `APPLIED` does not claim the
subsequent real feature acceptance condition has completed.
