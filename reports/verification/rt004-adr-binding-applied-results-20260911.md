# RT004 ADR binding: post-application verification

Status: ADR full suite and related boundary/round-2 suites passed. Not a formal gate PASS.

Human application was reported with backups `/tmp/sdd-rt004-adr-binding.0miBYB`
and `/tmp/sdd-rt004-adr-pwsh.9cGuzJ`. Original-path hashes were independently
recomputed after application:

- Bash: `f171435b6166904167712fe7e93c86f654b8dd3690777e29315298fce1b33903`
- PowerShell: `2a0eb682e2407e602710c97570680247ccce69fbae16740dcf95cb9113207de1`

Executed against the original validators, using the existing driver:

| Command suffix after `bash tests/impl-review-adr-inputs.tests.sh` | Result | Full log |
| --- | --- | --- |
| `--keys-only` | exit 0; 20 passed, 0 failed | `/tmp/sdd-rt004-keys-applied.sFm27W` |
| `--multi-precheck-only` | exit 0; 24 passed, 0 failed | `/tmp/sdd-rt004-multi-applied.nKCs59` |
| no arguments | exit 0; 448 passed, 0 failed; session 42816 terminal | `/tmp/sdd-rt004-full-applied.ZYre7n` |

These sets overlap and must not be reported as 44 distinct cases. Both runtime
validators and both implementation reviewer roles are covered. PowerShell here
is macOS PowerShell, not native Windows evidence. Earlier failing results remain
historical baseline evidence; they have not been rewritten as passing.

## Related regression results

- `bash tests/review-context-boundary.tests.sh` initially exited 1 because its
  document/test citation `:667` no longer located the under-lock ledger check.
  Full failing output: `/tmp/sdd-rt004-boundary-applied.0fVunh`.
- Inspection against the human backup showed inserted ADR binding code shifted
  existing constructs. Citation-only repairs updated the documentation and its
  anchor table: `667 -> 798`, `661 -> 792`, `676-684 -> 807-815`,
  `550-580 -> 650-690`, `601-606 -> 726-731`. Assertions and behavior unchanged.
  Ordinary apply_patch succeeded; no human operation or alternate executor used.
- Re-execution exited 0: 32 citation anchors and 22 Bash/PowerShell behavioral
  cases passed. Log: `/tmp/sdd-rt004-boundary-citations.ZyukBM`.
- `bash tests/impl-review-round2-contract.tests.sh` exited 0: four cases passed.
  Log: `/tmp/sdd-rt004-round2-applied.mjzQOZ`.
- Registry SHA-256 before and after that suite was identical:
  `21b10cd863c13a5d8399ea26dcc86ff9a0dedbe5eb3e91f89b6dbb134f0d18cf`.
- Whitespace validation of the citation changes exited 0.

Formal review, remaining required checks, CI and main integration remain
incomplete. No commit, push, merge, ticket closure or verdict change was performed.
