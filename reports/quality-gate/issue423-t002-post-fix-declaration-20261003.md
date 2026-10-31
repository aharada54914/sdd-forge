# Issue 423 T-002 post-fix artifact declaration — 2026-10-03

This non-frozen declaration records current bytes after the approved #423 recovery and the human-executed isolated FilesOnly assembly. It is not a quality-gate verdict, an independent evaluation, a CI result, host registration, or a Done decision. The canonical implementation report (`reports/implementation/sdd-domain-multitarget/T-002.md`, SHA-256 `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4`) remains unchanged; its historical `## Outputs` row for the validator names old bytes and must not be silently substituted.

The following path/hash pairs are the only additional post-fix artifacts authorized for a subsequent T-002 evaluator manifest. The declaration itself is a pinned source of authorization, not an evaluator input. Recheck its hash and every row immediately before reservation and native launch.

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

The 28-test boundary suite and its original contract/schema inputs are already declared in the implementation report's `## Outputs` table. New lint, strict typecheck, Registry, risk, structure, placeholder, state and helper-regression observations are summarized in the current-byte note above. The human build log (SHA-256 `450aba84af3339e078ec3f9f6e69d57928b1177fa24705edc294ddaf964a2fe8`) remains private local evidence, not an additional evaluator input or publication artifact. Its public summary records only current-byte distribution assembly, parity and installed validator execution; FilesOnly skipped host registration, irrespective of the installer's generic `registration failed` prose.
