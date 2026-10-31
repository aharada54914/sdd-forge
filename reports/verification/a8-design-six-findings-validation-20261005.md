# A8 six-finding design correction: bounded validation

Date: 2026-10-05 (JST)
Scope: epic-196-a8-integration, attempt 9 round 1 proposed changes; document inspection only.
Owning checkout: a8-release-sync-oct01/sdd-forge.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Risk: high/protected design and evidence contracts; this is not a routine implementation approval.

## Ownership and limits

The six-related design changes already existed before this validator began.
Their author and application route were not established. They are treated as
other-worker/user-owned changes, not changes applied by this validator.
The checkout was dirty, including design.md, tasks.md, AGENTS.md, ADR index,
review-context scripts/ledger, skills, and tests, with additional untracked
review/verification artifacts. No existing file was modified by this validation.
The observed design mtime was 2026-10-05T16:49:18+0900; the round-1 proposed
changes report mtime was 2026-10-05T16:42:08+0900. Timestamps do not prove authorship.

Round 1 remains BLOCKED (1 Critical, 5 Major). Historical Passed fields are
not new approval. No formal review, identity reservation, task transition,
runtime implementation, live MCP listing, authentication change, CI, Git
operation or protected-application helper was performed.

## Observed hashes

Commands: `rtk proxy git rev-parse HEAD` and `rtk proxy shasum -a 256 <paths>`.
All commands completed with exit 0. Design was rechecked immediately before
this report and retained the hash below.

| Repository-relative path | SHA-256 |
|---|---|
| specs/epic-196-a8-integration/design.md | 810c7cb4b2dc6189d75ae013ccf241731726e01514e8c5e1474275a5a6e6edd7 |
| specs/epic-196-a8-integration/requirements.md | f841443d88b4f58fdbb9e32ee050edf8395f3767ebbc08cc2d9d6be76cb3ac44 |
| specs/epic-196-a8-integration/acceptance-tests.md | 4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1 |
| specs/epic-196-a8-integration/ux-spec.md | c4dfe23795970cdcd3e6afe1bb8bd4cd512b14d638040598722c8b13d416e286 |
| specs/epic-196-a8-integration/frontend-spec.md | c992f19d99797c4189fe013380ba28d86c8b18dd691ddf642c09fbaa7aadfa76 |
| specs/epic-196-a8-integration/infra-spec.md | 59f2f26bbead2b5b5effa89642b58867f168db602b9c0738a65350a1fa02ae9e |
| specs/epic-196-a8-integration/security-spec.md | 45adc9bd1ffcfc1519444ce61a798b7d0f270851e393729b867c853d2aafcbe7 |
| docs/adr/0028-live-host-proof-ed25519-signing.md | 17b6c83d22126ed1095d556a80b3cb14173e4975deee039e5871656ce416186c |
| docs/adr/0035-a8-two-contribution-handoff-oracle.md | 50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923 |

Requirements, acceptance, four layer specifications, and ADR 0035 match
attempt-9/round-1/precheck-result.json. Its old design hash is
`6485d5585fd37fe9ce298b295168ad2304d6dec6a1c7dc768bf76bbebf8c1aa3`.
No old evidence was rewritten.

## Six findings mapped to current text

All line references below concern the observed design hash, not the old review snapshot.

| Round-1 finding | Current evidence | Bounded conclusion |
|---|---|---|
| DATA-COVERAGE | design.md:573-582 requires null skip_reason for PASS/FAIL and null feature-config outside Codex; :970-972 and :987-991 agree on repository-only=added/installed-only=removed and their null hashes | Both identified textual contradictions appear corrected; schema behavior not tested |
| TEST-STRATEGY-COVERAGE | design.md:350-364 fixes complete initial/final templates, UTF-8 without BOM, one LF, and output bytes binding both nonces without newline | Initial byte definition matches existing driver; live final oracle not executed |
| ADR-PRESENT | design.md:248 now contains the complete ADR 0028 path on one line; ADR 0035 declaration remains at :243 | Eligible for existing declaration grammar; actual next precheck/manifests not produced |
| NO-REQ-CONTRADICTION | design.md:1723-1727 maps requirements.md:144-146 to existing Global Constraints and Deployment / CI Plan | Missing constraint mapping now present; CI topology unchanged by this validator |
| INTEGRATION-IDENTIFIED | design.md:461-479 distinguishes successful list parsing from command failure; :1664-1686 records version claims and blocks unresolved absence proof | Version/help observations reproduced below; asserted live rows remain unverified and unsupported by located persisted evidence |
| VERIFICATION-PATH-CONCRETE | design.md:597, :751-754 checks exact registered operator/reviewer roles; :1225-1230 specifies issuer-role and reversed-role negative cases, including otherwise-valid signatures | Aligns with security-spec.md:94-95; role rejection implementation/tests not executed |

Driver inspection used `rtk proxy sed -n '1,28p;90,123p' tests/cross-runtime-handoff.tests.ps1`
and `rtk proxy sed -n '88,110p' tests/cross-runtime-handoff.tests.sh`.
PowerShell :10 sets `$fixtureNewline = [char]10`; :116-117 builds the complete
UTF-8 initial strings. Shell :100-101 uses the same byte literals with LF.
This is file inspection, not a claim that the driver or the future live path passed.

The identifier sweep used `rtk proxy rg -n` across requirements, acceptance,
all four layer specifications, and tasks for nonce, role, ADR 0028, CI topology,
skip_reason, feature_config, change_type, mcp list, and unavailable. Task
:217/:258 retains both nonce contributions, task :119 and infra-spec :3
retain no-new-topology, security-spec :94-95 retains the role requirement.
No contradictory restatement of the six corrected clauses was identified
in that bounded sweep. Security-spec :207 still lists generic signature/nonce
negative cases; the explicit additional role cases are in design item 10.

`rtk proxy git diff --check` completed with exit 0 and no output. This is
whitespace verification only, not formal independent gate approval.

## Reproduced local CLI observations

The following exact read-only commands completed with exit 0:

```text
$ rtk proxy claude --version
2.1.289 (Claude Code)
$ rtk proxy codex --version
codex-cli 0.160.0
$ rtk proxy copilot --version
GitHub Copilot CLI 1.0.91.
Run 'copilot update' to check for updates.
$ rtk proxy gh --version
gh version 2.97.0 (2026-07-31)
https://github.com/cli/cli/releases/tag/v2.97.0
```

`rtk proxy claude mcp --help` also exited 0. Relevant output excerpts:

```text
Usage: claude mcp [options] [command]

Configure and manage MCP servers
```

```text
  get <name>                            Get details about an MCP server.
                                        Unapproved .mcp.json servers are shown
                                        as ⏸ Pending approval and not connected
                                        to; approved servers are health-checked
                                        unless disabled for this project.
```

```text
  list                                  List configured MCP servers. Unapproved
                                        .mcp.json servers are shown as ⏸ Pending
                                        approval and not connected to; approved
                                        servers are health-checked unless
                                        disabled for this project.
```

These establish observed versions and help wording only. They do not establish
a supported version range, complete list grammar, list exit/absence contract,
or a successful install/uninstall observation. No live `claude mcp list` was run.

## Remaining correction and next precheck prerequisites

1. The new design's version/help factual claims should cite this persisted
   evidence by file:line. Its assertion at :1674-1676 that a live list returned
   server-name-prefixed rows on exit 0 requires the prior worker's actual
   observation/evidence, or must be revised to explicitly unverified. A search
   for `server-name-prefixed|claude mcp list|empty-list|six.findings` in
   reports/verification/a8* and the attempt-9 report tree found reviewer/proposal
   discussion only, no persisted live-row observation. Absence of a search hit
   does not prove the observation never occurred.
2. The exact empty-list contract remains explicitly unresolved. Keep affected
   Claude post-uninstall acceptance proof blocked until reviewed same-version
   evidence and parser fixtures establish successful absence. Do not invent
   output grammar or infer absence from failure.
3. Preserve round 1. Next precheck must create a fresh round-2 destination,
   validate prior round contract/reviewer bindings, detect changed design/ADR
   inputs, and derive/hash-bind both ADR 0028 and 0035. Source prerequisites
   were inspected at impl-review-precheck.sh:250, :253-273, :388-489; its
   single-line declaration grammar is at :75-129. Precheck was not executed.
4. Formal re-review, task-stage rebinding, runtime regression, native host
   verification, exact-head CI and delivery remain separate outstanding work.
   This report does not label all six findings resolved or issue a gate verdict.
