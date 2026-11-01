# Native coding standards checks

Run `python3 tests/verification.py --profile coding-standards --run` after installing
`requirements.txt`, PSScriptAnalyzer **1.25.0**, and `npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts`.
Python/Ruff and ShellCheck must be on PATH; PowerShell 7 (`pwsh`) and Node must be available.
The CI job in `.github/workflows/test.yml` installs these dependencies and runs the same catalog profile.
It fails on tool/config/runtime/parse/timeout failures. Local execution does not prove remote CI ran.

`python3 tests/coding_standards.py census` emits the tracked working-tree population,
with index blob identity and current content SHA256. It starts every review as unknown.
`scan --mode all` is the complete native scan; `scan --mode diff --base COMMIT` uses the
same rules on changed tracked files for early feedback. Missing/shallow bases fail.
Diff success cannot close the full audit. New files must first be added to Git's index.
Reports are JSON to stdout; exit 0 means selected native checks completed without findings,
1 means findings, and 2 means execution failed (finding count unknown). No source snippets
are logged. Zero targets are explicitly `no-targets`, never an observation about other files.

| Tool | Fixed version / contract | Enforced subset | Limits |
| --- | --- | --- | --- |
| Ruff | 0.13.3 (existing shared-launch version/config) | E4/E7/E9/F, CS-020 | Does not prove input semantics, exception intent, or oracle independence |
| ShellCheck | 0.11.0, shellcheck-py 0.11.0.1 | SC2086/SC2046, CS-001; SC2155, CS-019 | Existing parser owns shell grammar; bash -n additionally prevents syntax errors being filtered out |
| PowerShell parser / PSScriptAnalyzer | PowerShell 7, PSSA 1.25.0 | Syntax, InvokeExpression (CS-001), automatic variable assignment (CS-012), plaintext password parameters (CS-010), misleading backtick (CS-019) | Empty catch is contextual: strict failure and explicitly tolerant absence differ |
| TypeScript | Exact locked 7.0.2 | Native syntactic diagnostics and AnyKeyword (CS-021), including `as any` | Version 7 removed the old JS compiler API; this bounded adapter uses its version-pinned unstable/sync API. Public API stability is not claimed |

TypeScript-eslint 8.72.1 supports TypeScript `<6.1.0`, while all three MCP packages use 7.0.2.
Adding it with its compatibility warning disabled would hide an unsupported parser. The native
adapter therefore adds no package dependency; each package retains its own strict typecheck,
build and tests. Floating promises, unsafe assertions and external data contracts still need
context review and runtime controls. shfmt/formatters were not selected: mass layout changes
would not establish these failure-handling properties. Native tool success is not all 30 rules
passing: `manual_review`, `manual_unreviewed_count` and the canonical audit ledger preserve that gap.

Current executable code, tests, generated runtime files and templates are eligible for native
scanning. Documentation fences are surfaced for contextual review, not extracted as fabricated
standalone programs. Unknown fence languages and shebangs remain visible. Historical records,
human-copy bundles and symlinks remain in the census; routing does not approve or exempt them.
Symlinks are hashed as link text and never followed, preventing escapes and duplicate target counts.
The sole syntax-error fixture exception is exact-path/content-hash bound in `tools.json`, with its
resolver regression control. No blanket baseline, `noqa`, or repository-wide linter suppression is added.

The native positive/negative controls include every selected ShellCheck/PSSA rule, real TypeScript
AST discrimination (string/property named `any` is normal), Python unknown-name detection,
strict/tolerant conversions, quoted Windows paths, newline filenames, symlinks, empty population,
zero language targets, unavailable shallow history, invalid config/output, missing tool and timeout.
The existing verification runner owns scheduling and receipts; this module only selects tracked
inputs and adapts native diagnostics. It does not replace product Full/Lite check selection.
