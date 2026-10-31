# Installed / owner / snapshot comparison and bounded T-004 verification

Date: 2026-10-05
Status: caller diagnostic only; NOT formal fresh implementation report, quality gate, activation proof, or Done.

The refusal's exact argv and raw checker event were not retained. No denied command was reconstructed or retried. No new native allocation or role turn occurred during this follow-up. Future native execution must retain complete tool-command/result events, not only summary/final events; account/authentication notifications must remain excluded or redacted separately.

## Compared identities

| Runtime | Installed cache 1.18.0 | A8 owner = immutable snapshot | #536 working tree |
|---|---|---|---|
| Python | 248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227 | dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448 | 7392cccf47ece13bd6af919bcd319926f92911b11a41a6e7dd243eb41f68c77a |
| JavaScript | 05a6cf568b3ef34da443103650b99bc7155d98cc017687ea1728646d9c9b3637 | fa3cc8cad5661f8fbc6ee313fd8982762392adb3f08dd2ed13c736f985ccab0f | c8e2312ab73973793b2daef1bdea838ead497af023e031260ebf2c17a5794c70 |
| PowerShell | f50a52848f4141b85ddd7d0aa72f83a8867fb4619f75df1a403b0ff03057089d | 433888e8afae4c414ea4dda8501ae98cb00b2ae330b3223d3d07b4d86f93aa6c | 3f2a3a0bb7a431c9697513b15b460f670ad43b0102231d44ee80cfe1e8569806 |

Installed root: /Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/

#536 root: /private/tmp/sdd-guard-main.3JEj4I/repo/plugins/sdd-quality-loop/scripts/

Owner root: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge/plugins/sdd-quality-loop/scripts/

Snapshot: ../snapshot/plugins/sdd-quality-loop/scripts/ relative to this directory.

SHA-256 came from standard explicit `rtk proxy shasum -a 256 --` commands. `rtk proxy diff -u` compared installed vs #536 all three implementations, plus owner vs installed Python. The installed-vs-#536 differences are native Copilot input normalization (and the PowerShell top-level JSON object-prefix check), not the role-read helper or basename exclusion. Installed Python has the role proxy helper and both basename exclusions; owner/snapshot Python does not. Therefore differing owner and installed hashes do NOT demonstrate failed installation. The old candidate notes stating not installed are historical, not a current fingerprint determination. These are working-tree comparisons, not an assertion that every #536 uncommitted change belongs to its committed PR head.

## Refusal mechanism boundary

Installed `sdd-hook-guard.py:1046` contains the protected-gate refusal wording quoted by the worker. Its protected-path shell decision at lines 1709-1717 remains separate from `_role_proxy_rg_read_only` at lines 1720-1754. The helper requires explicit `--no-config` (1733), restricted ASCII pattern grammar (1743-1747), restricted path operands (1752), and at least one `.codex/agents/*.toml` operand (1754). It is not a general protected-guard-source read allowance. The owner-vs-installed diff changes role handling only in this area, not the protected-gate shell decision.

Existing #536 evidence read:

- reports/verification/pr536-integration-20261005.md: committed PR scope versus dirty worktree and installed-activation limitations.
- reports/verification/proxy-rg-safe-contract-result-20261004.md: explicit no-config safe-contract matrix 114/114; historical omitted-flag matrix retains three failures; no production activation claim.
- specs/guard-role-read-regression/verification/a9-basename-20261004/results.md and unicode-followup.md: basename two-predicate repair, historical broader command gaps, and separate Unicode candidate boundary.

These sources explain why no-config is a security condition (configuration can enable preprocessing), and why Unicode candidate GREEN is not installed proof. They do not prove that the lost A8 argv omitted that option or contained Unicode/write-like vocabulary. Exact cause, coverage by #536, and executed runtime identity remain unconfirmed. Do not claim that installing owner bytes or broadening Node/read permissions is a remedy. No such changes were made.

## Independent, nonformal A8 checks completed

1. Baseline diff: `rtk proxy diff -u handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/baseline-c886b790.ps1 tests/cli-hook-enforcement.ps1` returned exit 1 because of the expected single additive hunk: 34 inserted lines after original line 92, with no removed original lines. Baseline remains the 100-line c886b790 source, not the task prose's 101-line claim.
2. Historical RED and prior GREEN were read directly. RED contains 14 passed / 3 failed, with each new synthetic TEST-012 intentionally receiving a permissive result; GREEN contains 17 passed / 0 failed. This is historical evidence inspection, not a new RED run.
3. Current targeted test executed using `rtk proxy env TMPDIR=<this directory> pwsh -NoProfile -File tests/cli-hook-enforcement.ps1`, login false. Exit 0; 17 passed / 0 failed; TEST-017 reports all 13 pre-existing checks passing. Complete combined output is in targeted-regression.log. The suite's temporary fixture directory was created below this task-local directory and removed by its own finally block. No execution-policy or guard permission change was requested.
4. Post-run hashes remain unchanged: source 343aa50f12d790619dc5d636831d6f1c7d1559745b9ca289ad67fb28564a3bec; canonical report 48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f; tasks 8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66.

This targeted test exercises direct guard contracts/synthetic fixtures on macOS. It does not prove native hook dispatch, all three OSes, new-head CI, fresh implementation provenance, independent review, or Done. The stopped fresh worker has not authored its recovery report. Canonical report/history/ledger/frozen artifacts/approval/status are preserved. No #536 worktree was modified.

## Next launch conditions

Keep the current refusal recorded as incomplete, not PASS. Before another native attempt, establish a safe input-reading plan consistent with existing guard contracts, avoid arbitrary inline interpreter reads, and retain exact native requests/tool events/results. Explicit no-config belongs in any supported role proxy-rg instruction, but must not be presented as proof that the unknown protected-source refusal is solved. Do not replay the refused command using alternate syntax. If another actual refusal occurs, preserve its full command and raw checker output, stop that operation, and classify the specific grammar against the installed fingerprint. Any new guard semantics require their own protected-change/contract workflow, not an A8 T-004 source change.
