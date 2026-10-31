# A7 T-004 separate-exception evaluation and F2 collection — 2026-10-14

Run ID: a7-t004-exception-evaluation-20261014
Task Attempt Count: 3

This is the coordinator's non-frozen summary of independent Codex findings,
subsequent bounded correction and new response collection. It is not a formal
quality-gate report, ledger entry, task-state change, or replacement for any
historical report. Product-hook actual execution was not required under the
parent-relayed user exception; this means NOT RUN, not HOOK_ACTIVE/PASS.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`, detached and already dirty.
No commit, push, reservation, frozen-file edit, corpus overwrite or shared
workflow/ledger edit was performed.

Read-only GitHub refresh (`rtk proxy gh pr view 512 --repo aharada54914/sdd-forge
--json state,headRefName,headRefOid,baseRefName,mergeStateStatus,isDraft,url`):
PR512 is OPEN, draft, BEHIND main; remote branch `codex/a7-issue195-closeout`
head is `d64cffcb22b114779202847be33e41700c4ba11f`, different from this owning
checkout. These local dirty-byte results are not remote-current-HEAD CI proof.

## Independent assessment of the original current inputs

Fresh-context `fresh_t004_exception_review` received the separate input
manifest `a7-t004-independent-exception-inputs-20261014.json` and its two
requested-input supplements. It verified all 56 admitted hashes and returned
NEEDS_WORK, rather than stopping merely for a legacy launch prerequisite.
The manifests remain unchanged as historical evaluation inputs.

| T-004 Done When | Independent finding |
| --- | --- |
| F1/F2 structural assertions | NEEDS_WORK: bare Status/Approval were omitted by both field extractors; F2 lacks both fields but had passed |
| Three-digit REQ/AC grammar | PASS based on admitted code/evidence; not independently rerun |
| F4 dependency behavior | PASS for current active assertion; old SKIP is not required after activation; Git receipt not reverified |
| F3/F5/F6 behavior | PASS for F3 activation and governed F5/F6 SKIPs; not behavioral F5/F6 execution |
| Offline suite and parser hard failure | NEEDS_WORK: malformed YAML value `title: [unterminated` accepted by both canonicalizers |
| TDD / independent gate | NEEDS_WORK: historical RED correction valid (113/3, not withdrawn 115/1); newer suites missed both defects; no formal gate PASS |
| Aggregate registration | PASS from admitted registration checks; whole aggregate not executed |
| Report / mapping / gate | PARTIAL: addendum mapping and authorized amendment exist; no new formal quality gate |

The evaluator directly reproduced malformed flow YAML as exit 0, empty stderr,
and a frontmatter string value `[unterminated` in both runtimes. Sources:
`tests/lib/markdown-ast-canonicalizer.sh:39`, `.ps1:41`;
`design.md:963-974` requires malformed YAML failure and YAML-map parsing.

## Bounded correction completed, overall task still NEEDS_WORK

`a7-t004-status-fields-repair-20261014.md` records preflight, RED, the two-line
optional-prefix correction, current regression results, and a second
fresh-context independent scoped PASS. The untouched historical F2 now
correctly produces Bash 76/1 and PowerShell 83/1; the old 77/0 and 84/0 were
pre-correction results, not current GREEN. Isolated positive controls pass,
and both bare-field deletions are killed in both runtimes.

No YAML implementation was changed. Frozen `security-spec.md:143-153`
prohibits new external packages and additional runtimes beyond jq, Bash,
PowerShell. The existing `canonicalize-sdd-yaml.py:2-40` is explicitly a
restricted YAML subset and needs Python; adopting it unchanged would neither
satisfy these runtime constraints nor establish general YAML-map support.
The next parser repair must honor those constraints, or obtain an explicit
scoped design/dependency amendment; adding a parser or narrowing accepted
YAML silently is not authorized by the independent-evaluation exception.

## New F2 live response collected separately, not admitted

Fresh-context Codex agent `fresh_f2_response` read the current lite skill and
three templates, not the old corpus or evaluator findings. Input described
F2 (Context absent, AGENTS lite marker, no track flag, disabled-legacy) and
a synthetic in-memory team coffee order prototype. The agent was explicitly
told to generate a new JSON response, not execute installed-product hooks
or modify any file. This proves a fresh model response was obtained, not
end-to-end skill execution, a physically instantiated fixture, or AC-031
completion. Exact runtime model ID was unavailable and was not invented.

The model's raw response is retained in
`verification/T-004/f2-live-codex-response-20261014-attempt1.json` under this
feature. It used `schema_version` rather than required `schema`; the existing
Bash live-refresh dry-run rejected it: exit 1, `FAIL: invalid corpus envelope`.
The same collector returned a second full response correcting only that
envelope key; all artifact content was identical. It is retained as
`f2-live-codex-response-20261014-attempt2.json` and was not altered to pass tests.

Commands from owner, each through `rtk proxy` with a non-login shell:

```text
bash tests/structural-compatibility-live-refresh.tests.sh --state F2 --fixture specs/epic-195-a7-compatibility/verification/T-004/f2-live-codex-response-20261014-attempt2.json --dry-run
pwsh -NoProfile -File tests/structural-compatibility-live-refresh.tests.ps1 -State F2 -Fixture specs/epic-195-a7-compatibility/verification/T-004/f2-live-codex-response-20261014-attempt2.json -DryRun
```

Both exited 1. Bash: `FAIL: structural mismatch: design.md`.
PowerShell: `structural mismatch: requirements.md` (different iteration order).
The real generated headings instantiate `team-coffee-orders` and a task name;
the unchanged templates contain literal `<feature>` and `<タスク名>`, and the
current refresh compares canonical heading text exactly. This is a concrete
new-evidence admission limitation, not a legacy reviewer identity blocker.
No fabricated placeholder substitution or corpus overwrite was performed.

The existing refresh has no alternate-output parameter. Its non-dry path
always atomically replaces `tests/fixtures/structural-fixture-corpus/f2-lite.json`
(`tests/structural-compatibility-live-refresh.tests.sh:26,67-70`); it was NOT RUN.
T-012 is the sole sanctioned refresh owner (`tasks.md:1693-1721,1791-1818`).
Therefore a direct T-004 fixture edit or arbitrary new active-corpus selector
is not a sanctioned solution. Resolve the generated-heading comparison
contract first, then use T-012's sanctioned, independently evaluated refresh
with explicitly preserved old evidence; no current new F2 response is admitted.

## Evidence hashes and next authoritative work

| Artifact | SHA-256 |
| --- | --- |
| original F2, unchanged | `4fe2eff3b2842f5e1228db5f06f99188756e8800608620ef0dfb662fd29b7b88` |
| new F2 attempt 1 | `6a6625bf6be60613f97a72f04028cfca26b79ca8ca9dfa4cb27df7abbba1c8fb` |
| new F2 attempt 2 | `a887a1666d09226618070998170663bc843db174c775b5d201e2cc6e58f94126` |
| lite skill | `52d428aad3af3eabf65a6ba1380aa1cab3b5a8dc4b029a3c056557041ff81cd6` |
| requirements-lite template | `86b212b7a36652f7a617c21dfd80193d59a58babdf3a01a931c0ca626affb904` |
| design-lite template | `21e8827478ba6090d98639f9a899102705c2855981b95598561214a408b9e823` |
| tasks-lite template | `99ecea5271f55dde5764d12be63d1aa54288868d28cb15b9ec029d55e9619e31` |
| live-refresh Bash | `083e28aeb9c966468890d149b4066efca6336dea7599ca4424a085acb3e4aa89` |
| live-refresh PowerShell | `61a093e4ef82d9341df631289160e21f13d3890e639e7d6c111f9cc7ce14531b` |
| new status mutation driver | `f44491c1da29fd2ef83ca24d5cd7299a80777bd5a874f063dec134efa85820f1` |

T-004 remains Approved / In Progress (`tasks.md:555-561`). Its next direct
work is compliant YAML parsing plus lawful F2 input resolution, not setting
Done. T-012 remains Approved / Implementation Complete but depends on T-004
and owns refresh. T-011's cumulative CI cannot be promoted as complete from
this evidence. T-013 is already Approved / Planned (not stale Draft); its
T-004 relation is append-order-only, not functional. A parent may assess its
independent entry separately without conflating it with T-004 acceptance.

After the extractor fix, 18/20 rows of the preserved old declaration still
match; the two suite rows are intentionally stale. Any further evaluation
must pin current suite bytes in a NEW separate input artifact. The original
20-hash validation and 56-hash independent review describe the earlier
snapshot only. Formal old ledgers, verdicts and frozen Outputs remain intact.
