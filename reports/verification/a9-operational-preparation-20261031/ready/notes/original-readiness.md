# Issue 678 operational readiness — 2026-10-31

Read-only source: recovery work branch `75b169feb5e0f4a7c7fdfa95bf66f1ba86ca1740`.
No live activation, signature, release, or product edits were performed.

## Actual current result

`python3 scripts/validate-a9-candidate.py --phase phase1` exited 0.
The unpublished successor candidate is valid with no diagnostics. Its exact raw
SHA-256 is `a43669c40d374b1411df0ba2f3ed84c4fb05d337c33e850e157f9c612702076a`.
The validator's ownership digest is
`sha256:71ef2f0f9f42f9ba3cd87404ba93baec0d8118966d7300f802fc5e43902a6d1e`.
These are different bindings; neither is an approval.

Live Context, registry and advisory request are absent. Only existence/configuration
booleans were checked for the standard context-key locations; no key file or key
environment setting is configured. No key bytes were read.

## Reviewable unsigned inputs

- `unsigned-stage/sdd/project-context.yaml`: byte-exact successor candidate.
- `unsigned-stage/sdd/approver-registry.yaml`: proposal for the real repository
  owner `aharada54914` as the single approver. The owner must confirm this actual
  identity; this draft does not assert registration, approval or a second identity.
- `unsigned-file-hashes.json`: hashes of both proposed files.
- `prepared-request.json`: concrete request for actual MCP report lookup cache
  recovery, feature `mcp-report-lookup-cache`, contract
  `specs/mcp-report-lookup-cache/verification/T-001.contract.json`. Request keys
  and feature/path relation are valid; it is NOT yet publishable because the
  corresponding real contract and evidence are not committed.
- `review-tree/specs/mcp-report-lookup-cache/`: honest prospective DRAFT
  requirements/task packet and the real technical observation contract.
- `review-tree/sdd/a9-advisory-request.json`: identical prepared request, pointing
  at the actual contract within this review tree. Neither is committed/live yet.
- `history/prepared-contract-unexecuted.json`: retained earlier draft only, superseded by
  the review-tree technical observation contract. It is not the activation input.

The eight technical contract checks have genuine execution records. Existing
`check-contract.py` passes against the scratch review tree. The task-state checker
only establishes that Draft/Planned is a valid state, not human approval, Done or
successful advisory operation. The lint record is actual `git diff --check`
whitespace lint; there is no configured ESLint command. TypeScript static checks
are separately evidenced. The fullsuite is one actual 309-test execution,
referenced under unit/acceptance/regression. No fabricated workflow chronology is
claimed. REQ-005 remains unexecuted despite technical contract PASS.

The staging package is deliberately unsigned and not yet publishable. There is
no Approved field, signature, signed snapshot or live publication.

## Existing issuer and exact human operation

The existing issuer is
`plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py`.
It produces a signed sidecar and byte-exact approved snapshot in a fresh staging
directory, with a publisher-compatible manifest. No additional signing service
or UI exists in the inspected path. Its `--stage-dir` option supplies a private
output location; it does not write live files.

The actual owner runs the following on their trusted local terminal, outside any
agent-readable execution environment. Obtain the exact pinned source and this
reviewed unsigned packet first. Set the three absolute paths to that local copy:

```bash
reviewed_repo=/absolute/path/to/sdd-forge
reviewed_packet=/absolute/path/to/issue678-operational-readiness-20261031
signed_output=/absolute/private/path/to/new-issue678-signed-output
cd "$reviewed_repo"
test "$(git rev-parse HEAD)" = 75b169feb5e0f4a7c7fdfa95bf66f1ba86ca1740
```

Review the proposed Context and single-owner registry. Confirm the Context raw
hash above using `sha256sum` (or `shasum -a 256` on macOS). Use the owner's existing
private context key, or create a new one in that same trusted private environment
if this is the initial enrollment. The key must never be pasted into chat or
placed in this shared cloud workspace. The issuer supports `SDD_CONTEXT_KEY_FILE`
pointing at that private file; setting that variable alone is not approval.

After the owner decides to approve these exact bytes:

```bash
python3 plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  --schema sdd-project-context-approval/v1 \
  --content "$reviewed_packet/unsigned-stage/sdd/project-context.yaml" \
  --live-sidecar "$reviewed_repo/sdd/project-context.approval.json" \
  --approver aharada54914 --status Approved \
  --stage-dir "$signed_output"
python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
  --content "$reviewed_packet/unsigned-stage/sdd/project-context.yaml" \
  --sidecar "$signed_output/sdd/project-context.approval.json" \
  --approver-registry "$reviewed_packet/unsigned-stage/sdd/approver-registry.yaml"
```

The live-sidecar path must actually be absent for this bootstrap. If it exists,
stop and re-review the current live predecessor rather than issuing a fabricated
bootstrap. The key environment must be available to this human-run validator too.
Return only the signed public artifact directory and its successful verification
result, never the key. The output includes the approved snapshot and manifest.
The agent can hash-match the public artifacts but cannot independently authenticate
HMAC without a trusted external verifier; do not claim otherwise.

Source may change during branch-recovery work. Re-run static candidate validation
on the final activation base and update this review packet/source pin if candidate,
issuer, registry proposal or governing contract changes. Re-sign if candidate bytes
change; never retarget a historical signature to different content.

## After genuine signing, before first activation

1. Root completes a real feature contract and its actual evidence files, commits
   them with the corresponding `sdd/a9-advisory-request.json`, and has their exact
   relation independently checked. The request is exactly schema/feature/path;
   commands, hashes, commit IDs and approval claims are not request fields.
2. Compose a publisher stage with the signed sidecar, signed approved snapshot,
   exact Context and owner-reviewed registry, using their original signed bytes.
   Extend the staged manifest for Context and registry; do not recalculate or
   manufacture the approval. Review the full four-file publication before applying.
3. Use existing `apply-human-copy.sh` or PowerShell equivalent, with the explicit
   stage/manifest, through the authorized human-copy route. This preparation does
   not itself authorize invocation. Validate actual publication in the trusted
   signing environment and keep the original signed approval.
4. First activation PR must have a valid request/contract, because CI detects
   Context presence at either base or head. A missing request fails closed.
   Trusted collector is already merged in main; no new gate engine is needed.

## Real advisory release-cycle acceptance

Choose an explicit release-cycle base commit and actual ending release.
GitHub currently reports zero Releases (both gh release list and REST count 0),
so no existing published cycle can be reused. The validator mechanically requires
a base commit and an ending published final Release; it does not require a second
GitHub Release object at the base. Establish the intended baseline explicitly.
The bounded first-parent interval must have a nonempty complete PR roster, with
exact final PR heads and successful latest check associations. Keep every actual
advisory observation and its digest from the genuine check run. Ordinary green
CI with inactive capability-mode Gate is not usable evidence. Track actual false
positives/approval waits/recovery friction and WFI or explicit none.

The existing collector runs from trusted base against exact head, without executing
commands stored in the request contract. Raw observation bundles are private runner
files and not automatically uploaded. The collector supports exact reconstruction
from original inputs, trusted code and authentic original digest, but reconstructed
content alone is not historical CI authentication. Preserve API associations.

After a genuine final release is published, run existing phase2 preflight with
actual baseline, registry, resolver evidence, manifest and release export. It is a
consistency check, not a signature or authorization.

Then make an evidence-based required/facet-hybrid promotion decision. If promotion
is chosen, existing `validate-a9-promotion.py` requires actual phase2 HMAC approval,
operator Ed25519 decision, actual three-OS compatibility and current-trust A8 host
proof, original findings/WFI, and a signed matching rollback rehearsal. Solo
required-to-advisory weakening requires the contract's 24-hour cooldown; do not
pretend waiting elapsed or invent a second identity. Once promoted, one actual
feature must complete end-to-end. An earlier isolated fixture does not substitute.

A release tag alone is insufficient; candidate code explicitly requires a final
published GitHub Release whose tag resolves to the cycle head. Publish only the
concrete reviewed release version and payload under the owner's release authority.

## Boundary sources

- `docs/adr/0019-approval-sidecar-protection.md`: human-owned external HMAC and
  human-copy, never agent self-approval; conditional rollback approval.
- `specs/epic-189-a1-project-context/security-spec.md`: B3 human/CI-only signing;
  agent must not read signing keys.
- `specs/epic-197-a9-dogfood/candidate/README.md`: successor is unapproved;
  approvals bind actual bytes.
- `specs/epic-197-a9-dogfood/verification/advisory-collection-contract.md`:
  explicit request and real check-to-observation association.
- `specs/epic-197-a9-dogfood/verification/promotion-admission-contract.md`:
  signed actual operational promotion evidence.

No claim of completed operational acceptance is made by this packet. Technical preparation is now reviewable in the scratch tree; prospective task
approval, Context signing, publication/commit, final-source rechecks and actual
advisory execution remain prerequisites to operational acceptance.
