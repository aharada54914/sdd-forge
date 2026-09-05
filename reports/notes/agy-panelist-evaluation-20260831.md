# Antigravity CLI (agy) as the Google panelist slot — evaluation

Date: 2026-08-31 (supersedes an incorrect 2026-08-29 assessment; see "Retracted" below)
Outcome: **NOT VIABLE TODAY**, for a reason that is neither size nor timeout.
Action: `docs/ci-staging/agy-panelist.patch` is deleted — it was defective in two
independent ways *and* the approach it enables does not work.

## Why this was attempted

`gemini-cli`'s consumer backend was retired server-side on 2026-06-18 ("migrate
to the Antigravity suite"), removing the Google slot from the cross-model panel.
The owner installed Antigravity (`agy` 1.1.22) and a fallback patch was staged.

## Retracted: the 2026-08-29 "bundle size" conclusion was wrong

That assessment claimed agy could not process ~1 MB bundles and returned vacuous
PASS verdicts. It rested on two data points (20 KB succeeded, 957 KB failed) and
did not separate size from the default 5-minute `--print-timeout`. A size ladder
run with the same content-dependent question at every size refutes it:

| size | `--print-timeout` | result | elapsed |
|---|---|---|---|
| 957,196 B | 15m | **correct answer** | 183 s |
| 409,600 B | 5m (default) | timeout | 306 s |
| 204,800 B | 5m | correct answer | 295 s |
| 102,400 B | 5m | correct answer | 260 s |
| 20,480 B | 5m | correct answer | 267 s |

**Elapsed time is essentially independent of input size** (20 KB took 267 s;
957 KB took 183 s). It is agent overhead, distributed roughly 180–306 s, and the
default 300 s sits in the middle of that distribution — so runs failed at random
with respect to size. Size was never the blocker.

## The actual blocker: agy abandons the provided file on a panel-weight task

Same 957 KB file, same flags, same fresh-directory hygiene, same time window —
only the task changes:

| task | input path | directory | result |
|---|---|---|---|
| extract 2 fields | file in cwd | fresh | **success** (reproduced twice, hours apart) |
| panel judgment | file in cwd | reused | `Critical: bundle.txt could not be found` |
| panel judgment, read instruction leading the prompt | file in cwd | reused | same failure |
| panel judgment | file in cwd | **fresh** | same failure |
| panel judgment | **stdin** | — | `Critical: no bundle was appended` |

On the heavier task agy does not read the file it was given. It announces that
it is "searching your file system for bundle.txt … may ask for your approval to
proceed outside the restricted sandbox", the sandbox blocks that search, and it
reports the missing evidence as a Critical finding of its own review.

Hypotheses tested and refuted along the way, each with a control:

- **size ceiling** — refuted by the ladder above;
- **timeout** — refuted: the full-size success took 183 s, well inside 5m;
- **prompt ordering** (read instruction buried vs leading) — refuted: leading
  with `Read bundle.txt in the current directory.` fails identically;
- **per-directory conversation carry-over** (agy has `--continue` /
  `--conversation` / `--new-project`) — refuted: a brand-new directory
  containing only the bundle fails identically;
- **randomness / drift over the session** — refuted by the control repeat: the
  light extraction task succeeded in a fresh directory in the same time window
  in which the panel task was failing.

Separately measured: **stdin does not carry a large bundle.** A one-line stdin
probe is appended to the print prompt as documented, but the 957 KB bundle
arrives as nothing ("no bundle was appended"), so the existing runner contract
(`-p <prompt>` with the bundle piped on stdin) has no working analogue here.

## Why this is not adopted

The failure could plausibly be lifted by dropping `--sandbox` so the filesystem
search agy insists on can complete. That is not available to us: the sandbox is
what keeps a **blind** panelist from reading anything except the sanitized
bundle. Trading the isolation guarantee for a working invocation would remove
the property the panel exists to provide.

The gate's diversity minimum (>= 2 distinct vendors, >= 1 non-Anthropic) remains
satisfied by the Anthropic and OpenAI slots, which is how the 2026-08-28 panel
rounds ran.

## Two defects in the deleted patch, recorded so a v2 does not repeat them

1. **Presence-based CLI selection is wrong for a server-retired CLI.** The patch
   preferred `gemini` when present and fell back to `agy`. The homebrew
   `gemini` 0.28.0 binary is still installed and still answers `--version`
   locally — it only dies at request time with `UNSUPPORTED_CLIENT`. The runner
   therefore selected the dead CLI. A v2 must prefer `agy`.
2. **agy is an agentic CLI, not a completion CLI.** In print mode it may call
   tools, and headless auto-denies them (`no output produced — a tool required
   the "command" permission that headless mode cannot prompt for`). It needs an
   isolated cwd plus `--sandbox --dangerously-skip-permissions`, the shape the
   codex twin already uses, plus an explicit `--print-timeout`.

## A pre-existing `detect-panel` defect found on the way

`detect-panel` probes liveness with `command -v <cli> && <cli> --version`.
`--version` is answered locally, so a CLI retired **server-side** still
registers as an available vendor slot; the failure only surfaces later, when a
runner spends a real invocation. The retired `gemini` still shows up in
`detect-panel` output today. Fixing it means distinguishing "installed" from
"able to serve a request", which no `--version` probe can do — worth its own
ticket, and it touches a guard-protected script.

## What would make this viable

An explicit "attach this file as context" input path — one that does not depend
on the model choosing to invoke a read tool — would make the Google slot work
immediately, since agy demonstrably handles the full bundle when it actually
receives it. Re-evaluate if Antigravity ships that.
