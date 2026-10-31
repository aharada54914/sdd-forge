# A8 integration readback — 2026-10-14

Separate development evidence; formal_sdd_gate: false. No task, formal ledger,
historical verdict, human-copy asset, real signer or nonce record was changed.
Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge.
HEAD: 495c88d67af44530687ecea3ce9fb0a90a336539 (dirty historical work preserved).

## Observed local integration commands

All commands used rtk proxy with login=false.

- `bash tests/cross-runtime-handoff.tests.sh`: exit 0; native CLI contract and
  eight missing-token mutations; Bash model-guard empty/case-variant negatives;
  pseudo-CLI mutation/stdout/hash/nonces; AC-006 all six lifecycle values.
- `pwsh -NoProfile -File tests/cross-runtime-handoff.tests.ps1`: exit 0; same
  branches through PowerShell, including its model guard. Both explicitly state
  live CLI E2E was NOT run. These results are fixtures, not native attestations.
- `bash plugins/sdd-quality-loop/scripts/check-traceability.sh
  specs/epic-196-a8-integration/traceability.json . require-evidence`: exit 1,
  `check-traceability: file not found: specs/epic-196-a8-integration/traceability.json`.
- `git diff --check`: exit 0.
- T-005 validator and fixture hashes still match the prior 281/0 Bash and 281/0
  PowerShell regression inputs in T-005-v2-20261014.md. Fresh evaluator launched
  using quality-inputs.json; its result will be retained separately.

## Integration inventory and base

PR 513 head ac97422d6e347f4899a32d16fa9ceddc51b10416 is currently an OPEN,
CONFLICTING guard/CLI patch, not this complete A8 implementation. Its file list
contains guard JS/Python/PowerShell, corresponding legacy human-copy mirrors,
cross-runtime handoff/CLI and cross-model tests, and older guard evidence.
Do not overwrite its patch with the owner's complete dirty tree.

Small current-change units for integration (compare against the chosen final
base before selecting files):

1. Target-aware installation: check-installed-plugin-drift.{py,sh,ps1},
   tests/fixtures/installed-plugin-drift/fixture_driver.py,
   tests/install-uninstall-matrix.tests.{sh,ps1}. Default All remains compatible.
2. v2 proof: validate-live-host-proof.py and
   tests/fixtures/live-host-proof/run_cases.py, with existing validator wrappers,
   tests/validate-live-host-proof.tests.{sh,ps1}, tests/suite-inventory.posix and
   tests/run-all.ps1 registrations included only if absent on integration base.
3. Governing amended A8 requirements/design/acceptance/tasks and associated
   layer/traceability inputs must travel as reviewed contract revisions, not
   be represented by old Passed headers. quality-inputs.json pins current subset;
   design/task round-2 manifests pin the complete reviewed sets.
4. This directory's original independent results, input manifests and bounded
   repair evidence, plus reports/implementation/epic-196-a8-integration/
   T-005-v2-20261014.md, are separate provenance. They are not formal ledger rows.
5. Existing non-protected CI draft:
   specs/epic-196-a8-integration/verification/T-005/
   test-yml-live-host-proof-candidate.yml. It adds Bash except Windows and
   PowerShell all-platform steps. It explicitly is NOT apply-ready human-copy.
   T-005 tasks.md:1081-1084 still requires staged workflow+MANIFEST; existing
   caller prohibition prevents silently fulfilling that condition here.

Do NOT include unrelated dirty check-workflow-state, validate-review-context-set,
reviewer/precheck/quality skill, identity-ledger or old repair candidate files
merely because they coexist in the owner checkout. Resolve their own dependencies
against main independently; no blanket owner-tree transplant.

## Current-main source check

GitHub PR query initially reported base 3a1afcab243fcebb769dc4314599999af4545050;
the immediately following main API query resolved
bee54eb248b381f89d6badeb7d92a43359460ab9. This record pins the latter, not moving
main. No fetch, reset, merge, commit or publication was performed.

API recursive tree gave these actual consumer blobs at that main commit:

| Consumer | Current main blob |
| --- | --- |
| bootstrap | ea0ad62ff37fe0774b8660634a93ef713dfe684c |
| interviewer | 0cf6d77256e9de4f2902fe3c9ddb356096ab81cd |
| lite-gate | ab5f47333788c41074bcfdef33ed88d8b7a1d26b |
| lite-spec | 00a56a3dcb70ea35bc3206193abd8ef7d5ebe0d3 |
| ship | 09600f055e76a5796dfa93e4a8f5d7708f10415f |

All differ from AC-016's accepted c0aaf3a639f4cb4798b16acd115f0b05db44493f
map. At the accepted commit, git-show plus rg for handshake/hook.activation/
check-hook/HOOK_ACTIVE found no match in any of the five consumer files.
At pinned main, raw API source has explicit challenge → own real tool call →
verify-response wiring: bootstrap lines108–121, interviewer197–210,
lite-gate39–51, lite-spec38–58, ship104–125. Ship and lite-spec expressly allow
DISABLED_LEGACY when Project Context is physically absent; the other three
wiring blocks still describe non-HOOK_ACTIVE stop. This is source observation,
not a new assessment that modifies those consumers or their upstream contract.

Consequently v2 fixture acceptance of the old pinned source map does not prove
current-main consumer invocation. T-008 requires an explicit decision on the
accepted source revision/map before genuine current-main native records can be
claimed. No accepted map was silently advanced. T-005 code accepts the map
provided by its contract; the fixture pin is not a hardcoded production pin.

At pinned main, test.yml uses complete POSIX inventory fallback and checkout
fetch-depth:0. No explicit live-host-proof step exists; installed-drift PowerShell
step is present at1563–1565. Rebase CI draft into the final workflow, avoiding
duplicate Bash invocation when inventory fallback already covers it; retain a
native Windows PowerShell assertion. CI for an old PR head proves neither local
v2 bytes nor the eventual integrated head.

## Concrete completion boundaries

T-005 task remains Planned; formal quality-gate rejects non-Implementation
Complete tasks. The authorized independent exception does not rewrite lifecycle.
Missing traceability.json with actual evidence, prohibited staged CI/MANIFEST
application, and exact-final-head platform CI remain specific unmet T-005
conditions. T-008 additionally needs authorized native sessions, five actual v2
records with all five consumers, and genuine independent signatures; old v1
records and synthetic fixture keys cannot satisfy them. The obsolete explicit
Copilot-model blocker was not reused as a current observation.
