# Issue 423 T-002 post-fix declaration — installer evidence addendum, 2026-10-05

This is a new non-frozen preparation declaration under the approved recovery scope, not a quality-gate verdict, independent evaluation, reservation, launch, CI result, host registration, or Done decision. The earlier declaration and historical evidence are retained without modification.

The canonical implementation report `reports/implementation/sdd-domain-multitarget/T-002.md` was rehashed at `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4`. Its historical output hashes are not silently replaced. The predecessor declaration `reports/quality-gate/issue423-t002-post-fix-declaration-20261003.md` remains at `c42eb9c13c3d0d7d0943aa2bb333f0b3702808ab8a7614a7d800561935184de8`.

The following 26 exact path/hash pairs preserve the predecessor's 21 rows and add the installer, its test source, and three scoped evidence notes. Every row was compared with current SHA-256 output in this preparation. This declaration is a pinned authorization source for a subsequent evaluator manifest, not itself an evaluator input. Admission still requires the normal launcher contract: pin this declaration as `gate_report_declaration`, bind the listed inputs explicitly, and recheck every admitted hash immediately before reservation and native launch. No existing manifest is extended implicitly.

## Post-Fix Artifacts

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` | `4794ef81888e83a4d45f37a680ab65436cd1ca97e1d01c59acf8a22dae898788` |
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea` |
| `contracts/capability-registry.json` | `42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1` |
| `specs/sdd-domain-multitarget/verification/T-002.contract.json` | `ac635f41d70213d8e3efc7d364fea0d6f7d36954ddfb4d0c8b1349c75d5c3a22` |
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
| `install.sh` | `87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50` |
| `tests/install.tests.sh` | `648d093acbda64a1c3dff445fb2a97f537688a6f6426a64bd2701e36ff444bf4` |
| `reports/verification/issue423-installer-evidence-scope-20261005.md` | `94720da087497bb8f06a871f4ebc7a926d7c66ab036e831cc92b181ece3790a7` |
| `reports/verification/issue423-t002-installer-impact-20261004.md` | `5e82b93b82cf50b045d13c0e363d00eb793ee59476a197f8735b5b63107275f7` |
| `reports/verification/issue423-current-installer-recheck-20261004.md` | `570adf467f7f7eee9c8e245942b33fff102446305be8548113e48a295111ad36` |

## Evidence scope and limits

The three added notes distinguish the current installer EXIT-trap correction from payload copy/placement behavior. Their 43 passed / 0 failed observations are existing test records, not a newly executed suite in this preparation. The fixture uses HEAD payload with the current installer overlaid; it does not prove distribution of the entire dirty checkout. The unchanged validator/helper hashes preserve the scope of the prior human FilesOnly receipt and its installed-validator observations. FilesOnly is not host registration. A new full-current-tree assembly receipt is a separate delivery requirement if the selected gate requires that scope, not a consequence inferred solely from the installer hash change.

Private raw human build logs are excluded from this declaration and evaluator admission; only the bounded summaries above are included. No configuration, environment dump, or personal data is added.

## Current launch blocker and handoff

The manifest-filename binding human batch is still unapplied: all three current hashes match its BEFORE pins:

- `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`: `011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b`
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1`: `e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925`
- `plugins/sdd-review-loop/references/review-context-boundary.md`: `07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a`

The existing human-only runner `reports/verification/issue423-manifest-binding-human-apply.py` was rehashed at `7a0732632570770c853f915a85f51a698c053375bf06eed96d63dd90420e098c`. Its approved human execution, readback and required post-apply regressions remain pending; this preparation does not execute it or alter protection.

The previous evaluator candidate `reports/verification/issue423-t002-evaluator-input-candidate-20261004.json` remains unchanged at `eaea79e776ee9be5ca6e42fe349f246c8624a631726e1d84b130efbb5ce76843`. A future fresh manifest must explicitly incorporate the installer evidence using this new declaration, rather than reuse that candidate as though its input set had changed. Complete the normal caller/precheck, real identity, receipt and complete-delivery checks before a new formal run. No identity, reservation, or PASS is created here. No Git operation was performed for this preparation.
