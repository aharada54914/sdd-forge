# Implementation Report: T-005 QA1 repair supplement

- Task ID: T-005
- Model: gpt-6-astra (configured; no backend attestation claimed)
- Effort: high

Report Schema: implementation-report/v2
Run ID: work-agent:root:t005_implementation
Task Attempt Count: 1

**Snapshot Notice**: This supplement records the current repair source and evidence. Later changes or gate normalization may supersede it; the independent quality report governs gate-time state.

## Target

Repair the single Major URI producer/schema inconsistency from actual QA1 **NEEDS_WORK**, counts Critical 0 / Major 1 / Minor 0, tracked by `RT-20261019-019`. Root admitted and authorized the repair after test-only Red commit `ab98aa5670c5b6764778e6ce2066f483b9b1c9ed`. Root retains ticket, lifecycle and quality-gate ownership.

Input manifest: `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/fix-inputs.json`, SHA-256 `df7e32e5183067461c228affb1e0501409a294ac91893df8df15d0959cd20e62`

The 22 new inputs and 117 historical snapshot inputs were hash-verified, with each raw manifest verified before parsing. See `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/input-reverification.json`.

The canonical original report `reports/implementation/ci-model-modernization/T-005.md`, SHA-256 `0106b552e6e4d297deb1ff32618bc043f094d71dc3dd84382a2d038e3b31455e`, remains frozen. Its 174 Outputs rows and 319/322-method evidence describe historical source states. This supplement supersedes its helper, selection-schema and identity-test source pins for current verification. Original logs, plans, proof drivers and the mixed mutation diagnostic remain unchanged.

## Summary

A valid HTTPS authority with an empty default port was accepted and preserved by the producer while the schema required at least one port digit. Also, urllib could normalize leading non-whitespace C0 characters before testing the scheme. The repair gives the runtime and schema the same lexical HTTPS pattern, checks the original string before urllib parsing, and permits the URI port's zero-or-more decimal digits. Valid empty-port strings retain their exact bytes. Malformed suffixes after bracketed literals and normalized leading controls reject.

The existing urllib hostname, userinfo and port semantic checks remain in place. This is a small metadata-boundary repair: one private compiled pattern, one guard change and one schema quantifier change. It adds no URI framework, dependency, wire field, API, model choice or inference behavior. All 33 T-004 definitions apart from the existing extended `main` remain AST-identical; `_https_metadata` is the only function changed from QA1.

## Files Changed

- `plugins/sdd-implementation/scripts/model-policy.py`: original-string lexical guard before urllib normalization using a private compiled HTTPS pattern.
- `contracts/model-selection.schema.json`: optional authority port now permits an empty digit sequence; its pattern is identical to the runtime pattern.
- Task-local proof, execution/rollback receipts and this supplement.

The delivery schema, catalog, catalog tests and Root-committed 77-method identity suite were not edited by the implementer during this repair.

## Tests Added Or Updated

Root added four methods in `UriAuthorityContractTests`, `UriAuthorityCliTests` and `UriOriginalStringTests` and committed actual Red before repair. The four methods produced nine assertion failures and no errors: six empty-port producer/schema failures and three leading-C0 normalization failures. Bracket-suffix cases are explicit rejection controls. All previous 73 identity method ASTs remain identical, and current 77-method test bytes match the admission.

The new task-local real-jsonschema proof exercises ten URI vectors through direct validation/binding and the actual bind CLI: four valid empty-port strings, three invalid bracket suffixes and three leading C0 prefixes. It validates each published bound record against the shipped schema, verifies exact raw URL retention, and verifies rejected cases leave no output and retain input bytes. The existing 261-case and 40-case proof drivers remain unchanged and were actually rerun against current source.

## Outputs

Current six owned source/test files are pinned alongside new receipts and proof artifacts. `before/` preserves the QA1 pre-repair three files; `rollback/before/` separately preserves the three accepted baseline files used for actual rollback. No mutable lifecycle, ticket, contract or Root governance artifact is an output pin here.

| Path | SHA-256 |
|---|---|
| `contracts/model-delivery.schema.json` | `ddaa7802d5b93610d458f6a43a8d3a6b5ba71ac2c2b9279972cb1e52112af632` |
| `contracts/model-selection.schema.json` | `1249afc5c21ebb2d78344819f86f5d2e5b8f39a21b158147a5cf63066e512a8d` |
| `plugins/sdd-implementation/scripts/model-policy.py` | `0a49d7648482b80d69833ea0166d714f360106aaefe5216f65b00182fd1c95fb` |
| `specs/ci-model-modernization/verification/T-005/attempt-1/independent-schema-proof.py` | `f3c9a6f34fd847e195e387ab472294efdc67e778d7e437daf26ed8402f599a68` |
| `specs/ci-model-modernization/verification/T-005/attempt-1/supplemental-schema-final-proof.py` | `1abea4c756054f0cd0df2a40921d303a0e2c95c51f3377585f55f0cad0e37daa` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/before/contracts/model-selection.schema.json` | `8da6c134d9ffa92bb6337fa38e7639987b22fa083032da1609632b71a13dac2c` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/before/plugins/sdd-implementation/scripts/model-policy.py` | `6150c272f759a0802673060aa6c02bcf6e02d56158229ad0330be559dc75e23d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/before/tests/model-identity.tests.py` | `20ea534c2e85f2345b05e738059e7bda5ef5aeb0c05ecef073644d305eb48b25` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/final-verification.json` | `ce263e4adcf6fa0341856566051b3547dd1f0847e8b2a2c8b616f078c4735985` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/frozen-40-results.json` | `644e6ae794ff13690efd611908da2bffa647fdcbd4c5a1a2289ac1bac55f96d1` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/input-reverification.json` | `eac9030e0b92865baa1fabe535dc2ecae7837786f5841abc537337b645db7642` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-identity/receipt.json` | `7ee60074d8003ee9a305de1a1cecedf2dd57f61ae6f6266b8df001473ea6b249` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-identity/stderr` | `e0d562f8ca3978b49d45a87b7daa6c48b851c0a1f6c0a4babe56c3441a42dfe4` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-identity/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-observation/receipt.json` | `48a606091881c20428b1f2e93c8dd6db3d09f59a0ef61e48808cd62f4db92128` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-observation/stderr` | `65a1f14fd145f7ee7957582add609b577bde04be09bd53bc919144035c373f81` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-model-observation/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-required-checks-posix/receipt.json` | `66e5a45510992807934508059b3a0999965873ae41a5287e0e412cca5dbb2fe8` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-required-checks-posix/stderr` | `329697c705571887c18b52fb7e4f5f9da9cd12a4b689f3a10c082b1ec00c4e36` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-required-checks-posix/stdout` | `96445f41c1605c50a8ac43fea5acf518fe0d19eeffd4598160e34c3588a0a34d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-catalog/receipt.json` | `245b70d907043fc105a48baea5f1d4121f4aad6e628449050913935a9dd61b0f` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-catalog/stderr` | `6ce61d8349387e4c5e31712f2e06abad55d3685f9a072405ddee63e2bf084e95` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-catalog/stdout` | `007cae7f7ad90ae93f527a1c1f3bf108b271132a8ca1fcebb99fff17050f8552` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci/receipt.json` | `f200d0eb832ddf480b710e8d71d2969ff65c2467112fdb49b8d9e7dfa78d5983` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci/stderr` | `19c5aeade4bf40b6f68dc4f46900d08d6b4372370bcee8f27b00aa3e330f3f3b` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci/stdout` | `7c89bcc0dd4324f3c8baed14c36f813e41bb5c56a839b0b270426c34910dfaec` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci-plan/receipt.json` | `48e68cd168ce634e8fe4e4fbf76cb174fc4440a5dbf35b10a254f447b292e36d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci-plan/stderr` | `b7383bf1e1128a9d24c2f8642594136bc794249baaf2326cc552d6331f776950` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-ci-plan/stdout` | `e62117625d8a48c58682e610ea8af2028a498fe8d0aab9d509c767f156b06b59` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-impact/receipt.json` | `6f43103b2548ac38fd2ade9d5be70a11fee2efa8ec6df74083dfe3d397229743` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-impact/stderr` | `5a6603de1caa33e27926fb41473a73b59661c1bd9d7d07e858ddc33094792cac` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/candidate-verification-impact/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/catalog/receipt.json` | `d599a2f59d4167253f470370aeada24a821377248444a7398c1caadb9fb274b0` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/catalog/stderr` | `44523565b7915e034c159aa51e92ccd9f6f3480ab3f5531b0e77d6a825703c3c` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/catalog/stdout` | `007cae7f7ad90ae93f527a1c1f3bf108b271132a8ca1fcebb99fff17050f8552` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/identity/receipt.json` | `a331e9bafb1c60ead428bd41dd0128022e9adcb8f0bccf0d04655b4a8fdd096d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/identity/stderr` | `d8607beed29ef9d5428f30caf6c2e10418c808d2d5ee4d766256b2eb06b6b28c` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/identity/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/mypy/receipt.json` | `0a675e26841a346b2880128645d151e452a081aab4336c6f1e047d6e0768ed33` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/mypy/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/mypy/stdout` | `8228fcc5ce46d42d01caf3cd941f4e9c5f2bcc372bb5b147a2f0572d2dd675a8` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/observation/receipt.json` | `c669a2d43854fb7f6759f90886cf038fae5d00cb9ee35e84b1a9d875553dd480` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/observation/stderr` | `b69c511cbbbc27e8178a01330a87ccf073bd5ba44080d387ba4e56797b809c27` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/observation/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-model-observation/receipt.json` | `67e96be7ffbf35822b9d24c1646abc2771282c5da3ddad454cda2ca29dd3d76d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-model-observation/stderr` | `c0d1361af5c67efd826a07af32cf90c536a6b71160a3368c4bd36428f3131302` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-model-observation/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-required-checks-posix/receipt.json` | `6cda825c4f94d011784e32d85f72411e9565f62e676ae58ae55c95501bff0632` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-required-checks-posix/stderr` | `7f1fbb8cab4d1474c2bf2e7016fc6fc55a0d15ee2f91177dc35cb4eb0f4b09e0` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-required-checks-posix/stdout` | `96445f41c1605c50a8ac43fea5acf518fe0d19eeffd4598160e34c3588a0a34d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-catalog/receipt.json` | `b1a9b12116aa7a6efca6060d545054addfc074912eb7b57f66e1091e089d571d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-catalog/stderr` | `e04522c655f956df01922454f32099e2b621807872f6830a2373457a4a498e8e` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-catalog/stdout` | `007cae7f7ad90ae93f527a1c1f3bf108b271132a8ca1fcebb99fff17050f8552` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci/receipt.json` | `c8bade9990d964c239134cbafe0f1533a2e3b9f29ad7afae4c9792f3942e1bd1` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci/stderr` | `40f9bf02d484e6bde6839ac1a3a803a21a3ffd6e9cf8f46954cc34c456cf5a03` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci/stdout` | `7c89bcc0dd4324f3c8baed14c36f813e41bb5c56a839b0b270426c34910dfaec` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci-plan/receipt.json` | `cda1baecd5e2c1214aa31da6cf8e4a6943722698552ae7d5b7b053b95172b861` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci-plan/stderr` | `4fc3ebcc219801952748921eac5b97517582ee93d9a2208860c877df33c44ac3` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-ci-plan/stdout` | `a3e0a4f7d07b9e5a9951792f016bb445490a6845bf90f3bf09a4f114669f8131` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-impact/receipt.json` | `d0ca1ab46a0e7e52e18404d37dff7b171b9e0e0f18cddcfeb6a8ec653dae2179` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-impact/stderr` | `71b40fd0510f1c258c1462079631cfc5a9b69efa837f163dd56d27fc782d99b1` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/restored-verification-impact/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/ruff/receipt.json` | `cef130f4987ebb0f33bda0a3b9cf8686af7aa93be9f0e0f374242384df868664` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/ruff/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/ruff/stdout` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-original/receipt.json` | `a35441552ca37f4e840baf4c626bfac61a544e6efe3be9ebe4965282fbf5f14a` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-original/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-original/stdout` | `76b46235dc197e408f2fbaa438b558607fa51686a81f751d6850b10fb338aa6e` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-uri/receipt.json` | `bf65cfcfe910d247be87641f386a2bb3f5d43541b80fa2ae28cff08037929fc0` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-uri/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/product-checks/schema-uri/stdout` | `2a37d5abd50a4ea6e1ce8a87c25098cfb16aa92734f2f9266e26413f001bee1e` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/red/result.json` | `5e222fae75ad97a4e1500174b16411f69cc5e36a00fd17425a4cad9c7e53a975` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/red/stderr` | `92ec17cf6fab964dfb97308322c72228d6383692b5cd3e951c7626a956fb8fe0` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/red/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/red-test-block.txt` | `0258fd923ac03db6f93a521a1792716226334b99967d690045bf39b579c7d921` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/before/plugins/sdd-implementation/scripts/model-policy.py` | `64bb1934e2654b5d33de604c9dc649b92b91e7cd4b1d77bd1e8ceeffa9856894` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/before/tests/verification-catalog.json` | `3e3a747c84369d4f7713302d9895c0b143df0538384e62a966f1ed361bf9a4db` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/before/tests/verification-catalog.tests.py` | `c44127ba6505c9ad780e7e3007e589ae1287a70af4ad2fe92b057d32a4c76448` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/candidate.json` | `bf2d5326d003f1d7e928e5a6784069119bcb6292112033f5c6bd0ae41416d4bd` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/final-results.json` | `59fa0e7c0789fcb21abaff306bc35783e9e1598a66819df3ef622b69066ad93c` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/rollback/restored-before-rerun.json` | `154686c5a3dce147068db7a95b2e987c81302529d43296978c019f37fe75c7c2` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/run-check.py` | `29f71d1a263b1a22c0f8f9689af0c827a9f3723ef956f223f6a42f763f026674` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/schema-261/results.json` | `d0c5fe9ccead8c2d620dc192908bfe3604fc4dc90477b931c7dbcd7a9455586d` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/schema-proof.py` | `bd153ae9ab0706e50da63e77397624ea76bea084917130f25d073ca8153b9861` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/source-preservation.json` | `0c2d60b248d5c2062e82d65ebc821b7c4c4d1ac1231a514e4b3d07011d7f4ae2` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-path/bound.json` | `b7fa7a74dc67a09075aa6348890bbdf899ec44a2db1a4bd5d7f67a25819124af` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-path/selection.json` | `cfd7b25a9297d8e149fe1861bb8a01684475a004cbd12301e725c98798453804` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-path/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-path/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-uppercase/bound.json` | `2a2c48404ad78f4b638653a17133ba80a787e7a62bbab892ed5b853ead5b4d01` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-uppercase/selection.json` | `0d5e92e7645e98876fd21dd9774891e0a842b43ab62eed0f30fbadd9159da354` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-uppercase/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-domain-uppercase/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6/bound.json` | `ea0d6aabac2a432061c47bab2cc2eaadf45be4958082bb87f27072fea6b43d2a` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6/selection.json` | `a259c153981703c27d3345f672e45532f3516233d8d400ea62a2e7ed629783d9` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6-path/bound.json` | `4572c17b439aa50ee96ee0ba69fa80b35b0410c1ee112f9efa7964edf163dfab` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6-path/selection.json` | `875ea5fbf9b8f619a514f1d5c05c4071e2eacbea2e4565b41d30f2cb69520294` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6-path/stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/empty-ipv6-path/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-0/selection.json` | `e5a85492215bc0486e7f7df346ca585b15f1eac835b2bca599fe14ac4c803134` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-0/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-0/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-1/selection.json` | `e21d9e39ff8eaa55c47fad3e354729de05537c826ba3ebd501ccf86f3088b222` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-1/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-1/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-27/selection.json` | `a522b8660c2d6a477becf920e205d37379422e32262d78f7b9c1eeef521d026c` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-27/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/leading-control-27/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6/selection.json` | `67fab168c752e141d081f1c8e380552af92b67f78dbab6cec06d007a4f1455ac` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-long/selection.json` | `a5b81f298a863587dff8f756963706e0080d3a299f12dd165f25e18f71d4f804` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-long/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-long/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-port/selection.json` | `7d0eac60abd132f4b4c6465c2e6e81c8afd5f57c61701f056f1c0e3d84c91d12` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-port/stderr` | `a69c90f93d73a64a41a7eccd35ac0de98bfa14e3127ac56c41a1692d436dbdfb` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-proof/suffix-ipv6-port/stdout` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/uri-schema-results.json` | `dd1b1d219849b3489da65b9bb21d95c8c27cd3e9eff7d6c3f33b634f49be104c` |
| `tests/model-identity.tests.py` | `da24c1cbb5fd8c9892b65c756b3246da82f3a076054da8471da827d519fd277e` |
| `tests/verification-catalog.json` | `c799ee14873ed0caf65be69b58acb588d5f53d0f2bab86913c025257e1d18d8a` |
| `tests/verification-catalog.tests.py` | `0783c689ce7b042d5f96bc219a82f57bc9a1407288a26f576677bc1ae1b495a6` |

## Test Evidence

- **Test Command**: python3 specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/run-check.py --name identity -- python3 -B tests/model-identity.tests.py; exact argv/cwd/times/exits/source and log hashes for all checks are in the pinned receipts.
- **Test Result**: PASS
- **Test Evidence Path**: specs/ci-model-modernization/verification/T-005/quality-cycle1-fix/final-verification.json

Actual focused runs: identity 77, observation 51 and catalog 44 methods, all passing with zero skips. Ruff and mypy pass on the helper and both test files; Python compilation passes. Real installed jsonschema passes 261 original cases, 40 unchanged supplemental cases and ten new URI cases. The explicit stdlib calendar checker executes 248 times. Structural lexical acceptance and semantic urllib port/hostname checks remain distinct; no optional skip or custom schema evaluator substitutes for these runs.

The frozen 40-case driver was imported unchanged and its output destination redirected to the new task-local result path. Its original result file was not overwritten. Each new URI CLI result saves input/output bytes, stdout/stderr, exact argv, UTC start, elapsed time and hashes. CLI invocations call only the local metadata helper and do not execute a model host.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

This is the authorized repair following actual quality cycle 1, with fresh quality cycle 2 pending. No tier escalation or quality exception is claimed.

## Isolation Evidence

- **Scratch Root**: /tmp/ci-t005-qa1-fix-inputs-ml4ebdr1
- **Run ID**: work-agent:root:t005_implementation
- **Session ID**: work-agent:root:t005_implementation
- **Agent Instance ID**: work-agent:root:t005_implementation
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

The existing primary agent continued only from the admitted repair and historical snapshots. It changed only the two authorized product files and task-local repair evidence. It did not edit committed tests, the original report, Root lifecycle/governance artifacts or any shipped validator.

## Regression Tests Run

The exact previously accepted baseline bytes and absent paths were verified before installing the candidate in `/tmp/ci-model-t005-rollback-l36dha1n/repo`; the already successful 245-method baseline was reused without an unnecessary pre-candidate rerun. All seven candidate suites then actually ran against current six-file hashes:

| Suite | Current candidate | Restored baseline |
|---|---:|---:|
| model-identity | 77 | absent |
| model-observation | 51 | 51 |
| verification-catalog | 44 | 40 |
| verification-ci-plan | 50 | 50 |
| verification-ci | 80 | 80 |
| verification-impact | 6 | 6 |
| required-checks-posix | 18 | 18 |
| Total | 326 | 245 |

Every suite exits 0 with zero skips. The 326 candidate methods are counted once; the separate focused runs do not inflate this count. None of the earlier 319/322 candidate receipts stands in for current execution. Commands were `python3 -B tests/<suite>.tests.py`, using official PowerShell on PATH and already available pinned Node dependencies.

Rollback restored the exact accepted helper/catalog/catalog-test bytes from newly persisted `rollback/before/` copies and removed selection schema, delivery schema and identity test. The six restored suites actually pass 245 methods. Exact six owned states and six protected workflow/planner/selector hashes were checked before and after the restored rerun. Canonical product stayed at the repaired version. `rollback/final-results.json` records actual restoration and source/log receipt pins.

## Specification Differences

None. Empty default ports remain valid HTTPS metadata without rewriting the supplied URL. Original-string lexical checks prevent parser normalization from publishing schema-invalid records. Semantic port range and host checks remain delegated to the standard library. Frozen wire fields, identity limitations, create-only binding/resume and the 63-row field/counterpart matrix are unchanged.

## Unresolved Items

`RT-20261019-019` remains open pending Root's actual fresh QA2 result and closure process. Local repair verification passes, but this report does not declare the independent quality gate passed or the task Done. No additional implementation blocker is identified.

## Quality Gate Focus

Verify the original-string runtime/schema pattern correspondence, empty-port byte preservation, CLI output schema validity and malformed authority/control rejection. Review the full current-source 326-to-245 rollback evidence and preserved T-004/identity definitions. Root owns final scoped self-review, renewed governance/contract checks and fresh QA2 admission.

## Working Notes

The actual QA1 reviewer identified one Major producer/schema mismatch through read-only inspection. Root preserved its response and gate artifacts, opened an auto-fix-authorized ticket and committed reproducing tests before this repair. The implementer followed the admitted Ponytail/ECC guidance by reusing the existing regex style and urllib semantic checks. No new architecture or dependency was needed.

Codex continued under Root's authorized provider-limit fallback. The earlier official Claude five-hour limit remains a historical provider failure, with no retry before 21:10 UTC. No new delegation, native inference, network acquisition, manual Git action or ticket/lifecycle mutation was performed. The previous mutation runner's mixed assertion/exception exit 1 remains disclosed in the original report and is not current clean mutation evidence.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Root verifies this current supplement, completes scoped self-review and governance/contract checks, and launches fresh QA2; close the ticket only through the actual successful gate process.
- **Unresolved Items**: Root-owned ticket closure, lifecycle completion and quality cycle 2 remain pending.
