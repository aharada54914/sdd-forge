# Implementation Report: T-011

- Task ID: T-011
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 01a15001-1554-7b30-a10d-2104952bfd18
Task Attempt Count: 2
Input manifest: `specs/cloud-orchestration/verification/T-011/routing-guard-fix/task-input-manifest.json`, SHA-256 `23569cd11454d7161c2b900db7da4ae0e746c152e191b580c2a07602db3f59a5`

Supplemental manifest: `specs/cloud-orchestration/verification/T-011/routing-guard-fix/supplemental-task-input-manifest.json`, SHA-256 `7a0d692f4b36c9b7d09108bbbea608a0c52475d681827d6c5b34bc399834e5fa`
Supplemental manifest: `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invocation-task-input-manifest.json`, SHA-256 `de2db97af5960ab241c21df065b49d100d74dd95739b39c8c96dd0f8d5f039d7`
Supplemental manifest: `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirror-task-input-manifest.json`, SHA-256 `67fbba0bf635a1a076203e15c259df70bf4475db3fd92e2522940c1b1ebf1e73`
Supplemental manifest: `specs/cloud-orchestration/verification/T-011/routing-guard-fix/native2-task-input-manifest.json`, SHA-256 `18b071853274f7aeac64b236c9debcf0558c94e6956dc0d107b560c1c7c5f12b`

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / RT-20261018-CLOUD-ROUTING-GUARD / REQ-011, REQ-012.

spec_revision: `950f3369d7d8e3933cc30a3f149a6e70d646c0e4f94b803da7b20bc9153f4e32`. Entry Git revision: `2586bc3fbb7700ed41a55288c8f99e0531bfad2b`. Exact revision inputs and initial bytes: spec-revision.json and entry-snapshot.json.

## Summary

Repaired exactly the five missing cloud call-chain members in the existing canonical inventory and generator baseline; regenerated all four modules without removing old members or weakening the scanner. The two scripts/governed-setup.md files remain protected inputs.

Registration exposed a real invocation regression. The three existing guards now recognize literal CLOUD_WORKSPACE_ROOT/CLOUD_SHARED_RUNTIME_ROOT prefixes and Python's `-B` as part of the first script-input invocation, while scanning every remaining token. PATH/PYTHONPATH, mis-cased metadata/flags, preceding commands and protected output operands still deny. Provider/helper/skill bytes are unchanged.

**Actual final parity: 403 PASS / 0 FAIL.** Twelve guard-admitted installed fixture subprocesses preserve route success and prepare/apply denial. Root separately delivered actual native-host trial2 PASS (acceptance.json and follow-up-scope.md); this is not an independent review or quality-gate verdict.

### High-risk field/counterpart/mismatch preflight

| Persisted field / claim | Counterpart | Executed mismatch / control |
|---|---|---|
| Five protected members | Public call-chain scan and exact generator baseline union | Original scanner failure; executed writes allowed before registration; JSON-only generator rejection retained. |
| Four generated inventories/source hashes | Canonical JSON and generator | Generated-module byte mutation fails --check; final exact parity and preserved old membership verified. |
| Guard decision/exit and invocation allowance | Protected target versus script input; same Python/JS/PS grammar | Registration-only 373/9 isolates actual resolved-invocation refusal; final 403/0 retains write/rebind/output/case negatives. |
| Identity, attempt, manifest/input/output hashes, spec_revision | Caller-native identity, exact scratch snapshots and repository validators | Bad input digest rejected (exit 1); all five manifests and report validate; preservation checks exact source/evidence hashes. |
| Rollback/results and preservation claims | Captured entry bytes and actual process results | Restoring nine code/config files returns 327/76 Red; exact reapply returns 403/0 Green; baseline installed bootstrap and generator pass. |

Preflights and failing tests were committed before corresponding implementation: `7e78a97f` (consumer Red), `822332d3` (generator counterpart), `7180cc35` (resolved invocation Red). See preflight.md, generator-preflight.md and invocation-preflight.md. The initial Set-Content fixture used an unsupported tool alias: those 15 failures are not enforcement proof. Corrected `shell` payloads execute the guard; no assertion was relaxed. Initial insertion, generator, dependency-path and pre-mirror failures remain preserved, not relabeled Green.

## Files Changed

Canonical guard JSON, generator, four generated modules, three guard consumers, existing tests/guard-parity.tests.sh; five checker-confirmed stale applied guard/test mirrors, their existing manifests and refresh notes; this repair report/evidence only. Python guard annotations and local optional-value narrowing make the required strict checks pass without suppressions. No task/status/approval or original report edit.

## Tests Added Or Updated

47 new cloud payload cases run through Python/Node parity, real Bash dispatcher and PowerShell: five protected paths, writes/read controls, canonical/environment invocation, output/rebinding and case negatives. The verification addendum reuses existing installed-provider fixtures for 12 actual guard-admitted CLI calls.

## Outputs

Changed files, tests, unchanged dependencies and stable evidence; inclusion does not assert an edit. Private native logs and this report are excluded.

| Path | SHA-256 |
|---|---|
| `.agents/plugins/marketplace.json` | `dd4a8d5efb2d2f8eb5918897d9a499b4e532ec5654bab2fdd539500c5eaee36a` |
| `.claude-plugin/marketplace.json` | `dd935489bca5a357c90eec68081717e451c1d0b0b5f807f33b6ca8dd3b216155` |
| `.github/workflows/test.yml` | `48698cda10fa3d2ae083368fdc378f3def72271eeeb074f290fc63aad0f4d27a` |
| `AGENTS.md` | `be21577343b8b2cc488c47b373ed68130ded00d994f58f1f81b7b69bddd6d537` |
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
| `contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `docs/adr/0036-thin-cloud-orchestration.md` | `d67248086011bcabfe482073b33d25bc39f066fd0f3763ee88bd70ee902656fc` |
| `docs/contributor/shared-file-mirrors.md` | `b9406eb20abf5732c26987fc71bfc9163aa175174b7e43e6c100f74fdb388cfa` |
| `docs/review-tickets/RT-20261018-CLOUD-ROUTING-GUARD.yml` | `0c6905dea943f946854120116ae410b80f1b087f240eaca7efc2917b0be57cf0` |
| `install.ps1` | `2014193f4e31a234b0336087d434ed12d0f8d7f73ff87bd8bb9744c158ac42a7` |
| `install.sh` | `7827514addc02f00cb671d7963b8d70c80327113ea1bae5fa694bb69306e6f3d` |
| `plugins/sdd-aws-cloud/.claude-plugin/plugin.json` | `901affde1f22fd7f03420455ad247b89e6104a090940113e0d49b9024229642c` |
| `plugins/sdd-aws-cloud/.codex-plugin/plugin.json` | `fbaee91e13ec9a1fb202d9505c27e519f09655cce0fcb1ab266c85a1057aebec` |
| `plugins/sdd-aws-cloud/.plugin/plugin.json` | `2cef9f5155320fb1164da6264f47b50c71800dd95663cfbc7bc53cda6e6e2773` |
| `plugins/sdd-aws-cloud/examples/private-ec2/README.md` | `0caceb7832a0c3e467042a760789f03a47521eaca375e712ea15120931e2ea5a` |
| `plugins/sdd-aws-cloud/examples/private-ec2/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `plugins/sdd-aws-cloud/examples/private-ec2/cdk.json` | `7802e394180f0d618f4caf7d1a6647f406ad327fa0aaa38c84b8b6b8471b24a5` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `plugins/sdd-aws-cloud/references/aws-local-config.schema.json` | `1d8d1f63b8f2ff4836058d928752c5322b744727e03b14d2e34e1ec6b9d25f22` |
| `plugins/sdd-aws-cloud/references/aws-local-evidence.schema.json` | `d64402c81095bd9a0657d34f4723a02996d91bb93cb0d0906c4ca288aeaa3187` |
| `plugins/sdd-aws-cloud/references/local-preparation.md` | `2a890269fabb6128f125f5533d3eb4c6411589ca0d0843b642b47cc959f7a257` |
| `plugins/sdd-aws-cloud/references/observations.md` | `b474f3965405b3b5883d8550300aab4ac830261b14dc9cef615d47543794a748` |
| `plugins/sdd-aws-cloud/references/toolchain-lock.json` | `c46bafb8869840c879739f424746eda64ca6c62aafab906d9e98012dee7c3f5d` |
| `plugins/sdd-aws-cloud/references/upstream-lock.json` | `1898ede044cc25e0fba804077559544f5f58e9e323d8d0701721b8545cc97766` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/SKILL.md` | `af178f8e909efd66496b09c7301c5e11ef96681fd62bf91406dcb340a18aacf6` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/bootstrap-and-project-setup.md` | `ce48bf13921481aa6d2df131f0bd32faa8cc07bb50b63b1805ddbfe6ca18a5f0` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/compliance-and-drift.md` | `4d576be561b16fd140c7f44de3b905ca81718752003a5072fec7062f2a2e782c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/construct-patterns.md` | `029a6450cc738c220051c1e2df94cb08e82b9fd80b20ab6b1b31696015222d6c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/fast-deployments.md` | `b6ddc7a418ed0d2f6e450c1835e3dc83c0648cbcdf4b582ebd66234918b22171` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/import-and-migrate.md` | `375e247190c3ebe29b2b8b211f665d4f463c7d959d3a6a067f8816d1a5df3a26` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/refactor-and-prevent-replacement.md` | `bdc1dacfaaaef810923699fc19803b492815b404190f055f90bd3558587b335c` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-credentials.md` | `87b36861e1cf656fdb576536c20c61dfff5316e1b7465954f9b1b01cce0f0ee0` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-deployment.md` | `80b97fe332046fb025cf6635b3add76046bf9b2933bd45394255585f1694a967` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-synth.md` | `1397f0c8034ccafd1353c3053d119e721c4904b9dc2ba33a1f285f69bfb909ea` |
| `plugins/sdd-aws-cloud/references/upstream/plugins/aws-core/skills/aws-cdk/references/v1-to-v2-migration.md` | `f88efb1a4b7451fe194e5c617ea2c467be93ecaa7221264b80361cca035dc181` |
| `plugins/sdd-aws-cloud/scripts/aws_control.py` | `92842d7174dbb0bc8ba3ad796fd8a3bd7f46ed91178dfa80bbc6558762523d67` |
| `plugins/sdd-aws-cloud/scripts/aws_execution.py` | `69ba7b8b9fe43c1ddcb0a7af0b38f2c5f60affc7e86d02c3710e8a168b5974f7` |
| `plugins/sdd-aws-cloud/scripts/aws_governed.py` | `94f9f9c07aee2de6bb1e7229c0244cde7423441d59b813cc8c426e2a71943ff0` |
| `plugins/sdd-aws-cloud/scripts/aws_graph.py` | `21896c758e64f5db7571c2c5209a4ab122cac8347dc18096c29e79f7396a42fd` |
| `plugins/sdd-aws-cloud/scripts/aws_local.py` | `82bbf762e80d62abdc77b56f850729c72d4ae83c3e59f4de09751867f16e4b31` |
| `plugins/sdd-aws-cloud/scripts/aws_native.py` | `1e2ea86be1852796c55c3858d40bef1afbcdc0594a95b0b160d88d1e5c817855` |
| `plugins/sdd-aws-cloud/scripts/aws_observation.py` | `6c42f914d8c1b959542da30d614c673f50a78987b7dea95dd6638ac476420c81` |
| `plugins/sdd-aws-cloud/scripts/cloud.py` | `167b3e37e88a5ab1c32344e226823ae0e9d1518d7927a7ab4221422a011cc933` |
| `plugins/sdd-aws-cloud/scripts/governed-setup.md` | `2bd8c9b4ddcd7d9879a5b58d1e7c30d4d9c8c0286501b6b4d066eaf967712578` |
| `plugins/sdd-aws-cloud/skills/orchestrate/SKILL.md` | `27af791f755d21eefbf817dfa7e9b11b88fac34b075dbc3f413c1f20a163845a` |
| `plugins/sdd-azure-cloud/.claude-plugin/plugin.json` | `53b2dc69739b8035499407c40318599557e6773bc0d64c2e627521f602e2bec3` |
| `plugins/sdd-azure-cloud/.codex-plugin/plugin.json` | `72994a2916deec39493318312a22b21a7e81a643577fdc9f70e595d41c0c3b07` |
| `plugins/sdd-azure-cloud/.plugin/plugin.json` | `b8a3c04ec499f65f81494958067cf946c719f506e71464e56e4c92d015fe4c14` |
| `plugins/sdd-azure-cloud/examples/README.md` | `18d4bac06d053a486ab77936c75cd7e4f0824fff90728431cbfdf7f89d9cc873` |
| `plugins/sdd-azure-cloud/examples/private-vm.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `plugins/sdd-azure-cloud/references/azure-local-config.schema.json` | `c8390b8b18bf5f4c5cd961892b78f0d3d7f08641d14ae5052f62fe17f795fc3f` |
| `plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json` | `e4584e317609585b3effc865412757ef730448d814b2ce7f78eebf485728b68a` |
| `plugins/sdd-azure-cloud/references/azure-parameters.schema.json` | `5922b55565b1a506db4cc424560cbfaa0b07766f1e26bf50dd4247ade18fc3ae` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `plugins/sdd-azure-cloud/references/observations.md` | `e356a56677f3f26ada8f507c8fd2f90d06e28b9204e3ced96c13df0fe789c9f7` |
| `plugins/sdd-azure-cloud/references/upstream-lock.json` | `f7e22249f21c062e6207579460b1ad1042af52e4eb619d8566fd4d99db675644` |
| `plugins/sdd-azure-cloud/scripts/azure_arm.py` | `5ee98cf0fde60b1d8e9959cf17e7eb6e53fbaf179104ad0e080b849f936cff86` |
| `plugins/sdd-azure-cloud/scripts/azure_execution.py` | `cb8b14a85e305431aaf80eb568620aeb42b724aa13f485251338f9bde70c360a` |
| `plugins/sdd-azure-cloud/scripts/azure_governed.py` | `c919c2fe44f462db08ccfd5f766b7635ae3e9eb4bf416bac96e2c9ded1509bc8` |
| `plugins/sdd-azure-cloud/scripts/azure_graph.py` | `f46bdc77c12449d0f4befd0221b29687e7b4f48685cc6106080de62b3a4d075f` |
| `plugins/sdd-azure-cloud/scripts/azure_local.py` | `43d37a2ec9ae8e5bfc60690480c7ec607237b03b4c3d6fbb7f1e8d2ee7792f10` |
| `plugins/sdd-azure-cloud/scripts/azure_observation.py` | `4b56fcba4f3017eebea8e97c565e2df8a3b2691f8cce21478dc7bdf7819bc8b8` |
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `4ae02ced280a8267a99fbd18b92d5fbd7a61b3d3e64c369b02e02c63c15b5636` |
| `plugins/sdd-azure-cloud/scripts/governed-setup.md` | `b2f038ab953175e2fab863d5cc8baada77a79c0b8cef1281df68142831343388` |
| `plugins/sdd-azure-cloud/skills/orchestrate/SKILL.md` | `5a906f317b352c84f1b38f39464f585ce66f2261651079a6c79df528a6c774e2` |
| `plugins/sdd-bootstrap/.claude-plugin/plugin.json` | `8a8bffda62ca60cbcd995a61895b661fb9092ed9bdddaa0816c767a583fe9b21` |
| `plugins/sdd-bootstrap/.codex-plugin/plugin.json` | `eab6d07fd3af9c1515ad1319af3d0f5675c9631060d9ae27a58439f06db0c474` |
| `plugins/sdd-bootstrap/.plugin/plugin.json` | `06332645cba0d780f671f9df1f03bbc281f0ff387950395ab926f37822e21e12` |
| `plugins/sdd-bootstrap/agents/investigator.md` | `cf1e6b4bd3cbbb6a3dc767413443677c12a70b9faf2e9608cc402d3cff9e8e0a` |
| `plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md` | `6d3a714ebc686860b9407410033b7ef1bfb21d8df70cc93b11b1b00ec0b02e3e` |
| `plugins/sdd-bootstrap/rules/architecture-constraints.md` | `396ae779404da4c258e58d643fa0c25f154151a2d4c40c654c29dedc24de4af6` |
| `plugins/sdd-bootstrap/rules/spec-conventions.md` | `cdbc0a30067f146c10b2e4f97f130ffc5647fe837a91204891aa77a77eaf2f63` |
| `plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1` | `8e7feb31aee85b13e72ea13752405739afe93081b9ab5edc96deea6acf636e2b` |
| `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` | `0c3d60174684beb5796d4646b47c2d9e7fae0827ed548fcad0132b13703384fd` |
| `plugins/sdd-bootstrap/scripts/cloud-routing.py` | `2d20361ae77a726118b9cc565cf9c0bdb720346b5d8507c5e820fc8a7a80d11b` |
| `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1` | `8bc772740d8edd9998697c1e92c6b421f65772b44b0a7ac39bca7ad2e888fbce` |
| `plugins/sdd-bootstrap/scripts/design-sync-scan.sh` | `cd86b9c11d472cb3e8a9855849b183c2c078873640220beb88b507e0dba0080d` |
| `plugins/sdd-bootstrap/scripts/resolve-design-sync.py` | `6b3f6157366ba5d00977a937e0f1bb4469f3a4e8b682e60953607ea972141422` |
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | `9d78e75b7c98aaca5a4ef2ef0727b7924be84cf79346f327ff03c931a2a62000` |
| `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` | `c8e82741a7bee882ea837813aa14becd52c83361d49f833212add5a968d3bfa2` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md` | `4e33234e370bbdf873cd370c90743172f86cb333f526667a7ee3a7a4714f6174` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/references/investigation-policy.md` | `3e41d23227500a61429576c5f0750bb091d3a79aacd30383d035d511e1f22e32` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/references/spec-id-rules.md` | `bcf0823ace7f536f06ef2e8eb5355a555b8bf35f27fcae810669237ae4b1375d` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/baseline-behavior.template.md` | `ac455342b0c899e140ad35f5313e9c429311fc389620c0fbabdc8364e787251f` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/codemap.template.md` | `67b189171aa3254990203a81485c47193fc991aa12d86e02b10aee3c7ef030e5` |
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md` | `076acfd232ac4e1dc608c107115c2fa9b05fed3414b0313c7b6d414b74fe4d0c` |
| `plugins/sdd-bootstrap/skills/sdd-adopt/SKILL.md` | `4f2373243ff346a8594c5e2810b243be6e182354b46b1257b99a8356fd4497ba` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` | `91489f9fffc419f706e44cacfc6f93d7b6254e54c91e146a6b52e0a2d946fe5a` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/api-contract-rules.md` | `923bfbd58c94d7f3b539d922208dc21cbf1f85f6463bf3ca7fdad05534602efa` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-review-checklist.md` | `fff699c1d03fa41f016b3abdb543e3df0f4c85691e0211e1d01b60093f75c20e` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-rules.md` | `c8f642d466f4f871cce6fce1aa191544cb94f0f843e438ffae66e946d969434c` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` | `08990f38c953f07dfdb306cf9b6533a38a3ecc40a0dadb349e4dd429652d9ce6` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/interview-question-bank.md` | `0e92f2f9e1095e5a7a5d2fd1e8e9c3eefe63a6d371702f7f0236e28a06b9cffe` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/phase-quality-gates.md` | `c16b2ea90340a78ba9c31df205ae2805a2488f205278e161baa108560c93e4d7` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/task-splitting-rules.md` | `513bd19153ccb80f8fef74b74020bdf5262ca0f8b9d1e3e6f89a4ab13ed1d1bb` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/AGENTS.template.md` | `b66529702696bae80e073403611fcda95b4b812b33b7c34afe91cfcad93d54e4` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/CLAUDE.template.md` | `af0d4c442611862fc0c54d4130884d34cbecc7dd9eda44e5984a727313eb8392` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/acceptance-tests.template.md` | `e4708bbd8ab0a390b970e4aa75d793feedaa3358ca6562c85963ae1dfb050179` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/adr.template.md` | `bf314041612335324a71f26b0eae9a62cb0755f4dbc1ba830ab46f6de11f79ea` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ai-task.template.md` | `adeaba316f174d8f66b31b30d8c48eeda76258d096ac501973f98426fcd809c9` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-component.template.md` | `c5f30e31b7f4ecc9aec207c98ac4dbfadd605989f7b3988a413cfe17fcd94bea` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-container.template.md` | `feb511c7c347df87a3be2c39df226e3b4c3ec403d592a902a1bcba839a5fa5ef` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-context.template.md` | `b84748ecc5b01d83281d3c89f5e3a5ce30e133c384f8f9a8b9df52d003cba25f` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml` | `02442fe1f63c43da36d8f13cebe125e88168ad306745b5cb9e1fa4e006fe7c2d` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-gitlab.template.yml` | `30e103e639fa894a616dfcf524ee81cf11c267ba568ddeb50b31d9b2cc3f3aa9` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md` | `5d801b9a47db7bc363e58c2c7609ed923255aec83ae74189460398a4c6c5f0cb` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json` | `76f526f7c65ed20df8cef5805fe2c10f69dd19bee21aea040049773833481ae2` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md` | `748f31b0136a2eae7ad8978ffb461ca749247408afd19217b73e93377bd95798` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/frontend-spec.template.md` | `63fe6069647d5ca1b1214eba31fd0c191c27d7baa80b01577122898955b59f10` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/gitlab-issue.template.md` | `3353fc7232193d9ca0468012ea8c9aadf991803719c4ae539d0c43cbca6181ab` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/infra-spec.template.md` | `2089374cb3779b968c3dd511881213a5f2de51dafff33c07bd9bb953da39f020` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/json-schema.template.json` | `b9ae488e11e017beeb36772b0ca4ae95c537f7e036864684990d38321efa18d9` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/merge-request.template.md` | `4775037002942ee46f6c748a0ded512530fc7357384a032d3d46f3893d1436c8` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/openapi.template.yaml` | `a051e4381f84456526cb7e496d0e72043a3bf9fd60d2cf0bfcb2b0615234fe5e` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/pull-request.template.md` | `ddc7214401358daf0422966b8fecefb4aac0d803016cb7bbe31f0bdb2b271cbb` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/requirements.template.md` | `903a725c445fac4505dfea3a3ac7aaf13b37fdb103ccffc1d1a6d1608dc940b5` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/review-ticket.template.md` | `b50fdb8320412c4b18bf3f55cbe724aecd9c3e39b3a7e0c6edb8d5f0e31c4ffc` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/security-spec.template.md` | `f006ec05c71b0fe5f4800659a8d2b31628698187748d9de0eeaaa84004a533c5` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md` | `2bf9c1cc5f3fbfb77220ab4d5e60d1db5002a01c72db227bf38d3e2cbb58fc42` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md` | `448ca507d5f1e98edd75e2994e8f2691622d88a695ff934e2623629260785627` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md` | `b00f27065467cdb5217022e9e80a3272b632443692f4fd177a4af57abae504fc` |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ux-spec.template.md` | `eb35a0c3da4d6a68bd98045a387d1dcac1ce929a7407c5fa053ee6312d43a607` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1` | `18402647758202f2a8c6bd87245cf7450abf599e6f94de09a4fb9255e2cf5a2d` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/skills/implement-task/SKILL.md` | `6a3bdc2efd1e8338a961c23e69240e27e5c7a366580d6fc3a1a532461a1b507c` |
| `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | `d0622d44f13693cf6e32c918aba53efbcc5089dbfbba8a539bec3be601017051` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` | `5f00ddf2765b5086dfc83b3e24ad6873a7e08a08d419126fb619adcc82e0beff` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` | `739173bcd97aaa185206b85ce0fc88cbee96e51447d0097a082fedead40b30e6` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `plugins/sdd-quality-loop/contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `plugins/sdd-quality-loop/references/cloud-verification-registry.json` | `de0153f09def1b805818f9bef1ddea065a30d3fee95e12f026bdaec40720d06d` |
| `plugins/sdd-quality-loop/references/debugging-recovery-policy.md` | `7b392649cdfa5d565df1e7fb37db0ee5ff528ee870ff3feb523bb57e1294254c` |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | `f0d7c2040db8760434d27d698b7b971a77c056125b209968286d905ecbfd459d` |
| `plugins/sdd-quality-loop/references/readonly-input-contracts.json` | `4527e0d33080d59c9ac95b89bc8e78b3d2932e897bd75b6688b388f830189fb9` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` | `b357a8252a7ece91161f1eca6ec6ba434a0fa9f45a29abf77efb6f90477ee0ff` |
| `plugins/sdd-quality-loop/scripts/classify-readonly-inputs.py` | `d62d3accc7fe28a3fe0ca0d6fd1ca739918d0b9878d3f6da05682523d0ee2238` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `17f5ffd041fe2d32657452093c76f4eda87b37fc5bf5d8504a1c6352eaac9658` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/cloud_dependencies.py` | `7974e7e9a8d7da0c60b219a58db54c4747f0250653fda3af0146091f1f4fb475` |
| `plugins/sdd-quality-loop/scripts/cloud_verification.py` | `b2488aa48d32716b270fd920fbf4b13f43cf19440e975b48721d91e38de62a68` |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `c4b619bf7729a3742ee807b1b2efd1debf7f440d88d142c070e193c236221351` |
| `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` | `26c20a6a62259b598851beea58070aa1ddf2918fda5048f7467380852d648144` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `3fface3fd9bd38dd3919dfff11ce290aa3d4016cb9cb99f44f0275a545bc5a07` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `b8abe09fd6f86f080d477b638918d74657c2295bf4f7c575c28cb63fa3c3bd3b` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `564080c31fdcc4cf2270017867f90ea6e0265de000c07b141a6788479830ef80` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `31f6e2444069de7473030d88387f649fc420d59c4e3e853692013fcd787ac5a8` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `e3006fd5cdc11d86658e6ba44ccff673aff61447c82f353754c2ab7e4bada8b3` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `9380b5f98bf24d595cdb4f81edf3b4ad3ec974a454ed1e2ce3a7c29dd17647cf` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `31935ccdf2fad222561c5bbcc548e39faa2a696613a987cc82e5b80f319075e9` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh` | `1def3bcac3db0e1b6f8ae859cd8ae13957e199e87d2c0e2bc9b3317f18e9e840` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `4aa0e97622b47687508e305b1832e182926d0595b7626180e5736b23e0ef174e` |
| `plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md` | `0215d3a6c097c893727276afc6078415cc83c3aa4273dc8bc62865bc3af6efa1` |
| `reports/implementation/cloud-orchestration/T-011.md` | `2956e2e48c00cfcb8b7e5380362ae9df7f6627bfa086ad9b987f869931c765ea` |
| `scripts/human_copy_mirrors.py` | `2ea93f1061101eb5de6cc6e6bb201f95f81cf8a28408ad2cc7c241ae912e21e9` |
| `scripts/sync-human-copy-mirrors.py` | `13e9572f3757325f21884b0a2d94e7ed2eabf98acc1078d915d3159acc7c2be9` |
| `specs/cloud-orchestration/acceptance-tests.md` | `4eb6f1a088bc175196ff6f9e33393b05190903e061186fe70cf4895f044f06e0` |
| `specs/cloud-orchestration/design.md` | `f3605c89c9522f3f167db695e2bbf2bcbe7e9e71c92610ff0032272b0bca5f89` |
| `specs/cloud-orchestration/frontend-spec.md` | `586d52fd577b5eaa24be9037f80fbc0334ab934906a9125ead71206eb8561d2b` |
| `specs/cloud-orchestration/infra-spec.md` | `9fcb3698f73022d60b8848785b05ca137620b97cd43586da63a0e75716bccf7d` |
| `specs/cloud-orchestration/investigation.md` | `38229c1b74b815780bfd752a353f1dc15bbcfeefa0285e4f8dc097721227f20c` |
| `specs/cloud-orchestration/requirements.md` | `31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922` |
| `specs/cloud-orchestration/security-spec.md` | `fe980874e34da14db58b088b0ae6f989a6e0dadc3a39757851457c0c5312e1db` |
| `specs/cloud-orchestration/traceability.md` | `fba885046c68ba92568e1360806a3402fd522e525aefb3f21e5b434018dcbcf4` |
| `specs/cloud-orchestration/ux-spec.md` | `d02d6d219266ca0b5c0ae9705a58e67b66682f3539ce2cd749e545abe5bad8bc` |
| `specs/cloud-orchestration/verification/T-011/attempt-1/spec-revision.json` | `8028f8748d8635ee2931e9baa8018e057021cca193595b9c3e4ed92418ab3367` |
| `specs/cloud-orchestration/verification/T-011/native-host-trial-1/acceptance.json` | `22efb3e699a5a207800145f075b7f902cf5d3d13a6bcfa7b0f2e1caf2f6d98a1` |
| `specs/cloud-orchestration/verification/T-011/native-host-trial-1/current-source-binding.json` | `45ab723ba3e7b0ad0f5aaab732a4148811678e8afb01ead1db6cbe7d91f2dd29` |
| `specs/cloud-orchestration/verification/T-011/native-host-trial-2/acceptance.json` | `c0fef1a742fd690f0fcafae228d5fccd174159351769992fdc455a1bf4e05d2a` |
| `specs/cloud-orchestration/verification/T-011/native-host-trial-2/follow-up-scope.md` | `66b88a6893e7afd0855591764b91ef1ecdb1fc7c6876e1257cb4fddd2e7ca463` |
| `specs/cloud-orchestration/verification/T-011/quality-cycle-1/regression.log` | `1e279dc393efb28f52bb7750d382f2b40857892ec1b91cf9d94ab40b081363c9` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/all-manifests-final.log` | `d63c7737c3870a2196d2b5073a479033cf79f27d3001028783bcf62522252d46` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/baseline-guard-mypy.log` | `46ecbbcbce8b41fbdaed25d3a63950b509fabb912c9d1dc058fdbe79c1d39473` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/bootstrap-cross-layer.log` | `620c4871a194c0ffa48cc58ad62cd9b1459bf9abaded9e9c84abd28444667589` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/bootstrap-interview.log` | `fdc162c36eb95a0d5ab9bfb76e45a913c7cd84df51639214abff7e92991634c7` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/bootstrap-layers.log` | `90eea14b7a2c707d1f0caf7425927f55a6c88411502486b930d94458dae89ee5` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/check-preservation.py` | `c6d555f4d4c113c91a449d78e0b135de47e6abd03ddb9506f9634be8e8f81eba` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/ci-wiring.log` | `ef78e819b99301480b55e85f322bdce84a0b981e668a6b40e21eb8382717c686` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/cloud-routing.log` | `aa15ccac9005075a19d12f100bb1c58bc98d6d8f53ac5dd8e62e4da584c0d348` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/commands-and-limits.md` | `d7dcfd59bdbaf21722012992ac19e1b33403c71480852025c6aff97da1b16214` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/delivery-manifests-validation.log` | `fd5c3d1fe5dec5d2388084bfcea2b222eaa9c880b5547512cb60f8b1ba766456` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/edit-attempt.log` | `2f3c855a612759451d20fb076200efd30310526e3fa5444edde73fd47ac14813` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/entry-snapshot.json` | `7bfaa336a6f0df14efdb1cc122931aa9e1fef0c1fed59d5a3070095d6ec0db01` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/epic-a1-invariants.log` | `9d2b3ce28719b37275a6bbde31c0d70e46307abbfbd2236596646a5e91bf44fd` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-bash-syntax.log` | `1c89eafadad7f97a1bea0734412ac4bc1d80d35c3f7b29da6bf6934a92cc84b6` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-epic-a1-invariants.log` | `ff1774188d517832e620e47ccd2af392182d19257b98f90f6f5fddc00f4b4cce` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-gate-capabilities.log` | `82c83b2bfec7aa5d9d877ab68242cee38c7fe9001ef4655556ea4cb301ab469c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-generator.log` | `6b28958d0bc55b63ca767c83e3ab3b52857bd8dcb6565307df8262fb94e10826` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-ascii.log` | `a169dad6f180a9f3290dcfda68666fdb8351b81714cf3f4d24a73bac3a97badc` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-cwd.log` | `ea9b8513a088c4f1cf7bdee546654e07849e9b4ee0a87c2ecd2377ee22146a8d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-dispatch.log` | `216e83d71abdd2aec6f056ba5d09a961efa76d9cd6b3004fd5c221a65382d14c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-negative.log` | `56b5eca25fadfd61725c18630676b364aad0f44514e735c2910ce8bdc8a40adb` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-parity.log` | `9576e230e74c24b4b196167067087ed8801eddd13615fcaadf2272cfda3a4faa` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-staging.log` | `26492a8a48489a851dba09feffc6e50e98c3088c8698141b980b2d6aa63a803f` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-invariants-bash.log` | `0909d3f526ac5a91a79cb06211c4d33e9ed9ac5bd5b9e02f5aa3097b899f5674` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-invariants-powershell.log` | `0f11c284bce9674cc978f824d82627b266bff8b4e18d64316d909418ecff3a17` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-mirror-freshness.log` | `47abb13a64a11680b00e106147e64bef80693515bc9a2ea655870998645c33a3` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-mirrors.log` | `4a2f93d60d3d9b5fc67b5648f63b9c579b2963463c2c829eae34790be0c63fae` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-mypy.log` | `701eec497bef58e2a1eba06baaca8f0727bd828c1417fcf28b3b810a2fcd8392` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-node-syntax.log` | `182a9cb49f1c1658f4dcdc563b30c876d93add660809f28c12de907f032a0e46` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-r10-powershell.log` | `abf7f0071e22cfaab2bdc9e9f1885fa6359e1e6630a8e873d92a30d880b5c98c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-readonly-powershell.log` | `3ac5b28bc4c7b4c76c0c201d5f43d3c916f25887467103c30c54c8ba7279bb20` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-results.json` | `5e46083c3d6faef58377aeb0770e049ff6551349543bd0bc05ceecf8df1c7460` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-ruff.log` | `43d6d782c008e19f85daf5f2b166d4f22f6662e61ab35eef77e13330ffed8a52` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/gate-capabilities.log` | `25685724162101ee5a917918938ed34e3f2a07420c2ee0d8782be1c0aab4d3de` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/generate.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/generator-preflight.md` | `9b01e1d931b31e41ebafd82108e220fd4fa8bbe3016bd81b03230433f686c3f4` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guard-ascii.log` | `b7fbce441d3be0610e64f376fc148b07b79feae86030968294fdd1bd382839c3` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guard-dispatch.log` | `10b445e2cb1948d512b7e4138dddf8f8f9e5c911895512a88a1b9e79ace557ff` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guard-negative.log` | `db08bc0dc9299ff77bc64ddd28af65aef02b20ed6363ee442d2aac4d3d2c9596` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guarded-local-invocation-tool-path-failure.log` | `362945f1d0b075a1e1bd0be80795bd94fd85cc151484a2cd2c6b4f6dda01e15f` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guarded-local-invocation.json` | `3854ea160082decf80b93682aa3748c83a17c207e1b6a390639ed0574d203ee4` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guarded-local-invocation.log` | `e5781d086d765124e9a1d1afd46f4caed2fcbf77dc28703b5402f879476674ed` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guarded-local-invocation.py` | `2afca450632e49cb4b83e139eb6ca01172c8271e9a345c91ed76f6abca77290f` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/guards-mirrors-sync.log` | `37e2442345af5101c4814e7e909cc3cc8c8c30f9657a1b74cea096d36dfae464` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/identity-binding.json` | `8f1390d545fff2daa037442ec1082c898f0eb2252b7d1c460bdbc50ba7d8e59f` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/initial-generate.log` | `1fd76985600afa57b4fdcb1da887c8db369a83abe9f47187915577123bcc3053` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/initial-rollback-bootstrap.log` | `b0ef42573dbb50796d787cf3b9e2abc3e07e268615a719cbd195e353978735c0` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/initial-rollback-generator.log` | `d8a25ac22f0b12fff80060d5ee67806be0001ffde1c0d9f3a64a960ceaa3ef6d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/initial-rollback-results.json` | `2f96715628c697b2d82000b191d6969f298b55ef1e4b86f74e2ebeed5123c335` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invariants-bash.log` | `0fd4dabc48c65927cd7057a6bad5bb6b77b8e141062988eceffd828447564bf9` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invariants-powershell.log` | `257ee1e6604ec46209c42d417d12e4c0ca4e7969093aa6ed99d6d6a66e4e000a` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invocation-gap.md` | `c6294eed340857483546efca33441388587652b717bb59ab108861d703d0c203` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invocation-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invocation-preflight.md` | `9f32e2b11c01ba27a469d589285316463c0252f25eaf1cdd4d25faeeca50ea76` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/invocation-task-input-manifest.json` | `de2db97af5960ab241c21df065b49d100d74dd95739b39c8c96dd0f8d5f039d7` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-green-guard-parity.log` | `ee3fb04d69662b201d5711350e779ab02b471d0303ed55a75dd9c9cad11175a7` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-interruption.md` | `412e0951dba282ab7b7bdf91ba3906a4b8e08ae4a73f456afc5c9ab3f270c47c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-invariants-bash.log` | `c1683bd3ac205b7810f329fdabee50fc0c6a862095c00559e13336acb56735ca` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-invariants-powershell.log` | `7333c89e5d5cb7970fd1bec1ead619a52cdc19e83ad4d3007c8f65834891f451` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-r10-powershell.log` | `033434bad5e2938db9d10cbbfeea65abc6a1e6ea3e947b95d09fdd9468f33415` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/json-only-scoped-results.json` | `c9bc762b4816aba33d796ec6c01467f2231cafeef04f189bee8ad00b5dd882d8` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirror-freshness.log` | `a77c89cc45a8947dbc02848e0a7d52ba2c8250f50b0c17ef8ac28a2326e5e2ab` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirror-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirror-task-input-manifest.json` | `67fbba0bf635a1a076203e15c259df70bf4475db3fd92e2522940c1b1ebf1e73` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirrors-after.log` | `db813d56be63f527155d3835823fa1c8167a0a5ec995a2c7bf7e2abb7831315e` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirrors-before.log` | `362409dc82b480d787fa229ec2b2d9c684b94d953ef89b3320df916359774ac7` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirrors-final-check.log` | `db813d56be63f527155d3835823fa1c8167a0a5ec995a2c7bf7e2abb7831315e` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mirrors-sync.log` | `ead3eee3046955a466ed6e3f2d73068cc1251ec3f2418afc8c664c3465208b90` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/mypy.log` | `335bb3ecb72ae9890d13f4f8392a53e180638d3470322ed7bf755a98a3fac61b` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/native2-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/native2-task-input-manifest.json` | `18b071853274f7aeac64b236c9debcf0558c94e6956dc0d107b560c1c7c5f12b` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/post-mirror-invariants-bash.log` | `0fd4dabc48c65927cd7057a6bad5bb6b77b8e141062988eceffd828447564bf9` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/post-mirror-invariants-powershell.log` | `257ee1e6604ec46209c42d417d12e4c0ca4e7969093aa6ed99d6d6a66e4e000a` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/post-mirror-mirrors.log` | `59122df020b260c4624d9b29388994a15d59f96a70262c33dd247475f43af305` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/post-mirror-results.json` | `69daece78f44d695ea8166f4a08c6aab65425fa6acddc09a5fa5638e79278635` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/preflight.md` | `f8749e7eebc62393a2bd3ff5e55af25e0622c69862d0f2a2e708c25727b92369` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/preservation-mypy.log` | `5d4b6d285b77932e3d08212c3b4974d0a803f98ec60408ac6ccf6a063fa6c19e` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/preservation-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/preservation.json` | `779d4cc9b5059aa54458fb2fba9c9a820bf94130e2fd4602d682b29ee6d0b037` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/preservation.log` | `25f44a1841af9c01d9cddeb246e72132addee99ea03f9bbbf42f0a68c43a5802` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/r10-powershell.log` | `269f4f84b05fdfb06af2c77e2d1825cd84602df16b8e6b2e8a97b93ae707ff6a` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/readonly-powershell.log` | `1ffcd1f947ad8daad8dfeb61b612bf9422a3ca092c4777656cd62c494cdb8adc` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/reapply-generator.log` | `d8a25ac22f0b12fff80060d5ee67806be0001ffde1c0d9f3a64a960ceaa3ef6d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/reapply-guard.log` | `d4f6c7e4c64ac2367b104330e1d8754d8b96b85fab510719f3b7338e1deeafea` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/red-generated-mismatch.log` | `bd0d0dd3d6f906a0f4b05eccdae9e548214476daa670336f614c89f571d5a755` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/red-guard-parity.log` | `818b77ddc5eb15bad8369a9cb4bc65e12885db7390cd0d0bd07be7393facc1fd` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/red-manifest-mismatch.log` | `682e5cffa61695c8c2bebfb0ce42c91e59f85dc43eae339d6eecbfe184d38faa` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-corrected-guard-parity.log` | `e1a1a375fdb7dd921f4602907db1b9d924aa04b81e1958559ece4a36f50d4426` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-first-guard-parity.log` | `a3aea71f979a006d5aff03e366b82fe7fc9b17edfef65c70db0aa85f31180db5` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-reapply-generator.log` | `d8a25ac22f0b12fff80060d5ee67806be0001ffde1c0d9f3a64a960ceaa3ef6d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-reapply-guard.log` | `e8664d51c29113667eedf73326cd54c900c16c899a157b208b893a1afb85d78c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-rollback-bootstrap.log` | `6859463d5b1925396023b7a3f359b9d27d397bc4d359b740d98ef4b696f18ee6` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-rollback-generator.log` | `d8a25ac22f0b12fff80060d5ee67806be0001ffde1c0d9f3a64a960ceaa3ef6d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-rollback-guard.log` | `62334259f8ed3962edb9c8f91b6b889edf135e57297badc2c0bb3b2668e1ca28` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-rollback-hashes.json` | `4ea4ab752c11a53dbae80491f9339a543f34912517ff87f366d466702f9bf6cd` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/registration-only-rollback-results.json` | `7f9a0da681ae8db744fd795e9ca614afc5dea4f9c2911e82521db33f77fa02a8` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/rollback-bootstrap.log` | `602d7db23b1c247e11a2043ff54df66f4d696c8961ec62ef11c3e2d8d09aef37` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/rollback-generator.log` | `d8a25ac22f0b12fff80060d5ee67806be0001ffde1c0d9f3a64a960ceaa3ef6d` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/rollback-guard.log` | `dc665d093fce3ab58c3fd01e2331ce120553443e6caea4777a5c7b58efdd03ad` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/rollback-hashes.json` | `b0bf59b22ddc9a4cecee27b602b753abd605cef5755ec085116c8e6f6a32f515` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/rollback-results.json` | `f7deb7e9ef26a0ba21f4db3d051a2991bae47d77576c919ffbd703249a6dd489` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/ruff.log` | `e35d47e628c8f4378e6d0617bca1d2adced5f82ea78bcd414d71c6c1f0fe10e5` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/scoped-results.json` | `2ce2445dd1a6e219ba435f1007857c5e42b88cb5c893da4b9ff75a18d9e14d5c` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/spec-revision.json` | `8028f8748d8635ee2931e9baa8018e057021cca193595b9c3e4ed92418ab3367` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/stable-runtime-sources.json` | `c49f3cffb0bbe0f4b5be11c8acc57e204fc358cd307ffefaf83369d53fdd0b71` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/supplemental-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/supplemental-task-input-manifest.json` | `7a0d692f4b36c9b7d09108bbbea608a0c52475d681827d6c5b34bc399834e5fa` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/task-input-manifest.json` | `23569cd11454d7161c2b900db7da4ae0e746c152e191b580c2a07602db3f59a5` |
| `specs/cloud-orchestration/verification/T-011/routing-guard-fix/unchanged-inventory-recheck.log` | `b6651eb100df53f33cd7be5d383d93e68da468577297957eccb7910c2e049247` |
| `specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256` | `eeeaac58d94707ce2a8e5abc955816025c46be0a79e28acb17fffed0b19b896a` |
| `specs/epic-136-phase2-gates/human-copy/NOTES-cloud-T011-routing-guard-refresh.md` | `818c62705187d2d5b14a585ab9821042598bbbe7f51d93820cb9532e0b57b0d3` |
| `specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `e3006fd5cdc11d86658e6ba44ccff673aff61447c82f353754c2ab7e4bada8b3` |
| `specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `9380b5f98bf24d595cdb4f81edf3b4ad3ec974a454ed1e2ce3a7c29dd17647cf` |
| `specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `31935ccdf2fad222561c5bbcc548e39faa2a696613a987cc82e5b80f319075e9` |
| `specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh` | `1def3bcac3db0e1b6f8ae859cd8ae13957e199e87d2c0e2bc9b3317f18e9e840` |
| `specs/epic-136-phase2-gates/human-copy/tests/guard-parity.tests.sh` | `5f78d7c5f80fc50fa36e2083221866045b4a437ee6c8feba2dbc3e882bf760b9` |
| `specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256` | `646262931ac8dff156cd07246eb6b03bce9cf75a4d50bd864f11a0352036fd90` |
| `specs/epic-189-a1-project-context/human-copy/NOTES-cloud-T011-routing-guard-refresh.md` | `375a4e7d1be9904facb0f1e8a4b60e5c6037966d5b4a7e5cc377cd19daddf13d` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json` | `eb7c347bdba42369f48a9c842e5eeb3a0e61d4deb2d5f26fdf99bf54e5eac23a` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `0a743fa2a03ad4241f5a69964076a7d59f2f0c8fa36c3b356ae2b7fb886df9c2` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `a2a8828f32867df5855b3bf33005b101f8f1ad86aa4c1ae3e8f8df59271a3427` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `d578580e6ab511311fb5bd5471857c9c6d3bc1b6841f3e7e7fa78a0a9bf065e4` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `d3250ec7c22e8da327edc894f3348d857a75131925f3d21763b0318acfbb4da5` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `578e66fd70622b4ffafc3254f093ff7779e18086f7d65b51396a645d01e09681` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `e3006fd5cdc11d86658e6ba44ccff673aff61447c82f353754c2ab7e4bada8b3` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `8a20021958d84e1ae7e5a239a2500dc73f15289158a68e905c90d3d5f317d7e1` |
| `specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/references/guard-invariants.json.candidate` | `eb7c347bdba42369f48a9c842e5eeb3a0e61d4deb2d5f26fdf99bf54e5eac23a` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py.candidate` | `0a743fa2a03ad4241f5a69964076a7d59f2f0c8fa36c3b356ae2b7fb886df9c2` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js.candidate` | `a2a8828f32867df5855b3bf33005b101f8f1ad86aa4c1ae3e8f8df59271a3427` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1.candidate` | `d578580e6ab511311fb5bd5471857c9c6d3bc1b6841f3e7e7fa78a0a9bf065e4` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh.candidate` | `d3250ec7c22e8da327edc894f3348d857a75131925f3d21763b0318acfbb4da5` |
| `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py.candidate` | `578e66fd70622b4ffafc3254f093ff7779e18086f7d65b51396a645d01e09681` |
| `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256` | `d34c730daece7de30a07f7b381b8e1084b166f2a0a881a8aa0efa3087870caec` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json` | `eb7c347bdba42369f48a9c842e5eeb3a0e61d4deb2d5f26fdf99bf54e5eac23a` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `0a743fa2a03ad4241f5a69964076a7d59f2f0c8fa36c3b356ae2b7fb886df9c2` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `a2a8828f32867df5855b3bf33005b101f8f1ad86aa4c1ae3e8f8df59271a3427` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `d578580e6ab511311fb5bd5471857c9c6d3bc1b6841f3e7e7fa78a0a9bf065e4` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `d3250ec7c22e8da327edc894f3348d857a75131925f3d21763b0318acfbb4da5` |
| `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `578e66fd70622b4ffafc3254f093ff7779e18086f7d65b51396a645d01e09681` |
| `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256` | `d3d6d30573972c99084d153c55dc3008a560af811da6ff5a9c81755d0514f4b8` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json` | `eb7c347bdba42369f48a9c842e5eeb3a0e61d4deb2d5f26fdf99bf54e5eac23a` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `0a743fa2a03ad4241f5a69964076a7d59f2f0c8fa36c3b356ae2b7fb886df9c2` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `a2a8828f32867df5855b3bf33005b101f8f1ad86aa4c1ae3e8f8df59271a3427` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `d578580e6ab511311fb5bd5471857c9c6d3bc1b6841f3e7e7fa78a0a9bf065e4` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `d3250ec7c22e8da327edc894f3348d857a75131925f3d21763b0318acfbb4da5` |
| `specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `578e66fd70622b4ffafc3254f093ff7779e18086f7d65b51396a645d01e09681` |
| `tests/bootstrap-cross-layer-index.tests.sh` | `4b7ee150057258c73c10a5e83d787454710a92b827f2c0d7f847864bd2e6bff5` |
| `tests/bootstrap-interview-guidance.tests.sh` | `1b16b8012e7540c618c6ddde0845e37abc9e86d80a4dd2efbde6ad250eca51bf` |
| `tests/bootstrap-layer-templates.tests.sh` | `5705201ecf666d98c9ce7b354e0d4b0193eff2ceb9635de83b2846080354528b` |
| `tests/ci-suite-wiring.tests.sh` | `a3111d71e9be9129e0ec696ea8e51dc2aef1be5c6d76fe93342b7b7711cbf61b` |
| `tests/cloud-orchestration-routing.tests.py` | `2ea10b036fcfe019f045b7912b15c11abf2975f61424f055b44822bc59fbf971` |
| `tests/fixtures/guard-script-input/cases.json` | `69a3c67f7b94d7378fa900c4ee26ba44bf2366279e453a626d09c2b543c4a8e8` |
| `tests/generate-gate-capabilities.tests.sh` | `9b582adc310516f736125a42b257d98b304a70dd24285d362b42e8b48e471672` |
| `tests/guard-cwd-bypass.tests.sh` | `89f8e492406108d6579da14324d1ed229ca2158fec0166589622751eea9803cc` |
| `tests/guard-dispatch-fallback.tests.sh` | `fea16dbfe5527b988563192202f2c6916bfa3221e8d66f2dbcec78cf1bb9621d` |
| `tests/guard-invariants-epic-a1.tests.ps1` | `160b91a9d05c27ea99f60a2dfc7cf8193a3a782a5310e623703fb27aa0db5ec5` |
| `tests/guard-invariants-epic-a1.tests.sh` | `883fd0b1413b5c05db5473e168dba7cfda0a37c474909b38b99ea1ec8a07401e` |
| `tests/guard-negative-corpus.tests.sh` | `bb834f8357a95f9c90d183c8bb1b136a68803f744ca2a545c8508290ba764666` |
| `tests/guard-parity.tests.sh` | `5f78d7c5f80fc50fa36e2083221866045b4a437ee6c8feba2dbc3e882bf760b9` |
| `tests/guard-ps1-ascii.tests.sh` | `b4bc3f019a0534e9b61fc44eeb23f550f392488473746c80b44bd9da85b0d9a7` |
| `tests/guard-r10-port.tests.ps1` | `09f0fefbed2c7ab1a12f9e91732f2daa2370a40411dc571da4ce4576092474b3` |
| `tests/guard-readonly-inputs.tests.py` | `9ad61bc430e560e98b42605cf72f4455e4c623c813d2586ae3f72841184ac742` |
| `tests/guard-staging-exemption.tests.sh` | `5211b163e57d58e8611426873d4643131fd1bda8bac80f85ab1d61c41dc68b94` |
| `tests/guards.tests.sh` | `24e2cec71468b681f190e40ded7c3fb3dc2114c6a538b541a0483f6118f84377` |
| `tests/hook-guard-epic-a1-boundary.tests.ps1` | `fafb6c1e8194c9323aeefa20e965e8ecdf23f06be6da944e6452d3d39fc1f791` |
| `tests/hook-guard-epic-a1-boundary.tests.sh` | `55c9b5c5b8c6cffa719df0250f0b544fefffb74b3ba5db60ebf6e57e7e06f779` |
| `tests/human-copy-mirror-freshness.tests.sh` | `805bd0c4a4c02ec4e6200d66a5fda71fc8a0960060a9833d79db50a07f1ec267` |
| `tests/human-copy-runner-contract.tests.sh` | `854716fb7a1b2fb50aa6e9ef55b9a6ffa8a3f2b0875a86ae347404023a1222c6` |
| `tests/install-cloud.tests.py` | `7885c0d30108a2a67d0d3454f40553376acb4f5a22950158960b7958f889b7b5` |
| `tests/lib/fixture-matrix-builder.sh` | `71ec0a0653f182f0ee40aaa36161cfcbfab63d1ce12a5b982b542cbb3231fb8c` |
| `tests/lib/loop-driver.sh` | `4f2e03816b9a3f92ef22676aae764c131fe304e5f4f1f9d086a3ea881135779c` |
| `tests/lib/markdown-ast-canonicalizer.sh` | `10e300c456125d3ab0af3318d8b006e6d17bee7986b4d7d4aed4ae3df695b7d2` |
| `tests/lib/skip-allowlist-evaluator.sh` | `6c3f7e2194dfe69f8ed20445294600b2f264db7564523fc04cbc96dda81accf6` |
| `tests/phase2-guard-invariants.tests.ps1` | `eddaeaa0d49a4c1345393441cdd2b696d8333a9e15bc31ed882540d5b726dcf1` |
| `tests/phase2-guard-invariants.tests.sh` | `a2fb162c1039c3c1d04a68cd9d77f37c8fab6544c138ae9f5c26b1bcce505019` |
| `tests/phase2-guard-tokenizer.tests.ps1` | `e4b3fdb8c675ccce1e1e76b607e503f5d66bdb36dde8057676beea5766cb89dc` |
| `tests/phase2-guard-tokenizer.tests.sh` | `7624e6ed7e579073e8f3c808da88c4e22c44e4a65212efdb8405dc19296f3147` |
| `tests/promote-golden-baseline-ci-guard.tests.ps1` | `b2ca4b5a0c964d0374dd3444869a78cbdcc5becb11f21e1a3ceb0ff714e74ff1` |
| `tests/promote-golden-baseline-ci-guard.tests.sh` | `fdb5066fea071f481a2108945219377b1fd195eb5fe350acb539ca3e2bac9eec` |
| `tests/run-all-python.tests.ps1` | `71d42e12d0fa548dfc22f364ac7d05a9311070317badeae2d4fa60f27425e163` |
| `tests/run-all.ps1` | `abb3b0c8e5e8b33495376bd30130969709dc8f15e04204c0de0455744bd49bf9` |
| `tests/run-all.sh` | `e1d58fcae258fedcc4e0e3d78588f7fec2501bd6ff1e5a70e1f97feea9a79b14` |
| `tests/sdd-sudo-guard-mutation.tests.py` | `02cf929b9fcf381f39ed5d3a4d7acd851f383b6855c496b710d21101715e4326` |
| `tests/self-improvement-guard.tests.sh` | `0fd6ba699c43c5e4fd80720312666050854a6076fdb3bfd6f097eec26059d4a6` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |
| `tests/verification-catalog.json` | `74f67b89251c2b55c324e6b7e19f6923d2c0a53b871431f162949964f4e11d80` |
| `tests/verification-catalog.tests.py` | `94b56dd485f8a590e07f4fdd980158f28ef5d5cecef5ce25fe51fd62fb4b11a9` |
| `tests/verification-impact.py` | `325aa985ddc0746c7276398235fe090700c118b7b0e088baf24e4cb944060ff3` |
| `tests/verification-impact.tests.py` | `4d3ce93e8c253521ada3b1e61531ad6d6824953c13ae4d68e0d7081cb78aefcc` |
| `tests/verification-timings.json` | `dc20362834826bd087a00b42243d4436a8266e67d7616346fcde3649952a33fd` |
| `tests/verification-workflow.py` | `eb6b9185f7b70be56ca91a834eaa9ac3371be20c385450bf0ab0d0c33986d6b9` |
| `tests/verification.py` | `c77fb7ccb2942afae49d747328462e174e03a7479ac05322608990c6bf1daaf1` |
| `uninstall.ps1` | `b6deb1791e5509aeb538215f944c19d03913baa4e3f771cc93fdc1f45763baa7` |
| `uninstall.sh` | `6d038c1208abd9c66da3d4a9188286bf76d0eb601b9ace5f5db25081472c373f` |

## Test Evidence

- **Test Command**: `PATH=/workspace/.tools/sdd-forge-dev/bin:$PATH bash tests/guard-parity.tests.sh`
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-011/routing-guard-fix/final-guard-parity.log

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T011-routing-guard-01a15001
- **Run ID**: 01a15001-1554-7b30-a10d-2104952bfd18
- **Session ID**: 01a15001-1554-7b30-a10d-2104952bfd18
- **Agent Instance ID**: 01a15001-1554-7b30-a10d-2104952bfd18
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

Final guard parity 403/0 plus 7 reader tests; real PowerShell R10 252/0; negative/cwd/staging/dispatch/ASCII, invariant, generator, mirror and capability regressions pass. Strict configured Ruff/mypy pass for every changed Python file and both evidence scripts; Node/Bash syntax checks pass. Commands/exits are in final-results.json; its three pre-sync mirror/invariant failures are superseded by post-mirror-results.json (all exit 0), not erased.

Existing bootstrap interview/layer/cross-layer and CI wiring checks pass. Unchanged routing suite: 93 tests, no skips, including actual pinned local compile/synthesis (scoped-results.json). Twelve installed guarded CLI calls pass (guarded-local-invocation.json). These are local fixture/tool results, not model-host/cloud deployment proof.

Disposable rollback restores all nine task-owned code/config files to captured entry hashes, leaving corrected tests active: generator and five installed-bootstrap tests pass; guard regression returns 327 PASS / 76 FAIL. Exact reapply yields 403 PASS / 0 FAIL (rollback-results.json, rollback-hashes.json). No live checkout, ledger, approvals or cloud resources were restored.

Preservation: original canonical report SHA-256 `2956e2e48c00cfcb8b7e5380362ae9df7f6627bfa086ad9b987f869931c765ea`, original caller failure, eight frozen specs, original native acceptance/source bindings, all 134 native source bindings and 26 pending guard mirrors remain exact (preservation.json). Only checker-confirmed stale applied mirrors were synced.

## Specification Differences

None. Same-task integration defect only; no cloud schema, provider/helper/skill behavior, scanner, architecture or CI skipping change. Narrow shared script-input compatibility repair was explicitly confirmed by root. All prior members and strict generator checks remain.

## Unresolved Items

Root delivered native-host trial2 PASS: Azure `01a1500f-af95-7a43-a320-6efb70000cf1`, AWS `01a15011-8d4a-74d3-85d5-9017ebd4d8b8`. ALL8 packages refreshed (455 cache files / 426 source bindings); two trusted hooks executed; ten local CLI calls reached route/denial results. Root checked hashes and restored the original profile/cache exactly. Azure used individual host calls; AWS grouped subprocesses; follow-up-scope.md records stdout capture provenance. These are separate root-launched identities, not this implementer or live-cloud evidence. Root supplies the full native2 review supplement. Trial1 remains frozen.

Root still owns first independent cycle, final scoped review, full-suite committed checkout and statuses. No independent evaluator invoked here; runtime/guard sources remain stable.

Linux Bash/Node/Python and real PowerShell exercised; native Windows/macOS and junction coverage are not claimed. One existing PowerShell staged-runner install-path branch remains skipped pending its separate refresh candidate; no pending bundle was applied. No newly enabled platform-SKIP branch. Live TEST-003/005/009 remain BLOCKED by OQ-001. No cloud actions, publication, push, tag or merge.

## Quality Gate Focus

Verify exact five registrations/generated hashes, narrow first-command input handling, unsafe-environment/output denial, preserved native/source bytes, actual Red/Green/rollback chronology, and root-owned native trial2 delivery. This is implementation evidence, not a gate verdict.

## Working Notes

No subagents. Used local Ponytail full, ECC coding/security/verification, pstack blast-radius and fix-by-review-ticket/debugging policy. Reused existing guards, generator and installer/routing fixtures. Raw native transport logs remain private and are excluded from Outputs.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Root: accept scoped repair evidence, admit delivered native trial2 supplement, repeat caller checks/isolated committed full suite, then independent review and status decision.
- **Unresolved Items**: Root-owned full-suite/review; platform/live limits above.
