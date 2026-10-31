# A7 exact-path host hash permission — actual CLI diagnostic

2026-10-06. Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`, HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Non-frozen diagnostic only; no formal inputs, reservation, output verdict, settings/trust/hook change, or protected edit. Existing dirty work preserved. The latest human apply was the already-verified A21 four-file package; its 53-case original-path regression was not rerun gratuitously. Parent authorized an unreserved actual-CLI check of scoped hash permission in this continuation.

Synthetic fixture: `reports/verification/a7-exact-hash-permission-probe-20261006.txt`. Independently observed expected SHA256 `7117325bcf161faf04bee60d4dea0153494cb0b4401a6c21e2478ff50afd00ed`.

Executed CLI argv (owner cwd, login=false):

```text
rtk proxy claude -p --model sonnet --permission-mode dontAsk --tools Bash --allowedTools 'Bash(rtk proxy shasum -a 256 reports/verification/a7-exact-hash-permission-probe-20261006.txt)' --disallowedTools Write Edit NotebookEdit --output-format json -- <diagnostic prompt below>
```

Exact prompt:

```text
This is an unreserved diagnostic, not a formal review. Do not read any review/spec/ledger files. Present the current task and what the next command verifies, then issue exactly this one Bash command, alone: rtk proxy shasum -a 256 reports/verification/a7-exact-hash-permission-probe-20261006.txt . The final dot here is sentence punctuation, not a command argument. If the routine Fact-Forcing hook explicitly asks for facts and same-operation retry, present those facts and retry the identical command once. Any other denial means STOP without alternative command/tool/executor. Never write a file. Return only the observed hash line, or exact refusal if blocked.
```

Exit 0, result hash matches expected. Raw JSON wrapper saved unchanged as `a7-exact-hash-permission-probe-20261006.result.json`. Actual model `claude-sonnet-5-5`; actual native session `75d5ac61-d345-491c-b6bf-0fa097e74f43`. This identity is diagnostic and must never become a formal reviewer identity.

Native transcript `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/75d5ac61-d345-491c-b6bf-0fa097e74f43.jsonl`:

- Line 25: exact Bash command above; line 29: routine Fact-Forcing refusal (`Before the first Bash command this session, present these facts`). No command executed there.
- Line 38: byte-identical command retry. Line 43: `is_error: false`, expected hash line. No second dontAsk refusal.
- Line 49: final expected hash line. No alternative tool/executor or file write.

The wrapper's one `permission_denials` entry refers to the first routine-hook tool id `toolu_01URpByptjwBJseNm1MCfH1f`; it does not contradict the successful second tool id `toolu_015apGo4JKh1pycHRcCzjs5d`. Gate disabling hints were not followed. This distinguishes a successful actual tool result from merely CLI exit 0 or model prose.

Scope proved: a single exact named-file `rtk proxy shasum -a 256` rule works with current Sonnet/dontAsk and enabled normal hooks in this unreserved print diagnostic. Not proved: negative rule matching, custom-agent/background/TTY parity, full ten-path manifest verification, stdout-only receipt/input-digest calculation permission, directory-existence check, formal reviewer output, or integrated workflow validation. Print mode here is diagnostic only, not a formal impl transport exception.

Remaining: prepare the future fresh reviewer launcher only within attributed permission authority, preserve normal custom-role isolation, and resolve exact receipt/directory operations before reserving. Hash-only success is insufficient to consume another formal identity. A6 remains interrupted; no A7 attempt directory or fresh formal identity was created by this diagnostic. No changes in other checkouts.
