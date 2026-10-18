# Implementation Report: T-013

- Task ID: T-013
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

Repair only RT-20261018-CLOUD-PREFLIGHT under approved cloud-orchestration T-013. The defect is an inaccurate historical execution-evidence claim, not a reproduced product defect.

## Summary

Preserved the canonical report and corrected its line 370 claim in this dated addendum. Executed **126/126 current-code probe entries** (26 existing AwsExecution bodies plus 100 supplemental assertion groups) and **35/35 targeted sensitivity controls** in disposable source copies. Each sensitivity run exits 1 at the intended assertion with setup/body execution confirmed; the mutation driver exits 0. Unchanged execution regressions **86/86**, contracts **31/31**, configured Ruff/mypy and report/manifest validators pass. No production or stable test-suite changes, cloud calls, task/ticket status changes, independent verdict or gate PASS.

## Files Changed

- `specs/cloud-orchestration/verification/T-013/preflight-repair/probes.py`: supplemental current-code probes using existing AwsExecution, AwsWireFixture and AwsAuthFixture.
- `specs/cloud-orchestration/verification/T-013/preflight-repair/run-mutations.py`: isolated source mutation runner, exact patches/hashes/exit records and restoration.
- `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback.py`: scoped disposable-checkout rollback experiment.
- This new report and task-local manifests, policy snapshots, matrix and execution evidence only. Root-owned allocation/model-selection/native delivery files are untouched and are not outputs of this repair.

## Tests Added Or Updated

No edits to `tests/cloud-orchestration-execution.tests.py` or production code. Supplemental cases exercise the actual contract parser, readback, native serializer/signing/XML/S3 path and GitHub/OIDC/STS admission via the shipped synthetic wire fixtures. No alternate verification engine or replacement authorization implementation. Guard instrumentation records false guard code/file/line and calls the original guard unchanged. Socket connections are forbidden by the probe harness. See the complete per-field map in `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/preflight-matrix.json`.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `AGENTS.md` | `be21577343b8b2cc488c47b373ed68130ded00d994f58f1f81b7b69bddd6d537` |
| `contracts/cloud-authorization-receipt.schema.json` | `5c4f8efaaf458aba6f149a53967df7615eaf2a823c4ec6f75e44610a4c8ac8b8` |
| `contracts/cloud-dependency-lock.schema.json` | `e72395e755f13bff50f8f10d27a8181fcfa1894ef6c60499c01f84d4c2128cec` |
| `contracts/cloud-deployment-policy.schema.json` | `a064217e4a68838a3d719749fb751ba63ffabb2094d16cf13090afeaed080eb8` |
| `contracts/cloud-input-error.schema.json` | `d228ad47ea2c899022169a704c9408f6b5fee285be5be12ad3f0906bd2b4bc77` |
| `contracts/cloud-observation.schema.json` | `5ce80d6fb77fde9bc966d00db75c2650f3a37166fcccfd1071f087208191c826` |
| `contracts/cloud-operation-result.schema.json` | `a92bdac86499052256112babe5ff559c2e071adba411f4a2e92ec38b6b5b2aa6` |
| `contracts/cloud-ownership.schema.json` | `71079e7320c968bce57fba67bd105d59ab57c00a51165a3598d522919141f25d` |
| `contracts/cloud-preview.schema.json` | `12afaf962e1bf1325496d985b21ffc5c970c1e2d14fc43933c5ad8aa8940eb99` |
| `contracts/cloud-run-request.schema.json` | `781d83fad3d8e883e2c4aa886c5356da12f93d5ef5e35f16a5d83e9c024c9d81` |
| `contracts/cloud-verification-profile.schema.json` | `b25112c7e73583b180941639cb8f137a89fcb7daa82b1afd7ec8eec66c9353bf` |
| `contracts/cloud-verification.schema.json` | `dcfd0760733951080efc1f0cb993bfc46a081b4eff4a82bd07968f868b2f3f2e` |
| `docs/adr/0036-thin-cloud-orchestration.md` | `d67248086011bcabfe482073b33d25bc39f066fd0f3763ee88bd70ee902656fc` |
| `docs/contributor/shared-file-mirrors.md` | `b9406eb20abf5732c26987fc71bfc9163aa175174b7e43e6c100f74fdb388cfa` |
| `docs/review-tickets/RT-20261018-CLOUD-PREFLIGHT.yml` | `f6436dc2096967465fb31c49e6fa2e5b2b9c03ad7cf1d93ddfd43103d8685838` |
| `plugins/sdd-aws-cloud/examples/private-ec2/README.md` | `0caceb7832a0c3e467042a760789f03a47521eaca375e712ea15120931e2ea5a` |
| `plugins/sdd-aws-cloud/examples/private-ec2/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `plugins/sdd-aws-cloud/examples/private-ec2/cdk.json` | `7802e394180f0d618f4caf7d1a6647f406ad327fa0aaa38c84b8b6b8471b24a5` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `plugins/sdd-aws-cloud/examples/private-ec2/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `plugins/sdd-aws-cloud/references/aws-local-config.schema.json` | `90e8ebd3e71d4041d25a831b1c9a5823c90494f942b68d797d46f07f584bf85e` |
| `plugins/sdd-aws-cloud/references/aws-local-evidence.schema.json` | `d64402c81095bd9a0657d34f4723a02996d91bb93cb0d0906c4ca288aeaa3187` |
| `plugins/sdd-aws-cloud/references/local-preparation.md` | `2a890269fabb6128f125f5533d3eb4c6411589ca0d0843b642b47cc959f7a257` |
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
| `plugins/sdd-aws-cloud/scripts/aws_execution.py` | `5e1a90030b96ac2ae44c976d60c0e905ce03f7f467b035e7721b5835c97be20e` |
| `plugins/sdd-aws-cloud/scripts/aws_governed.py` | `135b2995f61f939a418e63176cca3c9c6199d66e62412816023e263119902235` |
| `plugins/sdd-aws-cloud/scripts/aws_graph.py` | `21896c758e64f5db7571c2c5209a4ab122cac8347dc18096c29e79f7396a42fd` |
| `plugins/sdd-aws-cloud/scripts/aws_local.py` | `277a0e905e3da8e8e8f9f714b369cb30525fef5c23aff047a66c7d43bba0f2f3` |
| `plugins/sdd-aws-cloud/scripts/aws_native.py` | `c49dc00931cda5a913e896278da3ba1f48c5c97dbc365c4618edc5ff377fcf8e` |
| `plugins/sdd-aws-cloud/scripts/cloud.py` | `a276aa085ce7cd46af359e0c67aee05f9a969dc49989668f312ce1eb88dd4689` |
| `plugins/sdd-aws-cloud/scripts/governed-setup.md` | `2bd8c9b4ddcd7d9879a5b58d1e7c30d4d9c8c0286501b6b4d066eaf967712578` |
| `plugins/sdd-azure-cloud/references/azure-local-config.schema.json` | `6a9d1d5fe91ca828ca2b50a282457c4e4e3dfa7f79b0c59d3a9e3f6c5f40ebb6` |
| `plugins/sdd-azure-cloud/references/azure-local-evidence.schema.json` | `e4584e317609585b3effc865412757ef730448d814b2ce7f78eebf485728b68a` |
| `plugins/sdd-azure-cloud/references/azure-parameters.schema.json` | `5922b55565b1a506db4cc424560cbfaa0b07766f1e26bf50dd4247ade18fc3ae` |
| `plugins/sdd-azure-cloud/references/local-contract.md` | `68850cae945e1e5357fedb284079cce67fec809a07cd1a35f6f923a39b89fdfc` |
| `plugins/sdd-azure-cloud/references/upstream-lock.json` | `f7e22249f21c062e6207579460b1ad1042af52e4eb619d8566fd4d99db675644` |
| `plugins/sdd-azure-cloud/scripts/azure_arm.py` | `5ee98cf0fde60b1d8e9959cf17e7eb6e53fbaf179104ad0e080b849f936cff86` |
| `plugins/sdd-azure-cloud/scripts/azure_execution.py` | `661a545a10620fceb0f05337834c36b20efa23b08b663b068efb388abe6444ab` |
| `plugins/sdd-azure-cloud/scripts/azure_governed.py` | `a0669240ae1acdfb62adfedb36e131d1421349c5a0b65f7411106c660aea458c` |
| `plugins/sdd-azure-cloud/scripts/azure_graph.py` | `f46bdc77c12449d0f4befd0221b29687e7b4f48685cc6106080de62b3a4d075f` |
| `plugins/sdd-azure-cloud/scripts/azure_local.py` | `13c1b71923501fdd861e583ce14f7026d538e6c8e89505a87f5211fc4b82bbbd` |
| `plugins/sdd-azure-cloud/scripts/cloud.py` | `83f9789f6d42eb68391d69ccf0dfeb7f24e214d677290e9ffd646b2dc999e5f7` |
| `plugins/sdd-azure-cloud/scripts/governed-setup.md` | `b2f038ab953175e2fab863d5cc8baada77a79c0b8cef1281df68142831343388` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/skills/implement-task/SKILL.md` | `6a3bdc2efd1e8338a961c23e69240e27e5c7a366580d6fc3a1a532461a1b507c` |
| `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md` | `d0622d44f13693cf6e32c918aba53efbcc5089dbfbba8a539bec3be601017051` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-craft-policy.md` | `5f00ddf2765b5086dfc83b3e24ad6873a7e08a08d419126fb619adcc82e0beff` |
| `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` | `739173bcd97aaa185206b85ce0fc88cbee96e51447d0097a082fedead40b30e6` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/references/debugging-recovery-policy.md` | `7b392649cdfa5d565df1e7fb37db0ee5ff528ee870ff3feb523bb57e1294254c` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `b165a6aa307a25721a63607f3c314bb6d290b1e1e450006be66c9a7d208ba916` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md` | `0215d3a6c097c893727276afc6078415cc83c3aa4273dc8bc62865bc3af6efa1` |
| `reports/implementation/cloud-orchestration/T-013.md` | `f7b6c8373b4540481f1be17f113ac45f4a93d4c9fdec555c264af809e0f4fe08` |
| `scripts/check-sdd-structure.sh` | `4b64e8027ce7cc5f99f788ea044ad54f8a5add23acc253419c5f26fc5b9671f6` |
| `specs/cloud-orchestration/acceptance-tests.md` | `4eb6f1a088bc175196ff6f9e33393b05190903e061186fe70cf4895f044f06e0` |
| `specs/cloud-orchestration/design.md` | `f3605c89c9522f3f167db695e2bbf2bcbe7e9e71c92610ff0032272b0bca5f89` |
| `specs/cloud-orchestration/frontend-spec.md` | `586d52fd577b5eaa24be9037f80fbc0334ab934906a9125ead71206eb8561d2b` |
| `specs/cloud-orchestration/infra-spec.md` | `9fcb3698f73022d60b8848785b05ca137620b97cd43586da63a0e75716bccf7d` |
| `specs/cloud-orchestration/investigation.md` | `38229c1b74b815780bfd752a353f1dc15bbcfeefa0285e4f8dc097721227f20c` |
| `specs/cloud-orchestration/requirements.md` | `31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922` |
| `specs/cloud-orchestration/security-spec.md` | `fe980874e34da14db58b088b0ae6f989a6e0dadc3a39757851457c0c5312e1db` |
| `specs/cloud-orchestration/tasks.md` | `469f155152297d1f4563eaf2bba21a772fdde3b23c26a409db0c61ee1fc4a4fc` |
| `specs/cloud-orchestration/traceability.md` | `6c7c7ff4fd36cb0468a5d91f6228b1d27f55f408e7098a660285290df277a0e0` |
| `specs/cloud-orchestration/ux-spec.md` | `d02d6d219266ca0b5c0ae9705a58e67b66682f3539ce2cd749e545abe5bad8bc` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/config.json` | `44f0deeb6b510736a1e2fd4b8449f20aefc738762e145ad0219b93888ce9c799` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799.request.json` | `6fd2d502e01d1d5e93708e24157abdeaa7d64602a91795f559b2e968c44ea23e` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.assets.json` | `61dc41017079b19bf33c9456734c5ac6a6b40321a36736618f5e9a1309a2404b` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.metadata.json` | `eca3c5a792ec796bccd3933f8016a843cbe404c87adc30672d9b73d6e0c620ae` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.template.json` | `5a38413c71992f0b05399d948f11b7853dfc2a34a4b59dee90ee7ea69e429113` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/cdk.out` | `2801c31b9ddf660f597e3c9d9ba2a9505ac144717ede055f34dc916602a35b25` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/manifest.json` | `5f9fef0f3c6a140e5899e8865438fa914b1c3ec5bb2790b01fbfdd8ea97d5139` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/tree.json` | `3761ef1db74a85d2947a3d83e28066d5ec59e9167d13b0ff87a84115c8bd8a1f` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/validation-report.json` | `37b01cf5f0a5b20784c30c5c70bddb00b633d76449ea5abec1fe334272da287a` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/lock.json` | `742c2c404cc22a8b93fef2e6958f431708643ae514eaf1ebbdda6cd70f990799` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/ownership.json` | `13714b3f1d710d9fe65c99901041d0fa2add43360017fd979e5b8e9243e66293` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/policy.json` | `9062f2dd81437a4c4b4072c84c6bedd63a5b58701b8becb2bfd43a3afcd3607d` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/unit/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/unit/cdk.json` | `9727d1b2d1513b0863b75f81d75d95db66a53d79dafdd78ab00a1338f4239112` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/unit/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/unit/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/unit/parameters.json` | `1f5b55cda74fe4c5b95515db9b12c5e30df3feead79deb0ad19200c2aa7a8e02` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/SKILL.md` | `af178f8e909efd66496b09c7301c5e11ef96681fd62bf91406dcb340a18aacf6` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/bootstrap-and-project-setup.md` | `ce48bf13921481aa6d2df131f0bd32faa8cc07bb50b63b1805ddbfe6ca18a5f0` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/compliance-and-drift.md` | `4d576be561b16fd140c7f44de3b905ca81718752003a5072fec7062f2a2e782c` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/construct-patterns.md` | `029a6450cc738c220051c1e2df94cb08e82b9fd80b20ab6b1b31696015222d6c` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/fast-deployments.md` | `b6ddc7a418ed0d2f6e450c1835e3dc83c0648cbcdf4b582ebd66234918b22171` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/import-and-migrate.md` | `375e247190c3ebe29b2b8b211f665d4f463c7d959d3a6a067f8816d1a5df3a26` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/refactor-and-prevent-replacement.md` | `bdc1dacfaaaef810923699fc19803b492815b404190f055f90bd3558587b335c` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-credentials.md` | `87b36861e1cf656fdb576536c20c61dfff5316e1b7465954f9b1b01cce0f0ee0` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-deployment.md` | `80b97fe332046fb025cf6635b3add76046bf9b2933bd45394255585f1694a967` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-synth.md` | `1397f0c8034ccafd1353c3053d119e721c4904b9dc2ba33a1f285f69bfb909ea` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/v1-to-v2-migration.md` | `f88efb1a4b7451fe194e5c617ea2c467be93ecaa7221264b80361cca035dc181` |
| `specs/cloud-orchestration/verification/T-005/evidence/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/config.json` | `ccc52fa5eb81253dec9a1edcbb6376c4f363cbcbe5cc6cd25e16bf51bdf1e6ea` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.arm.json` | `5d433080a667406b0e7372252cd1e3cace0fee1b505a295dbdc65561c6e96c7c` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.request.json` | `aa2abc4ddb432984ac48c57fdfe46778ea2fbe8356b6edc58307453324ed96a0` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/lock.json` | `5d2f63bf39f892ae40d578f257af645bf1eccbdf468f4fb047a4187157a797c7` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/ownership.json` | `5405208196f15113bc06f82ee538997a19415517561e79a07f0077259ed2022c` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/policy.json` | `ca75f6b9e1a6362ba36fa496974bff564a957003f73da3f32443f412469531e4` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/unit/main.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/unit/parameters.json` | `361d0679465fa218a24786f54017a8b4441e8baf9691a4efdea02bd600fd0935` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
| `specs/cloud-orchestration/verification/T-013/evidence/red.log` | `bb3546aac01c43880e9c7436bdad4ea4da4ce35be90ac42e3726f217de290489` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/config.json` | `44f0deeb6b510736a1e2fd4b8449f20aefc738762e145ad0219b93888ce9c799` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799.request.json` | `6fd2d502e01d1d5e93708e24157abdeaa7d64602a91795f559b2e968c44ea23e` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.assets.json` | `61dc41017079b19bf33c9456734c5ac6a6b40321a36736618f5e9a1309a2404b` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.metadata.json` | `eca3c5a792ec796bccd3933f8016a843cbe404c87adc30672d9b73d6e0c620ae` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/Private.template.json` | `5a38413c71992f0b05399d948f11b7853dfc2a34a4b59dee90ee7ea69e429113` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/cdk.out` | `2801c31b9ddf660f597e3c9d9ba2a9505ac144717ede055f34dc916602a35b25` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/manifest.json` | `5f9fef0f3c6a140e5899e8865438fa914b1c3ec5bb2790b01fbfdd8ea97d5139` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/tree.json` | `3761ef1db74a85d2947a3d83e28066d5ec59e9167d13b0ff87a84115c8bd8a1f` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/generated/b8e335ba271768fe7164a151ff326c7b8d41f6e3409d49f5eaacd72e7d656799/validation-report.json` | `37b01cf5f0a5b20784c30c5c70bddb00b633d76449ea5abec1fe334272da287a` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/lock.json` | `742c2c404cc22a8b93fef2e6958f431708643ae514eaf1ebbdda6cd70f990799` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/ownership.json` | `13714b3f1d710d9fe65c99901041d0fa2add43360017fd979e5b8e9243e66293` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/policy.json` | `9062f2dd81437a4c4b4072c84c6bedd63a5b58701b8becb2bfd43a3afcd3607d` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/app.js` | `710c6889188eac80e9f5e6b505c3796ded52747c9a56c305c58a53d05f3c2b25` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/cdk.json` | `9727d1b2d1513b0863b75f81d75d95db66a53d79dafdd78ab00a1338f4239112` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/package-lock.json` | `b106084fff5e18ca94260509133337891b58d5269d77166ff9320a36419cccec` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/package.json` | `beddc07bfbf3d198ca58b3d500e746b7bd4ebc14a25b469033fb1c41ba50a00b` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/unit/parameters.json` | `1f5b55cda74fe4c5b95515db9b12c5e30df3feead79deb0ad19200c2aa7a8e02` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/SKILL.md` | `af178f8e909efd66496b09c7301c5e11ef96681fd62bf91406dcb340a18aacf6` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/bootstrap-and-project-setup.md` | `ce48bf13921481aa6d2df131f0bd32faa8cc07bb50b63b1805ddbfe6ca18a5f0` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/compliance-and-drift.md` | `4d576be561b16fd140c7f44de3b905ca81718752003a5072fec7062f2a2e782c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/construct-patterns.md` | `029a6450cc738c220051c1e2df94cb08e82b9fd80b20ab6b1b31696015222d6c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/fast-deployments.md` | `b6ddc7a418ed0d2f6e450c1835e3dc83c0648cbcdf4b582ebd66234918b22171` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/import-and-migrate.md` | `375e247190c3ebe29b2b8b211f665d4f463c7d959d3a6a067f8816d1a5df3a26` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/refactor-and-prevent-replacement.md` | `bdc1dacfaaaef810923699fc19803b492815b404190f055f90bd3558587b335c` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-credentials.md` | `87b36861e1cf656fdb576536c20c61dfff5316e1b7465954f9b1b01cce0f0ee0` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-deployment.md` | `80b97fe332046fb025cf6635b3add76046bf9b2933bd45394255585f1694a967` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/troubleshooting-synth.md` | `1397f0c8034ccafd1353c3053d119e721c4904b9dc2ba33a1f285f69bfb909ea` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/plugins/aws-core/skills/aws-cdk/references/v1-to-v2-migration.md` | `f88efb1a4b7451fe194e5c617ea2c467be93ecaa7221264b80361cca035dc181` |
| `specs/cloud-orchestration/verification/T-013/inputs/aws/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/config.json` | `ccc52fa5eb81253dec9a1edcbb6376c4f363cbcbe5cc6cd25e16bf51bdf1e6ea` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.arm.json` | `5d433080a667406b0e7372252cd1e3cace0fee1b505a295dbdc65561c6e96c7c` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/generated/2171d811234c76745844acbc612901606f70bbbf00cace71420a7e4467b8972a.request.json` | `aa2abc4ddb432984ac48c57fdfe46778ea2fbe8356b6edc58307453324ed96a0` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/lock.json` | `5d2f63bf39f892ae40d578f257af645bf1eccbdf468f4fb047a4187157a797c7` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/ownership.json` | `5405208196f15113bc06f82ee538997a19415517561e79a07f0077259ed2022c` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/policy.json` | `ca75f6b9e1a6362ba36fa496974bff564a957003f73da3f32443f412469531e4` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/profile.json` | `4ec5f27f718f26f6086dad4216fc8e1a909aba5fed9ba971575c7d57c69747d4` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/unit/main.bicep` | `81ba478fb3744e96496243358f3aef3477646027a58e1220f3c16b7b428c9422` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/unit/parameters.json` | `361d0679465fa218a24786f54017a8b4441e8baf9691a4efdea02bd600fd0935` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/upstream/LICENSE` | `8a5d8efb70942e65032f930c761d097feeb41a7517ebd04c9d2e4ec3764071c5` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/upstream/reference.md` | `a4976e733b7793b0014b3be1d5a1c5282002ba16dd7be9a7fffd509c800b5505` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/README.md` | `61a52989ee67dfe4ee30aeb88a06bd15460d3d61d9f1101f3d0d58c19d1e4852` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/upstream/skills/azure-compute/workflows/vm-creator/examples/bicep/main.bicep` | `6fa0bd982a36436cc4a6929ce5a8bb2fff748248d2865000110de0a18ef51b5f` |
| `specs/cloud-orchestration/verification/T-013/inputs/azure/bundle/upstream/skills/azure-compute/workflows/vm-creator/references/output-adapters/bicep.md` | `ab54837a3cde78093ebb59875c0cb1f471c57ee786d8b7d417f808cf94b56439` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/0/AGENTS.md` | `0b57a17a89b0ad81a6be9f0c884930af3ee7f1091a6f5056c28af8714ba6aed8` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/1/SKILL.md` | `9badd22a32e19cb884e46dfa8d3aae82bb81dfa5484105b8b4f0262df823a509` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/10/aws-s3-2006-03-01.json` | `84c3a4e6ac1c80ed49cb1ddf1f548ea7f51d8a41acbfa0f198b9ba0028d784e8` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/2/SKILL.md` | `e80544c3d1eac5b14f22022146bd91a6b0ecc30e099cf5181894853aeb81dee1` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/3/SKILL.md` | `b9eb6416eebc8dda046674f0a2dbb3be88aff526d182b60a0f55998d3d6d0d8d` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/4/SKILL.md` | `5b06be54d4852f60e6cf1b04c6e9a4748554334eb3e41af6c0959b544e6464ae` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/5/SKILL.md` | `3ff578665c61394aea0fbe5a4243e8d6280d841d6e73c12a4e81f81d2ccc9b06` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/6/aws-cloudformation-iam-unavailable.json` | `415eab6f564b8124a27d3564e61cf902bb6cdd7dd630161987b263eba9780bf3` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/7/aws-cloudformation-iam.html` | `4855e6faddb5f57c160a3eff7dcfc73700943471c806b6cef67f13ceb2f6f592` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/8/aws-acquisition.json` | `8e5413290f160504a505c78e121f07e2c8748156e9e9bd39f3979ae6c409d8b0` |
| `specs/cloud-orchestration/verification/T-013/inputs/external/9/aws-cloudformation-2010-05-15.json` | `142ac136f30bf2ba93723536c67e66443b00d86cc2128448916d6d7ab145eec3` |
| `specs/cloud-orchestration/verification/T-013/inputs/iam/aws-cloudformation-authorization-acquisition.json` | `106b0ed368e8d6f10b25c7bc5ddf72268ddd694581170e5f376ff83857124f81` |
| `specs/cloud-orchestration/verification/T-013/inputs/iam/aws-cloudformation-authorization.json` | `5f5214d42df63c5d04964ae9086788bc060bd09d52c92a75ba51f6914385e83c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-contracts.log` | `a20c55ec70e7a16a85c375a07f09118889db7dd1bc9fca05ccb56ac55cc4f1d3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-execution.log` | `43c19d7156433e30dd150ebb8e47eb9af401d3980dc198a5dc059c20b2821bae` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-manifest.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-mypy.log` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-report.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/after-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/before-contracts.log` | `76e2fabd51dd96cc9c6a480af76fd420a550b47c4846a12bacab70457f7bda95` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/before-execution.log` | `6fcadff7edb14c3b85513a72aac8a679c35e4716f0819fe53d9337232e94642f` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/dependency-supplement.json` | `23420b49492cae59cc70397ad52be3576dba0f451f5f0dd3319dc15a2832f5f6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/entry.json` | `df8aed670d3850b02a41e58607f276b7b0d472e876ee40ca168bcf508c25f061` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/final-checks-driver-source.txt` | `716f89da39d47f8d1cd65fb6a4adcbbfa0f50b7500746c8a0b609e15c42eff78` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/final-checks-driver.log` | `89ee8f1a1ef6aa7cfecd7af7a99e4e2222b86cf0abc1919607f93a88a39e00d1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/final-checks.json` | `e1a96d7818490b7acf14eb392c1b962ea4c0c0bf1a44e263167d46ca2b5cc8e5` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/identifier-sweep.log` | `e25a1b05e69e9d978b6673c5cf8287b8da4411929d2de1bf2a1350964bdbef47` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/input-preservation.json` | `bb107818bfcfec7c91021170ecce03dd2dd42e73ba4e4a3d3f3555d989f20a34` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/local-evidence-commit.log` | `8682b61f04da1df95db87b7b8ed8f7d4bbd9cf1cc3a72bc3526cb2449aa43527` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutation-first-probes-source.txt` | `a66f012996c089da32d30356db88c716362faa23cabff0271d8ee42fa1be40ee` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutation-first-runner-source.txt` | `d2e7457e39836a455d3b2d42ab7b10ebb73156fd071cb8a025f6222cf47cecb1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final.log` | `e5b3edbbd3fe2b55ab158450a6df74bd149cf77d23870c3ed890d6b99a05768e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/approval.json` | `94a5875b8c3253e81f1fdda76004e1bb12b58d3082ab432bc12497c4e8de60cb` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/approval.log` | `a5858a65b493d111d5d7c5e2902a72fa6b96cf6b7d1ce8f916d4463382cf0f76` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/approval.patch` | `73a2bbf4f53b53207664dc4ec7b13422609f22cd5fb393198815172313ed4bcf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/arn-scope.json` | `0edfa72facd43d7ee7fc330d02f70d13eb367971838f59b481405f52d513d22a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/arn-scope.log` | `286017b2564817c2d26f4575886474936f1b0789ecb95f4ef90fef7a113f766d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/arn-scope.patch` | `3ff755ca597d60aafd2a09dba89d5342afeabbafd836354e52a88a5cdade962b` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-encryption.json` | `4fe09886502e7c6fbd4decf5861234aec2bb2333e75632ffe1ba15f78f4a79c9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-encryption.log` | `4e478d228598ea75337a04177749dfec16505f7578adc0c13d88ac4e6678ee8d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-encryption.patch` | `49256366e46783523ee7346fad0c9a19ac0272f783e6185caf27f5b049b65c77` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-key.json` | `bb58a748be6808b2551abebe7b08630ad9b7e4acab800c120b8882d1bd899df6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-key.log` | `5817b1a85c9f6eee81de8cbb5d368746b21cce13fc24fdd4ff106bb0c00d85c2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-key.patch` | `ef6a4225ecff2acd52902149312d20d12533cd15685e863d6ab59658ce207489` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-readback.json` | `c8be3242f68f6fed8964193b569cead0124eb41c57f838b52247e395edcead35` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-readback.log` | `a5527c3960780d242b0505fa6c9d7d7a607d6e3cd85358a92fef71bce07417df` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/asset-readback.patch` | `545540ff074a750f6fb4e72e4f2f8f151d91a579c591db8b61340f4e2d8ca680` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/event-token.json` | `ab683f7e5d6a50f8e7d7f18dd87e8ea2f6a85d48dd5a60bbcdb67896a00f3408` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/event-token.log` | `42873fed395e6a08dc90ceeb62c0552d96124dc9160a0ffde759ecb85dc80444` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/event-token.patch` | `04409a6121846e12666bac260e9e6498c49fb421748d896358b5745b0e92f5c8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/exit.json` | `5fdf02b8210f8d3b3b6fa3bcc791c43a235834dafe2de910ca0e3963b139070a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/exit.log` | `30574e347638bd89528389d14d99348cefe83417025b72ba1239cd46de04b285` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/exit.patch` | `87635c7d5206383c71a6af71aa47a360eea1e990902ffcfe3f9d6142a6cfda29` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/failure-policy.json` | `2b7c64d1e3f95aa553796c95ecce5b478e71f54ff59fc2a504f4c2e38cfb40e4` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/failure-policy.log` | `faf75166ee1c1f2fb18f22e9744520c42ed5fb33432263b624114114c1c7afb2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/failure-policy.patch` | `8281fd1a1f63d0ea0b50c540f1184d31dbd9fcf51be9627d7208bc5bce54124e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/file-digest.json` | `ca5a5c225fbee8637d7448a5c2b62873ed6e7de46037394fa03d741706f7128e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/file-digest.log` | `913617270c83bdac7faf4874526ba31583de6f2b45e385b31ec07826e8c42b91` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/file-digest.patch` | `bce73f01813d8b4ee8951f96ca6b5578247974099008d4d49954ef5ae70ba38e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/health-flag.json` | `a6a252418697960d163da389daf2ef38244e23f32087243ff7fd0f2a4cfe0cc9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/health-flag.log` | `4f47eaf4b912d24a01399917b5bb3c5ab51b0d607c9c25dd8ffbb8bb36c619ca` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/health-flag.patch` | `d526407fae6d4df4cf207020178230bf3c6c4d99a6d5fad759fd4c05c5486b20` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-binding.json` | `86412b369f4a7a7179385d0f4c0df1db646b595c93a4ba7834844c23395728b6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-binding.log` | `3f3a33e68b3b30536cc5e51694260a6be514ad5e595b6b46dde3f1d9d5704fbf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-binding.patch` | `8298befd7f8ca17bb4bd5e5156641f9cf93294541f4c3449fd853ac31b0272ff` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-body.json` | `b5ee14f804882e05a89a8347c6af3a923db18cab558d1f1d9d5105b32b082265` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-body.log` | `e4d70de937fd2cd9526ba5d24409d7068d298e5abb84f065e745682d5286d337` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-body.patch` | `4c267a915542f310c0d0da6e0a970865c2e2d9e6dd22812f52cee57b936a629a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash-emission.json` | `0760e5fbc06e15827c0d7dd1bed2fdda54848fb6d037d799ccc3433fa734953c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash-emission.log` | `945edfcf425884f79651dcdeafa18ef1d9ece8c511d045c354a925ae16cc2fec` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash-emission.patch` | `fd50bea9f19d5e887c46190966e986f6e779e57b2f11a6a7e7484edc735bee04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash.json` | `3a337a458ecbdd6fa6086559c1c1ce4d9c9db59e7d04b49cbc62b559fca437d0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash.log` | `2a489f3fba71b92ee3231a97f7d2581e1df56fc7ace78ffa949f88ea7e619374` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-hash.patch` | `f856738028fde35d035c35971146820436c7353d8f58aa879b23d580933d5aaa` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-time.json` | `9cf845e087e2d3f412cb56b755121179eeeb54cb6c366b515a806f93eee2c837` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-time.log` | `b7178275f0eb6e37e4dab8bba52b73384993b80c896669093dea6496b39548e8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/journal-time.patch` | `9e67eb6eafe9b5148dd33dc7419713336d650e2cf62d24ae500d1b49761ccf87` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/lease.json` | `b46272f60814f614d46894505d9e3e31f930dfe700516aa6e62cd6c16ea06d12` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/lease.log` | `ff4d0b57ef11a7d9e9029abeb22d5ff6780591ecc08732ce194a9546eb3441b8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/lease.patch` | `ec7c587a07005bb2b2d2709a03977db39989c224e5d8060ac9d042268690173e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/native-binding.json` | `2aa84a548ab2d5856f40cf5846fb6706b72cca4405c80eb795c284f6bd40cfc8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/native-binding.log` | `1f987883df638493504cd796be32d524a8a778bad1c33ba12c8066ed9c37e3da` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/native-binding.patch` | `d1576e56bbec7d0ca011293f5c54b21e1b89024b1bf0d1e7f86b0dd502199a07` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Changes.json` | `2792d23da00d53d4bb776af120726a23e7fe9bc82f7d232cb52be4d77b969b29` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Changes.log` | `c8d6e5d29dfb0e15762e05d5cff3af262a991b1f36279f07fbed1175ca828b9c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Changes.patch` | `aa6df6713ad36e8a642757a6bd56e66c5a7e3846efa9537e575c052a8ac6c2e6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-ExecutionStatus.json` | `3266cc19b56fbae77ca59441b0c9628d4b1e718e5fdbf8c9f8174979ea97c12e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-ExecutionStatus.log` | `5a5faf98b5afcb4335845c3453b30f991a4109bd0b1553982f9b0db7479d078f` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-ExecutionStatus.patch` | `06db9c2bc72708a08f86d65e9f51770d2366f62ce57d60e5512edd0f35b60943` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Status.json` | `4670248085d64e4fea78f4b38bcffa1e83bf95d84cc22a8ec8b6434e4330a5f2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Status.log` | `b4cdcaf4a6076e9af72ab52fc88af93516accf48b1230eada8b1d0af01f4a27c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-Status.patch` | `ae4716188694e164898cae78a5cbc1126dea0c6148e0c66e4eda89b8bac66214` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-StatusReason.json` | `de4c31caddd9e848c9beea9da6f72df91d417a201810a511f5a6c7c25b027b04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-StatusReason.log` | `0743960ea006dbd9dd91a94d27eba321e32488ee85f571745a51ab8efc5f0cc0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-StatusReason.patch` | `982a4d18c09ddfc13cc29bd2ffe6d191fa5fd1b6589dff997c6eda0312793bb2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-native-id.json` | `af68266f1f339f139fc75e9e17a3dcc01b6f0f211b95a732abbe2a6aba54d3ff` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-native-id.log` | `a6d1aa55939c1c6b1ca12b808e3e8064b89f6bb2cfd854b211bb4c692ead2a65` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/no-op-native-id.patch` | `c06dcc00549d3d56012e04e38528835145efcc2590f9241677ba86e675c2113b` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/preview-binding.json` | `75584bab67999e18788a21a1521a06e0105e674f7b28ea7f3817cd733adb0106` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/preview-binding.log` | `acba97aac04260eb8078540b4eaa85e17bfd9bd114957cf82225c35458d64de9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/preview-binding.patch` | `79214f6858742f022bafc8185e187796bc11af62bc03695fc470769675f34915` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/principal.json` | `7635db57e7f295d7f4034ea7a9c7e948c78005b5dd305599c9958e04397b9f83` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/principal.log` | `7069e09547c1bbff8238438e9d65c0e9ea0b784a599e6f098770ea6dbdadd8dd` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/principal.patch` | `205a51a8c58382da7bc2cad37d67f5764d5b3a8c9e2f684c6617a15a19f16888` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-expiry.json` | `9367b477b5d4c0dbccdd10f61b5715f5e28516cf5bff86be0ea031507c4ab281` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-expiry.log` | `884417a61ace4e9f692b23585ec80ccea245fb2e222262dcc4c14e4f34b09bd7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-expiry.patch` | `10ed22c79ddfda2349824182ec40ee9e625c00a0fe93985d2c37d405f4c0c85f` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-principal-emission.json` | `274ddbcb86b09f37d3143ffeac6dd34e39b491d2a2daa654746f9e17ca8bde04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-principal-emission.log` | `7bf526aa219f79d2861a271c983ee42864b2802dee4fcfd9391d380640bdc9af` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-principal-emission.patch` | `0297b45cf7d16abd43d19aba82560bbc0493f29affdb072399737b691cadf55a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-stage.json` | `79e5853587184271d4f99edc41c7d4074aed877e1f5fd3b1151e96f1a22c64f7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-stage.log` | `cadf3774da2d76cd3be875f6c515d6554641e85e6aa7a16e63651e2b8923732a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/receipt-stage.patch` | `4dea6642448d5ed4c76bbff2ceaf124a363b9c7d3a3bd3d0eec507d03769e52a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-scope.json` | `186872bfe02888abb3a54be80173177a4930a3a067bdb3f86a67111165aa99ed` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-scope.log` | `0293509682ad25e7416a6f2ddf49199352e0f76d359a841668590575b200bc50` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-scope.patch` | `c4f0d42b7ca34eaf2bc798019ffb4c4d17860eb71667bad0835798352b89c59e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-unit.json` | `bf45f80efbfdc744d758ae18e0cf050cd7cc66456ff68e1425b8a53b007ecdd8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-unit.log` | `c449b3d8afe714f1ab086dcf42ec9a663a26c2fdc64601070a33c25b1f5aeea1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/recovery-trusted-unit.patch` | `c01d8105123650be8bc50b9c8b92a4ee38e714dbc14bb1ae9b9705d17a3d7f1c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/response-digest.json` | `50e7e9563fbe4bf06162584509427faec4ff6fae08eb50698c36d218efe1cb42` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/response-digest.log` | `61a3c023b256797605e3a7d70a5233a64554b51b502fc48f62b2c983e51ff665` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/response-digest.patch` | `eba62c9637d67dc8f393f70e31286b2b2791990d96fe60856ddd0590fe03532c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/role-input.json` | `bac441cd4ec0a6f8d7cbe7636338cd92863f8b1875e1a5ee48612b644617e0f3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/role-input.log` | `1be662dba29e7bcffaacaf64e47ed26b37d7b915075a25e7509fd47e31ddb273` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/role-input.patch` | `ef6a4225ecff2acd52902149312d20d12533cd15685e863d6ab59658ce207489` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/semantic-drift.json` | `bb8cd977b50de82c25067cd40260b7d23aa003043f4c4ed1d97c50a4e0ff7758` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/semantic-drift.log` | `406f750aa23c3392ba7c9dd8986aa3bd533b412352b7c639c039be6594fc6656` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/semantic-drift.patch` | `f4f90b339ae6667de2867041b56f443dc794f90d581101d90d706811e9f0a6bf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/stack-role.json` | `450a9e2200a0409e1d4e88524e9630584faf9c7e837c4129a7ab4ae074f0ae40` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/stack-role.log` | `39b1a070b7b2bf61fac40d36b888e47ee06b01d1166dcaf6f24408357ce8a268` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/stack-role.patch` | `c4efed77451d1bcacb555aa6bcb6f9f8159a388fc6f36b714f19fd1982a88162` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/state.json` | `00cf9b12a8ad7d1de19f2b73d4988e62bee6a33b7db860d3ff881003e97963d7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/state.log` | `626d8edd43eaf3be7206cd2b46af5c81fe19613b804542683fe83f7dbb715f41` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/state.patch` | `dba5ecd2583c620ab03901baea6ab12b542507cb25026cece211b8a1a8f86e10` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/summary.json` | `3418b8ba1d4b2f01893b2b97b23ed057622053e8f593b0cd8be54270619394e8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/template.json` | `c7186d9dad57e3d92df89b3c224ec86f8037ae38ecdbb195d094b249891882b3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/template.log` | `f05bfa1df477c5526bd70ceb06af88b3ab4edd3cd0152050c4fe3a26f0376534` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-final/template.patch` | `01e8e93d9ffda7e69e134d63e3061eaf56f41ac3f75d652c36157d773f17f374` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations-first.log` | `c28bf279313e62b1ba8db980bd85aaf82850a7ae497b8316164cff32f0f8c5b5` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/approval.json` | `94a5875b8c3253e81f1fdda76004e1bb12b58d3082ab432bc12497c4e8de60cb` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/approval.log` | `a5858a65b493d111d5d7c5e2902a72fa6b96cf6b7d1ce8f916d4463382cf0f76` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/approval.patch` | `73a2bbf4f53b53207664dc4ec7b13422609f22cd5fb393198815172313ed4bcf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/arn-scope.json` | `6d30c75b1a30b7698fa8a756cb83af0b648b8eb8d01b43c79776d9441fb9fc7a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/arn-scope.log` | `91ae38cb0c1d0d78dc635eb60ff2ce4bbb4987ee2dd2cd077c6a25a70c812a56` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/arn-scope.patch` | `3ff755ca597d60aafd2a09dba89d5342afeabbafd836354e52a88a5cdade962b` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-encryption.json` | `4fe09886502e7c6fbd4decf5861234aec2bb2333e75632ffe1ba15f78f4a79c9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-encryption.log` | `4e478d228598ea75337a04177749dfec16505f7578adc0c13d88ac4e6678ee8d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-encryption.patch` | `49256366e46783523ee7346fad0c9a19ac0272f783e6185caf27f5b049b65c77` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-identity.json` | `f2298aae74c995bdefaf972a3a038d9fc92a1f37b4c7ff4f4a7d42d063223755` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-identity.log` | `fa4f5226ba641473fd1fe6e77b400f4617b348b57b0c7311f1d6d51161ec095d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-identity.patch` | `4ab1a19fc58e1f183d70d24bb8420ba24bba9e14a1225c29eff069430d0d25bc` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-key.json` | `bb58a748be6808b2551abebe7b08630ad9b7e4acab800c120b8882d1bd899df6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-key.log` | `5817b1a85c9f6eee81de8cbb5d368746b21cce13fc24fdd4ff106bb0c00d85c2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-key.patch` | `ef6a4225ecff2acd52902149312d20d12533cd15685e863d6ab59658ce207489` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-readback.json` | `c8be3242f68f6fed8964193b569cead0124eb41c57f838b52247e395edcead35` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-readback.log` | `a5527c3960780d242b0505fa6c9d7d7a607d6e3cd85358a92fef71bce07417df` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/asset-readback.patch` | `545540ff074a750f6fb4e72e4f2f8f151d91a579c591db8b61340f4e2d8ca680` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/event-token.json` | `ab683f7e5d6a50f8e7d7f18dd87e8ea2f6a85d48dd5a60bbcdb67896a00f3408` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/event-token.log` | `42873fed395e6a08dc90ceeb62c0552d96124dc9160a0ffde759ecb85dc80444` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/event-token.patch` | `04409a6121846e12666bac260e9e6498c49fb421748d896358b5745b0e92f5c8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/exit.json` | `5fdf02b8210f8d3b3b6fa3bcc791c43a235834dafe2de910ca0e3963b139070a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/exit.log` | `30574e347638bd89528389d14d99348cefe83417025b72ba1239cd46de04b285` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/exit.patch` | `87635c7d5206383c71a6af71aa47a360eea1e990902ffcfe3f9d6142a6cfda29` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/failure-policy.json` | `2b7c64d1e3f95aa553796c95ecce5b478e71f54ff59fc2a504f4c2e38cfb40e4` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/failure-policy.log` | `faf75166ee1c1f2fb18f22e9744520c42ed5fb33432263b624114114c1c7afb2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/failure-policy.patch` | `8281fd1a1f63d0ea0b50c540f1184d31dbd9fcf51be9627d7208bc5bce54124e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/file-digest.json` | `ca5a5c225fbee8637d7448a5c2b62873ed6e7de46037394fa03d741706f7128e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/file-digest.log` | `913617270c83bdac7faf4874526ba31583de6f2b45e385b31ec07826e8c42b91` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/file-digest.patch` | `bce73f01813d8b4ee8951f96ca6b5578247974099008d4d49954ef5ae70ba38e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/health-flag.json` | `a6a252418697960d163da389daf2ef38244e23f32087243ff7fd0f2a4cfe0cc9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/health-flag.log` | `4f47eaf4b912d24a01399917b5bb3c5ab51b0d607c9c25dd8ffbb8bb36c619ca` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/health-flag.patch` | `d526407fae6d4df4cf207020178230bf3c6c4d99a6d5fad759fd4c05c5486b20` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-binding.json` | `86412b369f4a7a7179385d0f4c0df1db646b595c93a4ba7834844c23395728b6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-binding.log` | `3f3a33e68b3b30536cc5e51694260a6be514ad5e595b6b46dde3f1d9d5704fbf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-binding.patch` | `8298befd7f8ca17bb4bd5e5156641f9cf93294541f4c3449fd853ac31b0272ff` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-body.json` | `b5ee14f804882e05a89a8347c6af3a923db18cab558d1f1d9d5105b32b082265` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-body.log` | `e4d70de937fd2cd9526ba5d24409d7068d298e5abb84f065e745682d5286d337` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-body.patch` | `4c267a915542f310c0d0da6e0a970865c2e2d9e6dd22812f52cee57b936a629a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash-emission.json` | `0760e5fbc06e15827c0d7dd1bed2fdda54848fb6d037d799ccc3433fa734953c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash-emission.log` | `945edfcf425884f79651dcdeafa18ef1d9ece8c511d045c354a925ae16cc2fec` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash-emission.patch` | `fd50bea9f19d5e887c46190966e986f6e779e57b2f11a6a7e7484edc735bee04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash.json` | `3a337a458ecbdd6fa6086559c1c1ce4d9c9db59e7d04b49cbc62b559fca437d0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash.log` | `2a489f3fba71b92ee3231a97f7d2581e1df56fc7ace78ffa949f88ea7e619374` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-hash.patch` | `f856738028fde35d035c35971146820436c7353d8f58aa879b23d580933d5aaa` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-time.json` | `9cf845e087e2d3f412cb56b755121179eeeb54cb6c366b515a806f93eee2c837` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-time.log` | `b7178275f0eb6e37e4dab8bba52b73384993b80c896669093dea6496b39548e8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/journal-time.patch` | `9e67eb6eafe9b5148dd33dc7419713336d650e2cf62d24ae500d1b49761ccf87` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/lease.json` | `b46272f60814f614d46894505d9e3e31f930dfe700516aa6e62cd6c16ea06d12` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/lease.log` | `ff4d0b57ef11a7d9e9029abeb22d5ff6780591ecc08732ce194a9546eb3441b8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/lease.patch` | `ec7c587a07005bb2b2d2709a03977db39989c224e5d8060ac9d042268690173e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/native-binding.json` | `2aa84a548ab2d5856f40cf5846fb6706b72cca4405c80eb795c284f6bd40cfc8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/native-binding.log` | `1f987883df638493504cd796be32d524a8a778bad1c33ba12c8066ed9c37e3da` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/native-binding.patch` | `d1576e56bbec7d0ca011293f5c54b21e1b89024b1bf0d1e7f86b0dd502199a07` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Changes.json` | `9a6c0d59c0a51adfeab483ef977017757b51cb9776618f719c136a49db999a5d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Changes.log` | `772ff69f5b296cf743697c03d24a47969fc2bb8d959038b1f815c212d1d7a338` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Changes.patch` | `aa6df6713ad36e8a642757a6bd56e66c5a7e3846efa9537e575c052a8ac6c2e6` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-ExecutionStatus.json` | `3266cc19b56fbae77ca59441b0c9628d4b1e718e5fdbf8c9f8174979ea97c12e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-ExecutionStatus.log` | `5a5faf98b5afcb4335845c3453b30f991a4109bd0b1553982f9b0db7479d078f` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-ExecutionStatus.patch` | `06db9c2bc72708a08f86d65e9f51770d2366f62ce57d60e5512edd0f35b60943` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Status.json` | `4670248085d64e4fea78f4b38bcffa1e83bf95d84cc22a8ec8b6434e4330a5f2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Status.log` | `b4cdcaf4a6076e9af72ab52fc88af93516accf48b1230eada8b1d0af01f4a27c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-Status.patch` | `ae4716188694e164898cae78a5cbc1126dea0c6148e0c66e4eda89b8bac66214` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-StatusReason.json` | `de4c31caddd9e848c9beea9da6f72df91d417a201810a511f5a6c7c25b027b04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-StatusReason.log` | `0743960ea006dbd9dd91a94d27eba321e32488ee85f571745a51ab8efc5f0cc0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/no-op-StatusReason.patch` | `982a4d18c09ddfc13cc29bd2ffe6d191fa5fd1b6589dff997c6eda0312793bb2` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/preview-binding.json` | `75584bab67999e18788a21a1521a06e0105e674f7b28ea7f3817cd733adb0106` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/preview-binding.log` | `acba97aac04260eb8078540b4eaa85e17bfd9bd114957cf82225c35458d64de9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/preview-binding.patch` | `79214f6858742f022bafc8185e187796bc11af62bc03695fc470769675f34915` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/principal.json` | `7635db57e7f295d7f4034ea7a9c7e948c78005b5dd305599c9958e04397b9f83` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/principal.log` | `7069e09547c1bbff8238438e9d65c0e9ea0b784a599e6f098770ea6dbdadd8dd` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/principal.patch` | `205a51a8c58382da7bc2cad37d67f5764d5b3a8c9e2f684c6617a15a19f16888` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-expiry.json` | `9367b477b5d4c0dbccdd10f61b5715f5e28516cf5bff86be0ea031507c4ab281` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-expiry.log` | `884417a61ace4e9f692b23585ec80ccea245fb2e222262dcc4c14e4f34b09bd7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-expiry.patch` | `10ed22c79ddfda2349824182ec40ee9e625c00a0fe93985d2c37d405f4c0c85f` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-principal-emission.json` | `274ddbcb86b09f37d3143ffeac6dd34e39b491d2a2daa654746f9e17ca8bde04` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-principal-emission.log` | `7bf526aa219f79d2861a271c983ee42864b2802dee4fcfd9391d380640bdc9af` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-principal-emission.patch` | `0297b45cf7d16abd43d19aba82560bbc0493f29affdb072399737b691cadf55a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-stage.json` | `79e5853587184271d4f99edc41c7d4074aed877e1f5fd3b1151e96f1a22c64f7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-stage.log` | `cadf3774da2d76cd3be875f6c515d6554641e85e6aa7a16e63651e2b8923732a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/receipt-stage.patch` | `4dea6642448d5ed4c76bbff2ceaf124a363b9c7d3a3bd3d0eec507d03769e52a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-scope.json` | `186872bfe02888abb3a54be80173177a4930a3a067bdb3f86a67111165aa99ed` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-scope.log` | `0293509682ad25e7416a6f2ddf49199352e0f76d359a841668590575b200bc50` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-scope.patch` | `c4f0d42b7ca34eaf2bc798019ffb4c4d17860eb71667bad0835798352b89c59e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-unit.json` | `bf45f80efbfdc744d758ae18e0cf050cd7cc66456ff68e1425b8a53b007ecdd8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-unit.log` | `c449b3d8afe714f1ab086dcf42ec9a663a26c2fdc64601070a33c25b1f5aeea1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/recovery-trusted-unit.patch` | `c01d8105123650be8bc50b9c8b92a4ee38e714dbc14bb1ae9b9705d17a3d7f1c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/response-digest.json` | `50e7e9563fbe4bf06162584509427faec4ff6fae08eb50698c36d218efe1cb42` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/response-digest.log` | `61a3c023b256797605e3a7d70a5233a64554b51b502fc48f62b2c983e51ff665` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/response-digest.patch` | `eba62c9637d67dc8f393f70e31286b2b2791990d96fe60856ddd0590fe03532c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/role-input.json` | `bac441cd4ec0a6f8d7cbe7636338cd92863f8b1875e1a5ee48612b644617e0f3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/role-input.log` | `1be662dba29e7bcffaacaf64e47ed26b37d7b915075a25e7509fd47e31ddb273` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/role-input.patch` | `ef6a4225ecff2acd52902149312d20d12533cd15685e863d6ab59658ce207489` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/semantic-drift.json` | `bb8cd977b50de82c25067cd40260b7d23aa003043f4c4ed1d97c50a4e0ff7758` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/semantic-drift.log` | `406f750aa23c3392ba7c9dd8986aa3bd533b412352b7c639c039be6594fc6656` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/semantic-drift.patch` | `f4f90b339ae6667de2867041b56f443dc794f90d581101d90d706811e9f0a6bf` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/stack-role.json` | `450a9e2200a0409e1d4e88524e9630584faf9c7e837c4129a7ab4ae074f0ae40` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/stack-role.log` | `39b1a070b7b2bf61fac40d36b888e47ee06b01d1166dcaf6f24408357ce8a268` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/stack-role.patch` | `c4efed77451d1bcacb555aa6bcb6f9f8159a388fc6f36b714f19fd1982a88162` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/state.json` | `00cf9b12a8ad7d1de19f2b73d4988e62bee6a33b7db860d3ff881003e97963d7` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/state.log` | `626d8edd43eaf3be7206cd2b46af5c81fe19613b804542683fe83f7dbb715f41` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/state.patch` | `dba5ecd2583c620ab03901baea6ab12b542507cb25026cece211b8a1a8f86e10` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/summary.json` | `eb7ad72adb10cdeba6f4adf9f67bf5ba1254506551fcf3f95c8207e19fe5ee82` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/template.json` | `c7186d9dad57e3d92df89b3c224ec86f8037ae38ecdbb195d094b249891882b3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/template.log` | `f05bfa1df477c5526bd70ceb06af88b3ab4edd3cd0152050c4fe3a26f0376534` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/mutations/template.patch` | `01e8e93d9ffda7e69e134d63e3061eaf56f41ac3f75d652c36157d773f17f374` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/observation-corrected.json` | `36ac8a12a12a4c0f0da51e2512532717be7c624f508cf6fff20c3c17b1cd32f0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/preflight-matrix.json` | `f8aa39263e7b1f0292f8df3f591e211524e0e9a426365d01ba9efde8f2b5ed22` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/preflight-plan.md` | `20d28d19a294a46aa667a9e1f09bbf8f98f38be4365660e9e4354de64acf67a1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-final.json` | `4f9b4c3bf4c172912666241320e397e971579d8b80a6c1ca613a002ac6ba4fc9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-final.log` | `a1fa0624fa451024e6966c489c9b3f0a6bf580e13c0cc808bb68f3de2b6c5d86` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-first.json` | `3d3000683478e14b8c8a7a9c18a85f9271bb97ad1228d6abc58aecdce776c022` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-first.log` | `5c0bcbccbca2ce3efbaa95f364cb5fb2d9c2a4be1e178e7d09c2fd97bddc786c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-candidate-probes.json` | `4f9b4c3bf4c172912666241320e397e971579d8b80a6c1ca613a002ac6ba4fc9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-candidate-probes.log` | `a1fa0624fa451024e6966c489c9b3f0a6bf580e13c0cc808bb68f3de2b6c5d86` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-commands.json` | `8a5b804c07e3b2e73971781a150f5d05ece50b12fbf294dd31bc46dec43a9bb5` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-create.log` | `b89551b222fc138829747cdd0ca977d827293ccc16c085e1b4b9603a6a0de1aa` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-driver.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-entry-contracts.log` | `0ea63a97e9fb86a63efc12dd7847fa4ac8ffb8d7de99a64bbc4bfb5de23415b4` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-entry-execution.log` | `7504ee1a4d92f6b2b7c29fdf1f4bd3fb8f11bc6d7e525b18e3062927bbdb236e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-reapplied-observation.log` | `48d968c2137f81bc9abdc8a19ad8b95e7e520c59e4740330148356d68fceaad4` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-reapplied.json` | `36ac8a12a12a4c0f0da51e2512532717be7c624f508cf6fff20c3c17b1cd32f0` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-remove.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-restored-contracts.log` | `634d66e21dbeb9a3710c55651c34c1e74aa5f17425cd9fd644f8f8e96428462d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback-restored-execution.log` | `be0e048ea7ba4e6ae9a7d6a342d51ee9d8340657372a3daddac1626677d4266e` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback.json` | `e1e5630e015d19ae1cd3c3f1742ffbf4bc9920d7e3c761056545118e9570e144` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/rollback.py` | `8cee8e2613d75a376791ef4123d0918561c526e7f0112e904c2741d9f65ba0e3` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/supplemental-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/supplemental-task-input-manifest.json` | `6b794d42f7f36250e5b0de361dba77229d9873655ae69f7568938bb31ffe3d95` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/tools.json` | `f9cfcb08721dc2058f44e02ac22c7fdbee41c26a625963a55b3184ad995b0aee` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/0/AGENTS.md` | `0b57a17a89b0ad81a6be9f0c884930af3ee7f1091a6f5056c28af8714ba6aed8` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/1/SKILL.md` | `9badd22a32e19cb884e46dfa8d3aae82bb81dfa5484105b8b4f0262df823a509` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/2/SKILL.md` | `e80544c3d1eac5b14f22022146bd91a6b0ecc30e099cf5181894853aeb81dee1` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/3/SKILL.md` | `b9eb6416eebc8dda046674f0a2dbb3be88aff526d182b60a0f55998d3d6d0d8d` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/4/SKILL.md` | `5b06be54d4852f60e6cf1b04c6e9a4748554334eb3e41af6c0959b544e6464ae` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/inputs/5/SKILL.md` | `13620c666f6bd55ee30262e18d6ae8428fae1bfb2876c1f47239f7d7705e25e9` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/probes.py` | `34e640b3d483336535f3d7081fc9ce31229e1da7386b0a4f7639416b55e9bd7a` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/run-mutations.py` | `5f4b83a1ad0eca600dea399e119c47d445100a6287c16944b38bd8dcb85046cd` |
| `specs/cloud-orchestration/verification/T-013/preflight-repair/task-input-manifest.json` | `e2ffc9bcdb443bba18e0a25abecdc19a4ed211a28b56ba55916a789879473282` |
| `templates/cloud/github-aws.yml` | `72ddd25758096b0844ed9e3b14d3563f90e3f80d67acc4090fe3294222b2c7b4` |
| `templates/cloud/github-azure.yml` | `5c9c208f3cc0eb4ea0fe11617a159acdcde9cb3bb61a8a92bc0ebf178299b4ab` |
| `templates/cloud/iam/aws-apply-permissions.json` | `9b6ab4f6f70b6d138b8f5b143e25b51abf82f2a00d5606484bb17578bb6342cb` |
| `templates/cloud/iam/aws-apply-trust.json` | `b6a668ac1c6d6bfecf347823a7bf7f4211eab6eedeb8b70e80d5b1095c88546a` |
| `templates/cloud/iam/aws-prepare-permissions.json` | `97b33e38eb4b5c62c45006b1fa82d101b3c745d89053b7aef1975ae63aaf5135` |
| `templates/cloud/iam/aws-prepare-trust.json` | `fb816c23c404a2c6dc664885da932bd208fdda8c4675c991ff694e03ab17406c` |
| `templates/cloud/iam/azure-apply-federation.json` | `edbece3a3e08ad661a37bb5bbad33e5738aee8ea96e66148fd8b948f3fb01a24` |
| `templates/cloud/iam/azure-apply-role.json` | `305f5622da98f47d3b81df756eb5ef1959069e47b59f7ec012c3d0fd4812d889` |
| `templates/cloud/iam/azure-prepare-federation.json` | `50d8cbc667ee96d6667bbbb5313562a426ab826966483b20c4187fa5b9934370` |
| `templates/cloud/iam/azure-prepare-role.json` | `18558291d8f2bd725926e1a99c532ebd4952a0a192aa7740c3be18e6c76cf61d` |
| `templates/cloud/iam/github-environment.json` | `5bf72c589d439d0dc23b02b92c62fb6b4d897f1b95a2653b2aaa4d0069ddd291` |
| `templates/cloud/iam/github-oidc-subject.json` | `69a4c0a488e543cb5bb6587ffd6ab9ccd66706ad0423db76b2d4fcc2dbbb1d60` |
| `tests/cloud-orchestration-contracts.tests.py` | `71b89cf257b302fe695f7bdb5b42e648eaec0edb7ef14ce2c7f927bb5cd1a90b` |
| `tests/cloud-orchestration-execution.tests.py` | `3ded22c4377536bfa7925555935d4e14a614263674c1d3acf2a973570cb14703` |
| `tests/cloud-orchestration-routing.tests.py` | `ed91ffb6d77b2c033574ad8db08abd81dc1b823f759399240f01ef910d80e21e` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |

## Test Evidence

- **Test Command**: python3 -B specs/cloud-orchestration/verification/T-013/preflight-repair/probes.py --output specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-final.json
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-013/preflight-repair/evidence/probes-final.json

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

- **Scratch Root**: /tmp/cloud-t013-preflight-01a14e44
- **Run ID**: 01a14e44-7b84-7691-afa4-e0a84f80d4a7
- **Session ID**: 01a14e44-7b84-7691-afa4-e0a84f80d4a7
- **Agent Instance ID**: 01a14e44-7b84-7691-afa4-e0a84f80d4a7
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

| Check | Observed result | Evidence (relative to this repair directory) |
|---|---|---|
| Before repair, execution suite | exit 0; 86 tests | `evidence/before-execution.log` |
| Before repair, contract suite | exit 0; 31 tests | `evidence/before-contracts.log` |
| Current-code probes | exit 0; 126 entries; all setup/body flags true | `evidence/probes-final.json`, `.log` |
| Final targeted source mutations | 35 intentional exit-1 assertion failures; driver exit 0 | `evidence/mutations-final/summary.json`, per-control `.patch`, `.json`, `.log` |
| After repair, execution suite | exit 0; 86 tests | `evidence/after-execution.log` |
| After repair, contract suite | exit 0; 31 tests | `evidence/after-contracts.log` |
| Ruff | exit 0; strict repository config, all three new Python files | `evidence/after-ruff.log` |
| Mypy | exit 0; three files, check_untyped_defs=true, explicit sibling MYPYPATH | `evidence/after-mypy.log` |
| Initial and supplemental manifests | exit 0 against own retained snapshot | `evidence/manifest-validation.log`, `evidence/after-manifest.log`, `evidence/supplemental-manifest-validation.log` |
| Report schema | exit 0 | `evidence/report-validation.log` |
| Scoped rollback | entry 86+31 pass; candidate 126 probes pass; restored 86+31 pass; reapply observation passes; 204 byte comparisons match | `evidence/rollback.json`, `evidence/rollback-commands.json` |

Exact final commands, start timestamps, exit codes and log paths are in `evidence/final-checks.json`; tool versions/binary hash are in `evidence/tools.json`. The explicit type-check environment is `MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts`; both tools use `tests/shared-launch-python/pyproject.toml`. No suppressions were added. Routing was not rerun: no routing, production, shared or stable test inputs changed. The whole repository suite was not run; root owns it.

## Specification Differences

None. Frozen specs, original implementation report and historical evidence are byte-preserved. The correction is additive and does not waive WFI-001/TDD or claim later tests occurred earlier. The identifier sweep across the nine feature artifacts is retained in `evidence/identifier-sweep.log`; the task still states the original pre-implementation obligation. No source freeze, API, IAM, architecture or approval change.

## Unresolved Items

- **Historical chronology remains a limit:** the original eight Red tests demonstrate an absent executor only. There is no evidence that their mismatch bodies ran before the original product implementation, and this session cannot supply that evidence retrospectively. No human deviation approval is invented and no requirement is waived. Root owns the ticket/task disposition and any independent evaluation.
- Live TEST-003/005/009 remain BLOCKED by OQ-001. These are synthetic transports, not live CI/IAM/S3/CloudFormation or workload-health acceptance. No cloud calls were made.
- No production bug was reproduced by these probes. Tests and guard-removal experiments are bounded evidence, not exhaustive security proof. Redundant checks can mask an individual mutant; initial masked/invalid experiments are disclosed below rather than counted as successes.
- Root owns independent named review, quality gate, final scoped review, isolated committed-checkout full suite and release. No push, tag or merge was performed.

## Quality Gate Focus

Verify canonical report/red-log preservation, current-code chronology, per-field matrix, actual setup/body flags, precise guard observations, all 35 expected assertion failures, exact mutation patches and restoration hashes, and the complete dependency inventory. Confirm no later test is described as original Red. Determine ticket/status only in root-owned evaluation; this report asserts no gate verdict.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

Ponytail full and applicable local ECC coding/security/verification guidance were read. The smallest change is task-local instrumentation and an additive correction, not production refactoring or a second verification engine. No subagents or peer review were used; no raw peer reviewer reports or identity ledgers were read. The caller supplied the native identities below; no inherited process identity was used.

The initial manifest was created and validated before the supplemental harness. It contains 192 exact inputs in the retained snapshot. A later dependency audit found 12 inactive shared regression template inputs absent from that manifest; they are transparently admitted in `evidence/supplemental-task-input-manifest.json` before the isolated rollback and final focused rerun. The initial manifest was not rewritten. Both validators pass against the same retained snapshot, now containing the 204-file union. `entry.json` records the earlier 191-file preliminary inventory before the schema oracle was added to the initial manifest, not a competing final inventory. No missing-template setup error is used as sensitivity evidence.

The first supplemental run exposed a test expectation mistake: TTL is bounded by OIDC iat (NOW-10) + 120, so expiry is NOW+110, not NOW+120. Corrected the harness expectation, not production. `probes-first.*` preserves this exploratory failure; `observation-corrected.json` records the fixed expectation. The first mutation trial also retained four non-successes: ARN and expected-owner removal hit redundant same-field guards; the no-op Changes fixture omitted native fields and raised KeyError; the unit guard removal made a forbidden read before a later stack-tag rejection. None is counted as a valid first-trial sensitivity success. The final ARN probe directly exercises the real ARN guard after matched wire setup, the no-op fixture uses a complete valid change, and the unit control explicitly targets the existing no-native-read assertion. The redundant S3 identity control is retained only as a limit; actual S3 substitution/encryption/key sensitivity controls pass. First-trial source copies and outputs remain in `evidence/mutation-first-*-source.txt` and `evidence/mutations/`.

Local commit `fb2d374ab671fa12856d0892dc8d958582b0d11f` contains only supplemental tests and their current-code failing mutation/positive probe evidence. It is **not** an original pre-implementation Red commit. No product implementation followed or was needed. Existing candidate code and its genuine missing-component Red were never relabeled unimplemented. No new SKIP branch was enabled. Visual verification is N/A: no UI files.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Root: independently evaluate the correction and evidence, decide ticket/task status, then perform the isolated committed-checkout full suite when appropriate.
- **Unresolved Items**: Historical pre-implementation mismatch execution is unproven; live prerequisites and root-owned evaluation/release remain outstanding.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.

Run ID: 01a14e44-7b84-7691-afa4-e0a84f80d4a7
Task Attempt Count: 2
spec_revision: 31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922 (frozen requirements SHA-256; all spec hashes in the input manifest)
Input manifest: `specs/cloud-orchestration/verification/T-013/preflight-repair/task-input-manifest.json`, SHA-256 `e2ffc9bcdb443bba18e0a25abecdc19a4ed211a28b56ba55916a789879473282`

## Dated correction — 2026-10-18

This addendum supersedes **only the inaccurate execution claim** in
`reports/implementation/cloud-orchestration/T-013.md:370`:
“All mismatch cases below were executed in `red.log`, exit 1, before production implementation.”
Every one of those eight original tests stopped in `setUp` at the assertion
that `aws_execution.py` existed. **No mismatch test body executed in that original Red run.**
The canonical report SHA-256 remains `f7b6c8373b4540481f1be17f113ac45f4a93d4c9fdec555c264af809e0f4fe08`.
Its nine-row field inventory is retained, but the corresponding execution
claim is replaced by the current-code evidence below, not by a historical claim.
The original `specs/cloud-orchestration/verification/T-013/evidence/red.log`
is unchanged. This correction takes precedence over the named span; it does
not alter any historical verdict or task obligation.

## High-risk corrective preflight

The initial report draft recorded all nine fields/counterparts/probe plans
before harness construction (`evidence/preflight-plan.md` retains that plan).
The actual current-code preflight below and all sensitivity experiments precede
this final correction; **no corrective product implementation occurred**.
All entries are fixture-based current-code observations. Expected rejections
are passing probe assertions, not failed unittests. Sensitivity runs are genuine
failing assertions in isolated mutated source, never original Red.

| Row / persisted fields | Counterpart | Executed mismatch / sensitivity evidence |
|---|---|---|
| R1: request digest; run/unit/provider/scope; owner; policy/profile/lock/config; assembly/source bytes | verified local closure and request/preview pins | 29 R1 probes: every bound byte reference, rehashed preview identities/refs and scope; DIGEST_MISMATCH/BINDING_MISMATCH; file-digest and preview-binding mutants |
| R2: ARN/name, stack/account/region, parameters/capabilities, semantic changes and original template digest | native DescribeChangeSet/GetTemplate Original and exact create request | 14 R2 probes: native wire substitutions, template, scope and benign semantic drift; native-binding, arn-scope, template and semantic-drift mutants |
| R3: S3 bucket/key/version/etag/hash/encryption/owner/region; template URL | protected destination, versioned readback and create URL binding | 12 R3 probes plus original bucket-denial body; S3 identity/header/body disagreements and valid alternate key; asset-readback/encryption/key mutants |
| R4: protected RoleARN, failure settings, creation/execution token | Control, actual create/execute query, stack role and original-token events | 9 R4 probes plus original exact-async body; role input/stack role/failure serializer/token disagreement; role-input, failure-policy, stack-role, event-token mutants |
| R5: authorization receipt/principal/stage/lease | real fixture GitHub/OIDC/STS through WriteBoundary and emitted receipt | 6 R5 probes plus emitted principal/lease assertions and original last-send revocation bodies; approval, lease, principal, receipt-stage/expiry and receipt-principal-emission mutants |
| R6: preview/result NO_CHANGE, absent deployment ID | exact native FAILED/UNAVAILABLE/diagnosis/empty-changes and result schema | 5 R6 probes plus genuine no-op body; four individual native predicate mutants and no-op-native-id mutant |
| R7: journal identity/status/time/body hash; UNKNOWN | original ARN/token/request/scope, authenticated history, native query bytes/events | 14 R7 probes plus original timeout/replay bodies and actual emitted journal assertions; journal-binding/hash/body/time and journal-hash-emission mutants |
| R8: recovery provider/account/region/deployment/policy/unit and journal identity | trusted Policy/Control binding before reads | 6 R8 probes plus R7 journal pins; structurally valid alternative policies reach authority guards, zero native reads; recovery-trusted-scope/unit mutants |
| R9: trace response/request digests and health=false; result/state/exit | actual transport bytes and shared operation-result contract | 5 R9 groups compare real response trace, emitted flags and all exit mappings; actual-result contradictions; response-digest, health-flag, state and exit mutants |

Matched controls: each `prepared()` helper performs a successful actual prepare,
authenticated apply setup and exact readback equality before inserting a fault.
The 26 original AWS bodies also execute their positive/no-op/timeout controls.
`preflight-matrix.json` expands equivalences/limits and exact IDs for every row;
`probes-final.json` records setup completion, body entry and actual guard locations.
The journal timestamp is validated as UTC and observed against the fixture clock;
no unsupported native-time correlation is asserted. Offline receipts are never
write authority. The complete S3 key counterpart is the create/URL binding, not
an invented key-lookup behavior in the transport fixture.

## Rollback Experiment

Base revision: `b31b4076e911f4fe548d42ff1b9fe8b0cc230a9c`.
A detached disposable checkout overlaid the admitted initial candidate bytes,
including pre-existing untracked dependencies; Git HEAD alone was not used as
the baseline. Initial execution 86 and contracts 31 passed. The two supplemental
harness files were added, and 126 candidate probes passed. Removing only those
two new files restored the baseline: execution 86 and contracts 31 passed again,
and all 204 admitted input hashes matched. Reapplying the harness passed the
observed-bindings case. `rollback-commands.json` includes creation/removal and
all actual commands/exits; `rollback.json` includes hashes and scope. No shared
workspace input, historical report, approval or ledger was reset. Cloud-resource
rollback is not implied; this experiment made no cloud operation.
