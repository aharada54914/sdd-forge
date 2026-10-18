# Implementation Report: T-007

- Task ID: T-007
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 01a14f96-e637-7773-aa3b-74e44216f500
Task Attempt Count: 1
Input manifest: `specs/cloud-orchestration/verification/T-007/attempt-1/task-input-manifest.json`, SHA-256 `bdc89658513bacae128425df7b0646bb82e9859e706c94d076dd529083632ce6`

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / REQ-011 / AC-011 / TEST-011 distribution only.

- spec_revision: `8bc2b9bc60fc89cd29082d988934e4e6bdfb8e09875f0d62183399fc05c507cf` (actual current eight-file raw revision; algorithm and inputs in `specs/cloud-orchestration/verification/T-007/attempt-1/spec-revision.json`).
- Initial Git revision: `2c2caf3f804b946a8fc6094bac0e76aced0b479c` plus preserved existing candidate bytes.
- This revision differs from T009's historical value only because traceability.md already had newer lifecycle-status bytes at entry. No frozen input was edited here.
- Native identity: `specs/cloud-orchestration/verification/T-007/attempt-1/identity-binding.json`; caller-supplied identities corroborated against stable native allocation thread.id. No inherited process identity.

## Summary

Packaged two explicit opt-in provider entries using existing installer and retained-dependency uninstall semantics. Default bootstrap/ship selection is unchanged; each cloud entry includes sdd-quality-loop. The installers materialize all four shared modules, protected T009 registry, cloud schemas and v3/v2 verification schema mirrors inside selected provider payloads before registration.

Skills collect canonical request fields, use the existing explicit trusted runtime override in isolated host layouts, and distinguish local operations from governed execution. Python 3.11+ is retained. No provider Python/execution code, cloud authority, custom agent, bootstrap routing, active workflow, or release-wide version/documentation change was added. Repository validation now follows actual exported skills roots rather than treating pinned upstream reference skills as public entries.

Scoped implementation and verification are complete, not a Done decision or quality-gate PASS. Independent named review, final full-suite isolated-checkout verification and gate disposition remain root-owned.

### WFI-001 executed preflight and Red chronology


Actual command: `python3 -B tests/install-cloud.tests.py`.
Result: exit 1, 5 test methods, 77 assertion failures; matched synthetic control
passes. `red-manifest.log` is the actual output. Tests invoke the verbatim existing
manifest-validation block from validate-repository.ps1 (not the unrelated global
workflow/agent prechecks). All mutated records and module/schema bytes are present;
no import/setup failure is counted. The old validator ignores unregistered cloud
records/mirrors: that acceptance is the actual failing assertion, NOT proof of an
existing per-field guard. Post-implementation controls/sensitivity must execute
every newly added check. Case-variant existing domain name also wrongly passes;
its existing version mismatch is rejected.

| Persisted field / packaging claim | Sibling counterpart | Executed failing mismatch test |
|---|---|---|
| Provider manifest name, version, skills (all three host manifests, both providers) | directory name, existing release 1.18.0, host skill path convention | ManifestBoundary.test_cloud_manifest_field_mismatches, each named provider/host/field |
| Marketplace name/source/version (both marketplaces/providers) | exact provider directory and host manifests | ManifestBoundary.test_marketplace_field_mismatches |
| Codex policy.installation/authentication | existing opt-in AVAILABLE/ON_INSTALL policy | same method, policy variant |
| Packaged four shared module bytes including dependency admission | canonical quality-loop scripts | ManifestBoundary.test_runtime_field_mismatches, each scripts/* variant |
| Packaged protected registry bytes | T009 final registry at quality-loop/references | same method, references/* variant |
| Packaged cloud schema, verification-contract-v3, selected-plan-v2 bytes | root cloud contracts / T009 canonical quality-loop contract mirrors | same method, each contracts/* variant |
| Existing manifest name exact case / release compatibility | sdd-domain directory/version | ManifestBoundary.test_existing_name_and_version_guards (name Red; version rejected as before) |

T007 introduces no authorization/receipt/result schema or cloud verdict fields.
Its verification claims will bind actual installed CLI/module paths and denial
results; public no-executor denial is distinguished from in-process dependency
validation. Existing predecessor and registry behavior is consumed, not replaced.
Report evidence identity/hash fields use existing manifest/report validators.
Live provider acceptance, host-model trial, independent review and quality gate
remain separate/root-owned; no PASS or Done claim is made here.

## Additional executed visibility Red before validator repair

`SkillVisibility.test_real_export_consumer_ignores_upstream_reference_skills`
fails in `red-visibility.log` (exit 1): validator counts 30 skills instead of 29,
including the existing pinned AWS reference skill outside exported skills/.
Field: public skill inventory/count; counterpart: manifest-exported skills roots,
not arbitrary SKILL.md files under references/. The test calls the real export
consumer block with actual populated provider packages. This is not missing
setup. Commit this failing test before narrowing discovery to exported roots.

The full validator's later WFI-054 reachability consumer has its own public
entry allowlist (original line 547 after this task's initial additions).
`red-reachability.log` executes that verbatim tail block too: new orchestrate
entries are wrongly classified internal. Field: public entry caller class;
counterpart: frontmatter disable-model-invocation=true, no hidden-human flag.
Extend the existing visibility test before adding orchestrate to that allowlist;
retain the original six entry semantics and case-sensitive comparisons.

## Files Changed

Exact task-owned source/test paths and hashes: `specs/cloud-orchestration/verification/T-007/attempt-1/changed-files.json`.

- install.sh/install.ps1 and uninstall.sh/uninstall.ps1: opt-in names, dependency closure, selected runtime packaging and existing partial/full uninstall behavior.
- Both marketplace manifests; six provider host manifests at current 1.18.0; two public orchestrate skills.
- tests/validate-repository.ps1, new tests/install-cloud.tests.py, and both Bash/PowerShell install, uninstall and matrix suites.
- This report and task-local verification evidence. No tasks.md, approval fields or frozen specifications were changed.

The Outputs table additionally binds unchanged test/runtime dependencies. A row does not assert that an existing dependency was edited.

## Tests Added Or Updated

`tests/install-cloud.tests.py`: manifest name/version/skills and marketplace source/policy mismatches; all packaged runtime-byte mismatches; six real temporary installer cells; installed CLI routing and unauthorized prepare/apply denial; four-module imports; missing/invalid predecessor denial; installed dependency set-guard controls/sensitivity; protected selection, missing/tampered registry and schema availability; 24 isolated host-cache-layout copies; partial/full uninstall preservation; operator and independent schema-discovery case variants; exported-skill visibility and frontmatter guard controls.

Existing installation suites now include both explicitly selected providers and the existing shared-dependency closure. No normal run-all registration was changed (T011 owns that).

## Outputs

Changed files plus unchanged runtime/test dependencies and stable scoped evidence.

| Path | SHA-256 |
|---|---|
| `.agents/plugins/marketplace.json` | `dd4a8d5efb2d2f8eb5918897d9a499b4e532ec5654bab2fdd539500c5eaee36a` |
| `.claude-plugin/marketplace.json` | `dd935489bca5a357c90eec68081717e451c1d0b0b5f807f33b6ca8dd3b216155` |
| `.codex/agents/sdd-evaluator.toml` | `31411fad2ea5bbdd06c3f3d8276b9b3535bb21717877522143a2512be7ec188a` |
| `.codex/agents/sdd-investigator.toml` | `5a10183be5d4ba742d7c80d929ac1cdd59b4d32109c48c7615ea05e4b6d6886d` |
| `.codex/agents/sdd-panelist-gemini.toml` | `cee875549343d2bc6bc8bee29694ee67b1f481819ed0a6e10a1044893c0ab270` |
| `.codex/agents/sdd-panelist-gpt.toml` | `7dc97360df3e6656f065fa207dcd67f4ccbd5eabbc7c41e7011c1f59bf824816` |
| `AGENTS.md` | `be21577343b8b2cc488c47b373ed68130ded00d994f58f1f81b7b69bddd6d537` |
| `CHANGELOG.md` | `eb5c357606bf289013f6859d772bc759959ca08fc3177a6af806f1ad17d281e5` |
| `README.md` | `430e0a0894f2b673044fc6be2f6b6e0f1918657d91ebf989951a5dd68990b046` |
| `contracts/adversarial-review-evaluation.v1.schema.json` | `79a3f7b75996474d318535dab04fd284706f2008ef7592fe66992e3dc39d054f` |
| `contracts/adversarial-review-report.v1.schema.json` | `3dd9bbb8cfd475444b4662abddedc86b9088d419323e4bfeb34b663a8353fb1a` |
| `contracts/agent-model-capabilities.json` | `b5a4bd4b156cfbc5f51bedf98c13e0ac3e4d237f1a00c1f79ae4c595b9f444b1` |
| `contracts/agent-model-capabilities.v2.json` | `847fe86588ea22dcb0a13b7b61548aa254f22a8244aa5153e63efefe8a4d200e` |
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
| `install.ps1` | `8928011600e821d882e80914445f3d9b2ac12a948019f1858ccc9f4bc7c4bc0a` |
| `install.sh` | `04436898b4d8d260f0743882f70ddcb6e01687b0d8b0373f41dfafb76ee5d221` |
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
| `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1` | `8bc772740d8edd9998697c1e92c6b421f65772b44b0a7ac39bca7ad2e888fbce` |
| `plugins/sdd-bootstrap/scripts/design-sync-scan.sh` | `cd86b9c11d472cb3e8a9855849b183c2c078873640220beb88b507e0dba0080d` |
| `plugins/sdd-bootstrap/scripts/resolve-design-sync.py` | `6b3f6157366ba5d00977a937e0f1bb4469f3a4e8b682e60953607ea972141422` |
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | `252ea8af1726a7684747d2db512c775928db4bc2f1405125aff4f789385fda25` |
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
| `plugins/sdd-domain/.claude-plugin/plugin.json` | `c2e9846fca5fedd8357bc1cbf9bfd8c8ce3e2ee9e6cbc6c45a9a478c630a67f8` |
| `plugins/sdd-domain/.codex-plugin/plugin.json` | `a84504f1dd31b8554d5faa64b82e165ca4608d207ecfe28a369c4ac2c11e1729` |
| `plugins/sdd-domain/.plugin/plugin.json` | `e7ccb1b18c512710bb955336e3aeebd077dc9e20f95870156ab3e01faf768d2d` |
| `plugins/sdd-domain/agents/domain-reviewer-a.md` | `782addb1bb2f60253ac48dfc0a5966b968b5b53f9ee1246dd45ae3c27717fefd` |
| `plugins/sdd-domain/agents/domain-reviewer-b.md` | `031cae9862ad7cf0d4776c26d5e06f49c40db197360c9a72fc5305d03045172e` |
| `plugins/sdd-domain/references/domain-review-calibration.md` | `9e979c2f1ac9285d4fd87cd005af84817879b96ae39239f763415c4d98dfba6e` |
| `plugins/sdd-domain/scripts/domain-review-precheck.ps1` | `ec72d99136d0747a4113fe6f32bde63c2651e7409fa8a8e22a0bb1ce896f7cc6` |
| `plugins/sdd-domain/scripts/domain-review-precheck.sh` | `712521803b54ebfc60832137a710e93810ee04ef9905378eeaf39ef38f6a97b2` |
| `plugins/sdd-domain/scripts/finalize-domain-review.ps1` | `5ab02a6f1ebf73511a1dbd526794e2691429a0c135167414bb73834214444154` |
| `plugins/sdd-domain/scripts/finalize-domain-review.py` | `47ccc5c746d2ee0231ddc878ca86273b3198d7b8427517d39fcd11ef9ba2c312` |
| `plugins/sdd-domain/scripts/finalize-domain-review.sh` | `3c194720c239a509ba5dc1ccab53b3e6b9d167ce6231ae7a09dc9769635f0b4e` |
| `plugins/sdd-domain/scripts/record-upstream-concept-issue.py` | `5cfd8a2e04ac3bba3915c801622551417220dc674f0c1940fab65831928b019a` |
| `plugins/sdd-domain/scripts/validate-concept-test.ps1` | `e9f26f5ec265cf4299cea6478c679705c3f3fd73f0dee66e7980e6e909c00393` |
| `plugins/sdd-domain/scripts/validate-concept-test.py` | `d1a65094eb2e32c49b2d0f3803e1270c5573de0acefbd72e7ae7270ed08b0f2e` |
| `plugins/sdd-domain/scripts/validate-concept-test.sh` | `b86d7395356372586d38971911046b7c5e9e122719eb07e8a98c10b8d872c23f` |
| `plugins/sdd-domain/scripts/validate-domain-contract.ps1` | `2de062d711ccf860a6216a4a288cf37cb62d93bf980ce998609c22c7d15ecdbc` |
| `plugins/sdd-domain/scripts/validate-domain-contract.sh` | `4613aacd33ed9c30956f218374a300503e25ddfa936e478759ca2a1253e152e4` |
| `plugins/sdd-domain/skills/concept-test/SKILL.md` | `81f7a75615404e0cd31bbc24e40b2f79e018102ff106a3eb80c42b00635f8faf` |
| `plugins/sdd-domain/skills/domain-interviewer/SKILL.md` | `24171685e75415493bb1addfd2812853b300091b15fba40325c090a796f9f8c1` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/aggregate.template.md` | `3b434585bb6489be3553c7b3c77ed26b9241ecf76760cbb98d6fcae9832b44e0` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/concept-model.template.md` | `846a5697cbc1030bb9187d1fc9caab7c80525076b1490f9523b6001bf6d8ad91` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/context-map.template.md` | `89d84febd68da0414d68fb46c96276c1f502fff1c02b1c61a9ea81ed018705c0` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/domain-story.template.md` | `389e157c79cbca67091b86b55ba552b23e165a5d371af7e429badf11cc2c4ef4` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/event-storming.template.md` | `cd12922028606d3132176421070373a99c63a8ecc6fd04c060970c856d62337f` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/message-flow.template.md` | `47bd084a44cdb18840dbe035813a1aea3073f23b9800375057b04c6dc8eb364d` |
| `plugins/sdd-domain/skills/domain-interviewer/templates/ubiquitous-language.template.md` | `a7442409c9656f5d5070ea0b179049a5c2273d36fb206e241e72b1ed6cc63de1` |
| `plugins/sdd-domain/skills/domain-model/SKILL.md` | `1f73139a596101269a5a123e51e51d6ec71a9b208b3696f6060b19c6df041dad` |
| `plugins/sdd-domain/skills/domain-reverse/SKILL.md` | `a1a0136267b674d04a025e9eae701164c92049d783ddcc41a28ba48d5e2be2f2` |
| `plugins/sdd-domain/skills/domain-review-loop/SKILL.md` | `36484fe991db49da3bc5aaeb6421b661b1412270d8059daec6128c15389eec1f` |
| `plugins/sdd-domain/skills/domain-sync/SKILL.md` | `ae41f8da490ef18ceb0328151a322590a63526be99e6386fbf9a45ec72fc3f7e` |
| `plugins/sdd-domain/templates/domain-review-contract.template.json` | `34b3b211a78094bfa7ff32f67cdc6cc1bbf2f1f43d57e914c80115c1832a0bc1` |
| `plugins/sdd-domain/templates/domain-review-integrated-verdict.template.json` | `f130fb85d59b68f1c697b89dc346b84576d3c1057b50db1ab1a71cbd094dc565` |
| `plugins/sdd-domain/templates/domain-review-report.template.md` | `fb08e1e4d9a9ec27d8d3b4b2d93692104a15a4c7cb3c9a82220e7917ef31802a` |
| `plugins/sdd-implementation/.claude-plugin/plugin.json` | `82a292a165f42ff82df185cdbc343d41537bc0a29d4d9f8bcded2d6beafdeb77` |
| `plugins/sdd-implementation/.codex-plugin/plugin.json` | `6c5e68a63928e967b15eb795d5835d6b3e10d291a4402048a5bc2054f7e2a546` |
| `plugins/sdd-implementation/.plugin/plugin.json` | `fc13bdbe1b6513c06015d8f72b949e8729d0fcb5044827d15ed231fc5f138e6c` |
| `plugins/sdd-implementation/scripts/check-terminal-tier-resume.ps1` | `eef6c101c5995cc550df36d3e833d26fb85b823b48bd54f6172e0704d9fb39e4` |
| `plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh` | `8f071fc5e98c43712653feaf67ec929270bc7faca20dbfd70310ce663a71b1d9` |
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1` | `aa1593b9349c0de434a8125a4d15d3a050ff93fc90f538456520aa2b5ad00dbe` |
| `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh` | `40f35e11b76a30ab38f183a772f1f18a35b0b2be8aaab399b012afeb4e96fa68` |
| `plugins/sdd-implementation/scripts/select-agent-model.ps1` | `f676675b41a91a9fc95c9fa9115542bf6a9430a3fe1c7d404438f8723c5321b0` |
| `plugins/sdd-implementation/scripts/select-agent-model.sh` | `d6225ff74bfcca136a551331ded93f2c57036f7268ce5c11ce5278b7e3105a54` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1` | `18402647758202f2a8c6bd87245cf7450abf599e6f94de09a4fb9255e2cf5a2d` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/skills/diagnose/SKILL.md` | `39177f847eff6d547a8bec279bca6d6b623396c2c59ee412bad9e0470b22de44` |
| `plugins/sdd-implementation/skills/diagnose/references/diagnosis-loop-policy.md` | `65eb29633cc37a2eedb45309865d2a6c719fb49e33842a12036a81efd2a965aa` |
| `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh` | `e05b3aad1e94b07ad102c1200c2e458400e5c0be6082aa79a3b8f3ceff2ce840` |
| `plugins/sdd-implementation/skills/implement-task/SKILL.md` | `6a3bdc2efd1e8338a961c23e69240e27e5c7a366580d6fc3a1a532461a1b507c` |
| `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | `d0622d44f13693cf6e32c918aba53efbcc5089dbfbba8a539bec3be601017051` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` | `5f00ddf2765b5086dfc83b3e24ad6873a7e08a08d419126fb619adcc82e0beff` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` | `739173bcd97aaa185206b85ce0fc88cbee96e51447d0097a082fedead40b30e6` |
| `plugins/sdd-implementation/skills/implement-tasks/SKILL.md` | `63ec0313cd660be60940bdcb0d8e88337b6e380ac4bb43a13100461ba388f291` |
| `plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md` | `7eadc63911214f798dc2c1a97b18609af7db8f474bc34c6246b791a0597edea0` |
| `plugins/sdd-implementation/templates/diagnosis-report.template.md` | `88a492b9132329b366a4cd788646382054e29b18804dce6eddfb78778e55a834` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-lite/.claude-plugin/plugin.json` | `5ae17da3db2d23496a20fb188c7253d66e2fd2cc3719b9300845043bf3593749` |
| `plugins/sdd-lite/.codex-plugin/plugin.json` | `4a7c37d3a1b44bfeafd34b0bea2c4ea863e9ea73e979bddcc7cfbf4fedca17fd` |
| `plugins/sdd-lite/.plugin/plugin.json` | `a4fddd29ed226d93d528729b3d439c1f27fcda8f745c68dcd4a78f4856789071` |
| `plugins/sdd-lite/lib/run-lite-gate.py` | `349800d440d6439de11b7615617123ac210df7265aa7aeaf18d6ec8777781b20` |
| `plugins/sdd-lite/references/lite-flow-policy.md` | `b328f8e7a805c227cf5a1be04066a6568ca75f4a4038da19ae8435d907e97ee3` |
| `plugins/sdd-lite/references/risk-upgrade-policy.md` | `40103332af2ad71f7effe873f0a118bceed32299c54710cc4f9b54a40aae3a5d` |
| `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `f627ab50b85a2855b7a65bece51948723a5b6a3ecdfb41f0122eb90d8348ff3c` |
| `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `4ffd5cd7c5b395dbd438ec6ae223b26eff691e96df89d73cc436190a6dc53c9d` |
| `plugins/sdd-lite/scripts/check-task-state-lite.ps1` | `ec51efbd03a5dfdba8d79ef72ebdb01943064b0ee11e283239bdab6cf836944e` |
| `plugins/sdd-lite/scripts/check-task-state-lite.sh` | `5cbb235b2a14123bab3cc44fdac09f1cd421fcdb341e59d34721a63f8ce79d2e` |
| `plugins/sdd-lite/skills/lite-gate/SKILL.md` | `bfdf9eda0e99fd43cf77fd7d6e3471739e282ec228bd69d702ff4d8d9d811998` |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `4896ab43ccb4dda0670c2253fdf2fac1dd600416ec7c6aa7396eaed5c2498570` |
| `plugins/sdd-lite/templates/design-lite.md` | `21e8827478ba6090d98639f9a899102705c2855981b95598561214a408b9e823` |
| `plugins/sdd-lite/templates/quality-report-lite.md` | `71facd0967dd6c9481f08cd15766f0c744249b6d995c61bea6260fc810081fd7` |
| `plugins/sdd-lite/templates/requirements-lite.md` | `86b212b7a36652f7a617c21dfd80193d59a58babdf3a01a931c0ca626affb904` |
| `plugins/sdd-lite/templates/tasks-lite.md` | `99ecea5271f55dde5764d12be63d1aa54288868d28cb15b9ec029d55e9619e31` |
| `plugins/sdd-quality-loop/.claude-plugin/plugin.json` | `132ffb6eb6e23f1a4d772f76065ecd9cb299370e0ed4bc4bb9d38ae3d8ba66b9` |
| `plugins/sdd-quality-loop/.codex-plugin/plugin.json` | `d957210bf8057abae2ad16472e1d6c36a46ceccd3a4ee2a4133f0126dd60d011` |
| `plugins/sdd-quality-loop/.plugin/plugin.json` | `ae3dc271a5b56f88efb97949f6e2d66cfc906b3e5813bf1bcec9597e863ec099` |
| `plugins/sdd-quality-loop/agents/evaluator.md` | `18d151073e388fe9e864d7192230c8686c6d8a24414d04f02796c00db4194a6a` |
| `plugins/sdd-quality-loop/agents/panelist-gemini.md` | `b45eeab1c070a96115d6d2813fff4a92cfc73796ed171ba1c8cf6112c4cd6093` |
| `plugins/sdd-quality-loop/agents/panelist-gpt.md` | `e0134fc5be428b1a0ab4b700f989d4fb7a114c119b12405dab14da9bda4629de` |
| `plugins/sdd-quality-loop/agents/wfi-auditor-a.md` | `864f6b857131ece8da42948fe17311b2e42c971cd6b4b64ccb39ed5241ec3230` |
| `plugins/sdd-quality-loop/agents/wfi-auditor-b.md` | `ad7a7defc893d9a60ca4b9506a144340759bf3090ab90157814c0113b781a298` |
| `plugins/sdd-quality-loop/contracts/capability-registry.json` | `dfc1b948bb085d3c86f1f7958b9564c1cb6cf6240ce9d57551656fffc2f15c75` |
| `plugins/sdd-quality-loop/contracts/capability-registry.schema.json` | `ef70a27785d325cc32d2c4a2faeed099e9df3058fd7a918e2efbd4013ed8f319` |
| `plugins/sdd-quality-loop/contracts/capability-summary.schema.json` | `09d4ace8cc599b4ef7632aaa09c7477e765bcfa69943f2231f8870aac4cbc42f` |
| `plugins/sdd-quality-loop/contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `plugins/sdd-quality-loop/contracts/context-projection.schema.json` | `3c8e39c6a8dedf948cbd7e6a8f36369f2a68a3fc3dd92192f90bbce917d32643` |
| `plugins/sdd-quality-loop/contracts/facet-manifest.schema.json` | `81d4f1621923133e55875621ba81b30ad9d21688d9442c5a371fc1023b4a4c51` |
| `plugins/sdd-quality-loop/contracts/lite-check-catalog.json` | `c251b3e02a2c93c45a7ea590bc5a7e36eef8e5915c485b0c6a6e83519afe086a` |
| `plugins/sdd-quality-loop/contracts/lite-check-catalog.schema.json` | `a4e458242d68237cf16e66aa28b362c30dae4a6d20109cb4af51711f6fc1cd19` |
| `plugins/sdd-quality-loop/contracts/lite-upgrade-reason-catalog.json` | `e73a730f9edacd7d2dad2da3e13b9e3df01f7002c25f7e947316ca249118eb76` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `plugins/sdd-quality-loop/contracts/selected-verification-plan.schema.json` | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `plugins/sdd-quality-loop/contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md` | `32be124ba06f958c73780c57176b19b68cf897bd1a16931408f010546f7874ec` |
| `plugins/sdd-quality-loop/hooks/claude-hooks.json` | `09c76c5dcd5d19d706530786b4728ff4e98e0d96c4d0e82c07bbb1a586c9ea5d` |
| `plugins/sdd-quality-loop/hooks/copilot-hooks.json` | `6e105f0c5526645564fe5fc60c7f8255fa4daba1f7bb63eb08e198ac69fde2a4` |
| `plugins/sdd-quality-loop/hooks/hooks.json` | `9035e3d5035ccdd093adc634f42fb3686e3a02ab2c7104d26ed15076dfc09b40` |
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
| `plugins/sdd-quality-loop/references/guard-invariants.json` | `4c43639cd9b90b2c7c4ac83d80b41b3808ad9f865550e465cb1db63743a523ae` |
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
| `plugins/sdd-quality-loop/rules/review-ticket-conventions.md` | `96de24399a9c4d6348088f2664c1f0ca6ad52906b6b170a5ae977a9aa24b6409` |
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
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` | `a08c294f2a7fcfb0e9c574feda16db135a0d4f50509da98661769a6ddcee4aeb` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.js` | `675b6add2a3abb482741c82ad6626fee93bcfd55aacb48545318dd19f2b7415b` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.ps1` | `2fe45e533b1dec24bcebfe13c506a66aa6efcef704bf7796cb9150d1e4be6fe8` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.py` | `dd3a0642deeceac3d8def2c476c97fe6cf69fbfcebb2e1682bcd7939862b0aaf` |
| `plugins/sdd-quality-loop/scripts/generate-registry-digest.sh` | `b75fd5fc0859bb3c9f2228f5fce3bd0a56a45aa8d9f5c48dd83cf1ae68c56453` |
| `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` | `26c20a6a62259b598851beea58070aa1ddf2918fda5048f7467380852d648144` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` | `d3efd787196da964ed140a5bcb710c163840cbc25567e43676603e90ebb83230` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` | `e5ba22671799fefccbd0f1f8a8f8d2aa8964a7cfc0e171ebbc4c50977f44cd58` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` | `5224e41dd30ad2d594997f5a44891615f048e14b12a9fed5f59919afd9fcd1b0` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | `e36f7c64f22fa347ed62fcedc9f85da7f784b13c9d602b1d11d6a7c3916a1013` |
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
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `78f6125f3a55617a6ede53881afd3cabc3b391c420f4086158ee15801d5ae29a` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `1123c6d1ad7c79d33d86d55098526d9d41db43a922b7643e60dd1d58548e037c` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `b95d798200b36c6d72a33c043a7837dc194732e2759a1f83709a5ae645716c8a` |
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
| `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` | `73ae95edb3c6dd7b1b8e85fd1e618cb78797a7c2269f72abb11ec23933e2a1f2` |
| `plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md` | `0215d3a6c097c893727276afc6078415cc83c3aa4273dc8bc62865bc3af6efa1` |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | `ce29654fc042e2e1fad4ce0f12c159dcbdc390137f5acc867a7e99d0dd4a21a2` |
| `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md` | `392e32a6478337274b0a927f58ed31d0fe0204c12bf5817e121d457de6a3ac98` |
| `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md` | `452b2138848e71268a5b02c51f6642c274c21d4fb8a5d353352cd907c04d03be` |
| `plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md` | `7df7769628098e0201671cb8c901347f445b1b8479bfb8ec624b433202140bc0` |
| `plugins/sdd-quality-loop/templates/evidence-bundle.template.json` | `d1a131c56c69a934186fe2fb940d8d689626746670682cda85f2e3efa67e7432` |
| `plugins/sdd-quality-loop/templates/quality-report.template.md` | `7edd8a98524177276225b0f67c0905866437a8a7f98c2fec911c0f0af02a4cd1` |
| `plugins/sdd-quality-loop/templates/retrospective-report.template.md` | `6082b26e4f72ebfdc28917d919c78bfe00d9e72b5fb84f659278da8b612c6f28` |
| `plugins/sdd-quality-loop/templates/review-ticket.template.yml` | `90a91199fd7012e65d7ed8106a03279c33ac7c5b05e8384e0e1906529c82b689` |
| `plugins/sdd-quality-loop/templates/verification-contract.template.json` | `d803be2741e21ea71ba7aaac691aeea314f63f477ee5bab27f37a8e7a553dbe5` |
| `plugins/sdd-quality-loop/templates/wfi-audit-report.template.md` | `a054995c844c77e0d76d84a04cd40ff992896a90b9b308cd3ca063484e02a9f5` |
| `plugins/sdd-quality-loop/templates/workflow-improvement.template.md` | `b99418c48b544a90e9dcb6a6150ae4327ea6329b223ca340fb3a8fbf14a316a9` |
| `plugins/sdd-review-loop/.claude-plugin/plugin.json` | `044d03a31bb19b077b607f1473aa6bdb456fd5993169a8389ecf587006941f03` |
| `plugins/sdd-review-loop/.codex-plugin/plugin.json` | `5cf0d64e677030216ecec03c012446318d69426af159f663aa62befd12154517` |
| `plugins/sdd-review-loop/.plugin/plugin.json` | `e6573a4ebb23fed3a4456e4467e9cb1a3bdc63e0aaf5cef769136a4a82543470` |
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
| `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` | `bc9c6ed4e2ad6fdfa84bca4eea7c52a92d825957005e18e0f8a8ec2848ed7f75` |
| `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | `4fc4285ebfe126d3104598909012cfda6785cd0356ffe89d5095f0924c0fb656` |
| `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` | `ab5705112fb2646ca4987b553ce58eebd956f8b8c61d91ce505d95bb2fb97ee3` |
| `plugins/sdd-review-loop/templates/cli-library-spec.template.md` | `13394c9079a7a0d786ed370dfd8715743a662e859497fe7c99d4cae0720872fd` |
| `plugins/sdd-review-loop/templates/developer-tooling-spec.template.md` | `35046d7f2c1494a9e445b7e1d6924fdac614a11c2d6b08648fe2edac9e9f713f` |
| `plugins/sdd-review-loop/templates/impl-review-contract.template.json` | `2c4e1c2d7f5b0dd495858432577a98b61f007c6daf97be8260f6501b091d46a3` |
| `plugins/sdd-review-loop/templates/impl-review-report.template.md` | `297917992ce7a821c6a234d3d070c8941e0fb8a9120654c6a2edfaef9029d205` |
| `plugins/sdd-review-loop/templates/spec-review-contract.template.json` | `b33961db0d5e7fd02261c86c23bc5b9b02b1857fa85433b239c64ff694936e60` |
| `plugins/sdd-review-loop/templates/spec-review-integrated-verdict.template.json` | `8834146f2616d92c420a7ed4960647351a5d17f5a578ca5302668d4c411a26b4` |
| `plugins/sdd-review-loop/templates/spec-review-report.template.md` | `0597ce0c38126c05e7e0d06d240538669853e8eaa75ea2979f68ccf1366a4d73` |
| `plugins/sdd-review-loop/templates/task-review-contract.template.json` | `f4c2809e9b3742518965f1387a681014544b5b9939fedb380fd23c57a8a1b5fd` |
| `plugins/sdd-review-loop/templates/task-review-report.template.md` | `c64765d789649d29ea662b4d6cc4ddab7fa633f93be49ba3e0c69ea051f3a59e` |
| `plugins/sdd-ship/.claude-plugin/plugin.json` | `be1c1dfe8cba928db9073c1c6ee2cee85aa76b7c0711a30b365054113adf9499` |
| `plugins/sdd-ship/.codex-plugin/plugin.json` | `b3454c5c54fb5cf00f2f7e6422ed2af44b549d73d00314a63578242b34bcb327` |
| `plugins/sdd-ship/.plugin/plugin.json` | `44a3d211bf3112bd4431fc32d5b900b8aee6524eed6d3eb2cd1efa03a869aff6` |
| `plugins/sdd-ship/skills/ship/SKILL.md` | `ffc89ec2b6ae1bf933c7e4f4e07617b3068db865ffd2499b2d79770d9903e57d` |
| `render-agent-frontmatter.ps1` | `51c73d5e3900d7d56147e4f6e930639feec6b8aeb5b010fb1b70f0b469c67aac` |
| `scripts/human_copy_mirrors.py` | `2ea93f1061101eb5de6cc6e6bb201f95f81cf8a28408ad2cc7c241ae912e21e9` |
| `scripts/sync-human-copy-mirrors.py` | `13e9572f3757325f21884b0a2d94e7ed2eabf98acc1078d915d3159acc7c2be9` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/changed-files.json` | `04df38699a519c0e436ee297cbe160aa19a78c93e4379fc1bd968ef3a1d4bf2a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ci-claude-install.json` | `d9a7fa0b432d2dda8f822ec5cdf4728bab75384c9530a01460c71b3dfed92832` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ci-claude-install.log` | `3e2cfd5fa389547744db3713b3227a940b3fb3c2d5d3b78c571e6dc2619f0193` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/cloud-packaging-final.json` | `6ebefab186375858b0f0b3ac552f7ba227a363744f9d63e2958376e6b0f19230` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/cloud-packaging-final.log` | `e6856c88c870378d556cfe15eeac42677e5bf5394955e2cc1ff251708d0b20f2` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/cloud-packaging.json` | `9c705266e76e2e9ca109d894f2295af8b5af59f5322a7702ec9be3538c1a1678` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/cloud-packaging.log` | `b131870a136dc23573920b77269a1b0d5aade83ea6a731c7c7cf483c63fbfc7f` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/command-summary.json` | `24db57735e3857716ff14dcafd9ef74c387192a4f3d7c38b36c2137edf2f175f` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/diff-check.json` | `95a973440cc7836e92caceeac6f33a3d60bbb9b959e570cbb9c3f8a2c4090b2a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/diff-check.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/entry.json` | `5fdfa039b5f393770a256533bb8b27af6f421af3e21ab5dc190f693836b4771a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-before.log` | `d3bd88af042fe8bef14d292e715e1d835ae2ff7d5538521eda15f549e5984c62` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-candidate.log` | `c5e24415a164d81bf279df4322e2d2e15c290f34ad07c7c068109695b42d8a10` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-commands.json` | `688f4f33e8cd7192cbb4adeb3b91d18cc4a1c063a90dfd74e3c2128fc4078a70` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-commit-baseline.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-commit-candidate.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-commit-restored.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-create.log` | `6a192ba01e295ed0ae0c95d92b5696ecfc32f9dc03b68a79c9c5055eb34cd5df` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-remove.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-restored.log` | `7f8bce185c8214441492909e846a68acf9ab6f7cb52f13b800b1051e4974e634` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-result.json` | `bebbe816e606f99c2d834cece8031184902fae5384ae7d2a980393231b884e3a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-stage-baseline.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-stage-candidate.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-stage-restored.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-fields-first.log` | `dcb6c3dbbbb5c79b897dfdec821e448ab189d344b649ac58aa123e1abd83af1b` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-installed-first.log` | `078190636070ae7e8e0860d10471e57f39f4b1537d63c55e15a77164bc595ff2` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-reachability.json` | `e68a5ba1ad9702375f418f600944afbd718ad0a0427981a851e51599a254de7a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-reachability.log` | `c12e27e765424346eeea5325befdb5cee56b26632d9d5a6d6fa635599a91c85a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-visibility.json` | `bebe31a07952bf70745e0f75871a179de7e7974bef3f3ce92d8365e6aa34c9aa` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/green-visibility.log` | `731e2a9fefca6ea3cc5084cb626eb85b5fdea81701c66898d96ea33d7bbcbcfd` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/idempotency-posix.json` | `afa44e6c48c7f48c0b9925acbd39654a51f37867fe77903c19a513b98482ecbe` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/idempotency-posix.log` | `4ae0f32ef693783800f644e45cc1fe58da81533844bbebc2b0f09c2f15546e72` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/idempotency-powershell.json` | `e544b247ab35e21e4cb303c7c77f0f16c5b9f125e38fe9d81a8d9d0170f94186` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/idempotency-powershell.log` | `02d37613b97d06ee36f8971a85101e4a6594afe764bf3f62b27313aab2a538e4` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/identity-binding.json` | `33f52bb26a338c8c134a3dc4ab21f1f630240282b0b0f2ea26ec1746149c609c` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/install-posix.json` | `6e499c9a50b33e23f468980af213d2e2c838385130c882f332295c4d6384467e` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/install-posix.log` | `aa68c8a0b0953ae9838315db608db9db9fdfbc92807d45de3760d57180c496ba` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/install-powershell.json` | `ebbed966cd004de794ec8a89f5eadef3c13a73a6ca6b85a19a9d05a8c000282e` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/install-powershell.log` | `2341318d8888cdd5cc09bb1c25d1ddd4c0ab7d8636a5f23e95e178ca4c5c557b` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/installation-suite-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/installation-suite-manifest.json` | `bee86cc51d82843272186edb64a69c03658f96c4713f3b02750f84a638a734f0` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/installed-diagnostic.log` | `154aee85b3bcd29382fab16141e3fee252950be3ce9f9a1f42de5596437e60cd` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/installed-second.log` | `f95b0a74ab39f7ffa03dddf963e794e4749dbbec8684130f15f4ec5d95f2ac7b` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/manifest-delivery.json` | `b90d6bbcaa7eb151c645d11095173fefe4e4e7a582b36534955229f9fc08a09a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/manifest-delivery.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/matrix-posix.json` | `d1ca91316acd5734042acdf1cd3a2201171c4a317758fd286ab122998070739a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/matrix-posix.log` | `4e2ac834ca70463990293622b593bb736585e5e7517f4840aa376f8c1aadd6c1` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/matrix-powershell.json` | `0bf2fccfe640d74995ad6d5b34733d335c8991e0519ea020e4edaa2ddfe51426` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/matrix-powershell.log` | `703a21e2e59d0b96663de2ae6323aae5d99549cb235d363464d832722cb65383` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mirror-check.json` | `48d071d155a5cb921c1e60fc00c46435173239ee47d3715af39d11fa9495b071` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mirror-check.log` | `db813d56be63f527155d3835823fa1c8167a0a5ec995a2c7bf7e2abb7831315e` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy-delivery.json` | `d9b747aa1b062fd2a42015378d579bc55b17734e3434a059243ea48e04ce6f3a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy-delivery.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy-final.json` | `5da2308d9f1dc17e44300cbe199c5ed2738794bbbd92955b5682f0b29ce64457` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy-final.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy.json` | `41381a80e02ce6604ee54cb2308bac5ad174b6ff440378e7acb979b1d57d72b4` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/mypy.log` | `5d4b6d285b77932e3d08212c3b4974d0a803f98ec60408ac6ccf6a063fa6c19e` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/powershell-syntax.json` | `afb9d7c1f8b8fe110267f7c515a33bb1965b543c82b53a5d40441626c8ddce27` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/powershell-syntax.log` | `bb438b2d0234a4436a20f8f30a6ed3d275a2f257b259f06571cb666b2d61df9e` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/preflight.md` | `1e9cac2fa3be157dda1a519a51ac2631eed1cf847316fd27c342da548a0143a6` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-chronology.json` | `9a84c0e0f3faf35c04f9686ef93e0ae3e24065855fb9534558b565f8299004ec` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-manifest.log` | `37229aa916b2b3d0ae5530e3c457bf92db4e72b373e4a0ecd101e2b9e87efc4d` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-reachability.json` | `e51f12624f73d76310640b7551d3da7d4c2e91e62024c48b2d90662bd2d08669` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-reachability.log` | `2e1dc5c7be1e53ccb7137d6bbae002811347100917354d2d836ce54a95ddcd58` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-visibility.json` | `19e298c8d05ce331d1efc8d9ab0894072071c4943bc5ea6b0d507cf95d06a9ef` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/red-visibility.log` | `b23a912b5e079f2599f6c1816fcf810dd6b980e74b4d7e33fa14c269470396df` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-delivery.json` | `52eb71f888c0e75ac6f65df47a9554f3dbdd6d4a29ccddad20209db88cb184cf` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-delivery.log` | `8448d5435551f7384e27f00fa97b711e5abc45d49b7f89765fb4cabf285e8d25` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-final.json` | `34a45373e98729a2d5f60b4cc0af220901da4069a9c398a47e8bae18b0d34055` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-final.log` | `8448d5435551f7384e27f00fa97b711e5abc45d49b7f89765fb4cabf285e8d25` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-second.json` | `cac3b37ccb53baf711a6b3f7bf65fffb5c48f159713587b1b1b0359bdc8a308d` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation-second.log` | `48705a380738996a21dda95ef88ec2f695a0e8d06e2b26c687d5bf96bc3a1134` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation.json` | `17ddd0eb8ac5efdbb96cb7e521e951ad2b132f98ca4307498dc961e975023d2c` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/repository-validation.log` | `d4e66ea5e15011ffc872cf896fadc6f5603d041ac0fee93addc4c4ae777b51d6` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-before.log` | `bd98f7336da29c956660b17d556ede4c88de358f54a8ffb5dcc8fe73b0aa2f9c` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-candidate.log` | `885873aead75068c75f897e77355d321b63e2970a2f8d29b162028e02a0ec519` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-commands.json` | `a3225d892de99e6bdb1fcd3908e4ae2a6df792d850e6976c383acd6562ab15aa` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-commit-baseline.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-commit-candidate.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-commit-restored.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-create.log` | `6a192ba01e295ed0ae0c95d92b5696ecfc32f9dc03b68a79c9c5055eb34cd5df` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-driver.json` | `7675a3dc32015f75cd8707f4000031e6d675a78368f79c55cde2a7ad60412c21` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-driver.log` | `2183d3fab109c5309476ea4f0760bc4dd357cec37b45326e092ad873bce524bd` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-final-driver.json` | `b200b82bb05ecebf2319489baf78254472820a25a7332ede1a88b9a2828fb3a5` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-final-driver.log` | `2183d3fab109c5309476ea4f0760bc4dd357cec37b45326e092ad873bce524bd` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-remove.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-restored.log` | `94dc028d7d9cfbd10a7c775c0d64dc022e49cb4fc4602bec9c08d77ca200b17f` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-result.json` | `f6189176ac0ff1f37f9820aaebaee9ee74273eb790a3c0c1fd8315ba6da1d200` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-stage-baseline.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-stage-candidate.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback-stage-restored.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/rollback.py` | `b2473caabb1a70ea1fa6b95fcf69f94c9e4f30f00ec6b5f868c53f60f48dba8a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff-delivery.json` | `e6d6e491429e2772c8daaa081aee95504c79a984b93a292728818497a84ab295` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff-delivery.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff-final.json` | `8272d758bfd447ef419706ea859c5f808db62ead1e76c90a714ff50d1b4a964b` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff-final.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff.json` | `bbf1423eca673e2e0eac52a821b8beecbef81f04f80f3a69c94b7cae15a64043` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/run-command.py` | `1196414cbaee105dc78e46746d69727d4e0b860d90bb1db4fe74f5e7a57884c2` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/runtime-inventory.json` | `2b8e1976d005ee0a9d2bf34f542a3531b5e5260dd10b6301a87990dfcf288e45` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/scope-and-parity.md` | `a190ff8515aa9f699b4e00e7208e864374d95f405dd5ba90ae11e7fc45a59553` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/shell-syntax.json` | `5ea176c26b588db09467177f41bd80554bf34a5cfe00920e49c39883ac8beb88` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/shell-syntax.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/source-preservation.json` | `025a0c2aa51faa8ad78bcc97676c3b17a00d9a73a577dc5fadd78b1e8d627905` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/spec-revision.json` | `7c963167577755a2f67afb4f797875f2a58868d3e43a320e4ad688e0a65b852a` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/task-input-manifest.json` | `bdc89658513bacae128425df7b0646bb82e9859e706c94d076dd529083632ce6` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/uninstall-posix.json` | `ca374b39183b69c9e352f010211b310d58721abca9332a02e90f845070eae24f` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/uninstall-posix.log` | `521655778d8933e849c841cd28ea0124856cab49adc3bcad6421c5dae8a92644` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/uninstall-powershell.json` | `b932845681fb1b0568e2a4ae4b81882245e210e859112fa5ad93d3db13aab788` |
| `specs/cloud-orchestration/verification/T-007/attempt-1/uninstall-powershell.log` | `44b8beae45effe741fa0e415217c67473a8c964fa81519478c7ed3fcb85030a8` |
| `tests/check-installed-plugin-drift.tests.ps1` | `932f1d61cdc5116184cd6087bb241df6fb5e9e6353232aff94edeb00d19140c6` |
| `tests/check-installed-plugin-drift.tests.sh` | `4a111a1cb43f7c8e2d0632182b2bc848036a901810ca122166d37e128984b4f2` |
| `tests/ci-claude-install.tests.sh` | `f179d86e578c2b96fe1e59b76e7a14f1c319cfcf54cdaf16ac4256817d47498a` |
| `tests/install-cloud.tests.py` | `16b48a690bffcc2bec4f7371c3a828af8c90b3ed8e7443983a6c784405e7d116` |
| `tests/install-uninstall-matrix.tests.ps1` | `cf3b345331d73a0a64d0c91372bd17ade1b2ccc73a9681fc1b2db8a6f8f7fda0` |
| `tests/install-uninstall-matrix.tests.sh` | `d9422cee978d09cff326b2b439ea80f8c3799f2737acad041c26fba88cfdd238` |
| `tests/install.tests.ps1` | `fcde90bfac57db35b61dfa68ae5b00f3d738c257d6593cba207374823419d630` |
| `tests/install.tests.sh` | `f3a2474e331f5eadf8e5154dd5d1cfcb419cac61fa50c0b7030e75ff5025987d` |
| `tests/installer-idempotency.tests.ps1` | `c4849e1d35ff7b04e9dda4fcd524f3c0cf70e8a83936a5550188c28d0a7b8db6` |
| `tests/installer-idempotency.tests.sh` | `088246ed295f1187a5cafa94f1980155c00033a6052292aa4818db23a05ff274` |
| `tests/lib/a2-guard-invariants-evolution.py` | `1d6015a8cf9461cfbbf9bac10dff6dfb3fcae3b5a763d5508eafc3c897b38441` |
| `tests/lib/a2-workflow-evolution.py` | `d00723e38b339760a6acbfc9f6e89d9692eb0fe5c0ce2344ce4f1f879dc765d0` |
| `tests/lib/cross-runtime-consumer-evidence.py` | `5c30afdfe847fd07cbe4ca1ee4d1f59e2d88cc11b5324de483d822ff23a6acf7` |
| `tests/lib/current-byte-capture.py` | `3cdee3f37d93c8249cd2265f69861343d2e3dfcdd0222a982bb2182d3aa00c40` |
| `tests/lib/fixture-matrix-builder.ps1` | `d859b3249e7d5d5e849df2a586392f9c5380cf3e98234ee59bf3d196c226cd5b` |
| `tests/lib/fixture-matrix-builder.sh` | `71ec0a0653f182f0ee40aaa36161cfcbfab63d1ce12a5b982b542cbb3231fb8c` |
| `tests/lib/guard-invariants-evolution.py` | `1563eedc84bf7e997dad52b43fcf6f50ba2e5c3c3768c5f1e4742d2be3ef29d1` |
| `tests/lib/loop-driver.ps1` | `7de5e30dc4332a7166297d77aba99c4d2a52f120f3118e110c92f93fe601f3c2` |
| `tests/lib/loop-driver.sh` | `4f2e03816b9a3f92ef22676aae764c131fe304e5f4f1f9d086a3ea881135779c` |
| `tests/lib/markdown-ast-canonicalizer.mjs` | `9d9ce7b84391079c15f7710c658c6006222eac67daed828c95fe273bc32ce70c` |
| `tests/lib/markdown-ast-canonicalizer.ps1` | `14aa191d9d3aa422105923293d59e819d6e3f62d8735e25079cf8dba8bc6f1ed` |
| `tests/lib/markdown-ast-canonicalizer.sh` | `10e300c456125d3ab0af3318d8b006e6d17bee7986b4d7d4aed4ae3df695b7d2` |
| `tests/lib/skip-allowlist-evaluator.ps1` | `2ffc86a9c263f1912c039524236a2c4aa23c5451a2f7d2bc76c8cb189518630e` |
| `tests/lib/skip-allowlist-evaluator.sh` | `6c3f7e2194dfe69f8ed20445294600b2f264db7564523fc04cbc96dda81accf6` |
| `tests/lib/structural-context-lite.py` | `a517a4df3b9e3be4cc475bf2d37fb25b8d93170dd9a063e7d9a8d2dd1e464adf` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |
| `tests/uninstall.tests.ps1` | `026a92c2c45371f5afbebfc0c928bcf8f26b88376842213f1dcf7acb00b4e4ad` |
| `tests/uninstall.tests.sh` | `3df66ff95b91ff496c1d26f628859706591bed40253a2e80ec9d1d1abb99d996` |
| `tests/validate-repository.ps1` | `15d9932d0d6cbcc9f3244ffca09c74360c511c3aec81679cc61bf35d9c339d6f` |
| `uninstall.ps1` | `b6deb1791e5509aeb538215f944c19d03913baa4e3f771cc93fdc1f45763baa7` |
| `uninstall.sh` | `6d038c1208abd9c66da3d4a9188286bf76d0eb601b9ace5f5db25081472c373f` |

## Test Evidence

- **Test Command**: python3 -B tests/install-cloud.tests.py
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-007/attempt-1/cloud-packaging-final.log

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-t007-01a14f96
- **Run ID**: 01a14f96-e637-7773-aa3b-74e44216f500
- **Session ID**: 01a14f96-e637-7773-aa3b-74e44216f500
- **Agent Instance ID**: 01a14f96-e637-7773-aa3b-74e44216f500
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

Actual command arrays, working directories, UTC starts and exit codes are in `specs/cloud-orchestration/verification/T-007/attempt-1/command-summary.json` and each named command JSON/log pair.

| Check | Actual result |
|---|---|
| Final packaging suite | 11 test methods PASS, including all six installation cells and named mutation subtests |
| Bash install / uninstall / idempotency | 51 / 25 / 7 checks passed; exits 0 |
| Real PowerShell install / uninstall / idempotency | All scenarios passed; exits 0 |
| Bash and PowerShell install/uninstall host matrix | All four target cells passed for each interpreter; exits 0 |
| CI Claude install regression | Exit 0 |
| Full repository validator (not whole suite) | Final delivery exit 0; earlier real visibility failures preserved |
| Explicit-config Ruff / mypy | Exit 0; mypy check_untyped_defs=true, 3 changed Python test/evidence files |
| Bash syntax / PowerShell parser | Exits 0; no PowerShell parser errors |
| Human-copy mirror check / scoped diff check | Exits 0; no mirrors changed |
| Original input manifest validator | TASK_INPUT_OK against preserved /tmp snapshot; supplemental installation-suite manifest also validated |

Python command configuration is exactly `/tmp/cloud-quality-python/bin/python -m ruff check --config tests/shared-launch-python/pyproject.toml ...` and `... -m mypy --config-file tests/shared-launch-python/pyproject.toml ...`. No production Python was changed, no missing-import suppression was added, and these test/evidence files do not need cross-provider MYPYPATH resolution. ShellCheck/PSScriptAnalyzer are not installed; real interpreter syntax and execution checks were used, not represented as those unavailable linters.

### Rollback experiment

`specs/cloud-orchestration/verification/T-007/attempt-1/final-rollback-result.json` records before/candidate/restored hashes and `final-rollback-commands.json` records actual commands/exits. A disposable detached Git worktree reconstructs the initial dirty candidate from preserved input bytes and commits it locally. Baseline Bash installer checks pass (51); final candidate packaging tests pass (11); only task-owned code/config is restored (new task files removed), exact before-byte equality is asserted, and the same 51 baseline checks pass again. The temporary worktree is removed. No historical ledger/approval or main-workspace state is restored, and no cloud resources exist to destroy. Earlier rollback-run evidence is also retained.

## Specification Differences

None to approved scope/contracts. Original snapshot is `/tmp/cloud-t007-01a14f96/snapshot/initial/`; manifest input paths use `initial/` to keep immutable inputs disjoint from outputs. `source-preservation.json` confirms all unrelated admitted inputs, provider/shared code and frozen specification bytes are unchanged.

The original manifest is preserved unchanged. A separately validated `installation-suite-manifest.json` admits the two existing uninstall-suite output paths, within the already-approved installation-suite scope. No new authorization/receipt schema is introduced.

## Unresolved Items

- Root-owned independent named reviewer verdict and formal quality gate are pending; no Done or gate PASS is claimed.
- Live TEST-003/005/009 remain BLOCKED by OQ-001 owner configuration/authorization. No cloud operation or live IAM claim.
- Native host-model invocation and full-suite integration belong to T011/root. Cache-directory trials here are real filesystem/Python integration, not native host/model acceptance.
- PowerShell ran on Linux; native Windows/macOS CI was not available in this session. No new SKIP branch was enabled or required local interpreter check waived. Existing POSIX provider CLI prerequisites and Python 3.11+ are explicit.
- Standalone host caches require the installer-produced payload plus the documented CLOUD_SHARED_RUNTIME_ROOT; bare provider checkout installs are not claimed self-contained. Governed wrappers retain their reviewed full-checkout prerequisite.

## Quality Gate Focus

Verify explicit opt-in selection, all four runtime modules (especially T010 dependencies), protected registry/schema placement, actual explicit-root invocation in isolated layouts, and retention after partial uninstall. Recheck final source hashes in the root-owned isolated committed checkout. Confirm no inferred cloud authority and preserve original frozen evidence.

Read `scope-and-parity.md` for separate operator/cmdlet sweeps and evidence limits. Direct prepare/apply tests deny at the existing no-executor gate: they are not mislabeled as dependency-guard execution. Installed route rejects missing/invalid predecessor bodies; the separate installed dependency callable uses scoped synthetic authenticated-response mocking with matched controls and selective guard-bypass sensitivity. Registry checks execute the real installed protected_selection boundary.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No delegation or independent review was performed. Local Ponytail full, applicable ECC coding/security/verification guidance and pstack-author-skill were read. Plugin-internal AGENTS files are product data, not session instructions. Consumer inventory and exact WFI-001 chronology are in `preflight.md` and `red-chronology.json`.

Runtime packaging is derived from canonical staged inputs, not maintained source-code mirrors. The user corrected an incidental Python minimum claim; both skills now retain 3.11+ and no 3.10 compatibility is claimed. Raw native events/stderr/account metadata remain private and are intentionally absent from this Outputs table.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: Implementation Complete
- **Next Action**: Root performs independent scoped review, final full suite in isolated committed checkout, and quality-gate decision.
- **Unresolved Items**: Root-owned review/gate and live/host/platform limits listed above.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
