# Antigravity CLI (agy) as the Google panelist slot — evaluation and withdrawal

Date: 2026-08-29
Outcome: **NOT ADOPTED.** The staged patch `docs/ci-staging/agy-panelist.patch`
(PR #370) is withdrawn and deleted; the Google vendor slot stays retired.

## Why this was attempted

`gemini-cli`'s consumer backend was retired server-side on 2026-06-18
("This client is no longer supported for Gemini Code Assist for individuals…
migrate to the Antigravity suite"), which removed the Google slot from the
cross-model panel mid-campaign. The owner installed Antigravity
(`agy` 1.1.22), and a patch was staged to teach `detect-panel` and
`run-panelist-gemini` to fall back to it.

## What was measured (all on this machine, agy 1.1.22, model gemini-3.1-pro-high)

| # | Probe | Result |
|---|---|---|
| 1 | `agy -p "Reply with exactly: OK"` | OK — headless print mode works |
| 2 | `printf … \| agy -p "…"` marker question | YES — stdin **is** appended to the print prompt, matching the contract `run-panelist-gemini` already used for gemini-cli |
| 3 | Isolated scratch dir, `--sandbox --dangerously-skip-permissions`, read a small file | correct answer — sandboxed file read works |
| 4 | The staged patch, real runner, real 957 KB bundle (T-003) | **failed**: the runner selected the installed-but-dead `gemini`, which exited with `UNSUPPORTED_CLIENT` |
| 5 | Same, with a gemini-free PATH so the agy branch is taken | **failed**: `jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied` |
| 6 | Isolated scratch + `--sandbox --dangerously-skip-permissions`, 957 KB bundle, review question | returned `{"verdict":"PASS","findings":[]}` **instantly** |
| 7 | Same input, **content-dependent** question (task id + a specific suite tally + a section's presence) | **`Error: timeout waiting for response`** |
| 8 | Same content-dependent question against a 20 KB excerpt of the same bundle | **correct**: `{"task_id":"T-003","feature":"epic-194-a6-lite-integration"}` |

## Findings

1. **Presence-based CLI selection is wrong for a server-retired CLI.** The
   staged patch preferred `gemini` when present and fell back to `agy`. The
   homebrew `gemini` 0.28.0 binary is still installed and still answers
   `--version` locally — it only dies at request time. So the runner picked
   the dead CLI (probe 4), and `detect-panel` reported the google slot as
   available through the same false-positive local version probe. A correct
   patch would have to prefer `agy`.
2. **agy is an agentic CLI, not a completion CLI.** In print mode it may
   decide to call tools, and headless auto-denies them, producing no output
   (probe 5). It needs an isolated cwd plus `--sandbox
   --dangerously-skip-permissions` — the shape the codex twin already uses
   (`codex exec --sandbox read-only -C <tmpdir>`).
3. **The blocking defect: SDD-sized bundles are not processed.** Probes 6-8
   together are the signature of vacuous verification: an instant `PASS` with
   zero findings on a 957 KB bundle, a timeout when the same 957 KB input is
   asked anything that *requires* having read it, and a correct answer when
   the input is 20 KB. Sanitized panel bundles are ~1 MB by design (the
   vendor cap the preparer enforces), so the Google slot under agy would
   emit PASS verdicts not grounded in the material.

## Decision

Withdrawn. A panelist that returns unfounded PASS verdicts is worse than an
absent one: it satisfies the gate's vendor-diversity minimum on paper while
removing the scrutiny that minimum exists to buy. The panel's diversity
requirement (>= 2 distinct vendors, >= 1 non-Anthropic) remains satisfied by
the Anthropic and OpenAI slots, which is how the 2026-08-28 epic-194 panel
rounds ran.

## A pre-existing defect found on the way out (not caused by the patch)

After the patch was reverted from the working tree, `detect-panel.sh` still
prints `gemini` alongside `gpt`. That is the shipped behaviour, not a
leftover: the liveness probe is `command -v gemini && gemini --version`, and
`--version` is answered locally by the installed binary. A CLI that has been
retired **server-side** therefore still registers as an available vendor
slot, so a caller is told the panel has Google diversity it does not have.
The failure only surfaces later, when the runner spends a real invocation and
gets `UNSUPPORTED_CLIENT`.

This is worth a ticket of its own: the probe would need to distinguish
"installed" from "able to serve a request", which `--version` cannot do for
any vendor. Recorded here rather than filed, because the fix touches a
guard-protected script and the panel currently runs fine on the two live
slots.

## If this is revisited

The blocker is input size, not authentication, model, or invocation shape
(probes 1-3 and 8 all pass). A future attempt would need the panel protocol
to change, not just the runner: e.g. chunked review with per-chunk verdicts
merged deterministically, or a bundle profile small enough for agy while
still carrying every declared output the panelist must judge. Both are
protocol changes that need their own spec and gate work — not a runner
patch.
