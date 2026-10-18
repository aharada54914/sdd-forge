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

cloud-orchestration / T-008, bounded attempt 4, caller-authorized test-only release integration repairs (REQ-014 / AC-014 / TEST-014).

Run ID: 01a1507a-333c-7fd0-ac6b-e012aa1447aa
Task Attempt Count: 4
spec_revision: `5cd2db84e3fc959fc576bcd7b0c1083eb12c03bd2e4d454a8d1082390b07ae83`
Entry Git revision: `a151c66a26bd2aad09232a1082d2ba9e3ae3643b`
Input manifest: `specs/cloud-orchestration/verification/T-008/attempt-4/task-input-manifest.json`, SHA-256 `69541d914b8797fc47edb55c5e5bcb0a8a93631535493b990c0aeeb2e8f7b5d6`
Supplemental registry inputs: `specs/cloud-orchestration/verification/T-008/attempt-4/supplemental-input-manifest.json`, SHA-256 `5be0775845f448778bc6abfbcc9c9745c0f880ad652600eac146b8a92039bd93`.
Supplemental cloud-test inputs: `specs/cloud-orchestration/verification/T-008/attempt-4/cloud-supplemental-input-manifest.json`, SHA-256 `20964ea47c4d31a903bb270f805df89ea68bea3734d48f04ae08418e85121fed`.

Each supplemental snapshot was captured and successfully validated before its newly authorized test files were edited. Initial manifest aliases are resolved by input-snapshot-map.json; initial/ avoids input/output overlap, and scope- aliases encode dependency namespace paths disallowed by the validator. Exact original locators/hashes and private scratch copies are retained. Two draft admission errors (namespace character and input/output overlap) were corrected before edits; no failed draft was treated as admitted.

## Summary

Fixed the two stale PowerShell model-matrix literals; completed both vendor fixture lists and made stale/generation diagnostics explicit; preserved safe Windows process essentials in isolated installer subprocess environments; restored skill mutations byte-for-byte rather than introducing Windows CRLF; limited one POSIX cloud-evidence integration method to its supported platform. No product, contract, registry, dependency-lock, workflow or documentation bytes changed.

The locked Inspector request-timeout problem remains unresolved, with caller acknowledgment. The actual real-repository smoke test is unchanged. This is medium-risk acceptance-first work, not high-risk implementation: WFI-001 persisted production field/counterpart/mismatch checklist and committed Red are not applicable. Existing failures and prior candidate work are not retroactive Red. No repository implementation commit was made (existing suites create disposable fixture commits).

## Files Changed

Five test files only, plus this new report and attempt-4 evidence. scope.diff records the exact delta. All prior canonical/repair T-008 reports and frozen feature documents retain their initial hashes (preservation.json). Unrelated concurrent root changes are not mine and were not reverted.

## Tests Added Or Updated

- Routing PowerShell twin now matches the existing Bash twin and current registered-available-model documentation. Legacy fallback, role floors and mis-cased negative fixtures remain untouched; CaseSensitive literal assertions remain in force.
- Registry-discovery twins copy exactly the three missing cloud schemas. Generation must return success; errors include captured diagnostics. The initial drift assertion now requires the specific stale capability-registry diagnostic, so missing-source cannot masquerade as drift. Fresh-tree no-write checks and all other cases remain.
- install-cloud uses an explicit PATH/PATHEXT/SystemRoot/WINDIR/COMSPEC allowlist, redirects HOME/USERPROFILE/TEMP/TMP to fixture roots and excludes ambient cloud credentials/configuration. The same helper covers default subprocess callers, installer environments, and restricted installed-Python environments (which retain os.defpath). A scoped mock proves the allowlist and rejects ambient AWS/Azure/Git settings. CLI POSIX guards and Windows unsafe-root refusal are unchanged.
- Skill visibility mutations/restoration use bytes, with full matched-control diagnostics. A real PowerShell validator probe on Linux, explicitly emulating Windows text newline translation, returns [0,1,0] for matched / CRLF write / exact-byte restore. The failure is “Skill must declare disable-model-invocation explicitly”; no validator relaxation or skip was added.
- Only AlarmNumericCases.test_public_synthetic_threshold_result_counterparts receives the underlying public harness’s existing native-Windows limitation. Pure numeric/XML alarm tests remain runnable on Windows. All supported Linux synthetic bodies still execute.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `contracts/agent-model-capabilities.json` | `b5a4bd4b156cfbc5f51bedf98c13e0ac3e4d237f1a00c1f79ae4c595b9f444b1` |
| `contracts/agent-model-capabilities.v2.json` | `847fe86588ea22dcb0a13b7b61548aa254f22a8244aa5153e63efefe8a4d200e` |
| `contracts/capability-registry.json` | `dfc1b948bb085d3c86f1f7958b9564c1cb6cf6240ce9d57551656fffc2f15c75` |
| `contracts/capability-registry.schema.json` | `ef70a27785d325cc32d2c4a2faeed099e9df3058fd7a918e2efbd4013ed8f319` |
| `contracts/capability-summary.schema.json` | `09d4ace8cc599b4ef7632aaa09c7477e765bcfa69943f2231f8870aac4cbc42f` |
| `contracts/cloud-verification-registry.schema.json` | `56c235d897412295cfa631906c8fd3688a43ae6918178753ee1ed934fd622392` |
| `contracts/context-projection.schema.json` | `3c8e39c6a8dedf948cbd7e6a8f36369f2a68a3fc3dd92192f90bbce917d32643` |
| `contracts/facet-manifest.schema.json` | `81d4f1621923133e55875621ba81b30ad9d21688d9442c5a371fc1023b4a4c51` |
| `contracts/lite-check-catalog.json` | `c251b3e02a2c93c45a7ea590bc5a7e36eef8e5915c485b0c6a6e83519afe086a` |
| `contracts/lite-check-catalog.schema.json` | `a4e458242d68237cf16e66aa28b362c30dae4a6d20109cb4af51711f6fc1cd19` |
| `contracts/lite-upgrade-reason-catalog.json` | `e73a730f9edacd7d2dad2da3e13b9e3df01f7002c25f7e947316ca249118eb76` |
| `contracts/selected-verification-plan-v2.schema.json` | `cddae6fd212bf40a10fa86a27f171f0342b578f7a651bc276448f7134f4e8fe5` |
| `contracts/selected-verification-plan.schema.json` | `0da68ea6b5c880ee7db2dc0bf88e9ca4c31c01fe8d859dfb50c664eb8a2bd7fe` |
| `contracts/task-input-manifest.schema.json` | `22a756c64a7c720b761b31d71c9fbb62c390a9f18b201673443e962998781749` |
| `contracts/verification-contract-v3.schema.json` | `c52f8795c274ea8dc8c3a54f2e6b0d55ca9a8f49164200065fff51e3d710345a` |
| `docs/adr/0003-turn-first-agent-routing.md` | `e96a895108ca8919073b722180b3c09e695bdf8f1ea558f099616348d95048df` |
| `docs/agent-capability-matrix.md` | `097ee2d4bf93ccb6a880d0aa2e7ece4a02663f965b4367d2a9ed50a8f8ffcea1` |
| `install.ps1` | `2014193f4e31a234b0336087d434ed12d0f8d7f73ff87bd8bb9744c158ac42a7` |
| `install.sh` | `7827514addc02f00cb671d7963b8d70c80327113ea1bae5fa694bb69306e6f3d` |
| `mcp/sdd-forge-mcp/dist/index.js` | `7ec12198da5ece99627ee80323196bc875e0f1bfb7dba0eadd62813cf90d6d96` |
| `mcp/sdd-forge-mcp/package-lock.json` | `2073331df48c2e05d7547aee4bde63a291c3940c5ece5bbb363a186b127c1608` |
| `mcp/sdd-forge-mcp/package.json` | `fdb9147028ded12a7470dcbb989390d669566f0f976151ecc5bc331311e07361` |
| `mcp/sdd-forge-mcp/scripts/run-tests.mjs` | `0ae887bcfa5501bfc8d83b2a13572657a6d5874a7ff9e3da2905efb459d1b87b` |
| `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts` | `8dd6c9ef06b0e15ec063ab38b8b12aa356823b14dcc8778400a48d6a8fd47a7a` |
| `mcp/sdd-forge-mcp/tsconfig.json` | `58ad1654c10d1c5f263c428d083263dd2001dd960a75d74a971225d44cb08c67` |
| `mcp/sdd-forge-mcp/tsconfig.test.json` | `1b0a03e8923981d7bbce5fd5d98aea907ea3215630de18deb7f906667c0b1201` |
| `plugins/sdd-implementation/scripts/validate-implementation-report.sh` | `430e0e45c6bb417cd65f7f7f228bb59280d6d0817c8b34236223b8fbd4702029` |
| `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh` | `5e209d11c50b9c580572adedee0c500fcc48233c1cafe5d22d08318c52059f73` |
| `plugins/sdd-implementation/templates/implementation-report.template.md` | `0c926d76c0aab214fe305ad5974dc6636aea81cc2764a0b37292ea61cb4f1f75` |
| `plugins/sdd-quality-loop/scripts/registry_discovery.py` | `5cb5fa8230a21e3b4d108b4643d3db474586b34601eb52c1fbcf932d259541da` |
| `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` | `a61f889f274a8069d06c359caf813f79a444de5c77ee64c5a37404a8de8b973b` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-bash.log` | `19d1f866a143b342d3467e95e0ac60b1bee77853362c40b3569ee151078a521d` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-cloud-verification.log` | `0940ee88dfbab4f298a19e85647c867929aa83bc0e7f874316e5f27446e8864e` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-install-cloud.log` | `87465e7a97817c4af1f5b9cc1c6c5088129bb26ae9a71eec1bedfe759287cdb8` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-powershell.log` | `3bcfa38413e7a45810b7e1f338650cd53d13ca2b405fd8379cbd1dd7a3032037` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-registry-bash.log` | `86cef72dcff05d1494fb0d2e410b5d4acc50988ed80c92032da5a2416c4feb19` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/after-registry-powershell.log` | `86cef72dcff05d1494fb0d2e410b5d4acc50988ed80c92032da5a2416c4feb19` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-bash.log` | `19d1f866a143b342d3467e95e0ac60b1bee77853362c40b3569ee151078a521d` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-cloud-verification.log` | `0eb955cf31e18aaf9e5fa2ca294a0778175e7bdc5aa6f7ade884f33d68c1d801` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-install-cloud.log` | `a2bc571976c4c270a6b70289a6ac2b995e7f9bc81776eefe5baeb91ee6fc604d` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-powershell.log` | `e6890c581702ec97e0bc37b6a9c923df35d40867ec8476697e043dcfe9991f8f` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-registry-bash.log` | `40220d6e43f3d57b1825cb36e300d5d9fca675771f719cec526da67ff872ee67` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/before-registry-powershell.log` | `40220d6e43f3d57b1825cb36e300d5d9fca675771f719cec526da67ff872ee67` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/checks.json` | `790fdd7409dbed705b61522431de4a7e66b5ab533d5f1b3a2a71a785b3afa823` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/cloud-supplemental-input-manifest.json` | `20964ea47c4d31a903bb270f805df89ea68bea3734d48f04ae08418e85121fed` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/cloud-supplemental-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/input-snapshot-map.json` | `2bff8e04bac36ca780fb9b769f95bf9c0104ddf161b03af3fde8d5cbb6f70009` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/inspector-interface.txt` | `c2a6d843dc381ca3d061c221bf99589e3ea1c90f66dfe40f86586e6ad299f375` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/inspector-probes.json` | `11a242cabb26ff1eaa3e5acfdc868bb2b82394e9f8f314661919fcd924ad273f` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/mcp-build.log` | `365d6b59b51f522938fa97cf21b7f96cca4e9f594b9b7a58ac5700e335078e21` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/mcp-tests.log` | `1120fc96801c1c8a65b60078a04689cbee0d0363610f754dc2064cc02a45a91e` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/mcp-typecheck.log` | `c3fb6b341c1dd8055671bf668496cf9c991cb9a51baba33c6863595b0d05dd4c` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/mypy.log` | `f9b031e5c45aa702cd4fef028d465551cb20a2c4698e0913c7b00766b20ac4d8` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/native-allocation.json` | `e43345fa63e347c3812efec902069576810adb3d5d53c34b8a04908b4a95c1d1` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/platform-controls.json` | `680f53e1cf92fdbd1ff352e8778b393b796fc01ed88696c9e1c89f213d6f1814` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/preservation.json` | `4cc46f591ec667bca88d6a09b65df608e840781e2c2d95147e62533abf13734f` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/report-validation.log` | `a0eb36646f9654b7ef1b674fed63ad247a1febe005869fbf36ce295f5437a10c` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/rollback.json` | `8f4ba003459113f33893b7e41482439126a4772966d0fec5c84853ca02421710` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/root-inspector-boundary-feedback.json` | `b22db8406d51823bd81244bb8b798cc04f48b9b13494cb5db75025b93efe5b62` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/root-registry-fixture-feedback.json` | `171138e40873473c81f0f6ca28ee0a2661a06d209622de30e4b0cdd559997e23` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/root-windows-cloud-feedback.json` | `63a3de288327fb794a2e5f73d735469a0090c0b64b029c9ca13dffcb0e40453c` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/scope.diff` | `eceb60ed54fd960cc57cd834a02f30a79120ef0ebcf44ed9e2a22203400579bd` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/spec-revision.json` | `41479a73a185f7a6bc6ea22133811fd5125b9a34d3547cf60ee62f5980f5d7e7` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/supplemental-input-manifest.json` | `5be0775845f448778bc6abfbcc9c9745c0f880ad652600eac146b8a92039bd93` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/supplemental-manifest-validation.log` | `5c5a224cdcb7cbc7dd87a9f22fc1e02889b8f3a0419b23f5705c63ecf143da75` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/task-input-manifest.json` | `69541d914b8797fc47edb55c5e5bcb0a8a93631535493b990c0aeeb2e8f7b5d6` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/verification-driver.py` | `5e219cc9fbb56538fc87cc83c7bd3805cc82198e4ffbcd9a2c7142ca73b82212` |
| `specs/cloud-orchestration/verification/T-008/attempt-4/visibility-control.json` | `4dd07a6fb96d714babd106e0b921119f9325459132bc70aab3fb0a0bf300d850` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/powershell-routing-failure.log` | `451da67548841e7d2d296d1047683305fb4a2b14b440e8635655fa97cca2365c` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/registry-discovery-fixture-failure.log` | `3379f81328f91e4627ecfbfb593e8edf2eb2cf121d10d554ce57b54d3b6fc717` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/scope.json` | `237026bcb11ea812dfbcabc4054bada6912df7d0ec003b07de2d6c1303743720` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/windows-cloud-alarm-failure.log` | `48526ff1edd8ed61af7efb5451c032aa55a6dcbaaac312064fab96a9c0dd64de` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/windows-cloud-install-failure.log` | `6d28e1cf6f34cf2ae77645ea10de54f30b733665d5877d391f18389bc8a7040b` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/windows-cloud-visibility-failure.log` | `59c5e1b5c1e138572be3d673829f6d41c41d7f542c49204649aad700cc078d19` |
| `specs/cloud-orchestration/verification/T-008/root-release-attempt-2/windows-mcp-timeout.log` | `b9a7d9e381f3f462b528b4b4d083aa73d8faaeff75422d19684480ebc0960a24` |
| `tests/agent-model-routing.tests.ps1` | `1fc1f0310aadc90b498755b0d6777a6a088c73ef6b2c4fb019f830d85b6a7027` |
| `tests/agent-model-routing.tests.sh` | `db805b44a8529b6f066fdcc14f90af20f0b0bd95658294b4406ac64d6a12b69f` |
| `tests/cloud-orchestration-execution.tests.py` | `dabe98ecf8a47d71da3947c70066c059bb7388f8134a9d069812a2d63507778b` |
| `tests/cloud-orchestration-verification.tests.py` | `12efb15e4a595c0507abce45556aeced8344564e0d5105d989c5b1649928385a` |
| `tests/fixtures/capability-registry/registry-discovery-catalog-bad-schema.json` | `bf667ad921cd30731675d6bda10273526331447b371f72b01fa30ea42d442c62` |
| `tests/fixtures/capability-registry/registry-discovery-catalog-valid.json` | `772baca07d3ec95ced4638ca1be80215c4803e19c331bf8857fd9cfdf0836b99` |
| `tests/fixtures/capability-registry/registry-discovery-registry-bad-schema.json` | `e7be0e482e1495c762cf923758db85d5e14dfc4b7bb68d9b26b4954113cabcca` |
| `tests/fixtures/capability-registry/registry-discovery-registry-valid.json` | `87516d042f5108d07f122f889dc942a21be060b16bd413898464220de3ede1ae` |
| `tests/fixtures/capability-registry/registry-discovery-schemafile-bad-id.json` | `913508a1edccfec737ec0d6d74c332f6f6f36bbada51c004255cfbca929c7a99` |
| `tests/fixtures/capability-registry/registry-discovery-schemafile-missing-schema-key.json` | `95f55997ad373f7d18f38188727297064fa501b7447603fa66f7d43e36a83761` |
| `tests/fixtures/capability-registry/registry-discovery-schemafile-valid.json` | `58181b930b865982842b84a6cfa9aca4d6d226a821601cd5cddb1cbefb8f557e` |
| `tests/install-cloud.tests.py` | `d51687890c89db046a4624e4a64a8b58643bf8917d76f82b2c9dacce5639ace1` |
| `tests/lib/verification-registration.ps1` | `ef7945b4e18e3bf70dba53b424e28846c92c0cb2f22feed92581c31d794f0d7f` |
| `tests/registry-discovery.tests.ps1` | `ca12dbdb4642e832ebb1e2f382d156c162909996e526c643a712d56a29b6dd50` |
| `tests/registry-discovery.tests.sh` | `c3f82f519a2877927a4f0773e1d0be072c374b106fde256d84607454607954b5` |
| `tests/shared-launch-python/pyproject.toml` | `8308097d7ca9084f9e3a02add4d78f96514cefa947c25bab3ed24a7b74393f12` |
| `tests/validate-repository.ps1` | `fd209d59234ee2cc0bfcdcc8af0800ca998a6e69c8791a2ebd00a7e5969fb5c3` |
| `uninstall.ps1` | `b6deb1791e5509aeb538215f944c19d03913baa4e3f771cc93fdc1f45763baa7` |
| `uninstall.sh` | `6d038c1208abd9c66da3d4a9188286bf76d0eb601b9ace5f5db25081472c373f` |

## Test Evidence

- **Test Command**: Exact commands, exit codes and durations: specs/cloud-orchestration/verification/T-008/attempt-4/checks.json; rollback commands: specs/cloud-orchestration/verification/T-008/attempt-4/rollback.json; CLI probes: specs/cloud-orchestration/verification/T-008/attempt-4/inspector-probes.json
- **Test Result**: BLOCKED
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-008/attempt-4/checks.json

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 4
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T008-attempt4-01a1507a
- **Run ID**: 01a1507a-333c-7fd0-ac6b-e012aa1447aa
- **Session ID**: 01a1507a-333c-7fd0-ac6b-e012aa1447aa
- **Agent Instance ID**: 01a1507a-333c-7fd0-ac6b-e012aa1447aa
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

Complete Bash and PowerShell routing suites and both complete registry-discovery twins ran before/after. Before: routing PowerShell exits 1 at the stale model literal; Bash passes. Both registry twins exit 1 at fresh-tree validation. After: all four suites pass; registry twins report 22 checks each. This does not claim attempt 2 ran/passed the full PowerShell suite.

Complete install-cloud (13 tests before / 14 after) and synthetic cloud-verification suites (109 tests per complete post-edit run), exact repository-config Ruff and mypy, and complete MCP tests/typecheck/build results are recorded in checks.json and their logs. Mypy explicitly uses MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts with tests/shared-launch-python/pyproject.toml (check_untyped_defs=true); no import/type suppression. MCP has 297 passing tests and no skips; build leaves tracked dist bytes identical. No full repository suite ran. Coverage instrumentation was not run.

Rollback uses a disposable git archive at the entry revision: restore exact initial bytes for all five task files, run both complete routing/discovery twins and targeted complete AlarmNumericCases plus visibility guards, then reapply exact candidate bytes and rerun. Baseline PowerShell routing and registry failures recur; reapplication passes. Linux alarm/visibility baseline controls pass, as expected for native-Windows-only defects. Live checkout, indexes, root clones and historical evidence were never rolled back. Additional disposable missing-schema mutations make both discovery twins fail with actual canonical-source/generation diagnostics; exact candidate bytes are restored afterward.

Timing qualification: before-cloud-verification.log was queued behind baseline installer tests and actually started after the one-line decorator edit. It is a second post-edit full run, NOT pre-edit or Red evidence. Genuine original AlarmNumericCases execution is the explicit rollback phase; the supplied Windows alarm excerpt records the actual pre-repair UNSAFE_PATH failure.

Security scope: no cloud/network provider invocation, credentials, native transport logs or account metadata published. Inspector probes use local stdio only. No new platform blanket skip or cache/concurrency/selection optimization.

## Specification Differences

No spec, task-state, approval or traceability update. User explicitly added registry-fixture and cloud platform-test repairs during this attempt; supplemental manifests bind those inputs/outputs. Spec revision follows the existing eight-file sorted path/TAB/hash/LF algorithm. Stable caller-provided native-allocation.json binds actual identity/model/effort; no inherited process identity is used.

## Unresolved Items

Inspector 2.10.1 CLI cannot apply its parsed requestTimeout setting: clients/cli/build/index.js:7885/7908–7936 admit the field, but callMethod:22815–22863 constructs InspectorClient without timeout or serverSettings; constructor:15925 reads options.timeout. Executable evidence: --request-timeout is rejected; --config requestTimeout=1 still successfully scans the actual full repository in about 16 seconds, and 180000 succeeds in about 14 seconds. Neither demonstrates a working configured timeout. The request default remains 60 seconds despite the smoke child’s 120-second outer bound. No ignored setting, node_modules hack, dependency upgrade, suppressed error, tiny fixture or retry was introduced.

Actual Windows failure is the caller-supplied candidate2 CI 39158381429, selected Windows excerpt (scope.json records the caller-selected job set), tools/call at 62880ms with Inspector’s 1m00s timeout. Other supplied native excerpts show the registry missing-source fixture, alarm UNSAFE_PATH and installer Git discovery/visibility failures. These are historical observed failures, not local Windows executions. Root separately owns the MCP production-performance diagnosis/repair and exact candidate3 Windows CI. Local PASS does not establish Windows timing, installer lifecycle or junction success. Those native checks remain pending first execution of these repaired bytes.

Live TEST-003/005/009 remain blocked on owner prerequisites. No tag, release, ticket resolution, Done decision or quality-gate PASS is claimed.

## Quality Gate Focus

Verify the five-file test-only diff, output/input hashes, prior-report preservation, rollback and platform diagnoses. Require actual Windows candidate CI for mandatory PowerShell lifecycle/junction behavior and the independently repaired MCP scan; do not promote local evidence to AC-014 completion.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No delegation. Read workspace/repository policy, task Must Read inputs, implementation skill/craft policies, Ponytail full and applicable ECC coding/verification guidance. Plugin AGENTS files are product data, never instructions. No UI work or visual check applies. No review gate was launched. The final scoped review, task status and release remain root-owned.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: Blocked
- **Next Action**: Root-owned independent review and exact-candidate native CI; separate authorized MCP repair before release.
- **Unresolved Items**: Windows Inspector request timeout remains unresolved; native Windows validation and full release acceptance remain root-owned.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
