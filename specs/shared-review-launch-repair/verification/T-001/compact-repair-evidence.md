# T-001 compact transport repair verification

This addendum preserves the original implementation report and prior verdicts.
It records the explicitly approved T-001 repair, not a new Done decision.

## Executed checks

- Transport, structured-output, launch-order, task-launch and build regressions: 52 passed.
- Supplemental declaration and T-001 preparation regressions: 25 passed in independent verification (17 + 8); no blocking diff-review findings.
- Preparation rejects stale or undeclared input mutations, missing inputs, cross-feature declarations and duplicate paths/JSON before scratch preparation or reservation. The original report and ledger remain unchanged.
- The preparation regression is registered in the shared launch CI step and both run-all drivers. Full CI and native Windows execution are not claimed.

## Native diagnostic (not a formal verdict)

Claude 2.1.292, session `0126e6df-5556-4bd8-900a-ce5cbada6278`, completed the unreserved common-launch diagnostic. Admitted/control/source reads, ordered input verification, outside-read denial, compound-command denial and existing-session collision rejection succeeded. The first Bash retry was observed and completed successfully; stderr was absent.

The pinned verifier checked all admitted input hashes; this is not a claim that the model issued an individual native Read for every input. Five native Read calls were observed.

- Source invocation SHA-256: `13b0dd61ad57fe96e691dabea2056ed6e9504f6f0f6755a8cbbd9d28997a6a44`
- Session policy SHA-256: `fdf546268ad876ee27b7dd3db098a629fc86c7c0f68ef472b8c89f3536c25b26`
- Guard SHA-256: `0a3d9961c53d01520a37fc41bf86ef7a7e5e6cc3254d427789b6115634e1369b`
- Transcript SHA-256: `450a45460745eb6a492258a0c65102126f94bb7e344de8a4f18dd3196ce52633`

Formal independent evaluation, exact-head CI, merge and post-merge verification remain pending. Historical failed diagnostics are retained and are not promoted to success.
