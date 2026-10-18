# Implementation Report: T-002

- Task ID: T-002
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

Run ID: 01a14d8e-ed12-76c2-b8f2-86311e279b8e
Task Attempt Count: 2
spec_revision: 31f5a76f5902e2d4361d89bb42c106fe2839dd0a9aa0dd9eb6f28822c7ec6922
Input manifest: `specs/cloud-orchestration/verification/T-002/integration-repair/task-input-manifest.json`, SHA-256 `12c285053bb6e9f2e652d3df4cfbeb941a356cec4443da089762975c90464e7b`


**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

T-002 / cloud-orchestration, bounded fix-by-review-ticket continuation, attempt 2.
Ticket: `docs/review-tickets/RT-20261018-CLOUD-CONTRACT.yml`.
Authority: `specs/cloud-orchestration/verification/T-002/integration-contract-decision.md`.
Original `reports/implementation/cloud-orchestration/T-002.md` is read-only context,
not this run’s identity. Its current hash is recorded in Outputs and preservation.json.

## Summary

Repaired shared artifact contracts and their immediate T-003 admission caller only.
Added explicit portable local boundaries, strict ownership/policy/profile bodies,
immutable apply intent across separately authenticated prepare/apply stages, and
honest pre-publication result errors. No provider plugin/executor, cloud privilege,
cloud operation, task/approval update, new review or release action was added.

The candidate existed before this run: its original 23 contract methods and 22
admission methods passed. They were not initial Red. Genuine new integration
regressions were committed before production changes. Final 31 contract methods
and 24 admission methods pass (55 total), including all original method names and
attack cases, plus 222 supplemental Draft-07/schema-runtime parity assertions.

## Files Changed

Production: `cloud_contracts.py`, `cloud_authorization.py`; changed request/result
schemas and added ownership/deployment-policy/verification-profile schemas.
Tests: both ticket-scoped cloud suites. Documentation: IAM README and inert trusted
policy example. Other cloud schemas are unchanged dependencies, not new work.
All remaining writes are this report and its integration-repair evidence directory.
`repair.patch` compares exact entry candidate bytes to repaired bytes, including
untracked production files that ordinary `git diff` does not show.

## Tests Added Or Updated

Retained the 23 original contract and 22 original admission test methods.
Added eight contract methods and two admission methods. Original admission fixtures
now use the required context and stable apply intent; the old operation-mutation
attack now changes apply to prepare (rather than assigning apply to itself).
Receipt reads use workspace-relative refs, and marker cleanup removes only
*.authorization.json, not freshly created preview data. No attack assertion was
removed. Both providers’ same-request lifecycle uses distinct authenticated stage
subjects and provider principals; all transports and identities are synthetic.

The new tests cover every local-context field, all fields of the three closed
bodies, physical roots/links/hardlinks, recursive undeclared metadata visibility,
contained input/dependency/evidence paths, ownership/profile/scope mismatches,
predecessor path identity, phase/preview/receipt binding, missing context/anchor,
wrong target/protected environment/digest, and nullable pre-publication results.
`schema-parity.py` supplements the existing limited structural oracle with the
already-installed jsonschema 4.26.0 Draft-07 implementation (222 assertions).
Its JSON evidence fingerprints the installed dependency files; no install occurred.

## Outputs

Rows include changed files, all prior frozen-report outputs at their CURRENT repaired
hashes, direct test dependencies, and retained evidence. The report itself is excluded.
`frozen-output-comparison.json` carries each historical-report hash, entry-current
hash and repaired hash without rewriting historical outputs. Root-owned native allocation/events, launch brief and model-selection artifacts
are excluded: they are not worker outputs, and event logs may still be changing.
Historical evidence rows remain unchanged; their inclusion is not a new test or authoring claim.

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
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
| `contracts/project-context.schema.json` | `a6a86903e8126ecc0d587499f75c7222aee0eb0f442a51b39fa8ff852829592e` |
| `contracts/project-context.template.yaml` | `afb8ae3ae563887e4f6383effe2873e4dbf164601f8b218fe6105810b1c57fd3` |
| `contracts/provider-bindings.schema.json` | `7adfa236d2bb00055bd38f3fc6b7664f6d41e88989e9aedba1c0a9c5d55f8cd7` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/scripts/cloud_authorization.py` | `0408cc042f46b329ea356e35b6d3c407535f64b5449f9179cc636bd40f88d8a8` |
| `plugins/sdd-quality-loop/scripts/cloud_contracts.py` | `c11225de15d8944a4183085b3df98f7b4da2d87227c473ad4eedde377b51164d` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `d19f258b904dd168410f184f7854d47a3790319832b5bda919b3f7049ab41a06` |
| `reports/implementation/cloud-orchestration/T-002.md` | `17c5a575998c13b8b030c54292e3981ffa2a8295e6d92a76d4137dc62675a50b` |
| `specs/cloud-orchestration/verification/T-002/baseline.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/before.json` | `b131597529578e6e48f4275c31828d2830cc32e5ddafc830dd419dc1d4994cb5` |
| `specs/cloud-orchestration/verification/T-002/cloud_contracts.cover` | `d451d7b9c397726651fc9d087cbe31d3d00e9dd60a994f605f8895a28253dde3` |
| `specs/cloud-orchestration/verification/T-002/coverage-real.log` | `da4d72b4a2afd53836f1b2e033d7246acb99866488c6c30b1addfef47b24beaf` |
| `specs/cloud-orchestration/verification/T-002/coverage-runner.py` | `0b6d57788eb55241833b93810cdeb94b8e99135f37c8d6097b58bde1c18904bc` |
| `specs/cloud-orchestration/verification/T-002/coverage.log` | `99b38355258cee18ab112577c56041920d8bf87b9cb8d093036a1418f3dcae0d` |
| `specs/cloud-orchestration/verification/T-002/execution.json` | `cfc229c1fe71edabcc29e363b454a83493c1ee13a5dd236d4c15680e2f902865` |
| `specs/cloud-orchestration/verification/T-002/green-boundaries.log` | `7cb44e7566c1525b40f40c42819a9e3aa83b39ad1c3c9521c78ed98c2102504e` |
| `specs/cloud-orchestration/verification/T-002/green-initial.log` | `05022cea730ead7035f8f90c5d7f840ed39d151c6498ee4582c22758fd1ef2fd` |
| `specs/cloud-orchestration/verification/T-002/green.log` | `fe95443cf7a95206a0ed03f168ed992dcddf6fe368ea47cd461e9d993f443e06` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/before-admission.log` | `75f79caf7b4506275553acfed074313f7fc66e7489df38d6b4a90cf3f7f4cc34` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/before-contracts.log` | `a307852b7842694fe7143cea52b52177090b5fa413db70283f68ba36ba8a30ce` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/before-schema.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/before.json` | `9d3143baf907511c2a464bebbff6320cea1f6080ef33f0a22c9a0276e7ee0c1d` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/callers.txt` | `725946574b884205ca126598edd9088e580dfb4906743c7c6dfcf2afe1cd8590` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/coverage-runner.py` | `2e5c14e04d15c31e66aa0d04956eae0dc1e655a2e17b56ee9f42b8a720d315a0` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/coverage.json` | `8925d013f0bba1999140ef6581c348d085badd8748db074cdda9805827ea0824` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/coverage.log` | `8516f99d808c8a9c05c98cd4b8e1b7579251e63d318524781e6e7fa4eceeb901` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/diff-check.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/execution.json` | `8ad5b75c1a4f72ef05dd73b9d31596742141622e7e1cf1a9c2b026eb7ec95386` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/frozen-output-comparison.json` | `b032a0ebcc800dd6214b032b46c6450608ed1080b9c27e218edfe09e23d46b23` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-admission-first.log` | `d6a8263a39bf47009332dd65f16cd6790d56cfde4beee4f9a7ef08cc773a6319` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-admission-second.log` | `8e6f03542aad3306d987033d19e5b9d804d8877df25e712069c40f0bdbba56c3` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-admission.log` | `ff0c0ecc31805a5e983aa532d7faa5c1ef87fa13097f318ac42c65244aef29c1` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-contracts-first.log` | `0de8fea3bf9efd12bf6c626347490b9330b1bb02f1dde0a31e9248613a8463b9` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-contracts-second.log` | `6d98e6aabf53a2cad5ca417afe7d42ff39964154a6ec62f52002f95e4d48b875` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-contracts-third.log` | `ab61dc63887a018782ce1b3727f12522bb5b31cc8489575279cdef4244051dc2` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/green-contracts.log` | `c421fa2718ad43f65451a08d5d58194ab6358781ebe48c146281d779f4a77237` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/initial-to-red.patch` | `c8fa5cca088ed55c8b9577f861a52f33d5479ff48d895b71799f1b1dfa34c9d9` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/input-path-map.json` | `b614d749624b10a63eb1a218b81e9ef40ce1f57100b4c2b25f4c70a4b57ff3c9` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/manifest-validation-final.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/mypy-first.log` | `4e3f724073d14e57c9632878620816421d927051d8cfe9bafc6e0aac0bbdd8a5` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/mypy.log` | `e317872697c2cbfdefa321527a6efe73290dff3a390b0fa8723b87092eccba6a` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/preflight.md` | `590f819462763038349f6b14afe1c3dae8304967d684c965e7266b7e068ce226` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/preservation.json` | `45dadf6e39697812a720689c01442f397c4bf0e051f1d8820b1f866b8e5d4d14` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/production-baseline-git.json` | `ca3c03c9e3abcfe8ade446c9137a20c7045a291aa32e61cafac149a6808fbb36` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/production-before.diff` | `4e7129168661bb986ac75fdb7d6ecd80e71550a261f143faed7f00b761086b0e` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/red-admission.log` | `552433a2b7d6ebe5ec2458e4115c035a9fd27711ada02bb5d54e1f2a4ad759b2` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/red-contracts.log` | `fc2b6e37a755abe89c7ca8946ec7af045647bf1635c0e0a48d5459628656ffa6` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/red-ordering.json` | `13840fc80095e8d366d4073e1742de8332babda2aaf7d3088311909971aa1080` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/red-root-controls-corrected.log` | `c4075681d91dbac15a62246be384a4267f4b489e8e7c50c09d154c6e5ca2530d` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/red-root-controls.log` | `6bec63926278f1414967ed5e86951497d33b262941d5c49b831f86b298ad8351` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/regression.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/repair.patch` | `1a646cbb3a8965fc708fe5e4eb786a0d95f1052dd83419b08509b7622a9ba623` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-before-contracts.log` | `06ac7986818e0af68f9498103ba3a81806f620aafd0f41870a5f37b7337fd076` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-before-execution.log` | `c8c7906e7fd12478ffa247d3f371fd98e43f561230d34ee6b12eadfe7f07fe48` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-before-schema.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-candidate-contracts.log` | `cac795fe094146d857c819089efd55c2c6b573f552745008577cf9c8e4e26e9a` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-candidate-execution.log` | `a82dbb96d390359995399c7fc5d260985d7fd1da7f12481d5ac9ffab2933a0c7` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-candidate-schema.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-create.log` | `d1436968f875a8b80333941683da6685c06a4d6234824580dea1a91a4c7c3330` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-remove.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-restored-contracts.log` | `a0a3e906a967e8b610f158c0ab6fbfde32f7e989fc16753458ffcd8dad558297` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-restored-execution.log` | `390f59f49b5b6a68f0000d111b8037e49660a09f96766c435142de8f16b11a82` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-restored-schema.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback-test.py` | `30ed46520dc3368867aaa54abffd39e30ae916db46b6812051fe9033a7febd88` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/rollback.json` | `95e09e7d970fbd95bfecb354ff279fc1afc62e365af2514e227f5272cb3445fe` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/root-controls-production.json` | `6b8c6ec7b0742bffdeaa7cd60fc83ff764d21f28e24bae6a1ae2e428bfaf852a` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/ruff-first.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/schema-parity.json` | `61ff7bff0397049a35750808b30f1866945795d22398e1c4315a2df760374719` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/schema-parity.py` | `c31cb1138ba8fb0904811f1273f5964674763815b941152716d610b741d2725c` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/schema-parity.stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/static-check.json` | `0a1380da04e55b7ecffc677aa44e943ab236aa8e73974564ce717f848a7dd347` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/task-input-manifest.json` | `12c285053bb6e9f2e652d3df4cfbeb941a356cec4443da089762975c90464e7b` |
| `specs/cloud-orchestration/verification/T-002/integration-repair/verify-local.py` | `6bc83a09cb9ebf28a6146196933f8124cefe3df5b16c989e993c81adb3ba1857` |
| `specs/cloud-orchestration/verification/T-002/manifest-validation-final.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-002/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-002/preflight.md` | `aa8f1790e20cee92bdccda1955cdaadc460e174b48f39e127d955db7d998bd7d` |
| `specs/cloud-orchestration/verification/T-002/red-boundaries.log` | `116f6c45e5648e9d41bf7c0ad5c43c50f088d1e2c57df4e5ec7d97ff0f020016` |
| `specs/cloud-orchestration/verification/T-002/red-conformance-corrected.log` | `3968aef783c16fae507743fa9259e2c86fc444f9fe1c32893705c9f9514621f5` |
| `specs/cloud-orchestration/verification/T-002/red-conformance.log` | `e3573f2501e40193ac0f6c8fe4fec875aad64f3326af5c4662baf3183fb75de8` |
| `specs/cloud-orchestration/verification/T-002/red.log` | `ad515e4f45a38fdf5888e422fddddf3540a125f0976ce5c74fb6308eb6623755` |
| `specs/cloud-orchestration/verification/T-002/regression.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/rollback-baseline-after.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/rollback-baseline-before.log` | `c049f86e64027e337e38c57ac9c5a74b84fc6f0d4dd879062fb4f032401b0587` |
| `specs/cloud-orchestration/verification/T-002/rollback-candidate-green.log` | `c9680826967e479443190bd44b885f960d2566e2409119efbc1d864c9c28c2cf` |
| `specs/cloud-orchestration/verification/T-002/rollback-checkout.log` | `ee7b0da337fbf94d042269a00dfe4de108f11147dd98ac030fd3393f38b02672` |
| `specs/cloud-orchestration/verification/T-002/rollback-cleanup.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/cloud-orchestration/verification/T-002/rollback-test.py` | `05a5efb9f295fb88e6c8359defc7580e1d042d4b0763a10fcc78f03c7b467c16` |
| `specs/cloud-orchestration/verification/T-002/rollback.json` | `1c4f80eff85dda62c5be8ab5d6568d15f4d0203705dba54d667684cea2add9b6` |
| `specs/cloud-orchestration/verification/T-002/security-check.json` | `11fbf2060ece1599426ebdd0d5fcb5b5c3e2287a739a986fa888befb6a81956c` |
| `specs/cloud-orchestration/verification/T-002/task-input-manifest.json` | `8fc18b0756b277d093ed11e7c8124e83e74ff4587bae00aa5f6276df718d0dca` |
| `specs/cloud-orchestration/verification/T-002/verify-local.py` | `9cc552489c55521591a50d5a2818a2c35a9c7d17142e1ced75d1ea7bb60ae7c5` |
| `templates/cloud/github-aws.yml` | `72ddd25758096b0844ed9e3b14d3563f90e3f80d67acc4090fe3294222b2c7b4` |
| `templates/cloud/github-azure.yml` | `5c9c208f3cc0eb4ea0fe11617a159acdcde9cb3bb61a8a92bc0ebf178299b4ab` |
| `templates/cloud/iam/README.md` | `5b0b6827c7c9eaaa794aea10d8474dcd0156d26f5f0673fe5364f61c596128c6` |
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
| `templates/cloud/iam/trusted-policy.example.py` | `7e70f84eec5094a6b4a2aee3fe16dcaec968f2ec330fb7f51226969a01bd64e9` |
| `tests/cloud-orchestration-contracts.tests.py` | `71b89cf257b302fe695f7bdb5b42e648eaec0edb7ef14ce2c7f927bb5cd1a90b` |
| `tests/cloud-orchestration-execution.tests.py` | `bcde82e05cbcc84865af664a6620971ce524eb5a2869b256c74ce4ad75089257` |
| `tests/project-context-schema.tests.sh` | `24f2a43393e39b2870a87aefcc213d3b096366000bfaafff60d31f5263027311` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |

## Test Evidence

- **Test Command**: python3 -B specs/cloud-orchestration/verification/T-002/integration-repair/verify-local.py
- **Test Result**: PASS
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-002/integration-repair/execution.json

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

- **Scratch Root**: /tmp/cloud-T-002-repair-01a14d8e
- **Run ID**: 01a14d8e-ed12-76c2-b8f2-86311e279b8e
- **Session ID**: 01a14d8e-ed12-76c2-b8f2-86311e279b8e
- **Agent Instance ID**: 01a14d8e-ed12-76c2-b8f2-86311e279b8e
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

Before: 23 original contract tests, 22 original admission tests, and 44 related
project-context schema checks passed. After: 31/24/44 passed. A disposable checkout
repeated the original 23/22/44 baseline, the repaired 31/24/44 suite, then restored
exact pre-repair files and repeated 23/22/44 successfully. No repository-wide suite
was run; the root owns that concurrent baseline.

## Specification Differences

No frozen spec, task status, approval, historical report/manifest/native log or
review cycle was edited. preservation.json records exact unchanged spec/task/report
bytes. The approved integration addendum governs these unreleased additive shapes;
old no-context integrity fixtures still parse. New execution paths require context
and explicit phase. No architecture or authorization authority was invented.

Schema structural checks are distinct from runtime cross-artifact/physical-file
checks: keyed uniqueness, scope/profile equality, exact evidence paths, time
windows and hash checks remain runtime invariants. Budget uses positive integer
minor units, avoiding floating-point coercion. Provider-specific config remains
opaque hash-bound data for the provider’s later strict validator, not executable
Python or a shared cloud DSL.

## Unresolved Items

Independent named reviewer verdict and formal quality gate are **pending and
root-owned**. No Done or gate PASS is claimed. Live TEST-003/005/009 remain BLOCKED
by OQ-001. No real GitHub approval, federation, credentials, cloud resource writes,
Windows filesystem trial, provider CLI compile/synthesis, host trial or full suite
was attempted. This implementation changes no environment-SKIP gate.

The router must classify actual scanned files plus inventory; the shared scan is
not owner detection. Provider tasks must validate provider_config, enforce actual
resource/budget/backup/network policy, independently observe transitive dependency
closure and tool identities, interpret previews, maintain immutable in-memory write
inputs, collect real fresh observations and reconcile native operations. T-010
predecessor admission remains fail-closed despite offline predecessor integrity
support. Trusted directory ownership and external IAM/CI serialization remain
prerequisites; local hashes and markers are not authorization.

## Quality Gate Focus

Verify the exact initial-to-Red Git ordering and candidate baseline blobs, then
review the full repair.patch (production was untracked on entry). Reproduce both
suites, schema parity, explicit-phase successful two-policy lifecycle and zero-write
controls. Check outputs against frozen-output-comparison.json, review local path
and body semantics, and preserve historical review cycles. Evaluate only this
bounded repair; root owns statuses, independent review and release.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No subagents, external messaging or cloud actions. Applied local Ponytail full,
ECC coding/security/verification guidance, and scoped blast-radius guidance.
Read the task and canonical implementation report first, then all Must Read inputs.
Plugin AGENTS/agents files were not treated as instructions.

Caller inventory is in callers.txt: verify_binding has the admission boundary and
contract-test callers; Policy has the execution fixtures and inert IAM example;
T-004’s existing routing suite consumes parse_artifact only. No second language
schema mirror, provider executor or published cloud CLI exists in this inspected
surface. All inspected direct production consumers were repaired. Existing SDD
schemas and legacy verification semantics were not changed.

Manifest input/output overlap is forbidden by the existing validator. Exact entry
bytes of files to be changed are therefore read as `pre-repair/<canonical-path>`
in the private input snapshot; input-path-map.json records each canonical source.
External local-policy inputs use `external/workspace/...`. Initial malformed
absolute-path and overlapping-path manifest drafts were corrected before the
successful pre-implementation validation and Red commit. The validated manifest
has not changed since; it contains actual supplied host identities, strong tier,
openai/gpt-6-astra, UTC estimate timestamp and the caller planning allowance, not
measured billing. No identity came from inherited process environment.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Root: independent scoped repair review and quality gate; then manage task/ticket state. T-004 may consume the public interfaces documented below without implementing provider execution here.
- **Unresolved Items**: No independent verdict or live cloud acceptance in this run; see Unresolved Items.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.

## Genuine Red ordering and diagnostics

- `06e55a3701fbfa26131d61b39d60cce53b66166e` (tree `e7fa07ed20e7733dfc367d8fe28ad82a3833873c`): Initial integration regression Red, before any production repair.
- `feeb5d7344a7d9d43c65fcc2a2bf5511a783d67e` (tree `e3812b66b646c7b907856284867644855cc31fbe`): Root-control harness failure, NOT product Red.
- `d3c1ce886a60165a79c6bf33cadebff8e3f91435` (tree `db4038b1706844a421dc59be757f953c765878f2`): Corrected root-control product Red, before control-byte rejection.

The first Red run had 27 methods (3 failures, 68 errors) and 24 admission methods
(1 failure, 92 errors). It rejected local_context/null-output shapes, lacked new
schemas/helpers and could not construct Policy.target_environment. Constructor
failures did not exercise negative admission branches; subsequent Green does.
All production files were unchanged at that commit. production-baseline-git.json
binds their exact pre-repair Git blobs and standalone tree; red-ordering.json
validates those blobs against the private entry snapshots and shows **zero
production paths** in each test commit’s diff. initial-to-red.patch isolates this
attempt from candidate formatting changes already present on entry.

The additional root-control test first failed in the test harness: POSIX environ
cannot contain NUL. That committed failure is explicitly NOT product Red. The
corrected test mocked the mapping and reproduced a real untyped ValueError from
os.open; its separate commit precedes the typed unsafe-root fix. All logs remain.
An early schema generator syntax error was a scratch-script error, not product
Red. Early Green logs retain the limited oracle’s unsupported anyOf/allOf mismatch;
schemas were rewritten with equivalent supported oneOf constraints, and the
independent installed Draft-07 oracle verifies them. Duplicate-array checks also
use that full oracle; the old structural oracle alone is not claimed to enforce
uniqueItems. No old attack was weakened to make a fixture green.

The first admission Green attempt removed previews while clearing consumed markers
because the new evidence path now held both. Fixture cleanup was narrowed to
*.authorization.json; preview freshness/binding assertions remained unchanged.
The first mypy run found a missing target_environment in the inert example and an
optional-preview indexing issue in tests. Both were fixed; ruff/mypy now pass.
These are development iterations, not model escalation events.

## Executed checks and rollback

| Command / phase | Actual outcome | Evidence under integration-repair/ |
|---|---|---|
| python3 -B tests/cloud-orchestration-contracts.tests.py | exit 0, 31 methods; 23 original plus 8 repair | green-contracts.log |
| python3 -B tests/cloud-orchestration-execution.tests.py | exit 0, 24 methods; 22 original plus 2 repair | green-admission.log |
| bash tests/project-context-schema.tests.sh | exit 0, 44 checks | regression.log |
| python3 -B schema-parity.py (full evidence-directory path) | exit 0, 222 Draft-07/runtime assertions | schema-parity.json, schema-parity.stderr |
| /tmp/cloud-quality-python/bin/python -m ruff check --config tests/shared-launch-python/pyproject.toml [five scoped sources] | exit 0 | ruff.log, execution.json (exact argv) |
| /tmp/cloud-quality-python/bin/python -m mypy --config-file tests/shared-launch-python/pyproject.toml [five scoped sources] | exit 0, no issues | mypy.log, execution.json (exact argv) |
| Python compile + AST import/dynamic-execution inspection | five scoped sources compile; no eval/exec calls | static-check.json |
| Existing task manifest validator with private --snapshot-root and --expected-task T-002 | exit 0, TASK_INPUT_OK before repair and finally | manifest-validation.log, manifest-validation-final.log |
| git diff --check, scoped sources/contracts/docs | exit 0 | diff-check.log |
| python3 -B coverage-runner.py (full evidence-directory path) | exit 0, real 55-test run | coverage.log, coverage.json |
| python3 -B rollback-test.py (full evidence-directory path) | exit 0; pre-repair → candidate → pre-repair hashes and tests verified | rollback.json, rollback-*.log |
| bash plugins/sdd-implementation/scripts/validate-implementation-report.sh reports/implementation/cloud-orchestration/T-002-integration-repair.md | exit 0, IMPLEMENTATION_REPORT_OK | report-validation.log |

Coverage: `plugins/sdd-quality-loop/scripts/cloud_contracts.py` 485/486 executable lines (99.79%).
Coverage: `plugins/sdd-quality-loop/scripts/cloud_authorization.py` 438/440 executable lines (99.55%).
This is stdlib line coverage, not branch coverage or an independent security review.
All transport evidence is deterministic synthetic. Filesystem checks are real local
POSIX operations. No provider network request was made by these tests.

Rollback created a separate detached worktree under this run’s scratch root at
entry base revision, then overlaid the exact PRE-REPAIR candidate snapshot,
including its untracked module/schemas. It ran original 23/22/44 checks, installed
only scoped repaired code/schema/test/docs files, ran 31/24/44, restored exact
before bytes (removed only the three new schemas), and reran 23/22/44. Hash equality
is in rollback.json. The disposable worktree was removed. No active-checkout
fixtures, status fields, ledgers or history were restored. This is code rollback,
not cloud-resource cleanup. No origin/main restoration was used.

## Public integration handoff for T-004

See `templates/cloud/iam/README.md#shared-local-input-contracts-t-002-integration-repair`
and the three new schemas for complete field/type bounds.

- `workspace_root() -> Path`: only explicit physical absolute CLOUD_WORKSPACE_ROOT;
  missing/relative/symlinked/unsafe roots raise typed ContractError.
- `verify_local_context(root, request, *, execution=False) -> list[str]`: requires
  strict context, contained/hash-bound input bodies and real recursive safe scan;
  returns all workspace-relative regular file paths. No owner classification or
  provider config interpretation. execution=True also requires apply intent and
  one supported inventory owner. Caller maps errors to BLOCKED.
- `verify_binding(root, request_ref, preview_ref, receipt_ref=None, *, now,
  operation=None) -> None`: use explicit prepare/apply for bound contexts. Prepare
  may omit preview; apply cannot. Omission is legacy integrity-only behavior for
  no-context requests, never a provider execution fallback.
- `Policy` adds required `target_environment`; `environment` remains the protected
  stage identity. Both policies pin identical deployment-policy JSON bytes.
  `WriteBoundary.write` signature is otherwise unchanged; root is now the explicit
  workspace Path and returned receipt references are workspace-relative. It
  authenticates every mutation with its actual trusted policy phase.
- Existing `parse_artifact`, `read_verified`, `read_artifact`, `verify_lock`,
  `publish_artifact`, `input_error`, `exit_code` signatures remain unchanged.
  publish_artifact still uses the private run evidence directory as its root and
  requires a trusted secret scanner; admission translates its result ref to the
  workspace namespace. Callers must safely pre-create that directory.

Request context: workspace_anchor, artifact_root, unit_roots, evidence_directory,
feature, task_id, ownership and provider_config refs. All refs use `{path, sha256}`.
Expected evidence path is specs/<feature>/verification/<task>/cloud/<run>/<unit>.
Body shapes: ownership owners and explicit existing_resources/additive attachments;
deployment policy allowed_scopes/resource types, backup_required, private_networking,
budget (ceiling_minor_units/currency), evidence (residency/retention_days/access);
verification profile id/version/required_check_ids/max_age_seconds. These are data,
not permissions, executable config, observed health or proof of policy enforcement.

Pre-publication BLOCKED/FAIL may have null evidence_manifest_path only with no
native_operation_id. PASS/NO_CHANGE/UNKNOWN require genuine evidence. Invalid run
identity uses input-error rather than an invented receipt. Provider tasks remain
responsible for honestly classifying whether a submission actually occurred.

## High-risk preflight recorded before production repair

# T-002 attempt 2 preflight (before production edits)

Ticket RT-20261018-CLOUD-CONTRACT; governing clarification integration-contract-decision.md.
Existing 23 contract and 22 admission methods passed before repair; no retroactive Red claim.
New tests ran against unchanged pre-repair production: red-contracts.log (27 methods,
3 failures/68 errors), red-admission.log (24 methods, 1 failure/92 errors).
Failures include rejected local_context/nullable result, missing helpers/schemas and
Policy's absent target_environment. Most admission negatives cannot yet reach their
assertions because the new Policy constructor is absent; this is explicitly not
proof of a negative path. Green must exercise all these cases.

| Persisted field(s) | Sibling / contract counterpart | Executed failing mismatch test |
|---|---|---|
| local_context.workspace_anchor, artifact_root, unit_roots, evidence_directory, feature, task_id; ownership.path/sha256, provider_config.path/sha256 | request schema and explicit physical workspace boundary, exact run/unit evidence directory, contained immutable input refs | test_repair_local_context_schema_and_each_field; test_repair_physical_workspace_and_declared_boundary |
| ownership.schema, owners[].owner/root, existing_resources[].resource_id/owner/attachments[].resource_type/name | cloud-ownership schema, recognized owners and explicit additive attachment data; router must still inspect scanned files | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| deployment-policy.schema, allowed_scopes[].account_id/region/deployment_scope, allowed_resource_types[], backup_required, private_networking, budget.ceiling_minor_units/currency, evidence.residency/retention_days/access | cloud-deployment-policy schema, scope allowlist, explicit budget and restrictive evidence/network requirements | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| verification-profile.schema/id/version/required_check_ids[]/max_age_seconds | cloud-verification-profile schema; request profile identity/digest and required freshness | test_all_object_boundaries_unknown_and_missing_fields; test_all_scalar_types_and_schema_versions (expanded fixtures) |
| request.owner/route (discovery), operation and environment | supported execution tuple; immutable apply intent and logical target, not protected stage | test_repair_discovery_and_honest_unpublished_errors; test_repair_explicit_phase_preserves_legacy_integrity_api |
| receipt.operation/ci.environment/request/preview/policy digests and all unchanged binding fields | explicit actual operation, external stage Policy.environment, Policy.target_environment, common JSON policy digest and identical request bytes | test_repair_same_request_prepare_preview_apply_separate_policies; test_repair_stage_target_context_and_digest_controls_zero_submissions |
| operation-result.evidence_manifest_path/result/state/native_operation_id | null only for pre-publication BLOCKED/FAIL, never successful/unknown/submitted result | test_repair_discovery_and_honest_unpublished_errors |
| Existing input/dependency/preview/receipt/observation/verification/result fields, identity and exit mapping | original eight schemas and 23 original contract / 22 admission methods (retained); no new truth claim | before-contracts.log and before-admission.log are baseline Green, not Red; repair tests above isolate changed behavior |

Minimal shared data shapes refine the approved named requirements; no provider
config DSL or authority is introduced. Provider config stays opaque hash-bound
bytes, validated by each provider. Owner detection/preview interpretation is not
implemented here. Integer minor currency units avoid float coercion or rounding.
