# Implementation Report: T-008

- Task ID: T-008
- Model: openai/gpt-6-astra
- Effort: medium

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration T-008, release integration repair RT-20261018-900 and caller-supplied supplemental CI failures only. AC-013/014, TEST-013/014.

Run ID: 01a1505e-4688-71b3-9816-af65b714a220
Task Attempt Count: 2
spec_revision: `5cd2db84e3fc959fc576bcd7b0c1083eb12c03bd2e4d454a8d1082390b07ae83` (sorted eight-file path/TAB/hash/LF algorithm in spec-revision.json).
Entry revision: `3017aca56ca3b96ad3cbbc8217f949bedba2d1a7`.
Input manifest: `specs/cloud-orchestration/verification/T-008/attempt-2/task-input-manifest.json`, SHA-256 `f67a0f0fce8369a79f5fc0f2720335ea51eba1bc034fb70944ef7d6c0c8848de`
Supplemental manifests: `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-task-input-manifest.json` , `specs/cloud-orchestration/verification/T-008/attempt-2/host-supplement-task-input-manifest.json`, `specs/cloud-orchestration/verification/T-008/attempt-2/host-complete-task-input-manifest.json` and `specs/cloud-orchestration/verification/T-008/attempt-2/classification-task-input-manifest.json`; preserved separately and validated against the initial snapshots in the declared scratch root. Snapshot prefixes map back to exact source paths; input-snapshot-map.json documents initial inputs.


## Summary

Acceptance-first, medium risk: integrate observed release failures, not a retroactive Red claim. No new cloud authority, persisted cloud contract or high-risk implementation is introduced; WFI-001 committed-Red does not apply. No development commit was created; existing regressions create disposable fixture commits/tags only. Frozen canonical report SHA-256 remains `a1efa08a83d5a603790916675d44a74488e557c1502b39afe2db72f4ee6ee195`.

Workflow-level Git runtime configuration precedes every checkout and propagates to nested fixtures. Twelve IDs become unused numeric 901–912 with exact historical aliases and unchanged paths/other fields. Two release guide fragments are corrected. Caller-authorized supplements update current registry-driven model assertions and the unactivated A9 cloud inventory. All final release/status/review decisions remain root-owned.

## Files Changed

See changed-files.json for task-owned before/after hashes. The Outputs table also binds unchanged test dependencies/evidence; inclusion is not a claim they were changed. Product/config changes are limited to test.yml, twelve ticket_id lines, two runbook links, exact A9 candidate inventory/validator, and existing model/A9/host consistency tests. Python typing fixes narrow module-loader optionals, distinguish workflow/classification variables and accurately describe release fixtures; no blanket suppressions or import suppression. No version bump, parser/schema relaxation, production guard changes, frozen spec/report edits, task status or approval changes.

## Tests Added Or Updated

Existing agent-model-routing tests retain all availability/tier/effort/fallback controls and add actual registered gpt-6-astra strong/high evaluator selection through Bash and PowerShell. Existing A9 tests retain nine original components and exercise eleven-component completeness, missing components, classification/ownership mutations, exact bounded templates ownership and unknown roots. Host test keeps the immutable unrelated baseline and explicit addition mutation checks. Task-local check-repair.mjs verifies parsed YAML semantic preservation, actual nested Git configuration visibility, ticket uniqueness/ID-only edits, and actual current heading/file links. check-preservation.mjs checks original A9 records, absence of live activation, and canonical report bytes.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `.github/workflows/test.yml` | `ef3e4de5d23ce794bc434766055e3c975c414a4834ff394026b523ae1ffe086d` |
| `AGENTS.md` | `be21577343b8b2cc488c47b373ed68130ded00d994f58f1f81b7b69bddd6d537` |
| `contracts/adversarial-review-evaluation.v1.schema.json` | `79a3f7b75996474d318535dab04fd284706f2008ef7592fe66992e3dc39d054f` |
| `contracts/adversarial-review-report.v1.schema.json` | `3dd9bbb8cfd475444b4662abddedc86b9088d419323e4bfeb34b663a8353fb1a` |
| `contracts/agent-model-capabilities.json` | `b5a4bd4b156cfbc5f51bedf98c13e0ac3e4d237f1a00c1f79ae4c595b9f444b1` |
| `contracts/agent-model-capabilities.v2.json` | `847fe86588ea22dcb0a13b7b61548aa254f22a8244aa5153e63efefe8a4d200e` |
| `contracts/agent-model-capabilities.v2.md` | `0ff9fb9dbe404b83d022e8ab5bf3ea717e35008c175c96c408dafa9db6d5ebb6` |
| `contracts/approval-sidecar.schema.json` | `f205da8f1103fc2ac876e7fbff4dc6f89db4146325e65aadc15d139ffa4265e3` |
| `contracts/approver-registry.schema.json` | `47c1c3e0eddfca0a6abbf22db2fd4b8d633e2bdc9362044ec3c903c82d85e94e` |
| `contracts/capability-registry.json` | `dfc1b948bb085d3c86f1f7958b9564c1cb6cf6240ce9d57551656fffc2f15c75` |
| `contracts/capability-registry.schema.json` | `ef70a27785d325cc32d2c4a2faeed099e9df3058fd7a918e2efbd4013ed8f319` |
| `contracts/capability-summary.schema.json` | `09d4ace8cc599b4ef7632aaa09c7477e765bcfa69943f2231f8870aac4cbc42f` |
| `contracts/ci-mcp-tools.v1.schema.json` | `7e2cc1d88a07ab4e62c4088d0cc0c2d0b0b49972b23cbc95d70debd3449ec357` |
| `contracts/cloud-authorization-receipt.schema.json` | `5c4f8efaaf458aba6f149a53967df7615eaf2a823c4ec6f75e44610a4c8ac8b8` |
| `contracts/cloud-check-result.schema.json` | `992b8f4d530d4aab0fe5bca1a28b459a6c9cd9bec7e6ed68b648f489127617c0` |
| `contracts/cloud-collection-context.schema.json` | `7706241bf1a949a64b18212ba09bd8a4aa66896df668084056ee6979fdb84272` |
| `contracts/cloud-dependency-lock.schema.json` | `e72395e755f13bff50f8f10d27a8181fcfa1894ef6c60499c01f84d4c2128cec` |
| `contracts/cloud-deployment-policy.schema.json` | `a064217e4a68838a3d719749fb751ba63ffabb2094d16cf13090afeaed080eb8` |
| `contracts/cloud-input-error.schema.json` | `d228ad47ea2c899022169a704c9408f6b5fee285be5be12ad3f0906bd2b4bc77` |
| `contracts/cloud-observation-evidence.schema.json` | `0d0dfccf3bd5982a2948a9db75fd459197b6bb683f19a993b5bfdce72df1d99e` |
| `contracts/cloud-observation.schema.json` | `5ce80d6fb77fde9bc966d00db75c2650f3a37166fcccfd1071f087208191c826` |
| `contracts/cloud-operation-result.schema.json` | `a92bdac86499052256112babe5ff559c2e071adba411f4a2e92ec38b6b5b2aa6` |
| `contracts/cloud-ownership.schema.json` | `71079e7320c968bce57fba67bd105d59ab57c00a51165a3598d522919141f25d` |
| `contracts/cloud-preview.schema.json` | `12afaf962e1bf1325496d985b21ffc5c970c1e2d14fc43933c5ad8aa8940eb99` |
| `contracts/cloud-run-request.schema.json` | `781d83fad3d8e883e2c4aa886c5356da12f93d5ef5e35f16a5d83e9c024c9d81` |
| `contracts/cloud-verification-profile.schema.json` | `b25112c7e73583b180941639cb8f137a89fcb7daa82b1afd7ec8eec66c9353bf` |
| `contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `contracts/cloud-verification.schema.json` | `dcfd0760733951080efc1f0cb993bfc46a081b4eff4a82bd07968f868b2f3f2e` |
| `contracts/concept-test.v1.schema.json` | `7b0bc534b1f0b819a19e5a70c0e3d39f35e3d5f6747e53086bb9c1dbbb810c71` |
| `contracts/context-projection.schema.json` | `3c8e39c6a8dedf948cbd7e6a8f36369f2a68a3fc3dd92192f90bbce917d32643` |
| `contracts/cross-critique.v1.schema.json` | `8c72c37907036cf00d1d8d341199d4d3502fabd57db1c60d0205926e23135991` |
| `contracts/design-system.contract.v1.schema.json` | `3b8d541218fda8e794350b8a545d6bcb3a85733f2e0ee00089eb49f7de3d1db1` |
| `contracts/domain-contract.v1.schema.json` | `0ab46b74c1e2561431b42b76106698339e79cd64ce0513b02aec5527b8b73841` |
| `contracts/domain-contract.v2.schema.json` | `ad69c28f323e5c2f83e07b78c4f14461b4f7152193a9021c0a12c3e0285aba16` |
| `contracts/domain-review-contract.v1.schema.json` | `b86f234e76f66887384284fed08ec3b5d951df3bcc7cc5722e9ed18489edfb35` |
| `contracts/facet-manifest.schema.json` | `81d4f1621923133e55875621ba81b30ad9d21688d9442c5a371fc1023b4a4c51` |
| `contracts/lite-check-catalog.json` | `c251b3e02a2c93c45a7ea590bc5a7e36eef8e5915c485b0c6a6e83519afe086a` |
| `contracts/lite-check-catalog.schema.json` | `a4e458242d68237cf16e66aa28b362c30dae4a6d20109cb4af51711f6fc1cd19` |
| `contracts/lite-upgrade-reason-catalog.json` | `e73a730f9edacd7d2dad2da3e13b9e3df01f7002c25f7e947316ca249118eb76` |
| `contracts/local-env-mcp-tools.v1.schema.json` | `f1f81d484cd13b62c64b4802195efd6d50edb1ccedcd489626f699f6cac4ae1d` |
| `contracts/project-context.schema.json` | `a6a86903e8126ecc0d587499f75c7222aee0eb0f442a51b39fa8ff852829592e` |
| `contracts/project-context.template.yaml` | `afb8ae3ae563887e4f6383effe2873e4dbf164601f8b218fe6105810b1c57fd3` |
| `contracts/provider-bindings.schema.json` | `7adfa236d2bb00055bd38f3fc6b7664f6d41e88989e9aedba1c0a9c5d55f8cd7` |
| `contracts/resolver-evidence.schema.json` | `0f37f39a8b45beff2cb53230568adeaa26ca4cc18683816f9331c0dbb38e92f3` |
| `contracts/review-contract.v1.schema.json` | `d1bf67c20a8b1229f5550ba6deab339962236a626d5a9aac84e847dc7727597a` |
| `contracts/rollback-1.5.0.json` | `64d5646d56c7d3836eba8734cb1e7d1aa64cd0effb82b0bad8bb7616d37c2197` |
| `contracts/sdd-forge-mcp-tools.v1.schema.json` | `055b04cf07b3a348880bcd253a54bddd0250fe86141550168469d812134e4b78` |
| `contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `contracts/selected-verification-plan.schema.json` | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `contracts/terminal-tier-blocked-state.schema.json` | `bcf0d1b969fb917b656b0d25e24dcb34021378cc2639bb4b30198c3ccb722dc5` |
| `contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `contracts/workflow-state-registry.schema.json` | `bee4972d7d4d4ae8116ac0115d16295d1f167333edffd5a08d9dc8ceea3c31d7` |
| `docs/adr/0003-turn-first-agent-routing.md` | `e96a895108ca8919073b722180b3c09e695bdf8f1ea558f099616348d95048df` |
| `docs/agent-capability-matrix.md` | `097ee2d4bf93ccb6a880d0aa2e7ece4a02663f965b4367d2a9ed50a8f8ffcea1` |
| `docs/contributor/release-runbook.md` | `0a5ff56974a9003c4f65be874f8b3b81016fd9d45456119a8efe02fb5c101a51` |
| `docs/review-tickets/RT-20261018-CLOUD-ALARM-NUMERIC.yml` | `dba3c956b9add51145ac176c71e253bde10c4f3c8c51f12b49baf1fe708f38af` |
| `docs/review-tickets/RT-20261018-CLOUD-BOOTSTRAP-PATH-TESTS.yml` | `4c26485003d1df3b49215bbf0cda1fd870c374b27fce4c7671eb53204ee40e78` |
| `docs/review-tickets/RT-20261018-CLOUD-CONTRACT.yml` | `9d3844242c7f6c120eb57a1f44eb66b6abdf97c7b228f9de79d12dfa5783221c` |
| `docs/review-tickets/RT-20261018-CLOUD-DEPENDENCY-EXPIRY.yml` | `4f3c6c2d52bcca417d9445cdf650f16d29c28288255336ad758388c21ba561b2` |
| `docs/review-tickets/RT-20261018-CLOUD-EXPIRY.yml` | `c6a7e4a16d9f214e286d6cdb3cf978474b6ecb24ad0f7e6c17313563f7e61673` |
| `docs/review-tickets/RT-20261018-CLOUD-INSTALL-SELECTION-RUNTIME.yml` | `e9a6c58ca6d10fa13a7690b1a99a36c8d4969a2daf41e477ba467cc4889dc09a` |
| `docs/review-tickets/RT-20261018-CLOUD-OWNER.yml` | `468cf843fd5b0bde2efaa79797a83fcaaaeee408a3f39bc3d1615bb89a3cdef2` |
| `docs/review-tickets/RT-20261018-CLOUD-PREFLIGHT.yml` | `340593cbb2620fbe8611ae8702792b9897b247d22e3d5bad849a1fc73e603489` |
| `docs/review-tickets/RT-20261018-CLOUD-PREVIEW-EXPIRY.yml` | `0322d78d83592a1b1a4e2c405daa3ce1552c7113c1e5b6e98ac7e9ac97e84858` |
| `docs/review-tickets/RT-20261018-CLOUD-ROUTING-GUARD.yml` | `610c48275597834307912ae2d89113adba18f5df9cb5bb3ec7430346a346a017` |
| `docs/review-tickets/RT-20261018-CLOUD-SANDBOX.yml` | `4fc66f7a3a83183f7edd966ba51a86008a16cbb186f59c193adf9246fca03e13` |
| `docs/review-tickets/RT-20261018-CLOUD-T009-PREFLIGHT.yml` | `7fb4b1fa6c2a20a4b4c3d7f77979cd71df0a15856412f46f53c4c82de3cb9642` |
| `mcp/sdd-forge-mcp/.gitignore` | `f62ff394250ef785348e959cfa2e4fe22c1fe2efae8b45396c14849b922293e8` |
| `mcp/sdd-forge-mcp/dist/index.js` | `7ec12198da5ece99627ee80323196bc875e0f1bfb7dba0eadd62813cf90d6d96` |
| `mcp/sdd-forge-mcp/package-lock.json` | `2073331df48c2e05d7547aee4bde63a291c3940c5ece5bbb363a186b127c1608` |
| `mcp/sdd-forge-mcp/package.json` | `fdb9147028ded12a7470dcbb989390d669566f0f976151ecc5bc331311e07361` |
| `mcp/sdd-forge-mcp/scripts/check-adversarial-report.mjs` | `edc7fa7bb43ead51a037e5f0276ace1d0c57de3954dec87375709d8737a90eb1` |
| `mcp/sdd-forge-mcp/scripts/check-cross-critique.mjs` | `d3d1ee9c580e4f9c5c1fe1c00725b562ad4f06c1382f7dfb3630b97b3bce7e1c` |
| `mcp/sdd-forge-mcp/scripts/record-golden-fixtures.ts` | `c467a1afa9cad170cc032eb50bc693a7e78d1c0a0c7068145b0d8846cb6bc290` |
| `mcp/sdd-forge-mcp/scripts/run-tests.mjs` | `0ae887bcfa5501bfc8d83b2a13572657a6d5874a7ff9e3da2905efb459d1b87b` |
| `mcp/sdd-forge-mcp/src/envelope.ts` | `756e7944925eda2b5fcd0750c033c3357cd3d37c511814d72fa9c6c7d96ce724` |
| `mcp/sdd-forge-mcp/src/index.ts` | `74bae1592882324891025b89730309ff71404d299af1c9829e88c4affeb7fe17` |
| `mcp/sdd-forge-mcp/src/next-command.ts` | `d12471cc16bef2cbc5bb3cd403f57c0fc1b8bef061ea13b5d60077df6dd78792` |
| `mcp/sdd-forge-mcp/src/parsers/agents-md.ts` | `8f7b29faa03981df3b5b73506938dd152a041ddb9fa0d1f03eb5f85b2262df97` |
| `mcp/sdd-forge-mcp/src/parsers/evidence-bundle.ts` | `dfb6672378ab07fe23db8365a5da593bc14624140f152726449eea7cd8a5ed57` |
| `mcp/sdd-forge-mcp/src/parsers/evidence.ts` | `1df7e57aee4f05f6996b82673519fe408c0131cd0848964bc83e4cb968c86d8b` |
| `mcp/sdd-forge-mcp/src/parsers/json-object.ts` | `c25c0a36a544721c424d1c53bd763ed0090399afed72a3c644407c2e1ac9dc5e` |
| `mcp/sdd-forge-mcp/src/parsers/quality-report.ts` | `39cfa446a855b117b2b9bf6deafe72f6a5ed69d1864c05a92cd3eaf0d26e38b0` |
| `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts` | `ea0448f5ae4d62350d7737824620e9ad51fc32204a06b6346e56ea27dc59cd14` |
| `mcp/sdd-forge-mcp/src/parsers/review-ticket.ts` | `7a7eb443774ca23d9b098ee5e02d018196d9feda9e22246062cb411ce696bfbe` |
| `mcp/sdd-forge-mcp/src/parsers/spec-header.ts` | `b9347e127e479727eb296bb22072a96f6f9be4c066f15312e041aec62ac166c4` |
| `mcp/sdd-forge-mcp/src/parsers/task-types.ts` | `b7a71c2f754507a54b7e57bab247172c1890e8abf0ff4ca223a1888553f8f1e3` |
| `mcp/sdd-forge-mcp/src/parsers/task-validation.ts` | `e9c45eac1158ae2cfd4f6918826754b189a0dcaac91ae5f7b05d3ce408ee8e1c` |
| `mcp/sdd-forge-mcp/src/parsers/tasks.ts` | `75da89565748dda07fc3f808e549793aad2ababe34a1ff4d5d2640083b505c7d` |
| `mcp/sdd-forge-mcp/src/parsers/traceability.ts` | `5a64e2b2d30aa1ed88c4ca7b84c4ead9165229a6b47dcab977e0890dd8a1fab8` |
| `mcp/sdd-forge-mcp/src/path-guard.ts` | `6cc067c34027ff7b98d7114a230ca397e953da4bb18ca6a8ab83b1292121cc09` |
| `mcp/sdd-forge-mcp/src/resources.ts` | `722e2b0b84cf9e486c155ba9c67b8b671df8eead33ebd33e3eed71a0dc133934` |
| `mcp/sdd-forge-mcp/src/root.ts` | `de472c935b26c3a83a9554e9755200517b3b3d13d1645abe946bbe66ef367d53` |
| `mcp/sdd-forge-mcp/src/server.ts` | `ad3fe5db0a58cb2336587595f1b2ee2d30d0b4e9f49b72dbc5d8480b0ea45182` |
| `mcp/sdd-forge-mcp/src/tools/core.ts` | `dc6806218200911a10e82895177d2e936d2a7bf34df965ab86c25df3786b98db` |
| `mcp/sdd-forge-mcp/src/tools/evidence.ts` | `18b51a88ada5ebd4a5a72725058338162a54737674a9e8e1b2c5ba04f2f929e2` |
| `mcp/sdd-forge-mcp/tests/adversarial-report-current.test.ts` | `ad7f95ca97081f1728b25a6e3a38e75cb0a4238f2c30061ee27abedaf5b6a3bf` |
| `mcp/sdd-forge-mcp/tests/core-tools/core-tools.test.ts` | `98f5ba17bec8c5c1514b035d6d6ff876bece4a04859e793495b1868d95141e1b` |
| `mcp/sdd-forge-mcp/tests/core-tools/test-helpers.ts` | `f95e5564d98c33a939dd2ba592f6bec144824090d405d2473a50f990e963eece` |
| `mcp/sdd-forge-mcp/tests/cross-critique-contract.test.ts` | `53a2f663cc4b5b188e2f5bf10c18dd8f1ac30e212c1a9c82390012dc898c66c1` |
| `mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts` | `da34a3fe0d277fc38fff2501aa176a0b9cb1b79d790655badaae8691dc34cca9` |
| `mcp/sdd-forge-mcp/tests/error-paths/too-large-and-not-sdd-root.test.ts` | `ad691f83b6f1ddb4382d4a0cd1e91139a1ad0d660d247c0d249d2e352f3874b2` |
| `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts` | `baded100003098481f02e13fbef6869409f0da6091f93ce9d1fbf19cc3fab1ce` |
| `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts` | `88c580105aa78f04f6aca17ff400ba7b31f4ca0d3b7a53f1e9e905aa0c04d112` |
| `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity-helpers.ts` | `d7a239faf7a9cdc1c8412977d6f068503541ab56a784a1fabe664ce602b81c6c` |
| `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts` | `439b727c9612411cf4ddfc7424216b1cde8983346f0d17d47e7ce75f2a23dbcb` |
| `mcp/sdd-forge-mcp/tests/golden/environment-dependence.test.ts` | `233032beb6496589799c8a9cf3d925db3d29d427fb8e57a7e6f5e8abad5feb36` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/bootstrap-interviewer-enhancement.expected.json` | `a267e594217e4f479d1abeac352d2a273c23704a94ea76caada11b688ea65402` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/ci-mcp.expected.json` | `727ca4bf247915fd4b6b5d9202b3d0aba148e695ea5b313d5d63c033ff8ee4eb` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/claude-workflow-compatibility.expected.json` | `00e3ecc9406f82b0f0a2e6e35808fa7c52c028786a55462ea4e5ab4e9c6c9886` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/cross-model-verification.expected.json` | `fca87351f9f95237cd7f32b5b401a8b174aa76671d4f9b917519b2d4e05f6743` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/evidence-deep-verify.expected.json` | `8120b67fa2a5c7e30a7de04fff494dc33839d6f3649e052c375931a154921b11` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/risk-adaptive-layer.expected.json` | `c18712794362e2049a306623b0b06337b2a6b1830c3acecd974d1731e2823530` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/sdd-forge-refactor.expected.json` | `b7078459625ee6380f9af4c85307b103909cb2169d7d566157d4b038b22dafe8` |
| `mcp/sdd-forge-mcp/tests/golden/fixtures/sdd-lite.expected.json` | `03f18878205f29f8023e1238fba6b07d385071a3b7e5ae55a63865cf8081eb87` |
| `mcp/sdd-forge-mcp/tests/golden/shell-runner.ts` | `a5c1f8a86bb5731499b9ad657631aa7d56fff962f6125db6db252b13aabdb814` |
| `mcp/sdd-forge-mcp/tests/golden/task-state-golden.test.ts` | `33c81df3a28b3894fc1d74205be694de7ab69d2fabbb423e28c5036fbc5bd5ed` |
| `mcp/sdd-forge-mcp/tests/next-command/next-command.test.ts` | `90818dba882b683a67308db4105f2529c2c810ee4411421673223d1a867ad61b` |
| `mcp/sdd-forge-mcp/tests/next-command/test-helpers.ts` | `90743ab6aff20706819c2ff99b86a0145c2fcc5abf5aa610d0314e8b71fe7a47` |
| `mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts` | `c6809e0e5ec30e39fd647b1a7346b06a06a6a7a4d6cf23e6b747bb39697252a0` |
| `mcp/sdd-forge-mcp/tests/parser/baseline-and-io.test.ts` | `6284ea4eef221c133bbc53f51ec075da8190b6ad8b6a62505f0d6369d9613596` |
| `mcp/sdd-forge-mcp/tests/parser/done-state.test.ts` | `b7bb6cfcb1566545262845cf0a71466f152256a48632a035fa719e508c610e0f` |
| `mcp/sdd-forge-mcp/tests/parser/evidence-bundle.test.ts` | `c6c77373b81bbfa81455ab0e708141d5910d30cd77637e4a7c42068623678843` |
| `mcp/sdd-forge-mcp/tests/parser/field-validation.test.ts` | `a60a47e217da46648c54191a523e62d90226e2048411b0900612c483213a27e2` |
| `mcp/sdd-forge-mcp/tests/parser/test-helpers.ts` | `d996c54a727ef3a68b830f7cf944c10b4c8275f2cf65442f02064d18243bc0f4` |
| `mcp/sdd-forge-mcp/tests/parsers-evidence/evidence.test.ts` | `d75d6cfa2d0264a2ce236fc3d3f73f2f8e53607fd901e99003f784bde53ce435` |
| `mcp/sdd-forge-mcp/tests/parsers-evidence/test-helpers.ts` | `e4df3a7c97a388865da6f38c168d68a3d5dfd4904eea462bef42880fac5f5af6` |
| `mcp/sdd-forge-mcp/tests/parsers-evidence/traceability.test.ts` | `557d9a7b2536cde282d9e6f1a5dc4f5b1fc893ccb80927b3c3b91bf4e1f354f2` |
| `mcp/sdd-forge-mcp/tests/parsers-state/agents-md.test.ts` | `aa27881e926cc0e8c91fede5f06fb78675579ee96e1ef775c7611bd5f6a69ebd` |
| `mcp/sdd-forge-mcp/tests/parsers-state/quality-report.test.ts` | `30f6407e975c15793dd15ae4a19a80698e8933ce95898d45e39d8ff7aa5e7435` |
| `mcp/sdd-forge-mcp/tests/parsers-state/review-ticket.test.ts` | `607e1695a7dc1a66269b4a19438ecfdc92cf87800c503cedd6d7aba54b0f1eae` |
| `mcp/sdd-forge-mcp/tests/parsers-state/test-helpers.ts` | `8a5e444b335d696a3681475465c4ffb8758c581cafc7a15e5027d6131d467358` |
| `mcp/sdd-forge-mcp/tests/path-security/denylist.test.ts` | `f8e201180644754c22d7101d80f72e2a0273dd6557d785676fe765d4a60ac140` |
| `mcp/sdd-forge-mcp/tests/path-security/denylisted-ancestor.test.ts` | `4b9f75b761f5e8bce06f37927389c619d5e6e32472984e1a4c4119b55e49b8bc` |
| `mcp/sdd-forge-mcp/tests/path-security/list-guarded-files-diagnostics.test.ts` | `fcdd79f9520401d07b0ad56649509383d1f00c4c881b7e94d2277c8de705b4b9` |
| `mcp/sdd-forge-mcp/tests/path-security/traversal-and-symlink.test.ts` | `cc068165d3a56ae35e319f652a2e6a41289f11b874b241a6df2c591fef5b5343` |
| `mcp/sdd-forge-mcp/tests/readonly/core-tools-snapshot.test.ts` | `87cc8bab9cc9b6f6fc2131118ee11d71bc70318e5f1d3373d7e6f8f077f549dd` |
| `mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts` | `41398c794f5170c0520562a597174ec77740a715ce0735adbe3b8c634fa26aec` |
| `mcp/sdd-forge-mcp/tests/readonly/static-check.test.ts` | `033d833b94ae820615851bd821c4acdca6be9bade9791be25d68d57035ef3b1d` |
| `mcp/sdd-forge-mcp/tests/resources/resources.test.ts` | `2243fa32b38f37b054f1e2136db516498db9e4efcad0b19f3487df036403b54b` |
| `mcp/sdd-forge-mcp/tests/resources/test-helpers.ts` | `ba982a9cdf42b95aef8fd8a8eff1fac0b9e2448a929f14bdd0fe1a91c11933a9` |
| `mcp/sdd-forge-mcp/tests/root-immutable/root-immutable.test.ts` | `3c8903ca0f2d3fb53d2a7d7f294e341185a521247aad9e9de4cdb034916635ad` |
| `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts` | `8dd6c9ef06b0e15ec063ab38b8b12aa356823b14dcc8778400a48d6a8fd47a7a` |
| `mcp/sdd-forge-mcp/tests/test-helpers.ts` | `ae81930daf647a9f126698150e5545bc74cd5630851c339b951fa2d4e3654470` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts` | `d8aa7bbbba90796db6fa83748e1d505d895dae58cc9b6cc2df5e93ed45ededef` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts` | `6fe545a06c85d790713f7dee6d9d26b8836c2e3e334f2b678c3a2601cb3d7d2c` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts` | `70dbe855ea99ff6afe7f66e0390d632123e459bce01d44e8db1440f67a4990eb` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts` | `0fcff6c24403358a4a960e31d23de7ddac379f71111a55abef284f0cf8a5f6b9` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts` | `9ca65ab14b9d50b1613223c2c3a36e3930a563ee94e9dcd4301d7bb5e1e63daf` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts` | `75293ee2eb25f5a3ef2842424503b13004f6b2cfaf69a1589282563b1189bde9` |
| `mcp/sdd-forge-mcp/tests/tools/evidence-shape-boundaries.test.ts` | `579d15b3c26ddf9c72332f785bd8ec43c9d79e48b4b774ee04b674d45276f9d3` |
| `mcp/sdd-forge-mcp/tsconfig.json` | `58ad1654c10d1c5f263c428d083263dd2001dd960a75d74a971225d44cb08c67` |
| `mcp/sdd-forge-mcp/tsconfig.test.json` | `1b0a03e8923981d7bbce5fd5d98aea907ea3215630de18deb7f906667c0b1201` |
| `plugins/sdd-bootstrap/agents/investigator.md` | `cf1e6b4bd3cbbb6a3dc767413443677c12a70b9faf2e9608cc402d3cff9e8e0a` |
| `plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md` | `6d3a714ebc686860b9407410033b7ef1bfb21d8df70cc93b11b1b00ec0b02e3e` |
| `plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1` | `eef6c101c5995cc550df36d3e833d26fb85b823b48bd54f6172e0704d9fb39e4` |
| `plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh` | `8f071fc5e98c43712653feaf67ec929270bc7faca20dbfd70310ce663a71b1d9` |
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1` | `aa1593b9349c0de434a8125a4d15d3a050ff93fc90f538456520aa2b5ad00dbe` |
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh` | `40f35e11b76a30ab38f183a772f1f18a35b0b2be8aaab399b012afeb4e96fa68` |
| `plugins/sdd-implementation/scripts/select-agent-model.ps1` | `f676675b41a91a9fc95c9fa9115542bf6a9430a3fe1c7d404438f8723c5321b0` |
| `plugins/sdd-implementation/scripts/select-agent-model.sh` | `d6225ff74bfcca136a551331ded93f2c57036f7268ce5c11ce5278b7e3105a54` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1` | `18402647758202f2a8c6bd87245cf7450abf599e6f94de09a4fb9255e2cf5a2d` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | `ec5a392cea7190660b8517317977584d36179e718856061acf968b36ef6bd23f` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/agents/evaluator.md` | `18d151073e388fe9e864d7192230c8686c6d8a24414d04f02796c00db4194a6a` |
| `plugins/sdd-quality-loop/references/accessibility-checklist.md` | `6e6cf107e582ad40417636bc5f4b2a545908bd74b8b467224c38ba2597b1b204` |
| `plugins/sdd-quality-loop/references/auto-fix-policy.md` | `ca0c00d0efe50422d149d0af0c56da90adbee6451b44d99395d05cdaab3590a2` |
| `plugins/sdd-quality-loop/references/cloud-verification-registry.json` | `de0153f09def1b805818f9bef1ddea065a30d3fee95e12f026bdaec40720d06d` |
| `plugins/sdd-quality-loop/references/copilot-native-handshake.md` | `fcbbaa0e570b3812210381a71c1d4c34c209a7c368cb6252fda29ba2875d021d` |
| `plugins/sdd-quality-loop/references/cross-model-verification-policy.md` | `0a27c8cea42ae1b5c9bb8e58a5d7d3ea1bc43032453eea8233a563c839bc6e69` |
| `plugins/sdd-quality-loop/references/debugging-recovery-policy.md` | `7b392649cdfa5d565df1e7fb37db0ee5ff528ee870ff3feb523bb57e1294254c` |
| `plugins/sdd-quality-loop/references/design-system-checklist.md` | `00123dbc5f432ecba079755b7b1d4c7c6eec8ce327e808fb2f452dc0a91ccb2d` |
| `plugins/sdd-quality-loop/references/deterministic-check-policy.md` | `ce2628c45b342a0883d9f6d13870cb70d22f3d73b14933de01085c332734ef41` |
| `plugins/sdd-quality-loop/references/differential-test-policy.md` | `191f71258780f0389cd3931ebd3edb4952ca911b1f3555dfadffdb5187df2217` |
| `plugins/sdd-quality-loop/references/evaluation-rubric.md` | `08fc8eff5769f2dbe43a638d2b29eac2cb0a6d57e2cc47b5a9e2617844e3197c` |
| `plugins/sdd-quality-loop/references/evidence-signing-policy.md` | `fb9839a1297268d5d41faf97c8cd086af3b3b85eb879c2668160dd187587d558` |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | `f0d7c2040db8760434d27d698b7b971a77c056125b209968286d905ecbfd459d` |
| `plugins/sdd-quality-loop/references/integrity-policy.md` | `09f7c046829de5ad5da0fed95c72c4cb1700734133ce015576d9330f32241946` |
| `plugins/sdd-quality-loop/references/performance-checklist.md` | `db06f69d17eacb2ed67851c262c0a5f983cc8e4a302080964d207655d5050e9b` |
| `plugins/sdd-quality-loop/references/provider-terms.json` | `2355adabd24e3d01b18f3eb99e986073791fb3f85b4d9d27a91fd6a0f0a0ae7d` |
| `plugins/sdd-quality-loop/references/quality-gate-calibration.md` | `fe2a3a11d5bc6144b2cb1a6eb258a6b2de837b6b2059e06a35009ecd47c9a542` |
| `plugins/sdd-quality-loop/references/readonly-input-contracts.json` | `4527e0d33080d59c9ac95b89bc8e78b3d2932e897bd75b6688b388f830189fb9` |
| `plugins/sdd-quality-loop/references/review-ticket-rules.md` | `eb97cf4b8c1aab618ea4712db8031ef01f7ba81f5c0be528f5ad80e1709220ce` |
| `plugins/sdd-quality-loop/references/risk-classification-policy.md` | `7adb73e4a4a7eff2909aa0e2add7db3a8675e2ec60b5c8e36604b5377c6ca305` |
| `plugins/sdd-quality-loop/references/risk-gate-matrix.md` | `57d70a7d615f60862ac3a7259b28f8452a0a32b50b58fe7aa3d7cbe336a6c725` |
| `plugins/sdd-quality-loop/references/security-checklist.md` | `2e25d44b824615bf9fe309a10e79d2f6f2a8f0afcfa65fb64b4d6fb91f7c97a5` |
| `plugins/sdd-quality-loop/references/sudo-mode-policy.md` | `0e7e9b535d5efe8d791d1f7bb3a4ab3b5103413586141ab89ceb9ce5878837ed` |
| `plugins/sdd-quality-loop/references/test-policy.md` | `ec77cace489812bf891c2988f80cd71b4e45cebf0e14d9afa840b86d780bab2e` |
| `plugins/sdd-quality-loop/references/verification-policy.md` | `3209e110db2ee0460289ea427dfbe7c85eed82fb43c2f28f2a5281fc7532c3ee` |
| `plugins/sdd-quality-loop/references/wfi-category-guide.md` | `3901050ddbd44d172427837a5d3cea201bfd078ef6d3050946e453527605263a` |
| `plugins/sdd-quality-loop/scripts/apply-human-copy.ps1` | `2c4eaa6ea12239b024d6dfba4e0a6262d7827275ac9d0207c80975e280a4b402` |
| `plugins/sdd-quality-loop/scripts/apply-human-copy.sh` | `93029c02bac7ef5390638cd0a2bcde77803bf07c780baa3d6080ca3caa2db800` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.js` | `6ceacdf43799b88ffb60618ea63abfb7b7fd9ee9722fcf1728a6109717a791d8` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.ps1` | `90ec01f971c350041442a132289209543686423758893f27d5362bb03fdb0635` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` | `b357a8252a7ece91161f1eca6ec6ba434a0fa9f45a29abf77efb6f90477ee0ff` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh` | `c144cd15c5ea474c7744be2b16a197c7930bd73e8078cc397ef185748a2052af` |
| `plugins/sdd-quality-loop/scripts/check-a8-citation-compliance.ps1` | `f0fe69df5227e4eb21bc65b33e12ac95f1ad4dc6e1bc831426d4e64bb836279b` |
| `plugins/sdd-quality-loop/scripts/check-a8-citation-compliance.py` | `69fc11d30af9214a5c24a791b215fdec8ff6d9f2a9c490288bf1a84647b331a9` |
| `plugins/sdd-quality-loop/scripts/check-a8-citation-compliance.sh` | `5eb24f5654f133ddfd5994b1e76cfa8981383ea24ee52d17b0e49ab4c2df368a` |
| `plugins/sdd-quality-loop/scripts/check-a8-classification-table.ps1` | `a7e5741f05d4a55ca4858607b148c69674d33721164aa7bbb7658e6cdc24f2a5` |
| `plugins/sdd-quality-loop/scripts/check-a8-classification-table.py` | `49752b8834db79ec6be60d90ecc400b98c2b692002d9bcf3827cad510a60e051` |
| `plugins/sdd-quality-loop/scripts/check-a8-classification-table.sh` | `bcae618488556503f80fd1677d3b276bfa3918cced915c3fe4bfcf8bd8cfdae1` |
| `plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.ps1` | `4d69f2d489d19f99888d8a3df116cdb6aa121ddf95f2ee568afe2dd3560477b3` |
| `plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.py` | `d6982f2568b659e0ef7f88941973df0114adeb5ef4b8e91a035ce41430b345ac` |
| `plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.sh` | `3d876483af223d59c4dd0d425630db049b9c1e2d46b8bc1ad9dfe28c194fc5e5` |
| `plugins/sdd-quality-loop/scripts/check-component-coverage.ps1` | `f8ea0ded7c6b9b794dba617ba0575500dc9491f502ebfb78f8ddb975ee6d0ae5` |
| `plugins/sdd-quality-loop/scripts/check-component-coverage.py` | `d6505e2909ea988384c0694c3f4b865e8f4539ba25eb71dab85d21ed447882fd` |
| `plugins/sdd-quality-loop/scripts/check-component-coverage.sh` | `487e96a95f4aa999173ecb33ce8b1b0525bff5456360202ca84250383c0628d4` |
| `plugins/sdd-quality-loop/scripts/check-contract.ps1` | `66505c65b073bc083d32b734a4e073bc85a216dd98a3b81a5bf581ae4956d9b3` |
| `plugins/sdd-quality-loop/scripts/check-contract.py` | `9bbc96658f775ed46c8d876e92803a8de46c9bf242bbc83d412776164e89e6b7` |
| `plugins/sdd-quality-loop/scripts/check-contract.sh` | `fc3a081d4e584ac13e4e09821815b8a14ca637e214fc70b8d470aff1bfecb416` |
| `plugins/sdd-quality-loop/scripts/check-criterion-freeze.ps1` | `33ecdaab4f9bb797106d79aff7e0ae36adcc1083b2f85776abae546d3d044a75` |
| `plugins/sdd-quality-loop/scripts/check-criterion-freeze.py` | `dc456d22f68da79856a668e588194793ec9c09ccac57d979927dddb2ba9ced42` |
| `plugins/sdd-quality-loop/scripts/check-criterion-freeze.sh` | `abf48c19906ce392e564240469923617989085bdb6291814acfe1e99435ab360` |
| `plugins/sdd-quality-loop/scripts/check-cross-model.ps1` | `e1495c4b32d628aabedb58f12911f02afeb8840bfbfb3b057489bdc44a0bdfc7` |
| `plugins/sdd-quality-loop/scripts/check-cross-model.sh` | `f3c210ef9205cec0f054388fdd5308a644b6b91c0b71eb0a28584635c2871b3e` |
| `plugins/sdd-quality-loop/scripts/check-design-system.ps1` | `cff0c77f6cc0e79d68459e190d5b8c0cf56a8cbd4ab070bfc6005edad414a7b9` |
| `plugins/sdd-quality-loop/scripts/check-design-system.sh` | `73965bb6679ba8418a3130dc5fe236cd59a7f4c188192082ac16e2548a37a8af` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1` | `da62db35889d2bf95da1d2894fe683c0a9157842b943fc5cbd06364d552c931a` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh` | `4a776b186b6fce40fd0fc486df43230c185898655eb4fe03040b7fab117ae6a1` |
| `plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1` | `0f9b32251f645f0aa51684007c5489cc34597b5976e07c6c1d2da93a890b7582` |
| `plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh` | `bc09790f2ab992f93e240b0e77a2919fdbaf4bd66286b8cba633b6efbf751c1d` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1` | `5837fcfa74fd7ea277163df531e1b0d42841aa8a5f8ca68c2500f8e5d59a9f00` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `c20dfa627a34d068dd5991345603a9b9440831b5e43352c23844449ab3622701` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh` | `c9a6a330238e8b466a3e08345affc3e0d51545091c84150ade94f8f8a7b06e12` |
| `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.ps1` | `1aaf8a07af7a7f36267cd3e16f970cb8e507adc73fa5a67c75d934908e9f197a` |
| `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.py` | `c84be3e7d7f50147d7aad1a0118bf03811e30ea641e7f268c32e51ae9c96e2e9` |
| `plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.sh` | `bcc0b34484841164e35ebcc103dd22efddb78cc043a08906eeb7fdd40a449f9a` |
| `plugins/sdd-quality-loop/scripts/check-placeholders.ps1` | `4a93071e79c29c7392e10b14aefc4dfcc8124c87e413cb79399eb741a3e6807a` |
| `plugins/sdd-quality-loop/scripts/check-placeholders.sh` | `d380f71ff0385f305f655081d537ccb4668a644f34f821564d80418cf52ac263` |
| `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1` | `9b727915cfc1945b48a217b3a2ed251baca877cd252ed3c80fc4959dc7df61ed` |
| `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh` | `21c74ddac1f742081c9d5f9a34021c4513f0efd6f2c4742fa559223716f9389f` |
| `plugins/sdd-quality-loop/scripts/check-risk.ps1` | `22d5acfb0674d99c8fbf7075def3d4cb1bea8c129f94b7a9af710f19bc9af3bb` |
| `plugins/sdd-quality-loop/scripts/check-risk.sh` | `ef5119f578fb242cd68cbdd35e41ac8d30a03af96d0ce3ea02f665fb33e2fe9d` |
| `plugins/sdd-quality-loop/scripts/check-task-state.ps1` | `51cf61779f4358748d21b0c2b13cbdf86253c0d2728d2822f9d53780ce832a0a` |
| `plugins/sdd-quality-loop/scripts/check-task-state.sh` | `209dab3d0fa72d980dc6247fef2f4566950ca3c228543dda8d930a1eec9e286d` |
| `plugins/sdd-quality-loop/scripts/check-traceability.ps1` | `0344b1b557b15abdc0c35516f6da7e551dffb1e3359773d7ba7e343a357a96ac` |
| `plugins/sdd-quality-loop/scripts/check-traceability.sh` | `f735a2b315161a2dfe61e45a199ffc513b8461a2cccb3adf00d74830dc56016d` |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1` | `3871a8163305d5108c35983cb31b017bced02b4c90c2fa6ee8297fcb5dad630c` |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | `bd168e57efa163636d916d97baaa963d96a9b33566e61258d1cb3bea4fdda1a1` |
| `plugins/sdd-quality-loop/scripts/classify-readonly-inputs.py` | `d62d3accc7fe28a3fe0ca0d6fd1ca739918d0b9878d3f6da05682523d0ee2238` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `17f5ffd041fe2d32657452093c76f4eda87b37fc5bf5d8504a1c6352eaac9658` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_dependencies.py` | `7974e7e9a8d7da0c60b219a58db54c4747f0250653fda3af0146091f1f4fb475` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `b2488aa48d32716b270fd920fbf4b13f43cf19440e975b48721d91e38de62a68` |
| `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.ps1` | `9d45b32b3f0eefa4e2cabf49e1bb9c4427701b5bf44a1006a64931415d1ae419` |
| `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py` | `e7b75cef97a477d98b1460d8f20124c144e4ecb96ea15866714e80e6d00e2f93` |
| `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.sh` | `dc25d2e9fb2ed0e81420f43e52beb547ba547ade3bd13dd56d709eeb8360df68` |
| `plugins/sdd-quality-loop/scripts/detect-panel.ps1` | `f59d1cbf8dcfb7087e9a43b102d2725ec3b12ab3a2edc88e72fe31a99825cd12` |
| `plugins/sdd-quality-loop/scripts/detect-panel.sh` | `7c55c1232761589c2f5de6575a060d445d4499d49009cf03e63cfd43ca273b1a` |
| `plugins/sdd-quality-loop/scripts/detect-policy-weakening.ps1` | `fa4bd8087dd4dd83ca75fc24821b901eaf986ebabf7d25cb7dbca38cb20f743f` |
| `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py` | `a40433693b5274de2816710b352a000736f806daa2b68a58bf34579488fd116c` |
| `plugins/sdd-quality-loop/scripts/detect-policy-weakening.sh` | `eee208c828f64d91d9949dd5b3ae12865d7178199faf23515b82080641b8ed16` |
| `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` | `e88ac07955691ef2350fe4e6bf92218824b08a47ea493f492af746901bb139cf` |
| `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | `4159a139e5997a79801bcbd9842285dd39b3259a168a990f03adafa0b8813129` |
| `plugins/sdd-quality-loop/scripts/evaluate-predicate.ps1` | `d5dfbec3f7808ff204ea1a17494f212b4cdc436e9e5b1ccfcafbe6fd6f50920b` |
| `plugins/sdd-quality-loop/scripts/evaluate-predicate.py` | `4daa549e9bb06b71759580a0ed1389033745dee21c5a1ae7ef694c725a2b9156` |
| `plugins/sdd-quality-loop/scripts/evaluate-predicate.sh` | `6304d64f0707f7ae1b65f71efa34cf5506a930cc4ccd7299e25656c43cb7133e` |
| `plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py` | `68b6ebecfb4996cae3e97e1723fa64d9e8d97ebbc2489058afddd442c7bd6e7c` |
| `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.ps1` | `e43e21b37ea5fed7ead05b611639a86c5eec3e1f23deed0cc2e0aaa29d52d06e` |
| `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` | `19672f400b225d26d1f328d28e4176f90acb8c868bba10805b4f1f5206a72592` |
| `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh` | `f75bb7613094c988c0b8d05204afeab507a6f64c055278c4a308dcbbee3301e5` |
| `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.ps1` | `b1a8e3fa0583747a0041ee122e4511e7152b27ded2214a34fb7dcc9a7b52ac2f` |
| `plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` | `92999f5c81fe4a7cf75c6e630427a9ff866d4973a60aa4bf4df7043ad546f448` |
| `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.ps1` | `26146457a7148c3ebebf3b22a939f3b7cf861ccf6b9ff1e69ac478c11f45fca0` |
| `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py` | `fba1559b635fedaa30b2e4cf716143e31ccf8f7d7b8bffd21f83fe4fca2b3eaa` |
| `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.sh` | `819f28415323152b4f57aac086002dab4a0499f2cfce9036febe7a1d49ddfa85` |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `c4b619bf7729a3742ee807b1b2efd1debf7f440d88d142c070e193c236221351` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.js` | `675b6add2a3abb482741c82ad6626fee93bcfd55aacb48545318dd19f2b7415b` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.ps1` | `2fe45e533b1dec24bcebfe13c506a66aa6efcef704bf7796cb9150d1e4be6fe8` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.py` | `dd3a0642deeceac3d8def2c476c97fe6cf69fbfcebb2e1682bcd7939862b0aaf` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.sh` | `b75fd5fc0859bb3c9f2228f5fce3bd0a56a45aa8d9f5c48dd83cf1ae68c56453` |
| `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` | `26c20a6a62259b598851beea58070aa1ddf2918fda5048f7467380852d648144` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `3fface3fd9bd38dd3919dfff11ce290aa3d4016cb9cb99f44f0275a545bc5a07` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `b8abe09fd6f86f080d477b638918d74657c2295bf4f7c575c28cb63fa3c3bd3b` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `564080c31fdcc4cf2270017867f90ea6e0265de000c07b141a6788479830ef80` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `31f6e2444069de7473030d88387f649fc420d59c4e3e853692013fcd787ac5a8` |
| `plugins/sdd-quality-loop/scripts/initialize-review-identity.py` | `09d18de4572a758a8db987c5cf6d2b09f9d87d8d41ff35b4eafacfa37f7f73be` |
| `plugins/sdd-quality-loop/scripts/issue-live-host-nonce.py` | `40fb8ec7238c7bf9b06c1894260c00698c39a963f9cef2f127e9c95554cb0e8a` |
| `plugins/sdd-quality-loop/scripts/kill-switch.js` | `3896e82a012b771390e20b38ec52453742ce77b81352762fbe5b67c9c742b01a` |
| `plugins/sdd-quality-loop/scripts/kill-switch.ps1` | `06c3bbf762fc11aec733b1e5c54413e8ceb2e51e03c72a139947059787115ee4` |
| `plugins/sdd-quality-loop/scripts/kill-switch.sh` | `c87cb7a12d59b517006dd5d3d9f8ab0b2f55bcee61f9c9e349d9709fb365f0cd` |
| `plugins/sdd-quality-loop/scripts/lib/panelist-common.sh` | `9423a58476d09acf3efd40f1e480c76d1984f97abfeab9260d50f7968855980c` |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1` | `b15ef1ee7b8b89fb7717ed09b4d7c0e6150bbbd87478594f61a146b6596b30fb` |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh` | `abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c` |
| `plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py` | `4a9fa0c679b77959983eb3cc6c0674c03c2c3e3641d41b374fdbae51cb758a3e` |
| `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1` | `8b782db2163ed17f9ebde2bf5be7bfefb599093df7764aaf7645f7aad189573d` |
| `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh` | `17cb11a0aa3c38b6f83bfe3324723f3349d5b088653ae78c28c204bf7f6be752` |
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `5cb5fa8230a21e3b4d108b4643d3db474586b34601eb52c1fbcf932d259541da` |
| `plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1` | `ac2118d4104e187a51b0ae8d04d3d591201ff0caf7f0a5072b29195a13903b05` |
| `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` | `7de26e8f1c5aa9bd6b69c9224794f25b0dc35a8a08bb89640d9c54b70388ec26` |
| `plugins/sdd-quality-loop/scripts/resolve-component-paths.sh` | `f5852cb1960830e3d42214485d89e552423ec4246a4804851c8a2512a3b35528` |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.ps1` | `d8eb942924296d36a9df5222dc0ecf2e446c462e1f66493b9ed0fbfde3e20656` |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.py` | `edbcad8326293e6c83cf96d9e457c819ebef64c19a9a4090ccb0cdcbc7a62b56` |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.sh` | `03986de0a2cbc1e1fd69b93444accfe4215b5ab5ea17c3a3449f9cef37fe9429` |
| `plugins/sdd-quality-loop/scripts/review-conditional-inputs.py` | `48a565069a10edb132c98d22d8efc24a714442faad7a71585d3067d06305acf2` |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1` | `13ffd439854bef7756cbd4d4c0cdca85be8c70d0cda36a6ee2ef134dea678932` |
| `plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh` | `160e43c240be47536b068c7f968ad3d7f04d49b4e0a1b36243bb33484f877225` |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1` | `da8adf0021ac10f1511e52c2def5404c7dd9b4772fdad0e9b45efc1c8771a5c1` |
| `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | `32aacffa4f8ba92e7a2d49cdc07d1073afef620c2e9d56f8213b008768173b81` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `e3006fd5cdc11d86658e6ba44ccff673aff61447c82f353754c2ab7e4bada8b3` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `9380b5f98bf24d595cdb4f81edf3b4ad3ec974a454ed1e2ce3a7c29dd17647cf` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `31935ccdf2fad222561c5bbcc548e39faa2a696613a987cc82e5b80f319075e9` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh` | `1def3bcac3db0e1b6f8ae859cd8ae13957e199e87d2c0e2bc9b3317f18e9e840` |
| `plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py` | `a9c23a27bee1174a46ec7203c90ace1988ea582d0d47cb5f029ed3e16c659766` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.ps1` | `99616f83e2f8120745a31ad6442009c6903a986f71ee519d69211969ac6a85fd` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh` | `5b6e7c83f35415d30cca173978abd6d70896d4fce087124d79a68af8ede9271e` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.ps1` | `ce2bbbcdf123a1c9f4afe3e55a19f6cb9a26461b8b0048024115c52173cd5556` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `4aa0e97622b47687508e305b1832e182926d0595b7626180e5736b23e0ef174e` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.sh` | `ff95edd6b487142af51b08a37cd5d7df108d6228891bbfa8b700124a659c67d9` |
| `plugins/sdd-quality-loop/scripts/validate-capability-summary.ps1` | `63a9066cd6f793a6ab3fca4c58f967a9ae500db30afd9884f763c62cb3f7ce90` |
| `plugins/sdd-quality-loop/scripts/validate-capability-summary.py` | `7ef1abd13e6c15b8b6b3ec85757e1b3ba72663f2283a54c7a6fd2997e964604f` |
| `plugins/sdd-quality-loop/scripts/validate-capability-summary.sh` | `b036a0dc08607d864b68a9abfe7f57ae4b262bb050fd392c56bec19a486785c3` |
| `plugins/sdd-quality-loop/scripts/validate-context-projection.ps1` | `263931aa9cf3b8ab6da0889c389fd3f59d24c24725b1e11f4104d9d475b482d8` |
| `plugins/sdd-quality-loop/scripts/validate-context-projection.py` | `7a0fc4c486e1341ce635f14d480779e25a60cdd3d078a877f9ee47c0fe0f2169` |
| `plugins/sdd-quality-loop/scripts/validate-context-projection.sh` | `54b517ba7152a2e92d3693271d37ddf3d3759fb101e86c38d30bbaa53bfb5612` |
| `plugins/sdd-quality-loop/scripts/validate-facet-manifest.ps1` | `b3a7d3aa6dd5891022f48d527abdbf9411dfef5e3c3882213f8134fb1f5da51f` |
| `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` | `343895ffea39fe4459af667308d815bd75cc6d4f4eaad7ef4e51b5753994ce99` |
| `plugins/sdd-quality-loop/scripts/validate-facet-manifest.sh` | `1b9114aacc964a79244b47b8afde5b0990529aae742c961b45c545d991718ce3` |
| `plugins/sdd-quality-loop/scripts/validate-feature-scratch-history.py` | `0ca6da3eca4239d4d2bc5c9740effd67866b7f463310d0085f25d59a5fc6af6f` |
| `plugins/sdd-quality-loop/scripts/validate-live-host-proof.ps1` | `f246562e8995d1810b989843d2887477b4436ae87c8e05b2e356e79bdc21a976` |
| `plugins/sdd-quality-loop/scripts/validate-live-host-proof.py` | `ddafb7bf7494a4788443c1c1aba268da29ffe0fb1ccf34fc09335746f8d69420` |
| `plugins/sdd-quality-loop/scripts/validate-live-host-proof.sh` | `1bacc058fd39668ca78c1b6778244772e410c5597cc1b24cb88e5dcdfbc292f2` |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.ps1` | `146abd05148d331ea7dfc922a5e6474a806b037fb67572fe311a1d603ff01cb2` |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py` | `11bbff0409344168c57095631c333c714cd9dbffb22da664989494e50dc5757e` |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.sh` | `acc9b90b7ac3e6b72438bcbb154098fdcf7a2dc07ff730550625125b6198a289` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` | `e6325e03773792ad28081447a5884e040fa537f9261f81f13c87d6d597064cda` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `47e7d8de3281e3b20b52a2c03ecde820167a20149bbdaac6022d7ebe4f7e9735` |
| `plugins/sdd-quality-loop/scripts/validate_path.py` | `56306107b68809f5ee443085028019f6187cba7c99379ad290be51661933d2b9` |
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.ps1` | `6727f54b5032f5c3f2c28b539315436d1bd0238eed9d41ac4685ab26b04ebb7e` |
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` | `a61f889f274a8069d06c359caf813f79a444de5c77ee64c5a37404a8de8b973b` |
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.sh` | `5ae99d403710e7f2d1a5300148daf74a861726a8ebdc4539d83c0430cbcce5ce` |
| `plugins/sdd-review-loop/agents/impl-reviewer-a.md` | `6d302654a8662e233e038e254548bad68d593cd1181433174f9c950bc6a2b7aa` |
| `plugins/sdd-review-loop/agents/impl-reviewer-b.md` | `af34ac767af2956b488ba59e75605324df623f9faa46ff239c007bd6c16fece8` |
| `plugins/sdd-review-loop/agents/spec-reviewer-a.md` | `1e4bec0592136e1c2a610d66ecd0b15b79190cd985a966a46925e7d58d8f0731` |
| `plugins/sdd-review-loop/agents/spec-reviewer-b.md` | `d9d7e8e3abb0d822daaeb19b30183f7e283602c741d440d35d78accac166cbb1` |
| `plugins/sdd-review-loop/agents/task-reviewer-a.md` | `bdb7c2cde255ae57c676abf1fc7031d88ea4ce257e7a13223632e4e05b448bdf` |
| `plugins/sdd-review-loop/agents/task-reviewer-b.md` | `9af60291bfabdff5058e870a4f749837f5180853e91435cf8fcdb54cab257e82` |
| `plugins/sdd-review-loop/references/a8-expected-hook-config-digests.json` | `96e0f84ee6b97537f1784dc2d3460199380af2023ba1e8a3299032b06ac2daa6` |
| `plugins/sdd-review-loop/references/a8-skip-allowlist.json` | `0bd487921d967d431766976fb8a62d0f181c27eb6478ab5b04a32190f03154f5` |
| `plugins/sdd-review-loop/references/a8-trusted-signers.json` | `f6ec9affdaec7ce9eab180b5dcad45a468dd083a0261aebba64392ead8176886` |
| `plugins/sdd-review-loop/references/phase-review-checklist.md` | `cc3d2db0154ad36909168704226909f8eddaed805d7babe5960b1c75805717d2` |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | `dee610c3acbbada9325d58143abdd8a6fd0b51270af1fbf51891733bbc3878fb` |
| `plugins/sdd-review-loop/references/reviewer-calibration.md` | `63f0005c6dd64ee8e07e61770266ace305f9239a3695069dd2ea5671611885a9` |
| `plugins/sdd-review-loop/references/spec-review-calibration.md` | `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385` |
| `plugins/sdd-review-loop/scripts/fixed-review-inputs.py` | `c3c88aff64bc9de6f5e989bce03a25d027f73f159676fb7a9ef155d835de4aa7` |
| `plugins/sdd-review-loop/scripts/fixed-review-state.py` | `0051f87b6bea7921d5963aa32b34189e5888f5eeecdf204ef465001b38811153` |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` | `2f08227f3c697307777e762fc6c01f604e9ffe5d521a304930563ff5895fd867` |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` | `c35b033f438ee0f6e16113cf7e399d90ee7278237f96fc68f6d2e453b0e98b76` |
| `plugins/sdd-review-loop/scripts/launch-impl-review.py` | `855985841eb0fb8735ba81b88df21de409dea288edca584bf4a59bac69e2aff4` |
| `plugins/sdd-review-loop/scripts/lib/fixed-input-source.ps1` | `3acfab8eb3c144ae437e1495cb98b6d162edac4f2029bf9a340744ade19ba046` |
| `plugins/sdd-review-loop/scripts/lib/fixed-input-source.sh` | `e0d521a0ea059516c46b0cd36f6397d680e49a294903ab259e0a75c3e762ee46` |
| `plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh` | `a32d8e831d0360470c90c80089208fd401262cbe47fba2e2a0e90157f724e1ee` |
| `plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs` | `0a3d9961c53d01520a37fc41bf86ef7a7e5e6cc3254d427789b6115634e1369b` |
| `plugins/sdd-review-loop/scripts/preflight-host-review.py` | `2bc182b85691ac0cc848f5ff5c34e1a5ba488cfe7025f6e6ea9b079f4847b752` |
| `plugins/sdd-review-loop/scripts/probe-nontty-review.py` | `de497ca1a28b3e07ba1b7e717dd629dd66068c78b31698689628cbf494f2108b` |
| `plugins/sdd-review-loop/scripts/review-contract-validate.ps1` | `cb3a1b2181fa5731252457bcd82134da2e2243cbbf97a70a893555b01dafc96a` |
| `plugins/sdd-review-loop/scripts/review-contract-validate.sh` | `431f6cd98493b5a5c42a5d66e5bde11c9087f450709a1eecf05600a00373ecd6` |
| `plugins/sdd-review-loop/scripts/review-hash-normalization.ps1` | `06c8e58f2256f6b8c2ff698a73e6d1308caf5ab73ec2e20e7c8074ea8d991e42` |
| `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` | `08792df3be712917b9e771abec28e153a8d013624286ad221da1837f2d462b2e` |
| `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` | `73a547e30025ad4c54313aaf03a3bec31286e50f90d80c37340c22ffee0603d4` |
| `plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py` | `52bc01ad07f930d3dffd3788e6a44e506b3a041a502fcc0ffa3a814262ef9e53` |
| `plugins/sdd-review-loop/scripts/task-review-precheck.ps1` | `6fc9975eb047af08004a299be8a5d0a00dbf2e91fb8af917e5b60235e187acbe` |
| `plugins/sdd-review-loop/scripts/task-review-precheck.sh` | `2b8881f9f5cd5d27811cdbb0b5eec1510073993761f68f3c4882b951fdf8d588` |
| `plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1` | `03a36e7234f35c290a3648cecdbd72b4a48da50159b496330aca802dd94ba7b1` |
| `plugins/sdd-review-loop/scripts/validate-layer-traceability.py` | `b893b7799734bcf67b4d84d7d6d3a314de41024bc9a342ff5d68f71f2db5222d` |
| `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` | `c5ba7e73c929b2734a2b4053c22bff3d89a55ea1276cb56ab58507894f4bde45` |
| `reports/implementation/cloud-orchestration/T-008.md` | `a1efa08a83d5a603790916675d44a74488e557c1502b39afe2db72f4ee6ee195` |
| `scripts/apply-branch-protection.sh` | `83ac459aa0b645758a80eded165d5d9626d0ef289600d810484872c830f64a22` |
| `scripts/bump-version.sh` | `4999f5d1c1dd143570548d0913e2c16c2e2bc27c166f7da736199a1649180b47` |
| `scripts/check-sdd-structure.sh` | `4b64e8027ce7cc5f99f788ea044ad54f8a5add23acc253419c5f26fc5b9671f6` |
| `scripts/human_copy_mirrors.py` | `2ea93f1061101eb5de6cc6e6bb201f95f81cf8a28408ad2cc7c241ae912e21e9` |
| `scripts/measure-evaluator-scratch-isolation.py` | `abbed4956bccec91733d0cbe3fef5194561fb10cfefc7bb85617bc177ed58640` |
| `scripts/observe-a9-advisory.py` | `d788e472e4d0e70b37d9ab197c7b04c3bfcaef7624d1fb9490a53eef9af1d0ab` |
| `scripts/rollback-1.5.0.ps1` | `953efb6192206b7d91519403e18890851330d89e8163f775b56ed0399d9985bc` |
| `scripts/rollback-1.5.0.sh` | `6eea918fa80135ff34fa2e0aa8c9719e34ca2efcf133ddd036c6a755b1117127` |
| `scripts/sync-human-copy-mirrors.py` | `13e9572f3757325f21884b0a2d94e7ed2eabf98acc1078d915d3159acc7c2be9` |
| `scripts/validate-a9-candidate.py` | `232e30cb0b43aeac1c86659bec1058a5e2c4fe66a6f2777bdb9faaebc39f7a06` |
| `scripts/validate-a9-promotion.py` | `3e7ab956de48ebaaae21769c5dabe2f904821973a2dda4106a66b88874c6bdc3` |
| `scripts/validate-a9-rollback-receipt.py` | `aabe53a0a123232a0a25a91f21268e6a23f906412118e3688009598a3130c924` |
| `specs/cloud-orchestration/acceptance-tests.md` | `4eb6f1a088bc175196ff6f9e33393b05190903e061186fe70cf4895f044f06e0` |
| `specs/cloud-orchestration/design.md` | `f3605c89c9522f3f167db695e2bbf2bcbe7e9e71c92610ff0032272b0bca5f89` |
| `specs/cloud-orchestration/frontend-spec.md` | `586d52fd577b5eaa24be9037f80fbc0334ab934906a9125ead71206eb8561d2b` |
| `specs/cloud-orchestration/infra-spec.md` | `9fcb3698f73022d60b8848785b05ca137620b97cd43586da63a0e75716bccf7d` |
| `specs/cloud-orchestration/investigation.md` | `38229c1b74b815780bfd752a353f1dc15bbcfeefa0285e4f8dc097721227f20c` |
| `specs/cloud-orchestration/requirements.md` | `31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922` |
| `specs/cloud-orchestration/security-spec.md` | `fe980874e34da14db58b088b0ae6f989a6e0dadc3a39757851457c0c5312e1db` |
| `specs/cloud-orchestration/tasks.md` | `7a9aca7ff38c3dcb420c92606d6dcf492a16dc716c28978f9e7d18b439bcbe71` |
| `specs/cloud-orchestration/traceability.md` | `5d6ed8d89b688ee11406b5059323b537d37dcbc8d4ae8d32c43c1dece6809b43` |
| `specs/cloud-orchestration/ux-spec.md` | `d02d6d219266ca0b5c0ae9705a58e67b66682f3539ce2cd749e545abe5bad8bc` |
| `specs/cloud-orchestration/verification/T-008/attempt-1/docs-check.py` | `0d1309540d5ad35de4fe309fddac5c371bca40b39098d794dd27036cdc1e0b73` |
| `specs/cloud-orchestration/verification/T-008/attempt-1/link-check.py` | `f74ae19cb915869e9a448224857d877b5994da6fbd94a1d4ff4489b94918e621` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/T011-protection-delta.patch` | `ba5710883c67426f8c6a1879d15ae8c0a949fe020c05ac1bace97846ef76c0b6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-advisory-final.command` | `4607db1a15394beb0c97d1d8a9f5638f1f62a3df13b8bc072ffb1519bd16b1de` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-advisory-final.log` | `9edb6e0f075e44747fc5f294d46e5d20ae4f4d4756a4dee78be3345b0468ceef` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-advisory.command` | `c1fa225b9c885ce2c1833dcc9d9f74033e91a6c9b56b06e8bcb37c5bfcb7768c` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-advisory.log` | `21753dae4785ec81fc1b94a6fd325d19b4df3881cbbe42fc1ba9960035fb6a37` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-candidate.command` | `dfddf7bcba7c8e0f15616e20f6613564900f8d7a82d1636bbd582a6786b8c72f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-candidate.log` | `8fda10aa98fdf0913fa797b33ce04f23c4bf5cffbe195590f099e8e85ae2b8c1` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-classified-final.command` | `6846b39df5fccfed753c9b37f615e55a5d0e9230c58cdb2d68d30af62da62cb6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-classified-final.log` | `6e03bc1154e0a162908c79c9237c785b2b5e6344bf683e934555f0805b4ffa84` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-dogfood.command` | `6846b39df5fccfed753c9b37f615e55a5d0e9230c58cdb2d68d30af62da62cb6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-dogfood.log` | `0078c904c3ca0f480671123db34b90971e53819cdde86cf4ed890d9423394493` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-final-dogfood.command` | `6846b39df5fccfed753c9b37f615e55a5d0e9230c58cdb2d68d30af62da62cb6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-final-dogfood.log` | `61c7b573524bda6323ba0517c38b7321d4874450046eb688c4e3713bb033cc7f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-promotion-final.command` | `c5860f18fc0a33cdd15706bdfa8b981cc6062389bf6f9ad5d888d89ce8864dd9` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-promotion-final.log` | `81e21d8253affbf8fb57412e167cb2684e4cdae51eee252dc3b6da241cd7f4bd` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-promotion.command` | `7b8fe27d3513c29cca2dbba9465bfea9599f0e33c9f5d49386f143ccbcc97ada` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-promotion.log` | `24af811e89c96a410e5511ab9c685cfe3e1fe49c5e9fda5c4b476ae6e16df76e` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-rollback-final.command` | `8ad3f8f31d2ccde21563fdb484e013fbe2f6d59cbd78cb3a8858ac6a2363e919` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-rollback-final.log` | `9678584b224336884ba09a1de0c0d3a83af09a1725f54dadb5661be6f3319564` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-rollback.command` | `01fa1ba4019a2d2e3a5f0fb40bba552dd6dfc75de390e2af7eb9799c153170ac` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/a9-rollback.log` | `2e4317e563b6756f2a475cfcf228c94e09735eb1ba9df4893108bb6a8540e6f4` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-mcp.command` | `b3ee15627ada443e0f9a535b178f4c01b02556bf8e28dd9c70d58c2a2202be1b` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-mcp.log` | `2e9054eb77e217c5c369d6ad26f59cae3e5b4b19070e823a9172f044ab3c3b94` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-repair.command` | `2554fbc7fbc83f5b449365ebd2dbf8482ca42c027460477d5a96cfcc846a9fe9` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-repair.log` | `67e55c81a382295667a69f0d840f7ea36fc9ce2b6599a2719914640832749957` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-routing.command` | `90a427b61f01b32c48b46c42b46d3d1839c1bb07a95ed68b1a936d887b4b113a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/after-routing.log` | `19d1f866a143b342d3467e95e0ac60b1bee77853362c40b3569ee151078a521d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-a9.command` | `18e2851e6687aea8c427485c394aa35d30ccd628c04e6cfa5aecedbbd74bd75e` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-a9.log` | `50e619da4d3da36c1cdeb6dfa51f5a5df35c8e769c7d86aede88b70d7cd2fb0d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-hashes.json` | `1b5f6e52885884eb06e8ba22eeac85313293128e650ee35e819a3d15764100e2` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-host.command` | `312dd5d35f4e69c0cc31dd2374b250965896a4fa421d819fb403ee121193fa8a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-host.log` | `d8d25fc36d2a98c82f06322cb61ab637552e6e80341b554ca7e647d70d212477` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-mcp.command` | `b3ee15627ada443e0f9a535b178f4c01b02556bf8e28dd9c70d58c2a2202be1b` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-mcp.log` | `cc9a64ee521ebddacad2067d68d08cce92ce1b7ace67795bc8a645b1e2a01786` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-repair.command` | `2554fbc7fbc83f5b449365ebd2dbf8482ca42c027460477d5a96cfcc846a9fe9` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-repair.log` | `e58e83af483445858ba9f3ae40e1e87fda47ab4d8217d99a9176e213d5d3b8f2` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-routing.command` | `90a427b61f01b32c48b46c42b46d3d1839c1bb07a95ed68b1a936d887b4b113a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-routing.log` | `f4e68cbb772e160f3ea448763ddc46f45e918fc59f55773e7138fae1498b3b95` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-static.command` | `158c7b7c1dd693d4ab3195fcaf9c0fb3aeec627424308524bab69c711d4629ce` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/before-static.log` | `d1b9401a3f64cecf6c118f436f4dfcc7893d42b9359c0b5264f6d54d92b364d7` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/changed-files.json` | `0e3e4979f637818d60b1e0e139e98cf5889bbe18aa65d7e7c5bcac7e9a376bec` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/check-exits.tsv` | `afc8d228c0d8fe4cbbc0b06f0503718c6b7ed49c81599aa32bf039a6ad228d2a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/check-preservation.mjs` | `a5aac81ed38732c2a35451cbbfac98f8d666e8abf661a64d821a4a0adc541808` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/check-repair.mjs` | `b0d578f2546ee6c89964a2fa16393770bf298a8ca866f042c3e1607aa42f07fc` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classification-manifest.command` | `464fb74505ba2cbb7649c12cc8c5cacd6d3032989105a5e9a6306376a5d00626` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classification-manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classification-task-input-manifest.json` | `da4035f0d385bece771bb2199f1acdb99d0f5fb9951c1bdb4920b90ed90ce79f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-mypy.command` | `78b6be4e69153551b50cace801fe3ca83145c2132588ff92b78deaf615906822` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-mypy.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-preservation.command` | `808a3e0c16417620e6d3535a0bd4d2d6f04c1aed6dd05bb75db31a06c3f9d09e` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-preservation.log` | `e352f151d996e7dce0da1f2b47c2f18fae946c1180d028b5261932f6ed028d8a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-ruff.command` | `727cd69ab5a9e463d170f05547e37f5c06ce7c4c01971a068472844336b216fa` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/classified-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/current-inventory-addendum.md` | `dc7ce6b8f4a2518c94ad9c1547226f1f8025b23ac355ce0dfd191d5aaf2bb106` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/diff-check.command` | `e34962efe3181e7251d3af0c3911c5752f605e21f7a38187d8acc5b19d2b271b` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/diff-check.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/docs.command` | `9a53a809904dac760187d4ea154630dc1cd4a311ca9439df7283770a470cdfd7` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/docs.log` | `c0edaeb38d8fd9c3540175d852b676908486bf03e703f4856a5d16e9f8a04d0c` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-all-mypy.command` | `78b6be4e69153551b50cace801fe3ca83145c2132588ff92b78deaf615906822` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-all-mypy.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-all-ruff.command` | `727cd69ab5a9e463d170f05547e37f5c06ce7c4c01971a068472844336b216fa` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-all-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-candidate.command` | `dfddf7bcba7c8e0f15616e20f6613564900f8d7a82d1636bbd582a6786b8c72f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-candidate.log` | `8fda10aa98fdf0913fa797b33ce04f23c4bf5cffbe195590f099e8e85ae2b8c1` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-diff.command` | `e34962efe3181e7251d3af0c3911c5752f605e21f7a38187d8acc5b19d2b271b` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-diff.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-mypy.command` | `158c7b7c1dd693d4ab3195fcaf9c0fb3aeec627424308524bab69c711d4629ce` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-mypy.log` | `f9b031e5c45aa702cd4fef028d465551cb20a2c4698e0913c7b00766b20ac4d8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-ruff.command` | `1d19de590135c9679ff18af85740df833a505ffc34beb25326c85f4fb62929c5` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-workflow-ticket-docs.command` | `2554fbc7fbc83f5b449365ebd2dbf8482ca42c027460477d5a96cfcc846a9fe9` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/final-workflow-ticket-docs.log` | `67e55c81a382295667a69f0d840f7ea36fc9ce2b6599a2719914640832749957` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/frozen-preservation.json` | `a1e744131cfce2216e87c24f5c63a0f064549b1f1b3b11fe5ab2c0706351b931` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-complete-authorization.md` | `ba47f2ccdde5d2276b5db473d26225f1262b3bfb7af16fdea69704cab540f945` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-complete-manifest.command` | `86a0961d1b389f68a5255032ae32010f77139fecf7c978676e88a29bb53bf60d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-complete-manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-complete-task-input-manifest.json` | `6447ea987d1b2456966bee42adb11d765cfbcefda2f07e91ac51a94d32871a68` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-final.command` | `978e6596b8f6e7c5afbee86e95fd2cb3cd0fcdd0114bf563b15b4bcb5bf43b65` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-final.log` | `2ae8ccfae2231e5df08764a92b7d49f3018d492419a387e978ecad5cb32a0dce` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-manifest.command` | `63993090e57c1ae01b642ad4192e1af9813baca6114f2f79567f7bbc158ca930` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-mutation-audit.command` | `10d613a61495fb258b92e98bdc5e09844aad7ac36f87c33538b0c4d1258a9101` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-mutation-audit.log` | `0a0b9a9bfeb86e988ba18123c0987baa3783605a93ee13077020ad73e37bd878` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-mutation-audit.sh` | `545dc5799303d93c76fc898398c82aff20899407e712ea54b857ffff3212aef4` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-preflight.command` | `978e6596b8f6e7c5afbee86e95fd2cb3cd0fcdd0114bf563b15b4bcb5bf43b65` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-preflight.log` | `be788a2c32839446a8e66b94609b3532a3853c2e278bde0c6181c84f917c1aa2` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/host-supplement-task-input-manifest.json` | `4be114951aca15a39870e1b11498f6efdf141d775bd5d58f9aa96ab7460f9108` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/identity-binding.json` | `153ea09f4bdfb3f649c2e25898821588ddf3fd74b3b8f4bf4ea245d3a1fc208f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/input-snapshot-map.json` | `6221ba33f84a93d9644cc766a51217fa9809d1fdfb0b2536179c35585d61de00` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/inventory-rollback.command` | `a6312541f570de7daab662d775f9d1aa5cfd151be2990004517ec845d1757c9d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/inventory-rollback.log` | `405799915cd3ebdc5ecd06146cb59595dc6baca7addb32c0ae2664c0aa0a0d09` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/inventory-rollback.sh` | `55ce0b29d65a04abf7fe0b52e1aacb890ae9703419074014eb9464c7a3e824e8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/js-syntax.command` | `b6e61814f9e4cfb5dc6b8c928ab4e030c3a3968920fc9e81ef66b417b2e37a63` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/js-syntax.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/last-static-mypy.command` | `78b6be4e69153551b50cace801fe3ca83145c2132588ff92b78deaf615906822` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/last-static-mypy.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/last-static-ruff.command` | `727cd69ab5a9e463d170f05547e37f5c06ce7c4c01971a068472844336b216fa` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/last-static-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/links.command` | `0dc88aef196d5d7245d9c30e2a5a286a97fed3e9f2452a9af621150d7bca90fe` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/links.log` | `154640ac97ab3c2b325a1ca15a55b6553efe3f93ade2abf6aac0fcd942b095e1` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/manifest.command` | `10b3e10d894d18605de9566d6b24a7181e2644eb8c92503667b271b2c44f62c1` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-dependencies.command` | `27bed2527786b8457162723c7ffe6146e4c183c810d1489224cf5973c12bf9a6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-dependencies.log` | `2b699ffb47419807fa260e1c43c2b72b6c5b5f027ee25a29706df368c7a19b38` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-final.command` | `1852f1990cc2c357a0d65d66d7df61b8bbb4c80e19dfd8761e487cd91429f32f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-final.log` | `57e8612446a7a020bd619e0e3a6975a9e7cc5f8985538289a124426ccbca0128` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-full.command` | `1852f1990cc2c357a0d65d66d7df61b8bbb4c80e19dfd8761e487cd91429f32f` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-full.log` | `e05473e312753aabbd6e5af24d7225a180af7f606374bdf9d7adb571065b47ce` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-typecheck.command` | `0764f5d8cc1787638560f39aece855e6e9c27f3b80a7ae77bdc12d0c71072ea0` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/mcp-typecheck.log` | `c3fb6b341c1dd8055671bf668496cf9c991cb9a51baba33c6863595b0d05dd4c` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/model-candidates.json` | `728ca805f6b788814db189916e748407559d65b09923e28c49741e76095b4a71` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/model-selection.json` | `c57a944a43caa36d0484e81624b667b25a5ea3db2f3666e98667065b1914a0f0` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/native-allocation.json` | `96e5d66a93afa08aba84770914a14c2e8305f8f19bfefcd50cc2a52ae71486bf` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/preservation.command` | `808a3e0c16417620e6d3535a0bd4d2d6f04c1aed6dd05bb75db31a06c3f9d09e` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/preservation.log` | `e352f151d996e7dce0da1f2b47c2f18fae946c1180d028b5261932f6ed028d8a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/prior-cloud-protection-delta.patch` | `789dcd7da9664185b310bbe779ba2959ee3982748ef22a243a3c687a9a625e44` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/prior-cloud-protection-gap.json` | `76bacf2abd6bfb524732e7b812616602d04786995925992b2d8e0da347cc93e5` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/record-command.sh` | `eb12ec83f3f11f78538070305ab10b23e0da7f9a74341166db00af5f5d52e856` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/release-gates.command` | `1cae82df61dc7a65f589d68e88f329c5361ecb18ae265ed5a9d5b8c9808c4f16` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/release-gates.log` | `eb4272cd3f6545c1f08a52e4b800e800ece51463b42c5ad0da52d4219ac21cac` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/report-validation.command` | `15b7fdc573d962ac64d956d0fb0d9b3e9173b2aa5342af8e1ff22e5cf4315962` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/rollback.command` | `00bdb1fee4db96b5b4a20fc18b54d0f5dbb2a08dde4187c888591fc4fe055c01` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/rollback.log` | `45261152817b2c2b8acd19f5be55a41860ae236cdb488040d29dadd50aa1cf7d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/rollback.sh` | `7273f3e7a6fc8a367bc9f8763b11bcacbca55914fa5b0a3e0ff8e46adc6ab194` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/root-additional-ci-feedback.json` | `c9d5e00c7f870c42f43781024b2813a69c2c8a99156db61e7ea3d3a24ecbeb86` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/root-cloud-classification-feedback.json` | `c23195de9a0a95d0d904f1c8eda738359f3cf3a4cdf151210ff7890cdbbab4a8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/root-complete-protection-delta-feedback.json` | `f5cd0ab07f45b16a3007040e626062fde25c267ed033b7d970a14f15850951b6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/root-host-baseline-feedback.json` | `51de2df5bde1e5c1080bf2b5c8f95b403adabb6a5cc4611ff5d3162c67924670` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/shell-syntax.command` | `369e5cd76ba2103efd7741ec7f6195c0ab26f10c7e8fe104ae9f87acd1281088` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/shell-syntax.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/spec-revision.json` | `115e7fcce2d87a9fe8072f790073292a3b1331323562c07e4befd08e90eb0175` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/static-mypy.command` | `158c7b7c1dd693d4ab3195fcaf9c0fb3aeec627424308524bab69c711d4629ce` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/static-mypy.log` | `0acddb3d33939fe40f8b6097f03a42a005d9f707e82d3214003f72a2e494bff5` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/static-ruff.command` | `1d19de590135c9679ff18af85740df833a505ffc34beb25326c85f4fb62929c5` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/static-ruff.log` | `e262a7e7e2f98c87f20e4e2a4f61f71f7396a26a352608231e213e4acfddcb2a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-manifest.command` | `271590be6f14d3a5ffabc137c19581b33607c3849db66199e9af68f7eb731339` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-rollback-final.command` | `e3dc17625ba13372bb95c414c87d3655395578bcf38ccd6d55a1bb10c847d832` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-rollback-final.log` | `6299447a610752912743da6f4fcfdbef2efaa1ef09cd843f446be905ad80d8e8` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-rollback.command` | `e3dc17625ba13372bb95c414c87d3655395578bcf38ccd6d55a1bb10c847d832` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-rollback.log` | `e56b5e77544d779cbd55b4721480f653c9985dc9adfaac23997fa5852efb0abd` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-rollback.sh` | `9bed0a0a68fd936339174e5a6c2d9a6e89fbd30497c501eaea085b19f8df5241` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-scope.md` | `074f0f46820522e962b3f0b5def990e4f1206023671d0ed97b4c41f3d7b797cf` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/supplemental-task-input-manifest.json` | `79b48327d1c8c103e153e130678287b265d9584dfb3f7ca42ab6d495b375c8d6` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/task-input-manifest.json` | `f67a0f0fce8369a79f5fc0f2720335ea51eba1bc034fb70944ef7d6c0c8848de` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/ticket-id-aliases.json` | `b7ea3cbd6a619cf2d776fc1f30715fe6e3aa38a63a2fefc7149541387ac4352a` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/ticket-id-sweep-before.json` | `ca5e7a3db0246e44d2fef2fcb8442cea120ffa165a3369af08865836db25ff45` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/tool-versions.command` | `dc53ce044aeabad1efdbbbba614dce2476ab47aecad930789b1d9c9b721cc8ff` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/tool-versions.log` | `e91092df13599f82fb398cb27b595a2bf57134ca6bc6f8de2fb415fc1979dd6d` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/workflow-docs.command` | `625f1d4a22175d8da04a4ec7d806e96598f588972bc63b2502e9f239a98f2375` |
| `specs/cloud-orchestration/verification/T-008/attempt-2/workflow-docs.log` | `669574b7c4dfaec0436809bcabba0072d7a66a5d1372f77fac8a928820397325` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/a9-candidate-failure.log` | `87fb0609ae1215838c2b58f73b5c4316b37146b0c0c50e58b89ee47ec2ca74ea` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/agent-model-routing-failure.log` | `34d41c24e78962deea268ba9a3fbf13615170fedab883a5f00496b2f42e4397d` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/anchor-inspection.json` | `e324e320ac76d05be0d49250c6992d1191bcc46811703b2e6d6e606e0bdb7ffa` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/host-protection-baseline-failure.log` | `93ab386135c2d62efe59e905c8b9cf1c820aab82caaedfb5efb9ea228ba11c67` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/mcp-linux-annotations.json` | `fb2b0891bc0941c9909964889b0aa5fc69a7c7056951199b43a248a6b36c7323` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/mcp-linux-failure.log` | `131735a6c9bfe04cf3bc8100354ef551186ee2d31167b9ce6ecca0f386ee6f65` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/mcp-linux-job.json` | `0c39bf4a1b87a216b6de0f0dc5e6e468f0d1273a6899677d81ace3ee840df14b` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/scope.json` | `22b4401aee4d8db291fdb90fb10c1be0174e55a19acb2f5eb8c9b6e5ad765ce1` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/windows-checkout-annotations.json` | `afa2db1d3aebe8699639870339a44a9f45e86e5e0d9299127b0630a70b0a1cb4` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/windows-checkout-failure.log` | `062dffb98f2a20ddb5e0e042dbc611fb3b1f7f77a0d58861d53ee5f06f988e65` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-1/windows-checkout-job.json` | `15aea78d29598a891d685623a4d03ab0b3ad8d990c04f87582135839e7681644` |
| `specs/epic-197-a9-dogfood/candidate/project-context.yaml` | `57178adcee2d11ccb8660c6127cf395177ee9129cd25a2e19557c1f95f50cd10` |
| `tests/a9-advisory-evidence.tests.py` | `a807a300059619afb95a7babddb4ac810fdd31050377064162b36098cf21f706` |
| `tests/a9-dogfood.tests.ps1` | `df36e6c30a8d72fa16caa957e9a03ff0f369a5a9595aaa23f85657e44de3bfb2` |
| `tests/a9-dogfood.tests.py` | `366d90bc9aaf7ff386d971410451ec066e42ad6cf8a2253b66959911882f7cba` |
| `tests/a9-dogfood.tests.sh` | `029920ddc66c05c34f68661c9dad4d434134c8b518aed620d26123896a936736` |
| `tests/a9-promotion-admission.tests.py` | `d838d295cdfeb1d1bb854ef09455de1c0e56e47d1f80b91cee4d0fe77899a394` |
| `tests/a9-rollback-receipt.tests.py` | `88c2ac41f0e2bb011e434e66bddb49dbe8f15fbf42e0544172e7b2fad2972234` |
| `tests/agent-model-routing.tests.sh` | `db805b44a8529b6f066fdcc14f90af20f0b0bd95658294b4406ac64d6a12b69f` |
| `tests/fixtures/live-host-proof/cases.json` | `7a977b6a6c2e9582af4ce6c05da7c275a348b5ee296caafa88b30d347a588c6b` |
| `tests/fixtures/live-host-proof/issuer_cases.py` | `b4cb7ef06e7b8c3ee0ebd0ede33c53d3a0f5af5b28887dc817523e12dc9c84b6` |
| `tests/fixtures/live-host-proof/known-synthetic-output.txt` | `bf66a7588c2bceab5e68d72396d0c362212450ff4e11c0fc3a45380ff10d2c14` |
| `tests/fixtures/live-host-proof/known-synthetic-request.json` | `48c736a26121cff55fc48ad13d89e4be594aaf138a67aa1debd60a4a0e678780` |
| `tests/fixtures/live-host-proof/run_cases.py` | `fba9a2970b6e2d25a801254cf57e822db97d8b1372411742aa5db5981fa1415b` |
| `tests/host-review-preflight.tests.py` | `b2c1c8a823450a29268087ba42af57972904b3f2dfd3c089c9b270a65f6a09f8` |
| `tests/release-loop-gate.tests.sh` | `eb81d7c2646ee7a181f643d0de6523b7e1cbdd3563bf64b13b6618436082b824` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |
| `tests/workflow-documentation.tests.sh` | `6e1b9eb8a5a3d1ced77e5904c2b13da16f367ad1f9eab87b513d68cc36cb5299` |

## Test Evidence

- **Test Command**: Scoped exact commands in specs/cloud-orchestration/verification/T-008/attempt-2/*.command; exits in check-exits.tsv. No whole repository suite.
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-008/attempt-2/check-exits.tsv

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/T008-release-01a1505e
- **Run ID**: 01a1505e-4688-71b3-9816-af65b714a220
- **Session ID**: 01a1505e-4688-71b3-9816-af65b714a220
- **Agent Instance ID**: 01a1505e-4688-71b3-9816-af65b714a220
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Scratch Root, when declared, uses plain text or exactly one balanced
single-backtick Markdown span for the same path; malformed spans, controls
and duplicate declarations are invalid. A quality reservation additionally
requires a canonical absolute path with forward slashes and no empty/dot/parent
segments. Do not edit a frozen report to change its recorded root.

Fresh-agent reports MUST use `None` for both fallback fields. The only allowed
fallback is `same-session-file-reload`, whose exact reason is
`host-does-not-support-implementation-subagents` and whose evidence is a
lowercase 64-hex SHA-256.

## Regression Tests Run

Before edits: existing MCP real-repository ticket test failed on twelve IDs; local acceptance found missing workflow environment and both broken fragments. Existing model assertions and current A9 ownership failed; host baseline failure reproduced. These were executed acceptance failures on existing code, not newly invented historical Red tests. Hosted Windows failure on frozen long path and Linux failures are preserved in root-release-attempt-1 (run 39155983283, old exact candidate).

Initial scoped Green: MCP tickets 9/9; full MCP npm suite 297/297, no skips; real installed npm dependencies and typecheck recorded. Parsed workflow differs only by env; Git config reports command-line true in a new nested Linux fixture. Documentation matrix, 122 file links across 23 current documents, actual two heading fragments, workflow docs and release-loop checks pass. Initial fourteen-file rollback in an isolated checkout gives candidate pass → restored failures → reapply pass, including the real MCP tests.

Supplemental checks, final static verification and rollback completion are recorded in check-exits.tsv. Intermediate A9 development runs preceded later caller-authorized classification refinements; only the named final groups bind the completed repair. Earlier static failures were genuine existing diagnostics (61 mypy, 13 Ruff); corrected without suppressions. A scratch helper briefly shadowed stdlib types during authoring; that setup error is not mismatch evidence. Both exact configured final static commands pass for all three changed Python files. No MYPYPATH is required for these local dynamic-module tests.

The five-only host addition run genuinely failed at the preserved unrelated digest before mutation bodies. The caller then explicitly authorized the exact eleven earlier cloud protections isolated in prior-cloud-protection-gap.json. Final host suite passes 21 tests; host-mutation-audit.log records all 32 actual remove/duplicate bodies for the sixteen cloud entries, matched count controls and arbitrary-extra/unrelated-field rejection. UNRELATED_SHA256 is unchanged. Both historical Git deltas and the failed five-only run remain intact.

Final counts: MCP 297/297; A9 candidate/Pack 32/32; promotion 36/36; rollback 34 run with only the native-Windows case-alias test skipped; advisory 28/28; host preflight 21/21 plus 32 audited cloud membership mutation bodies. Supplemental isolated routing/A9/host rollback all give candidate 0, restored 1, reapplied 0.
Final scope command results: a9-classified-final=0, a9-promotion-final=0, a9-rollback-final=0, a9-advisory-final=0, supplemental-rollback-final=0, host-final=0, host-mutation-audit=0, classified-mypy=0, classified-ruff=0.
A9 rollback Windows case-alias test is not native-tested on Linux. PowerShell publisher controls run using the required workspace pwsh path in the final groups; earlier unavailable-runtime skips are retained separately.

## Specification Differences

No frozen specification changes. Caller authorized the current-tree cloud inventory and consistency updates in this task; current-inventory-addendum.md distinguishes them from historical nine-component A9 evidence. Publication requirements are not deemed satisfied by local tests.

## Unresolved Items

Scoped local repair checks and isolated rollback/reapply are complete. This does not satisfy outstanding native/live/release acceptance.

Native Windows long-path checkout/fixtures and junction coverage remain pending first real execution at next root hosted CI. Linux Git config visibility is not Windows proof. No whole-repository suite, exact new-candidate CI, independent quality gate, push, merge, repository release tag or release asset action was performed. Root owns those steps. Live TEST-003/005/009 remain BLOCKED on owner sandbox/IAM/budget/health prerequisites. Seven full AWS HTML copies remain outside publication; root owns factual JSON/source/hash assessment and final curation. No raw host transport/account logs are public outputs.

## Quality Gate Focus

Root should confirm exact allowed file delta, ticket uniqueness/alias preservation, all original workflow semantics and pins unchanged, A9 unactivated exact ownership, preserved unrelated guard hash and actual mutation execution, and all final command results. Re-run exact-ref full suite/native CI from the root-owned isolated committed candidate. This report is not a quality verdict or Done decision.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No delegation. Read workspace/contributor policy, Ponytail full, applicable ECC coding/verification guidance and implementation policies. Used standard Git runtime configuration and existing js-yaml/selector/ownership tests rather than new dependencies or relaxed contracts. No graphical interface or visual check applies. Actual identity binds caller-provided run/session/agent to stable native allocation (identity-binding.json); never inferred from inherited environment. Previous attempt artifacts and unrelated root supplemental evidence are untouched.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: Implementation Complete
- **Next Action**: Root final scoped independent review, isolated full suite, exact new-candidate hosted CI and authorized release sequencing.
- **Unresolved Items**: Native Windows, live sandbox and release publication remain root-owned/pending; no task status changes.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
