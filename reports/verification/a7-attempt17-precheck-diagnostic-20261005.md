# A7 attempt 17: admission and read-only diagnostic (2026-10-05)

This is an orchestrator verification note, not a spec-review verdict or reviewer output.

- The immutable approval audit is `reports/verification/a7-spec-fresh-approval-audit-attempt17-20261005.json` (SHA-256 `7b8ce385bb454910a24301072f969ab227aa860446243925522c6751e93d362c`). It transcribes the user's current authorization and does not claim a human-authored signature.
- The immutable recovery contract is `reports/verification/a7-spec-fresh-review-contract-attempt17-20261005.json` (SHA-256 `f1afe5eb62f2d493f3f9d487371e646db36965c94ab463269a2dbc02ac9823cc`). The installed recovery helper admitted it with completed rounds 15/1 and 15/2 preserved; this establishes integrity, not retrospective review legality.
- The normal Bash precheck for attempt 17, round 1 returned exit 0. `reports/spec-review/epic-195-a7-compatibility/attempt-17/round-1/precheck-result.json` has SHA-256 `74b1aed39b36ccb00b99da4f9c945aedc5872e71e4b40302a16556a35c9bb08c` and pins that exact contract and the current input hashes.
- No A/B reviewer identity, manifest, reservation, first turn, or verdict had been created when the admission and diagnostic observations above were made. The later formal-A transport failure is recorded separately in `reports/spec-review/epic-195-a7-compatibility/attempt-17/round-1/launch-blocker-note.md`; it must not be interpreted as a specification verdict.

## Separate diagnostic host

The first unreserved Sonnet diagnostic used `--tools Read,Grep,Glob,Bash --disallowedTools Write,Edit,NotebookEdit --permission-mode dontAsk` without a Bash command allowlist. `Read` succeeded. Its first hash attempt was stopped by the active Fact-Forcing Gate; after stating the request and command purpose, the same hash was denied with `Permission to use Bash has been denied because Claude Code is running in don't ask mode.` This was not a reviewer turn.

Read-only settings inspection found no matching `Bash(rtk proxy shasum ...)` allow entry in the user settings and no shasum-specific deny entry. CLI help defines `--allowedTools` separately from `--tools`. A *new, unreserved* Sonnet diagnostic was therefore launched with the ordinary hooks and deny rules intact, adding only the exact command allowance:

`--allowedTools 'Bash(rtk proxy shasum -a 256 -- specs/epic-195-a7-compatibility/requirements.md)'`

The Fact-Forcing Gate again rejected the first Bash request; after the diagnostic stated the current request and the command's purpose, the identical command succeeded and returned SHA-256 `492f54a812be75ca20d0a05ec41dcf225f9b1b17cd512148498e02cf954dd96c`. No hook, deny rule, or permission mode was disabled or bypassed. This proves only the specified read-only hash capability in that diagnostic context. A formal reviewer must have its own fresh host-issued identity, exact allowed-input manifest, reservation, and independent first turn.
