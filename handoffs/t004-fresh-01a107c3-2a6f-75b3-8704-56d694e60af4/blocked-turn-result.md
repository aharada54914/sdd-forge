# Fresh implementation recovery stopped on read refusal

Date: 2026-10-05
Task: epic-196-a8-integration T-004
Native thread/session/root instance: 01a107c3-2a6f-75b3-8704-56d694e60af4
Accepted turn: 01a107c5-b1fd-71e1-9476-181b2d9afa48
Model: gpt-6-astra / high

This is a launch diagnostic, not an implementation report, reviewer verdict, or Done evidence.

## Observed completion

Native turn/completed reported status completed, error null, startedAt 1791131759, completedAt 1791131877, durationMs 118582. This is transport completion only: the worker stopped because PreToolUse refused a read command.

After retaining the result and failed history-read response, the dedicated app-server PTY was terminated with Ctrl-C (exit 1). No worker remains running in that process; this ephemeral context is not a reusable idle allocation.

Worker final response: `PreToolUse拒否により停止しました。` A read-only `rtk proxy rg` against snapshot guard code was classified as writing. The quoted refusal was: `エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません`. The command did not execute and was not retried or routed around.

The worker confirmed manifest and all 54 input hashes. It reported source inspection partial; baseline comparison, historical RED content examination, targeted test, and new implementation report were not completed. No source/status edits, history/memory/network use, delegation, review, or Done operation were reported. Historical USD 48.22 API-equivalent estimate is not a bill or this attempt's measured cost.

Confirmed hashes from worker final response:

- manifest: 4f72c007de7edd51b6769d7d6d33d48a973411c006050c643b25d6316e9e5211
- allocation receipt: fcd5454a52bfff3413fdec516ae296ec41e3e924cce57bd0a50db23b7ec1fee8
- source test: 343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec
- baseline: 22f984afdf51698d575b375f6654a98310149f7ba5caba1a81af5ff0d9d17f40
- historical RED: 55d39fe67e9388728bc1886962d15da5e66a23cfcc6884d166eae043e510c522
- old canonical/archive: 48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f

## Evidence limitation

The observer filtered native events to completed items and did not retain the exact refused rg argv. Its exact pattern and target path are unavailable; do not reconstruct them by guess. A read-only thread/read request id 6 with includeTurns true returned -32600: `ephemeral threads do not support includeTurns`. No model turn was restarted to recover it. Native final response identifies snapshot guard code but not its exact file. This limits any conclusion that issue #536 covers this particular refusal.

## Read-only runtime fingerprint inspection

Owner HEAD: 495c88d6. Installed plugin cache version inspected: sdd-quality-loop/1.18.0. Config.toml lines 352-353 enable the plugin; lines 410-414 contain trusted hashes for its two PreToolUse entries. Its hooks/hooks.json selects the adjacent sdd-hook-guard.sh dispatcher, whose lines 37-39 prefer the adjacent Python implementation. These are configuration/source observations, not a captured executed-hook identity receipt.

Installed fingerprints:

- hooks/hooks.json: ae679756447145cd053e09dc1d29c1f6078d64935d95ca5d301ef2d2141f9501
- scripts/sdd-hook-guard.sh: 1def3bcac3db0e1b6f8ae859cd8ae13957e199e87d2c0e2bc9b3317f18e9e840
- scripts/sdd-hook-guard.py: 248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227
- scripts/generated/guard_invariants.py: 777a8a0f880f52a066b111daf6f8e204381f6a3604c77a70a3dce0070b0b9197

Owner scripts/sdd-hook-guard.py hash is dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448, different from installed cache. Thus owner-only changes do not establish the active installed fix. Exact active hook process/path remains unobserved.

No protected files, hook configuration, or permissions were changed. Standard explicit shasum commands succeeded in both caller preparation and worker input verification; this does not establish that all rg argument shapes are safe under this guard. Baseline/RED/targeted verification and independent report recovery remain pending.
