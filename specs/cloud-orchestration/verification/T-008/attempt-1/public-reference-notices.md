# Public reference attribution and publication exclusions

This addendum supplies notices without changing any frozen source snapshot or
historical report. `public-reference-inventory.json` maps exact source URL,
recorded acquisition provenance, SHA-256, matching local copies and applicable
license. Mutable main URLs are historical hash-bound retrievals, not immutable
Git revisions. `license-acquisition.json` records this task's actual read-only
license retrievals and hashes; the three reconnaissance hashes were reproduced.

- Azure REST API specifications: Microsoft Corporation, MIT. Preserve the full
  copyright and permission notice in `licenses/azure-rest-api-specs-MIT.txt`.
- GitHub REST API description: GitHub, Inc., MIT. Preserve the full notice in
  `licenses/github-rest-api-description-MIT.txt`.
- MicrosoftDocs Azure documentation: Microsoft and contributors, CC BY 4.0,
  `licenses/azure-docs-CC-BY-4.0.txt`. Includes “List Azure role assignments using
  the REST API” at the exact source URL in the inventory.
- MicrosoftDocs Entra documentation: Microsoft and contributors, CC BY 4.0,
  `licenses/entra-docs-CC-BY-4.0.txt`. Includes “Best practice recommendations for
  managed identities” at the exact source URL in the inventory. This is a
  different repository from azure-docs; its license was separately acquired.
- botocore service models: Amazon.com, Inc. or its affiliates, Apache 2.0 at
  commit 4de93abe62cc263980414f7a66be5226bd541b77. Preserve both
  `licenses/botocore-Apache-2.0.txt` and `licenses/botocore-NOTICE.txt`.

The cited source copies are unmodified; relocation/renaming and this separate
index are the only presentation changes. Attribution does not imply endorsement.
CC BY terms and license links are retained in the full notices. Existing provider
vendored upstream skill licenses/notices remain untouched and still apply.
Repository-authored acquisition JSON, reports and workspace policies are not
misclassified as third-party API source simply because they are named external.

## Restricted publication

Seven full AWS HTML references have no established applicable redistribution
permission. `publication-exclusions.json` lists local path, exact SHA-256 and
source URL; retain local frozen bytes, do not publish the HTML. Their public URL
is not a license grant. Root must exclude them explicitly from staging and verify
the final curated tree. URL/digest references allow independent retrieval but do
not pretend the complete historical inputs are distributed.

Raw native-events.jsonl, native-stderr.log and account metadata are separately
private and must never be staged. No content from them is reproduced here.
These exclusions do not rewrite frozen manifests or historical review claims;
root must disclose intentionally unavailable source inputs in release evidence.

Additional provenance correction: the AWS CloudFormation service-authorization
JSON comes from servicereference.us-east-1.amazonaws.com, **not botocore**.
Root's explicit disposition classifies this narrow dataset as public factual API
metadata (machine identifiers/ARN formats/condition keys/SDK mappings/booleans/version),
not full documentation prose or source code. factual-api-metadata.json retains
source/hash attribution with **no license claim**. Lack of an explicit documentation
license does not itself block this factual dataset. Root will bind the final factual
inspection record before publication. The seven full-text HTML exclusions remain.
