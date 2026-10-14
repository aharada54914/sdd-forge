# Fixed-input native probe retry correction

Date: 2026-10-14
Scope: the unreserved native probe's existing first-Bash fact-forcing handshake.
Status: native diagnostic verified; formal signed-state acceptance not established.

## Reproduction and bounded change

The fixed-input route removes the model's hash-verification Bash calls. Its first
Bash is therefore the deliberate chained-command negative check. On the native
host, the existing fact-forcing hook rejects that first call before the pinned
guard. A truthful-facts response and identical retry then reaches the pinned guard,
which correctly denies it. The old probe recognized this existing one-retry
handshake only for the non-fixed hash command, so its final exact sequence check
rejected the fixed route despite correct native read and deny behavior.

The correction recognizes only one first-Bash fact-forcing refusal followed
immediately by the identical command and its paired pinned-guard denial. It retains
the complete exact tool-sequence comparison. Changed/repeated/delayed/overlapped
operations, unknown or pinned refusals, mixed refusal markers, extra Bash calls,
and successful rather than denied retries remain rejected. No guard, approval,
identity, reservation, read authority, or global trust setting was changed.

## Executed verification

- RED: the new valid-retry regression failed with
  `ValueError: native probe tool sequence differs` on the original implementation.
- GREEN: the focused 3 tests passed, including 9 negative transcript variants.
- `python3 -B tests/fixed-review-launch.tests.py`: 50 tests passed.
- `python3 -B tests/task-structured-output.tests.py`: 13 tests passed.
- `python3 -B tests/quality-nontty-transport.tests.py`: 20 tests passed.
- `git diff --check`: passed.
- Independent Codex diff review: no findings; the reviewer independently reran the
  50, 13, and 20 test suites and checked the executed probe source digest.

The actual shipped probe was executed with a Git-pinned read-only snapshot and
separate inventory/invocation via its fixed-input arguments. The native model was
`claude-sonnet-5-5` (requested alias `sonnet`). After the correction, the probe
exited 0 and verified sampled admitted/control reads, the source invocation read,
the exact guard read scope, chained Bash and outside Read denials, one observed
first-Bash fact retry, and rejection of existing-session reuse. The diagnostic
made no canonical reviewer reservation. Canonical ledger bytes were unchanged.

Recorded SHA-256 evidence:

| Artifact | SHA-256 |
| --- | --- |
| Executed probe source, before and after native run | `ada61260a4f17ff43f835658b24fed592e00f40d1e38bce16f2340337409ecd6` |
| Successful native transcript | `39298296ce6525952186848fc8adddf26d151211618aad5d235f8da78594409c` |
| Fixed input inventory | `8673b7d5f18ad8330c3e8da3246047915d7262ce7c0a15d76378ad78a2556753` |
| Canonical ledger, before and after | `c0518fcc733f0ad34c8f6574c2612ef4d740796d5d35ad70aa8a67f148f97316` |

The original failed transcript and the successful retry's raw evidence are retained
locally; they are not replaced or included in this public summary. Existing
untracked canary reports were neither changed nor included.

## Acceptance boundaries

The native result covers sampled transport reads, not a full substantive review.
It does not supply an authentic `sdd-fixed-review-approval/v1`, authenticated
detached state, formal review reservation, task transition, or final four-point
acceptance. Those remain separate evidence requirements. No approval signature or
approver identity was invented. Final-head CI and merge status must be established
from the associated pull request rather than inferred from these local results.
