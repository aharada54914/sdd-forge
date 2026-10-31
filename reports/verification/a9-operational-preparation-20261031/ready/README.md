# A9 operational acceptance: concrete unsigned review packet

**Ready for review; operational acceptance has not run.** This packet prepares
Issue #678 using the actual recovered MCP report lookup cache. It is not a live
Context, a signed approval, a completed task, or an advisory release observation.

## Review these concrete inputs

- [Requirements](draft/requirements.md) and [T-001 task](draft/tasks.md):
  prospective operational acceptance, **Approval: Draft / Status: Planned**.
  The implementation was recovered before these draft documents existed; no
  retroactive workflow compliance or approval is claimed.
- [Context candidate](candidate.yaml): exact successor raw SHA-256
  `a43669c40d374b1411df0ba2f3ed84c4fb05d337c33e850e157f9c612702076a`.
- [Approver registry proposal](registry.yaml): the real owner `aharada54914`,
  not a fictitious second approver.
- [Technical contract](draft/contract.json) and [actual request](draft/request.json):
  feature `mcp-report-lookup-cache`, intended contract path
  `specs/mcp-report-lookup-cache/verification/T-001.contract.json`.

The files are exports only. They have not been placed at those live `specs/` or
`sdd/` paths. [path-map.json](path-map.json) maps original review-tree paths to
these shorter publication paths and records byte-preserving hashes. Original
runtime paths inside execution records are intentionally unchanged. Restore the
original review-tree layout before invoking product consumers; passing a flattened
publication directory as a live repository would be incorrect.

## Genuine observed checks and their limits

Final dependency-lock execution passed TypeScript checks, build, **309 tests /
zero skips**, and production dependency audit with **zero vulnerabilities**.
[e/executions.json](e/executions.json) retains actual UTC timestamps, commands,
exit codes and the lock hash. One fullsuite execution supports the unit,
acceptance and regression views; these are not three independent executions.

Additional actual preparation commands passed whitespace lint (`git diff --check`),
placeholder scanning of the four changed production sources, and the existing
task-state checker against the Draft/Planned task. There is no configured ESLint
command; whitespace lint does not imply a broader ESLint analysis. TypeScript
static diagnostics are separate. [e/preparation-executions.json](e/preparation-executions.json)
retains these commands and results.

The existing contract validator passed against the original scratch review tree.
The first preparation attempt rejected empty lint stdout as evidence; the final
contract uses the genuine execution record and raw-output hashes. No test was
weakened. Draft-state validity and technical contract PASS **do not mean owner
approval, completed REQ-005, activation or operational success**.

The inspected source was `75b169feb5e0f4a7c7fdfa95bf66f1ba86ca1740`; its MCP
files were unchanged from recovery commit `451fa4c9`. Hashes measured after the
original execution and their limits are in [e/source-binding.json](e/source-binding.json).
This is not an invented clean-commit execution certificate. Final activation source
must be revalidated if any relevant candidate, tool, contract or code changes.

## Actual owner actions

1. Review and explicitly approve or reject the prospective T-001 scope and Done
   conditions. Preserve actual human-origin approval; an agent must not convert
   this Draft into a claimed human decision.
2. Confirm the registry proposal identifies the actual single owner.
3. If the exact Phase-1 Context is approved, sign with the existing issuer in a
   trusted private local terminal. Never share the signing key with an agent,
   paste it into chat or place it in the shared cloud workspace.

With reviewed source and this export on the owner's machine, set absolute paths:

```bash
reviewed_repo=/absolute/path/to/sdd-forge
reviewed_export=/absolute/path/to/this-export
signed_output=/absolute/private/path/to/new-signed-output
cd "$reviewed_repo"
test "$(git rev-parse HEAD)" = 75b169feb5e0f4a7c7fdfa95bf66f1ba86ca1740
```

Review `candidate.yaml` and confirm its raw hash above with `sha256sum` or
`shasum -a 256`. Configure the owner's existing private `SDD_CONTEXT_KEY_FILE`
outside any agent-readable environment. If initial key enrollment is needed,
perform it there under the owner's custody. No key is configured in this shared
workspace. Once the owner approves these exact bytes, run:

```bash
python3 plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  --schema sdd-project-context-approval/v1 \
  --content "$reviewed_export/candidate.yaml" \
  --live-sidecar "$reviewed_repo/sdd/project-context.approval.json" \
  --approver aharada54914 --status Approved \
  --stage-dir "$signed_output"
python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
  --content "$reviewed_export/candidate.yaml" \
  --sidecar "$signed_output/sdd/project-context.approval.json" \
  --approver-registry "$reviewed_export/registry.yaml"
```

This is bootstrap only while that live-sidecar path is absent. If it exists,
stop and review the real predecessor instead of inventing an absent one. Return
only the signed public artifact directory and the trusted validation result,
never the key. Key-free hashing by an agent is not independent HMAC authentication.
The same existing human/CI-only key-custody contract remains in effect.

## Agent work still required after those decisions

- Independently review this packet, publish the real feature/task/contract/evidence
  and request in a reviewed PR, and preserve actual human approval provenance.
- Recheck the final source; assemble the signed Context, sidecar, snapshot and
  owner-confirmed registry into a reviewed publication stage; apply through the
  authorized human-copy route. Signing alone does not perform publication.
- Actually execute advisory collection on the clean committed final PR head and
  retain authentic check/digest associations and real failure/recovery friction.
- Complete a real final published-release interval. GitHub currently has no
  Release object to reuse; no release version or payload is approved here.
- Decide promotion from real evidence. If chosen, satisfy actual signed decision,
  live-host proof and rollback admission requirements, then complete a real feature
  after promotion. Phase-1 approval does not pre-approve later promotion.

See [status.json](status.json) for the explicit observed/missing split. No live
files were modified, signatures issued, releases published or credentials read to
prepare this packet. #678 remains open.
