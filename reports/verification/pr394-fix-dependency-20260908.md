# PR #394 Windows repair dependency

Primary-only investigation; no agent delegation, implementation change, retry,
publication, merge, or issue closure.

Fresh failed-log read `fe7704` binds run 34023439393 to two Gemini TEST-004(c)
failures (iterations 4/5: 2908/3459 ms, exit 1, no verdict). Their cause remains
unproven. The earlier full failed-log read b5668e was truncated and is not the
source for these details. No active CI run is being waited on.

Exact test-file comparison `ccc1d0` between PR394 head
423edd3b0f9f6710e1de00183e4040fdd8de8ef3 and PR400 head
8fa3eb8561d6f59b692ec574900f87e181145928 establishes that the failing PR394
variant lacks all three approved T002 diagnostic/fixture changes:

- The synthetic CLI does not consume stdin with Console.In.ReadToEnd.
- It does not persist wait-end and output-complete timing sidecars.
- The assertion does not emit escaped, bounded runner failure diagnostics.

The deadline (2 seconds), completion margin (800 ms), five repetitions per
runner, and success assertion are unchanged by that exact diff. These facts
justify testing the approved repair on the integration candidate; they do NOT
prove that stdin handling caused the two historical failures. Production runner
source was read (431df4): Start-Process redirects stdin and output, then waits
within a shared absolute deadline. Its timeout path must remain enforced.

Do not cherry-pick unrelated specification edits from PR400 into the dependency
PR or merge solely on its older green CI. PR400's formal acceptance amendment
still has an unresolved guard-membership input finding. The prior human-output
boundary remains; a concise human-only read-only collection block is now in
`pr400-human-membership-evidence-20260908.md`. Its source excerpts must be
evaluated, not mistaken for computed enforcement or a formal PASS.

Next: receive the human-collected evidence, bind the relevant verified facts to
the canonical investigation input, complete the approved provenance/review chain
and required implementation verification, then integrate the exact approved
fixture repair and dependency candidate and require fresh all-green CI. No
timeout widening, favorable-sample retry, test removal, or historical FAIL
reclassification is permitted.
