# PR integration dossier — 2026-09-05

Read-only findings, not merge authorization. Baseline main: `3749a252af31c504387c4cb8855342261c41dbbd`. Recheck all heads, ownership and gates immediately before consuming this dossier.

## Execution addendum — 2026-09-05, after owner handoff

This dated section supersedes historical state/authorization statements below. User transferred repository coordination, then explicitly approved a PR #386-only administrator bypass of the one-review requirement. PR #386 merged at 02:10:25 UTC as `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`; local main was fast-forwarded with existing dirty files preserved. Protection rules and branches were not changed. See EXECUTION_HANDOFF.md and the PR audit comment for exact authority.

PR #389 now has an isolated local integration candidate `c5d3230714dd064b3e5a48ac79fb179f45ae3a76` (tree `e677808be1a9df76573978a853626c86c180b996`), containing both the remote #389 head and updated main as ancestors. It has not yet been pushed. The remote PR being BEHIND does not imply this local candidate is behind. All three MCP package installs/audits/typechecks/rebuild parity checks passed. Package tests passed 148 + 51 + 243; subsequently all four formerly hanging deep-verify parity cases also passed with system Bash selected through scoped PATH. A fresh complete sdd-forge-mcp run is being collected.

WFI-058 tests passed 3/3 in each SH/PS lane and WFI-059 passed 4/4 in each lane. PowerShell prepare-panelist: 179/179; repository validation passed with 10 targets and 0 mirror drift. Bash prepare-panelist returned 183 passed and 3 failed; each failed message assertion exhibits an echo/grep pipe write error despite expected text being present. Baseline comparison and exact-tree independent review remain pending, so no final combined PASS or merge readiness is claimed.

## Wave 1: dependency repair, then WFI-058/059

PR #386 head: `1bd368aa3584a6a435e9b7ad4849dfb7019e3ec7`.
The current GitHub response still reports OPEN, REVIEW_REQUIRED; all named returned check runs are successful. The unnamed rollup entry is not treated as a successful check. Head and base match PR386_VERIFICATION.md, so its 148 ci-mcp, 51 local-env-mcp, and 243 sdd-forge-mcp passing tests are reused, with the explicitly documented baseline parity non-termination exception. No blanket full-suite-pass claim.

PR #389 head: `cfa81def37a59b7b288f9092f603c801fdea7b1b`.
CI run [33889193748](https://github.com/aharada54914/sdd-forge/actions/runs/33889193748) has these failing jobs:

| Job | Job ID | Failed step |
|---|---|---|
| ci-mcp-tests (ubuntu-latest) | 101076651974 | Audit production dependencies |
| mcp-tests (ubuntu-latest) | 101076652005 | Audit production dependencies |
| local-env-mcp-tests (ubuntu-latest) | 101076652127 | Audit production dependencies |
| required-checks | 101084092993 | Check all required tests passed |

Each package log contains `npm audit --omit=dev --audit-level=high`, fast-uri 3.0.0–3.1.5 (high), qs 2.2.5–6.15.3 (moderate), 2 vulnerabilities, and exit 1. The fast-uri advisory identifiers are GHSA-5jgf-p345-68v8, GHSA-f65p-4m7j-42xc, GHSA-fph4-wmhf-6fwf and GHSA-jqff-g426-hqxp; qs identifiers are GHSA-x5fp-wj9c-mxmx and GHSA-4mjr-xmp4-gh2g. These are the known dependency findings targeted by #386, not evidence of a new WFI implementation defect.

Proof of inheritance: `git diff --stat 3749a252af31c504387c4cb8855342261c41dbbd cfa81def37a59b7b288f9092f603c801fdea7b1b -- mcp` is empty. No MCP path differs. Job metadata and individual failed-step log excerpts were read; large full job output was truncated, so this is not a complete retained log archive.

Recommended order: obtain owner handoff and applicable governance/merge approvals for #386; integrate its exact verified changes; update/revalidate #389 through its owner on that new base; rerun package audits and CI. Combined-tree tests have NOT run and cannot be inferred from separate heads. Both branches have occupied worktrees. No duplicate fix, owner-branch update or merge was performed.

## Wave 2: #371 versus #381/#382

| Item | Exact head | State/relation |
|---|---|---|
| #371 | 9e39c396f4ca8f9abe3c9aabb090868ada17b53f | Open; adversarial enhancements #345–#350 |
| #381 | 92528375705085967c19d75deb5f12e0fa66c276 | Draft; broader adversarial plus CI/WFI work |
| #382 | eba07a297117ec32104fcbdf90c3515a63e2163f | Merged into #381 branch, NOT main |

GitHub records #382's base as `codex/conduct-critical-review-and-improve-plugin` and merge commit `92528375705085967c19d75deb5f12e0fa66c276`. Both #382 and #381 heads currently have the exact tree `62e66812b3ee1c247a7883f5ef8285526e4fe3de`; `git diff --stat <382-head> <381-head>` is empty. This establishes snapshot tree equality, not identical history or main inclusion.

Shared-file presence does NOT establish equivalence with #371. Direct schema diff from #371 to #381 shows:

- Evaluation schema adds branch nonempty/path constraints, requires at least two reviewer launches, and separates Phase-R ran/not-ran evidence fields.
- Report schema requires full 40-character commit IDs instead of 7–40, and a nonempty skill version.
- Cross-critique schema constrains available/unavailable verdict cardinality, evidence-versus-concern citations, and nonempty unique REQ/AC/T identifier arrays.

Therefore preserve both PRs until an owner-approved consolidation chooses a survivor and maps every requirement to implementation/tests. #381's stricter schemas need fixture compatibility and producer/consumer checks; do not cherry-pick only schemas without their corresponding tests/skill contracts. #382's branch is not a main-integrated cleanup candidate merely because GitHub says MERGED.

## Required decision before implementation/integration

Nearest boundary: #386 exact-head owner handoff, identification/acceptance of its applicable SDD evidence (no matching task ID established in this audit), GitHub review approval, and explicit merge authority. The requested comprehensive work does not fabricate these records. Issue #298 is a separate investigation candidate, not an Approved task. Keep occupied Epic chains and unsubmitted branches unchanged.

## Execution supersession — 2026-09-05, after owner handoff

The earlier snapshot and recommended next steps above are historical, not the current execution state. PR #386 was merged at `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa` after exact-head successful checks, independent review, and explicit user approval of that PR's administrator review exception only. Protection rules were unchanged. Local main was fast-forwarded with its dirty-file set preserved.

PR #389 is now pushed at `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`, tree `e677808be1a9df76573978a853626c86c180b996`, with both main and its original head as ancestors. Full combined MCP tests are 446 passed (including all parity tests); audits/typechecks/build parity pass. CI run `33938647223` is pending. Astra review is NEEDS_WORK for merge: one Major and two Minor findings; its PASS authorized only the ordinary fast-forward CI push. Staged remediation is in preparation, with no live protected-file application or PR #389 merge performed. See PR389_VERIFICATION.md and PR389_REMEDIATION_PLAN.md. Issue #298 and Wave 2 remain incomplete; all branches remain preserved.
