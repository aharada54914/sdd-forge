# A7 T-004 remaining parser contract reproduction — 2026-10-14

Run ID: a7-t004-yaml-contract-reproduction-20261014
Task Attempt Count: 3

This is separate diagnostic evidence, not a formal gate report, corpus refresh,
task transition, or new acceptance verdict. The previous status-field repair
and its independent scoped PASS remain recorded separately.

## Scope and checkout

- Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
- HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`, detached, pre-existing dirty
  checkout. Other contributors' changes were preserved.
- Existing task: T-004 Approved / In Progress, high risk. No production parser,
  frozen document, corpus, ledger, task status, reservation or Git ref changed.
- New output: diagnostic driver under the task's non-frozen verification folder.
  It invokes the actual canonicalizers against temporary files and removes only
  its own temporary directory. No new dependency was introduced.

## Executed result

From the owner checkout, `rtk proxy bash
specs/epic-195-a7-compatibility/verification/T-004/yaml-contract-probe-20261014.sh`
with `login=false` returned exit 1:

```text
bash flow exit=0
bash quote exit=0
bash colon exit=0
bash plain exit=0
bash quoted exit=0
bash equivalent-scalar DIFFERENT
powershell flow exit=0
powershell quote exit=0
powershell colon exit=0
powershell plain exit=0
powershell quoted exit=0
powershell equivalent-scalar DIFFERENT
contract violations=8 (diagnostic, not a gate verdict)
```

The three malformed values are `[unterminated`, `"unterminated`, and
`alpha: beta`. The equivalent valid scalar forms are `alpha` and `'alpha'`.
All cases have a closed frontmatter block and the same valid ATX heading.
Therefore the failures are not missing delimiter, heading, shell startup, or
missing runtime errors. The driver also passed `bash -n` (exit 0).

The raw-string extraction in `tests/lib/markdown-ast-canonicalizer.sh:39-46`
and `.ps1:41-48` explains both false acceptance and false inequality. Merely
rejecting an opening `[` would not resolve quoted scalars or other malformed
YAML and is not a root fix.

## Exact remaining contract boundaries

1. `design.md:963-985` requires YAML-map parsing and a hard failure on parser
   failure; it names no YAML version/schema or supported subset. `tasks.md:659-667`
   requires the specified algorithm exactly and unchanged template comparisons.
   `security-spec.md:143-153` rules out a new parser package, Python, or another
   runtime. These constraints do not logically forbid writing an in-repository
   parser using the allowed runtimes. They do rule out silently borrowing a
   Python/subset parser or silently declaring an arbitrary subset equivalent to
   YAML. A bounded grammar requires a defensible scope interpretation or an
   explicit amendment, not a success label based only on these probes.
2. `design.md:979-985` compares heading text and level after whitespace-only
   normalization. `tasks.md:666-678` names unchanged templates. The actual lite
   template `plugins/sdd-lite/templates/tasks-lite.md:1,3` contains `<feature>`
   and `<タスク名>`; the preserved fresh response instantiates both. The existing
   refresh compares the two ASTs at
   `tests/structural-compatibility-live-refresh.tests.sh:49-54` and correctly
   rejects this text difference under its current literal algorithm. Treating
   placeholders as wildcards, dropping heading text, or rewriting the raw model
   response would change that comparison; none was done.
3. `tasks.md:1693-1723` makes T-012 the sole sanctioned corpus mutation path and
   requires pre-write structural validation plus independent content evaluation.
   The old corpus and both new raw responses are retained unchanged. No direct
   T-004 corpus patch or new active-corpus selector was added.

The smallest potential YAML contract decision is a named supported grammar,
including type resolution, semantic scalar tests, and explicit hard rejection
outside it. The alternative is to implement the broader existing YAML contract
using only allowed runtimes. Neither option authorizes an unsupported-input
PASS. No dependency relaxation is proposed.

## Independent scope assessment and next entry

Fresh-context `yaml_contract_scope_review` independently read the governing
requirements, design, task plan, security specification and implementation.
Its static assessment was not a formal gate or runtime verification:

- A flat-scalar-only final grammar requires specification clarification and
  approval: hard-fail language is not authorization to restrict valid YAML.
  The observed malformed-input and scalar-equivalence bugs are valid repair
  targets, but a limited parser is not by itself complete AC-030 evidence.
- Known placeholder expansion can remain within the existing template contract
  if trusted values are fixed BEFORE observing the response, only named
  placeholders are expanded in the expected template, source templates remain
  unchanged, and text/level/order remain exact afterward. The requirement for
  generated templates (`requirements.md:328-350`) supports this interpretation.
  Deriving expected values from actual output, broad wildcard matching or
  adding mandatory corpus-schema fields is not covered by that interpretation.

Thus the F2 issue does not inherently need a new contract if fixed fixture
configuration is used. The existing response cannot automatically be admitted
under this rule: its feature was specified in the collection input, but its
task-title text was chosen by the model, not precommitted as a trusted expected
parameter. A future collection must fix BOTH values first and preserve its
input before generation. This is a new response, never a rewrite of attempt 2.

The bounded next implementation entry is T-004 expected-template rendering with
fixed fixture parameters and negative tests for wrong parameter value, fixed
heading text, heading level and heading order; T-012 subsequently owns the
actual collection/admission/write operation. This must be reconciled with
retaining the historical corpus rather than adding a silent alternative oracle.
The YAML acceptance-profile decision remains separate and unresolved; no
limited parser was installed to make the suite appear complete.

## Measured hashes

| Artifact | SHA-256 |
| --- | --- |
| diagnostic driver | `27bc2c05be4fb792a8779ad84efa1fda37b4087e2ad1344e4628e8c1371be6df` |
| Bash canonicalizer, unchanged | `4178e59df40c8a3222913faf5b228181298a4c528b6653221575b987240f5d29` |
| PowerShell canonicalizer, unchanged | `ea522fc5069dd508d8ac5ebbe7a025cf1eadd49a70d0aee2552bac5aed8be96d` |
| historical F2, unchanged | `4fe2eff3b2842f5e1228db5f06f99188756e8800608620ef0dfb662fd29b7b88` |

No new full-suite GREEN, formal quality-gate PASS, product-hook execution,
current-head CI, merge or delivery is claimed.
