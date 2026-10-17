# Requirements status corpus refresh

The full requirements template initializes `Spec-Review-Status: Pending` after
change `24fd8033`. The current F1, F3, and F4 structural fixtures lacked this
field, so the unchanged exact status-field comparison correctly rejected them.

These three **current test fixtures** were updated through the existing
`structural-compatibility-live-refresh.tests.sh --fixture` entrypoint. Each
requirements artifact gains only that one status line. The other artifacts,
fixture states, and dependency metadata are unchanged. The provenance label is
`deterministic-template-contract-refresh`, with source commit
`1eb302bb4689ed9351ea4a71f4bd40deb3206042`; this is an explicit deterministic
fixture adaptation, not a newly observed model response or native-host proof.
F2 and the product template are unchanged.

The original captures remain byte-for-byte available at source commit `1eb302bb`
under their original corpus paths. Their original metadata and file digests are:

| State | Original recorded commit | Original corpus SHA-256 |
|---|---|---|
| F1 | `e973307f05f9ada72c11b2817e56b143525cc3b7` | `bc81859db511a175889189ebf58503d3ecd4a5917a9a4d0a754facb55ef107fc` |
| F3 | `25e0b66c552a7fdc052486cc0a6822dadcd82e41` | `fdace646eb985a57ac3e0d5486d5cf0d55b637ba0328eff92b13e5d7f8df30d3` |
| F4 | `25e0b66c552a7fdc052486cc0a6822dadcd82e41` | `3fe4da5acbd4a1216494f6b06e0e764e6567a41aa163df84e43e129230baff62` |

No historical Canonical capture, approval, review record, or immutable baseline
was rewritten. The comparison criteria and all test code are unchanged.

Validation reproduced exactly three missing-field failures in both Bash and
PowerShell before refresh. The updated corpus passes both complete structural
suites. Removing the field or replacing its name with `Unknown-Review-Status`
is still rejected by the existing refresh validator for all three full states
in both runtimes (12 negative controls), without modifying the checked-in
corpus. This verifies current structure; it does not claim a new native run or
completion of the remaining A7/A8/A9 acceptance conditions.


## Reviewed consumer snapshot

The T-004 consumer snapshot retains its original requirements-template hash
`16250a183bf286f1967f160bc816c73f882e0f53158cd4fb11a09e9acdadf5d8`.
The test now validates the single reviewed change from `24fd8033` explicitly:
current full-file SHA-256 must equal
`903a725c445fac4505dfea3a3ac7aaf13b37fdb103ccffc1d1a6d1608dc940b5`,
and undoing only the exact Pending field immediately after the existing title
must reproduce the original full-file digest. All other consumer paths still
use their original complete digest comparison. The baseline JSON and product
bytes are unchanged.

Regression controls reject a missing, Passed, unknown, duplicated, or moved
status field; an unrelated body edit; replacement of the old baseline digest;
and modification of another template. The original failing pin assertion is
retained on the strict reviewed-change path, rather than skipped or refreshed
from whatever current bytes happen to contain.
