# Read/hash refusal diagnosis (read-only)

The idle native thread was terminated without a model turn. No guard modification or alternate hash execution was performed.

## Repository mechanism

- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:9` includes word-bounded `node` in `SHELL_SUDO_WRITE_RE`; line 14 also includes it in `SHELL_INDIRECT_CMDS`.
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1709-1717` detects a protected path, then the write regex, and rejects unless the shell write targets are provably safe.
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1241-1269` expressly fails closed for interpreters and other unmodeled syntax. The attempted command contained both protected input paths and `node -e`. Its `fs.readFileSync` semantics are not interpreted by this checker. Arrow `=>` also contains the broad redirect regex's `>` token; removing that alone would not remove the explicit `node` classification.
- Equivalent JS decision: `sdd-hook-guard.js:834-837`; PowerShell decision: `sdd-hook-guard.ps1:1220-1225`.

This matches deliberate unmodeled-interpreter fail-closed behavior, not evidence that the command would actually write. The installed hook's exact source/config was not independently fingerprinted; repository mechanics explain the observed denial but should not be overstated as a verified runtime source mapping.

## Hash utility distinction and minimal scope

`generated/guard_invariants.py:10` only explicitly names cat/ls/test/grep/stat/head/tail/rg as read-only starts; neither shasum nor sha256sum is named. However `sdd-hook-guard.py:1715-1716` returns allow when no write-regex token is found, independently of that start list. Thus a literal `rtk proxy shasum -a 256 <exact files>` without redirects, expansions, inline interpreters, or write-like vocabulary in operands has a statically different, already-supported path. This is a source-derived expectation, NOT an executed successful hash collection. It was not used after the refusal.

Minimal recommendation: do not globally allow Node and do not remove it from the indirect/write lists. No guard code change is established as necessary for this exact failure. If the coordinator authorizes the existing simple hash-utility route as a documented supported read (not a changed executor for arbitrary Node), verify that route with existing rules first. If a simple literal hash command is itself wrongly denied because of operand vocabulary, scope a separate guard change to quote-aware fixed-command/argv hash recognition with no redirects, substitutions, compound execution, or unsafe options; preserve all opaque interpreter denials and include all three runtime twins plus generated-source parity and negative fixtures. Such a change is outside this T-004 launch preparation and requires the protected-change process.
