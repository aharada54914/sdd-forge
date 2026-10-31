# Owner review: what is ready and what is still missing

This packet is ready for review, not ready to call operationally complete.

## Decisions the actual owner can make on these concrete files

1. Review `review-tree/specs/mcp-report-lookup-cache/requirements.md` and
   `tasks.md`, then approve or reject prospective T-001: accepting the recovered
   MCP report lookup cache through actual advisory operation. Approval: Draft
   remains intact until actual human-origin approval is recorded. The prior
   maintenance implementation is not retroactively described as having followed
   this future operational task.
2. Confirm `unsigned-stage/sdd/approver-registry.yaml` contains the real owner
   identity and no invented second person.
3. Review exact Context bytes in `unsigned-stage/sdd/project-context.yaml` and
   the pinned raw hash in README. If approved, use the existing issuer command
   there in the owner's trusted private terminal and return only signed public
   artifacts plus trusted verification result. Never return or expose the key.

## Agent-side work still remaining after those decisions

- Obtain independent review of this draft and its technical/source bindings.
- Commit the actual draft/approved packet, contract, evidence and request through
  a reviewed PR; no request currently exists at the main repository target path.
- Refresh/revalidate final source as needed and preserve actual human task
  approval provenance; Draft-state checker PASS is not approval.
- Compose the signed four-file stage, verify genuine approval externally, and
  publish through the agreed human-copy route. The unsigned candidate alone
  must never be activated.
- Run real advisory observation with original CI association, record actual
  friction, and complete a real published release cycle. No GitHub Release
  presently exists to reuse, and no release version/payload is approved by this
  packet.
- Make the later promotion decision using actual evidence. Required-mode
  promotion is not pre-approved by this task or by signing Phase-1 Context.

The eight contract checks now have real technical observations. The previously
missing lint, placeholder scan and Draft task-state checks were actually run in
scratch. Whitespace lint has limited scope; typecheck is separate. The 309-test
fullsuite is one execution, not three. The separate unmet operational requirement
REQ-005 is explicit; technical contract PASS does not mean it passed.

No main files were changed to produce this packet. A later publishing PR will
necessarily require its own final-head verification; skipping that to avoid
restarting CI would leave the operational inputs unreviewed.
