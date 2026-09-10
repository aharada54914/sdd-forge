# Parallel dependency and WFI verification — 2026-09-05

## Disposition

Verification work advanced independently of PR389. This is an execution dossier, not an SDD quality-gate report, task approval, ownership release, or merge authorization.

Main remains `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`. No product source edits, commits, pushes, merges, branch deletion, owner-worktree modification, protected-file application, or protection-rule changes occurred in this wave. Ordinary builds changed only scratch generated output where stated. Existing dirty main files are preserved.

## Exact-head results

| PR | Head | Latest observed workflow run | Local package suite | Bundle parity |
|---|---|---|---|---|
| #374 | `62b42b655782e40144bead7e242a6295b6d0d697` | 33938436778 success | ci-mcp: 148/148 | PASS |
| #375 | `8920c5970fd453261e4f74f820ada7310ae2e985` | 33938430630 success | local-env-mcp: 51/51 | PASS |
| #377 | `921fe4a0aabd255f20fbc1dc686411d3faff221d` | 33938428549 success | local-env-mcp: 51/51 | PASS |
| #378 | `6f7bda654c2f810d81d8a7fbd92b24f6e0393592` | 33938428893 success | sdd-forge-mcp: 247/247 | PASS |
| #379 | `7712cf754c974ba1de23799b570e853d0f326d0b` | 33938430906 success | sdd-forge-mcp: 247/247 | PASS |
| #376 | `614e5afa4fc7c90397880d54363360db178657bb` | 33938419764 failure | sdd-forge-mcp: 247/247 | FAIL: stale tracked bundle |
| #373 | `c03f4dfea7372bf8c162e7ecdeabe80acd122b87` | 33938423408 failure | Not rerun locally in this wave | Not rechecked |

The five green-workflow dependency heads passed 744 package tests in total. Including #376, six separate-head executions passed 991 tests; this is not a combined-tree suite or 991 distinct test definitions. No file exclusions, cancellations, or skips are included in those successful totals. Primary directly executed and observed each final package-suite result.

For the first six rows: clean install used `npm ci --ignore-scripts`; audit at low severity threshold reported zero vulnerabilities; typecheck succeeded. Each package built twice with matching hashes. This checks the installed dependency graph, not a source-level audit of every upstream dependency. Hosted run results are snapshots, not permission to omit a fresh required-check/head/base check immediately before any merge.

Primary independently inspected the package/lock deltas for #374/#375/#377/#378/#379. Each changes only its package manifest and lockfile. Inspector changes 2.3.0 to 2.4.0 with proper-lockfile/graceful-fs/retry additions; type updates change 26.2.0 to 26.4.1. Lock metadata removals do not change those other resolved package versions. No source or committed bundle changes are present in these five PRs. Local smoke tests exercise Inspector stdio startup and tool calls.

## Reproduction environment and retained scratch

Primary verification command prefix:

```text
rtk proxy env PATH=/Users/jrmag/.nvm/versions/node/v24.13.0/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

Append `npm audit --audit-level=low`, `npm run typecheck`, `npm test`, or `npm run build` with explicit package cwd. Node is 24.13.0; the scoped Bash is macOS 3.2.57. No global PATH/configuration was changed.

- #374/#376/#378/#379 roots: `/Users/jrmag/.local/share/sdd-dependency-verify.Ip4i4E/prNNN`; package cwd is `mcp/ci-mcp` for #374 and `mcp/sdd-forge-mcp` for the others.
- #375/#377 roots: `/Users/jrmag/.local/share/pr375-377-verify.sLgzkQ/prNNN`; package cwd is `mcp/local-env-mcp`.
- All are detached exact-head diagnostic worktrees. Do not treat them as implementation branches or delete occupied owner clones.

Repeated-build SHA-256:

| Package / heads | dist/index.js SHA-256 |
|---|---|
| ci-mcp #374 | `8bdc4d5581dcb6342770b3ee206df534a5f2c24bc72bad35f5a111ed5c5b10ba` |
| local-env-mcp #375/#377 | `0397bf3509c5cc7141222a146c7ec1aab7a18f083eb629d5618da5578f68aa29` |
| sdd-forge-mcp #378/#379 | `d985b884de9cea1894b32e23d486c22e1f70d3d5999e8403fe88719c4d6f9604` |
| sdd-forge-mcp #376 rebuilt scratch | `0fba99ddacc6c0b7ec49f4f7e511e52cbadf9d2cc71679fe5b7da240dcd97313` |

Primary checked `git diff --exit-code HEAD -- <package>/dist/index.js` and clean worktree status for all five green-workflow heads. The tester initially incorrectly reported changed bundles for #375/#377; those assertions are excluded and superseded by primary exact-head, hash, empty-diff and status measurements. Primary also repeated both 51-test suites, typechecks and audits after that inconsistency. Repeated-build equality for these two heads is delegated evidence; final tracked parity is direct primary evidence.

## #376 remaining repair

The package update changes js-yaml 5.3.0 to 5.4.1 but leaves the committed bundle unchanged. Primary inspected the entire generated diff: one file, 139 added / 30 removed lines, including js-yaml merge-work accounting, document/BOM boundaries, scalar-style logic and the 5.4.1 license footer. `git diff --check` passes. Rebuilding twice gives the same new hash above. This is a deterministic candidate repair, not an applied/approved product fix.

The initial delegated full suite was interrupted with SIGINT (reported exit 130); its 243-pass/one-cancelled statistics are not accepted as completed-suite evidence. The delegate gave inconsistent timing descriptions of that interruption, so the exact ordering is unestablished. A subsequent scoped-system-PATH run passed 247/247, followed by a separate primary 247/247 run with exit 0. This proves success in that environment, not a general root-cause proof for all earlier hangs. No tests were removed. The hosted bundle-parity failure remains unwaived.

Next product step requires the matching reviewed task/scope to regenerate only the committed bundle, independent exact-diff review, full package checks, hosted CI on the new head, and the normal merge boundary. Do not push the scratch generated file as though those gates had already passed.

## #373 Windows timing diagnosis

Run 33938423408, job 101230830670: cross-model PowerShell suite 62 passed / 2 failed, both TEST-004(c), GPT iterations 3 and 4. Iteration 3: parent elapsed 2658 ms, stub startup 689 ms, exit 1, no verdict. Iteration 4: parent elapsed 2925 ms, stub startup 1197 ms, exit 1, no verdict.

Control #377 run 33938428549, job 101230845683: 64 passed / 0 failed. Both jobs used Windows image `windows-2025-vs2026`, version `20260824.214.3`, provisioner `20260819.586`. Identical git blobs between the two heads:

- `tests/cross-model.tests.ps1`: `02173ebb277a93758cdd7553c170abd98752517c`
- `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1`: `1d5b7f82073f99e6a50d359bf3a1c132c17107d4`
- `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1`: `1f022cb5aace65c44a8175ac34a153e196123623`
- `.github/workflows/test.yml`: `fccc303c3164a354cf21836e038db36968ce3d73`

The harness at tests/cross-model.tests.ps1:595-636 passes on exit zero plus verdict existence, not on total elapsed <= 2000 ms. A control GPT iteration passed with 2533 ms total elapsed. Therefore total elapsed above 2000 ms alone is not a failed assertion or proof of a runner defect. The stub waits until deadline minus 800 ms, then still has serialization/output/process teardown work (same file:161-225). Runner deadline accounting is in run-panelist-gpt.ps1:242-267.

Conclusion: evidence supports a timing-sensitive failure, not a conclusive cause or failure waiver. Needed next evidence: Windows reproduction with actual stub completion/output and process-exit timestamps against the same absolute deadline. No tolerance increase, removed assertion, blind rerun-until-green or Windows coverage claim was made.

## WFI #363 / #364 preservation

Cheap read-only investigation found both branches still checked out in the owner clone:

- #363 head `8d35a13f2cf6993b0589250b7a89a241aef09c08`, `/Users/jrmag/Projects/active/sdd-forge-wt-wfi057`.
- #364 head `7d1ffc440d80c7a46cc001cc01adde087c5ec1b0`, `/Users/jrmag/Projects/active/sdd-forge-wt-wfi055fix`.

Both merge bases are `807a818d4b1f3dd15f342d9edb3021e334bc7707`. GitHub reports mergeable false, despite historical workflows succeeding (33086719562 / 33124754127). WFI-057's proposed file is absent from current main; WFI-055 adds evidence/rationale missing from the older main document. Neither is proven redundant. KEEP both; no conflict resolution, closure or deletion occurred. Their draft proposal state does not alone forbid merging documentation, but also does not authorize implementing their proposed product changes. Exact owner handoff and current-main conflict review remain unresolved.

## Governance and review boundary

### Subsequent owner authorization — 2026-09-05

After this verification wave, the owner explicitly extended the administrator approval-review exception to other issues' PRs in the consolidation program. This includes #374/#375/#377/#378/#379 and supersedes the historical narrow exception statement below. The exception is conditional on completed SDD gates and all mandatory CI success; it does not change protection rules, waive failures, bypass runtime hooks, establish missing task/gate evidence, or release occupied worktrees. Record the exact reviewed head when exercising it, and recheck base and required checks immediately before each merge.

Fresh remote reads following that grant show all five dependency heads and base unchanged, PRs open/mergeable, and their listed workflows successful. PR389 head 25304d3b842d76e5da152e659af0d678d537e026 has successful completed workflow 33960178745; local shell assertion failures remain unresolved. No merge occurred in this authorization update.

### Historical pre-grant snapshot

The GitHub reviews API returned an empty reviews array for each of #374/#375/#377/#378/#379. This is separate from local technical review. No new administrator-review exception was granted for those PRs; PR386 and conditional PR389 exceptions remain narrowly scoped.

Exact SDD task/gate coverage for these dependency updates is NOT ESTABLISHED. An explorer reported a hook denial during a task-approval search but could not retain the exact command and refusal text. Its approval-coverage conclusions are excluded. It was explicitly instructed not to retry via alternative searches/reads. This dossier does not assert that no matching task exists, nor infer one from adjacent completed tasks. No status marks were edited.

Primary review disposition: local technical checks of the five green-workflow dependency heads are satisfactory within the scope above; whole-program merge readiness is NOT established. Required next decisions/evidence are matching SDD task/gates and ownership coverage, then normal GitHub review approval (or a separately scoped, explicitly authorized exception). Recheck heads/base and all required checks at the point of merge, one PR at a time; shared lockfile PRs must be revalidated after earlier merges. Preserve the stale-bundle and timing failures as blockers for #376/#373.
