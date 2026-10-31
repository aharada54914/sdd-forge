# Issue 423 T-002 current-cycle post-fix declaration — 2026-10-07

Preparation-only authorization source for a fresh independent quality evaluation. This document is not an invocation, reservation, evaluator verdict, or Done decision. It preserves the previously declared T-002 dependencies from the v4 declaration, subject to current hash readback, and adds the current-byte implementation addendum, exact 29/29 caller test log, and T-002-only focused diff. The prior evaluator's `NEEDS_WORK` and all historical reports remain unchanged.

The old mixed focused diff and five installer-specific paths are intentionally absent from this T-002 evaluation scope. Installer changes remain dirty and separately owned; omission here is not a finding that those changes passed review. The current focused diff is restricted to the T-002 source/test paths, while previously declared ci-mcp, registration, scratch-recovery, and contract dependencies remain available. Historical 28-test and failed contract logs, where retained, are evidence of prior states only; the 29-test follow-up records the current local execution, not CI or a quality verdict.

The canonical implementation report's `## Outputs` still describes an older snapshot; it is not rewritten. The separate current-byte addendum below identifies post-review bytes and limitations. A fresh manifest must hash-pin this declaration through `gate_report_declaration`, include only needed paths, and pass ordinary admission, dependency, scratch, live permission, and ledger checks before any reservation. Each row authorizes only the exact path/hash pair; no wildcard or inherited authorization is intended.

## Post-Fix Artifacts

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5` |
| `specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py` | `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca` |
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea` |
| `contracts/capability-registry.json` | `42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1` |
| `specs/sdd-domain-multitarget/verification/T-002.contract.json` | `a1fc82b280cce0ea58af9cacc94895071d863847edc31fa3414d2c9d4b092198` |
| `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/current-build-and-checks.md` | `7ffa0e76bbc8d171b96e11e7357922238e8797f2c9ee3986552b88efb7a4de7c` |
| `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/python-toolchain-evidence.md` | `f375addaa09fce5a8805c84a9eaa23bee76d66976c09fdbdeb3e9094bb9fde81` |
| `specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py` | `77882cfbf36adca2668e32b580557d1fb13aa67b1feff22c369a955fd7857852` |
| `contracts/provider-bindings.schema.json` | `7adfa236d2bb00055bd38f3fc6b7664f6d41e88989e9aedba1c0a9c5d55f8cd7` |
| `contracts/capability-registry.schema.json` | `3a2ddfa6ad3fde7cce3b6b23399ff5772311380d6d2fdde885df69889b8ccef7` |
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `b7311b30a9b4224a60a251facbcf0d4ca71db563df06f62a301a7e698b88cf13` |
| `plugins/sdd-quality-loop/scripts/resolve-component-paths.py` | `38b870f89b8b95cd4e9de7074cd77f610d53aca19715d4bff6df05381c11383e` |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.py` | `ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511` |
| `plugins/sdd-quality-loop/scripts/validate-context-projection.py` | `7a0fc4c486e1341ce635f14d480779e25a60cdd3d078a877f9ee47c0fe0f2169` |
| `plugins/sdd-quality-loop/references/provider-terms.json` | `2355adabd24e3d01b18f3eb99e986073791fb3f85b4d9d27a91fd6a0f0a0ae7d` |
| `mcp/ci-mcp/src/server.ts` | `ba5824252063b78cc078219852b74cd3c661bf12e12af79701227c2874c4fed5` |
| `mcp/ci-mcp/src/github-client.ts` | `2158b448b1a6b6181dc48b6b069aff428b71c224bbeda4179c189e1608604a5e` |
| `specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/fixture/capability-registry.fixture.json` | `70ccb4e052514edae6b7b617da94e5ce5cc003e9ed55b79afbe34d498989a9fc` |
| `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/current-validation.md` | `129f25f6588bb60b69b435e98de95aeae1e759c812f0f302734247d1dd0fb149` |
| `docs/adr/0016-workflow-axes-separation.md` | `c72452308fc5d40f422f748b729e86a1190e57fc06a178f2e807d8a17b4d144c` |
| `docs/adr/0017-gate-stage-model.md` | `8b6b337dfcaa18d6ffc25f04151bfb9e1aafaaf69dcbb21d9b5326baba2ad650` |
| `docs/adr/0018-provider-binding-separation.md` | `26b70c330c3d42146c31381a09beca3df8b3b92e374359a9d141bbc2e115d597` |
| `mcp/ci-mcp/src/auth.ts` | `d9c98796282df43b78b500a77233ec4135c8ab89b33d81463b9b98aa339f301d` |
| `mcp/ci-mcp/src/index.ts` | `22873cbab38617dbdb94818e0a53840ba6cd2f7da63640891722d97e2a1e07b2` |
| `mcp/ci-mcp/src/diagnostics.ts` | `2bc46044a2525d6b507c9dcdbff1eb7b9d5d71e924e3023538953f31c10bca96` |
| `mcp/ci-mcp/src/repo-resolve.ts` | `147d8306a00b01649450b3ff90659d861df2aaec2f5fb2f103fb6c2573add143` |
| `mcp/ci-mcp/src/error-normalizer.ts` | `b1b15448efe52d4f22a8de2d73ea670370f086162da7d499f5f97e1d2e8a0e97` |
| `mcp/ci-mcp/src/tools/actions.ts` | `6f2a30a4b8a64c14bc0a6b58eeb2dc4ebebeb04985b4cc3e130b1186a4f07328` |
| `mcp/ci-mcp/src/envelope.ts` | `af1160812b48e6bfdfbde71096c1768f5f05e3e9872286f7019eff2127d5c176` |
| `mcp/ci-mcp/tests/no-write/no-write-behavior.test.ts` | `7569f16dff5958bb17869a1e8b2cf0cbec63782e70131a573b63d0d700ea1fa0` |
| `mcp/ci-mcp/tests/no-write/input-schema-fields.test.ts` | `7123d90b4331e14ec45ef82070b38590554ee091b963e0f39271ed0828235112` |
| `mcp/ci-mcp/tests/no-write/support/write-inducing-fields.ts` | `8d6f5d6ff4dc5157874927f72db113753e2210218579206ee8be498e389b80ba` |
| `mcp/ci-mcp/tests/readonly/static-check.test.ts` | `3753edc9756e41c3876427e91eb20fea50507ce680edb3631075adbd6e45e342` |
| `mcp/ci-mcp/tests/readonly/support/source-scan.ts` | `cde664a264487d43ca96674a7d67a66db2e805d6e0265462f416be1b3a88e4fc` |
| `mcp/ci-mcp/package.json` | `787b7a6639b674256da91747835693b7f960f333130e50bafec359d8b1b47713` |
| `mcp/ci-mcp/package-lock.json` | `cb97c37946a9f3d7b0e5ce17b25da9396eec4f1123ffc50781a9089d41b10b6f` |
| `mcp/ci-mcp/tsconfig.test.json` | `1b0a03e8923981d7bbce5fd5d98aea907ea3215630de18deb7f906667c0b1201` |
| `mcp/ci-mcp/dist-test/src/auth.js` | `2f407385151b1f480f30a65c0ad8e6299c20901ec566f09a1950bc3a08f1d86d` |
| `mcp/ci-mcp/dist-test/src/envelope.js` | `66c3b015eb63b73d717e9a4a01fe4bd22ce5485e722445d33124b0d0ff6b6769` |
| `mcp/ci-mcp/dist-test/src/repo-resolve.js` | `424feec30cc13e13af91ccc99612c3be7f2066d7e4d0700f6c49a33a9944bef7` |
| `mcp/ci-mcp/dist-test/src/github-client.js` | `272bd6203a486cb1749b646f25d0a24c22c4a5e137571a5988717da567cbc42a` |
| `mcp/ci-mcp/dist-test/src/error-normalizer.js` | `f50ef2a0e99e2811a995230e307bdab1f20cb1393631e87aa3f5bb3cb02012fc` |
| `mcp/ci-mcp/dist-test/src/tools/actions.js` | `24044a6b586c7065a3fed167acf6f11e4121cc616bafd2dc151675d23491da16` |
| `mcp/ci-mcp/dist-test/tests/no-write/no-write-behavior.test.js` | `63b28864750fb226d72d262c8fbd860936975bac97de1c4d42c3986ada3ad626` |
| `mcp/ci-mcp/dist-test/tests/no-write/input-schema-fields.test.js` | `92e47174e67513ae2b84118a19d18fd01f4698a5b0f5d15660c1bb7944365598` |
| `mcp/ci-mcp/dist-test/tests/no-write/support/write-inducing-fields.js` | `288ee31e2e64310e7ed89d8d0999235909d4229cbc4a89c846901fe6c5c3e0f8` |
| `mcp/ci-mcp/dist-test/tests/readonly/static-check.test.js` | `df0fa0e6473970b50894912d9c3f82087cf6d930a7b618e71c5b7a4db644f6fe` |
| `mcp/ci-mcp/dist-test/tests/readonly/support/source-scan.js` | `7b75368d8404cc4ed8776bea141f7e700bf8d8ebd40d24987d4b43809b71dc84` |
| `reports/verification/issue423-t002-donewhen-evidence-audit-20261005.md` | `ab93e09d1a673602ff5465549428f434820702e33f0dc6e0e0a8e8b3d887c670` |
| `reports/verification/issue423-t002-ci-readonly-current-20261005.log` | `5e3e1a68560659a236ff3de10173f45107b05d7f3186db13e90b8caacd314778` |
| `reports/verification/issue423-t002-build-human.log.SYnVYKXU` | `2af432e4dcf7f61048f9168ec3ad971fa0a4a1187702343438681fccc7076a5f` |
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md` | `a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462` |
| `reports/implementation/sdd-domain-multitarget/T-003-attempt2.scratch-owner.json` | `1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/T-003-attempt2.owner-observation.candidate.json` | `4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679` |
| `reports/verification/issue423-scratch-recovery-candidate-20261006/independent-recovery-review-completed-20261006.md` | `bc3c60c14eafbf263d3774fe0a22b7df0a178c4906d88fc71b34dcfbb8ee561e` |
| `specs/sdd-domain-multitarget/verification/T-002/registry-registration-candidate.json` | `c8a6beddf73e02e16bc31e4588b7ca0a1a632f554bdf41ec748da533a788170d` |
| `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py` | `fba1559b635fedaa30b2e4cf716143e31ccf8f7d7b8bffd21f83fe4fca2b3eaa` |
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.sh` | `ff95edd6b487142af51b08a37cd5d7df108d6228891bbfa8b700124a659c67d9` |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh` | `abde8035c825c318a56a3d9e1b24b2fd618553f10f9784ceae8ab2173eeadf0c` |
| `plugins/sdd-quality-loop/scripts/check-component-coverage.py` | `d6505e2909ea988384c0694c3f4b865e8f4539ba25eb71dab85d21ed447882fd` |
| `plugins/sdd-quality-loop/scripts/check-contract.py` | `2b94c174a534309c6b8744451a34bc6124406df373c45be6deb63c8a311249d3` |
| `plugins/sdd-quality-loop/scripts/check-criterion-freeze.py` | `99816d7ed8c767f5a19670e582e1df764fe39a36ae2d979595d72e6761a05c90` |
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064` |
| `plugins/sdd-quality-loop/contracts/capability-registry.json` | `42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1` |
| `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` | `e9db61b7a9eeb28c1c50668e017fd8d570e490684daf68bc5d98f5348b0a31e1` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/BASELINE.sha256` | `6d2e1905a778ff34d1eddcbca1ef435c6dec7aaa387c7051e93fba19d76109f0` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/CANONICAL.MANIFEST.sha256` | `7d7cbabe15ccef2bfee316dec0387c360a084ec6b9899ae925d64da295a756e9` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/DERIVED.MANIFEST.sha256` | `c901d358d710023c9155394a0be9daf4001d13c80b1931736a59c766ba97326d` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/contracts/capability-registry.json` | `b09dc7759542e9cbfe8cc81c38e4f7a1d7630d0c1be77ec13d6d981785c00d67` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/plugins/sdd-quality-loop/contracts/capability-registry.json` | `b09dc7759542e9cbfe8cc81c38e4f7a1d7630d0c1be77ec13d6d981785c00d67` |
| `specs/sdd-domain-multitarget/human-copy/T-002-registry/plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` | `e74ecd4c9b9ed7e79238f85d69e689f1c76aacda9d886deaacb6f81a4d58682b` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/lint.stdout.txt` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/typecheck.stdout.txt` | `5d4b6d285b77932e3d08212c3b4974d0a803f98ec60408ac6ccf6a063fa6c19e` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/boundary-tests.stderr.txt` | `750c03af12d223b75a1fd614662f33d42bf02c82b0b9a0489d33a24e30949d99` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/placeholder.stdout.txt` | `3786ea13bcd82f362d4c7039731b2dadc932eef395ce8af5856e033fc4df26b1` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/task-state.stdout.txt` | `5167b82fa998683b6137e47954c61dfa14e36a39759ffce3850590ccf6eb4a35` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/evaluator-result.txt` | `e8ddf1cd415ea051d225f85795ec814142cd7d5306c174e15662ce1296aaf203` |
| `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/registry.stdout.txt` | `94c7743c4c51abdf221ee7c8bad93f29e4032aa6f9ccff0dc8adccb8aea9f808` |
| `reports/verification/issue423-t002-formal-major-followup-20261007.md` | `d720645523aa86e12b23cf09334eacbff4e8532d9771c8a21d9c01b9634a885c` |
| `reports/verification/issue423-t002-focused-diff-20261007.md` | `ecf55da74d39add6529c271d4cf5836e852748a04cf146dbe14360bf486caafd` |
| `reports/verification/issue423-t002-current-byte-implementation-addendum-20261007.md` | `5a68b0645c5cd539a3b83e96ec969f525f4671389c36d022129d11070b6792c5` |
