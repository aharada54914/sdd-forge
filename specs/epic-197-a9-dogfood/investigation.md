# Investigation: epic-197-a9-dogfood

Investigation-Date: 2026-09-01
Mode: feature (brownfield)
Source: full local captures of GitHub Issue #197 and parent tracking Issue #187,
plus `docs/ai-dlc-foundation-decision-v2.md` §§17,19

## Scope

This read-only investigation maps the repository surfaces needed to specify
sdd-forge's own Project Context and its first developer-tooling / cli-library
Capability Pack. It does not create `sdd/project-context.yaml`, alter a Registry,
or run a review gate. The previously unavailable full issue bodies were supplied
locally and read in full on 2026-09-01. The A9 draft has now been reconciled
against every Scope, Notes, Done, Dependency, and Parent Tracking statement in
Issue #197.

## Authoritative Issue Inputs

- `issue-197-full-body.md`, lines 8-37: complete
  verbatim Issue #197 body, including Scope, Notes, Done conditions, dependency,
  and parent tracking.
- `issue-187-tracking.md`, lines 4-48: complete parent
  tracking body; line 25 lists #197 and line 27 places it after #188-#196.

These local captures are the source of truth for issue content in this
reconciliation. No network retrieval was attempted.

Domain-Sync: `domain-sync skipped: no domain/ directory`

## Findings

| ID | Finding | Relevance | Evidence |
|---|---|---|---|
| INV-001 | The decision names sdd-forge as the first dogfood target and classifies it as developer tooling, CLI, and plugin package, distributed through GitHub Release and multi-runtime installation on Windows, macOS, and Linux for Claude Code, Codex CLI, and Copilot CLI. | Governs component characteristics and Pack triggers. | `docs/ai-dlc-foundation-decision-v2.md:481-489` |
| INV-002 | Epic A9 starts with `legacy-seven-layer` plus `advisory`, then promotes to `facet-hybrid` plus `required`. | Fixes the two lifecycle phases. | `docs/ai-dlc-foundation-decision-v2.md:551-555` |
| INV-003 | A required-to-advisory rollback is policy weakening. With one maintainer it uses first approval plus a 24-hour cooldown; with two or more real registered identities it requires distinct two-party approval. | Makes rollback approval a security/governance boundary. | `docs/adr/0019-approval-sidecar-protection.md:83-94` |
| INV-004 | The Project Context schema requires `schema` and `workflow`; workflow requires `spec_profile`, `artifact_layout`, and `capability_enforcement`. | Defines the live YAML contract. | `contracts/project-context.schema.json:1-20` |
| INV-005 | Component records can carry artifact kinds, runtime classes, OS/architecture targets, seven boolean characteristics (`pii`, `ui`, `auto_update`, `local_persistence`, `long_running`, `replayable`, `human_in_the_loop`), distribution, classification, provider bindings, and include/exclude paths. | Defines the component inventory decision surface. | `contracts/project-context.schema.json:21-65` |
| INV-006 | Shared paths are represented either by a component list or the `cross-cutting` classification. | Defines the ownership exception surface. | `contracts/project-context.schema.json:67-76` |
| INV-007 | The generic starter is explicitly not a live sdd-forge instance; it seeds `full`, `legacy-seven-layer`, `advisory`, an empty component list, and six cross-cutting patterns. | Useful starting point, but copying it would not complete dogfood. | `contracts/project-context.template.yaml:1-30` |
| INV-008 | The current Capability Registry contains one `durable-workflow` capability and one implementation gate; it contains no developer-tooling or cli-library entry. | The first Pack must be added rather than selected from existing content. | `contracts/capability-registry.json:1-67` |
| INV-009 | sdd-forge presents itself as a three-host plugin and documents the human approval transition from Draft tasks. | Confirms consumer surfaces and approval boundary. | `README.md:1-16` |
| INV-010 | Root installers cover macOS/Linux and Windows and register plugins and MCP services into Claude, Codex, and Copilot targets. | Installer/release paths must be owned or shared. | `README.md:148-175` |
| INV-011 | Three MCP servers are documented as read-only; `ci-mcp` alone consumes a read-only GitHub token. | Component characteristics must not flatten distinct credential/data boundaries. | `README.md:108-144` |
| INV-012 | The repository has seven top-level plugin packages: bootstrap, domain, implementation, lite, quality-loop, review-loop, and ship. | Candidate decomposition input; not a binding component decision. | `README.md:250-259`; directories under `plugins/` re-verify before implementation |
| INV-013 | CI has separate test, installer, loop/routing, version-gate, MCP, CLI-hook, and required-check jobs. | Promotion evidence should reuse existing CI topology. | `.github/workflows/test.yml:21,249,327,455,952,1013,1065,1114,1145` |
| INV-014 | Release publication depends on the existing loop gate and grants contents, OIDC, and attestation permissions. | Release paths are security-sensitive and must not be casually assigned. | `.github/workflows/release.yml:26-50` |
| INV-015 | Approval sidecars are protected from agent writes and use external-key HMAC; the canonicalizer, validator, weakening detector, resolver, and generated projection are protected machinery. | Live Context publication and rollback cannot be ordinary agent writes. | `docs/adr/0019-approval-sidecar-protection.md:49-82` |
| INV-016 | The first Pack order is developer-tooling / cli-library, followed by desktop, cloud-service, and durable-workflow. | A9 must not define later Packs. | `docs/ai-dlc-foundation-decision-v2.md:488-492` |
| INV-017 | A1–A8 define the prerequisite Context, Registry, ownership, Manifest, Resolver, Lite, compatibility, and three-environment integration machinery. | A9 implementation requires a fresh dependency readiness check. | `docs/ai-dlc-foundation-decision-v2.md:522-549` |
| INV-018 | The A5 spec exists on `origin/feature/epic-193-a5-capability-resolver` but not in this branch's working tree or Active Spec list. | Readiness cannot be inferred from another ref; implementation must verify merge state and contracts at its own HEAD. | `git ls-tree -r origin/feature/epic-193-a5-capability-resolver`; `AGENTS.md` Active Spec Directories |
| INV-019 | Workflow improvements are stored as numbered `docs/workflow-improvements/WFI-NNN.md` records with human-controlled status. | Dogfood friction must be captured in the established WFI lane, without self-approval. | `docs/workflow-improvements/WFI-045.md:1-31`; `README.md:257-259` |
| INV-020 | The checked-in bootstrap documentation requires Phase 1/2 review separation, but this delegated bootstrap explicitly requests first drafts and forbids review execution. | All authored statuses must remain pending/draft/planned. | `README.md:250-251`; task instruction |
| INV-021 | Issue #197 requires five concrete scope items: a live Context with components/path ownership/characteristics; Phase 1 legacy/advisory; Phase 2 facet-hybrid/required; the first developer-tooling / cli-library Pack; and dogfood-friction WFI capture. | Supplies the complete issue-scope reconciliation oracle. | `issue-197-full-body.md:12-18` |
| INV-022 | Issue #197's Done conditions require every sdd-forge PR to pass the advisory capability-mode Gate for one full release cycle, at least one feature to finish end-to-end under facet-hybrid after required promotion, and a friction WFI result that records `none` when zero. | Strengthens the earlier representative-run and no-WFI wording. | `issue-197-full-body.md:25-29` |
| INV-023 | Issue #197 assumes `specs/`-type growing paths were registered cross-cutting at bootstrap under A3. | Makes cross-cutting registration an explicit bootstrap prerequisite and acceptance check. | `issue-197-full-body.md:20-23` |
| INV-024 | Issue #197 depends on every Epic A1-A8 and is tracked by #187; #187 lists #197 last in the A0-A9 sequence. | Fixes dependency and parent provenance. | `issue-197-full-body.md:31-37`; `issue-187-tracking.md:14-27` |
| INV-025 | Issue #197 fixes the first Pack selection and priority as developer-tooling / cli-library, but does not define its internal capability count, predicates, facets, checks, gates, Lite policy, minimum enforcement, or delivery shape. | Resolves OQ-005 while preserving the genuinely open internal design as OQ-006. | `issue-197-full-body.md:17` |

## Candidate Decomposition (Non-binding)

The repository supports at least three plausible models: one component per
plugin/MCP service; capability-oriented groups (authoring, implementation,
quality, distribution); or a smaller hybrid with plugin packages, MCP services,
and distribution/tooling. The human must choose in OQ-001. Any proposed include,
exclude, or shared rule is likewise provisional until OQ-002 is resolved.

## Risks

- A component map that mirrors directories too literally may obscure shared
  release and guard policy.
- A broad cross-cutting rule may suppress meaningful unowned-path findings.
- Promotion criteria that only say “tests pass” could permit enforcement before
  resolver output and rollback evidence are reviewable.
- Treating a policy-weakening rollback as an ordinary YAML edit would bypass the
  accepted approval-sidecar model.

## Issue-Reconciliation Result

The prior limitation that the full Issue #197 body had to be reconciled before
spec review is discharged. Reconciliation added explicit full-release-cycle,
post-promotion end-to-end, zero-friction `none`, A3 cross-cutting-bootstrap, and
#187 provenance criteria. Issue #197 line 17 also resolved OQ-005's Pack choice
and priority; the issue does not settle the Pack's internal encoding.

## Historical Open-Question Carryforward — Superseded 2026-09-26

The preceding carry-forward list was accurate only when this investigation was
first drafted. It is superseded for current Phase-1 review by the resolved
normative decisions in `requirements.md`: OQ-001/OQ-002 (2026-09-02, amended
2026-09-08), OQ-003/OQ-004 (2026-09-02), OQ-005 (`issue-197-full-body.md:17`),
and OQ-006 (2026-09-02, with the dated current-tree clarification there).
Those requirements govern; this historical paragraph does not state that the
questions remain open. The frozen sibling `design.md` and `security-spec.md`
retain earlier open-question framing and are not edited here; for component,
ownership, promotion, rollback, and Pack decisions, the dated resolutions in
`requirements.md` supersede those stale statements for the next Phase-1 review
and must be rebound before any later gate.

## Current-tree classification reconciliation (2026-09-26)

The schema provides optional string-array fields rather than controlled
classification vocabularies for artifact, runtime, distribution, and data;
platform entries require both `os` and `architecture`, and the seven
characteristic keys are exactly those listed in INV-005
(`contracts/project-context.schema.json:21-65`). The decision's OS list is
product-wide, not a per-component architecture matrix
(`docs/ai-dlc-foundation-decision-v2.md:483-489`). ADR-0018 keeps provider
details in separate binding records and the Context uses IDs only; no approved
A9 binding IDs are present (`docs/adr/0018-provider-binding-separation.md:49-78`).
The requirements' dated A9 classification table is a proposed classification
policy using only these facts; omitted optional values mean unasserted, not
false and not absence of sensitive content.

The A2 Registry currently has only `durable-workflow`, and A2 specifies
capability/gate records plus fragment selection by ID for A5; no Pack record
or developer-tooling/cli-library entries exist
(`contracts/capability-registry.json:1-67`;
`contracts/capability-registry.schema.json:5-19,40-76`;
`specs/epic-190-a2-capability-registry/requirements.md:311-318`). The dated
OQ-006 clarification in requirements preserves the 2026-09-02 approval while
stating that A9 adds the two approved capabilities under the existing schema
and composes them through A5's capability-ID fragment-selection mechanism; it
does not invent a Pack schema.

The release-write override uses the already-approved `.github/**` cross-cutting
rule from OQ-002 (`requirements.md:445-462`) and targets the tracked release
workflow `.github/workflows/release.yml` (`.github/workflows/release.yml:10-28`);
no additional ownership rule is introduced. OQ-004's two historical registry
branches are augmented only by the fail-closed zero-identity case, tested
separately; the existing HMAC-protected approval sidecar and Ed25519-signed
rollback proof remain distinct mechanisms
(`docs/adr/0019-approval-sidecar-protection.md:83-94`;
`docs/adr/0028-live-host-proof-ed25519-signing.md:56-99`).

## Amendment Re-Review Context

Amendment snapshot commit: `40684ed6dafe987f751f1c054a8318cff8af7f09`.
The following SHA-256 values identify the three amended documents **at that
commit**, before this declaration was appended. They are not claims about
the self-containing current investigation hash; the next review manifest
binds its actual current bytes separately.

| Document at the amendment commit | SHA-256 |
|---|---|
| `specs/epic-197-a9-dogfood/requirements.md` | `49af2cb252bfb92013abf20d1087df72b0019ca1526cbb5898c4754e1f6d8834` |
| `specs/epic-197-a9-dogfood/acceptance-tests.md` | `4905f3c5a542fdbd9cc84827236848f6a29cbc06af4f6cce578b46e268cbbf9e` |
| `specs/epic-197-a9-dogfood/investigation.md` | `1bc941111128aa95739924a5bfe30df17cab9ec2d1d9a0f85a906e8f8329b2af` |

Human approvals, quoted verbatim from the originating conversation (UTC):

- 2026-09-08T01:03:10.532Z: 「A9 を進めるため、plugins/domain/** を独立した「9番目のコンポーネント」として扱う設計変更を承認」
- 2026-09-09T12:09:41.400Z: 「その他の設計変更も承認する」
- 2026-09-09T12:24:26.062Z:

  > そのほかの作業についても承認を求めなくてよい
  > 人間がターミナルで実行しなければいけないコマンド以外は全て君の判断で実装せよ

The first statement authorizes the ninth-component amendment; its historical
path spelling is reconciled by OQ-001. The later statements authorize the
additional bounded specification repairs, not a fabricated task approval,
review verdict, or claim of successful implementation. This declaration is
the durable conversation-approval record once committed and review-pinned.

Later-phase and historical artifacts cited by this package are pinned below.
Every entry is a file **at commit
`40684ed6dafe987f751f1c054a8318cff8af7f09`**, not an unqualified live-path
reference. The pins disclose history; they do not certify current acceptance
or unlock a later phase.

| Referenced artifact at the pinned commit | Reason for reference |
|---|---|
| `specs/epic-197-a9-dogfood/design.md` | Historical A9 design; resolved Phase-1 decisions supersede its stale OQ framing. |
| `specs/epic-197-a9-dogfood/security-spec.md` | Historical A9 security layer; same precedence. |
| `specs/epic-197-a9-dogfood/traceability.md` | Existing A9 traceability, not new completion evidence. |
| `specs/epic-190-a2-capability-registry/requirements.md` | Existing A2 fragment-selection contract cited by OQ-006. |
| `specs/epic-190-a2-capability-registry/design.md` | Existing A2 schema/composition design cited by OQ-006. |
| `specs/epic-195-a7-compatibility/tasks.md` | Historical T-010 cross-task suite observation in OQ-002. |
| `specs/epic-196-a8-integration/tasks.md` | Historical T-005 signing scope cited by OQ-004. |
| `reports/implementation/epic-196-a8-integration/T-005.md` | Historical signing implementation, not a fresh A8 verification claim. |
| `docs/workflow-improvements/WFI-047.md` | Transferred future backlog, explicitly outside this REQ/AC set. |
| `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` | Existing signing-key consumer supporting the classification inventory. |

The amendment remains pending independent specification review. Historical
reviews and later-phase artifacts are preserved; subsequent gates must bind
the amended inputs rather than inherit historical PASS results.
