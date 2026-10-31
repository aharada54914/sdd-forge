# Owner-cwd native CLI startup observation — 2026-10-03

This is a failed startup observation, not an installed activation, implementation run, quality-gate verdict, or native canary result. No canary write was attempted by the launched CLI session.

- Intended checkout: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge` via ordinary `codex exec -C`.
- Executable: `/Users/jrmag/.nvm/versions/node/v24.13.0/bin/codex` (normal PATH npm CLI); version `codex-cli 0.147.0`. The previously suggested `/Applications/ChatGPT.app/Contents/Resources/codex` was absent on this host.
- No approval, sandbox, hook-trust, or rules bypass flags were supplied. Current user config showed `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`; these settings were not changed.
- CLI thread/session ID emitted: `01a10027-e710-74f2-ad7d-c69c97feb72d`.
- Process result: exit 1 before the agent attempted any tool call. The fatal API error was `The 'gpt-6.1-sol' model is not supported when using Codex with a ChatGPT account.`
- The CLI also warned repeatedly: `ignoring hooks: expected a string, string array, object, or object array; found object`. Hook enforcement in this CLI was therefore not established.
- Actual native `apply_patch` canary calls in this CLI session: **0**. No raw host-denial response, owner-cwd `host-response.json`, or `HOOK_ACTIVE` result exists from this attempt.

The caller had earlier emitted nonce `9194a4f38f43b504100fed105998c812` through the installed verifier while investigating this checkout, but did not dispatch its exact relative patch because the caller's native patch tool was rooted in the primary checkout. That nonce is not reused. The separate historical 2026-10-03 native evidence under `native-20261003-5e13f6/` explicitly records a primary-relative patch and does not prove this owner-cwd CLI launch.

No alternative model, hook configuration, executor, or canary path was tried after these startup warnings. A future owner-cwd host session must use a supported model **and** demonstrably loaded protective hooks before issuing a new challenge and its one exact native canary attempt; otherwise stop without claiming activation. This observation changes no task/review status, identity ledger, implementation report, or protected source.
