# README selection activation evidence

Baseline f80ac878fb815b029e5b07f9d9dc4035c387bffd ran full in GitHub run 39647850787 and passed the unchanged collector/aggregate: 448 verified obligations and one expected inactive advisory obligation. Mutation 78170dded31b9f9db346192ebc6acecbd0264a58 changed only the README release marker to v0.0.0 and ran full in run 39647858757. Its aggregate is intentionally FAIL/execution-failed: 179 failures, 269 verified obligations, one inactive advisory. All 179 failures are retained by the 443-obligation category; all six omitted CLI obligations passed. No acquisition/binding errors count as mutation evidence.

Restore f43e84ca2453fa9c9c8c328568d6c16515fcb8a0 restores the exact baseline README and tree through B → M → R ancestry. Consumer hashes were recomputed from 44 actual baseline Git blobs; no historical hash restamping was used.

The original tests/verification-ci.py collector SHA256 is 2705fb54c1cdaf5a0bfcadffe700153e401f0be240db40293dd60e9a72ddb6c1. The previously committed connector transport adapter supplies only exact authorized artifact ZIP bytes where shell artifact redirects were unavailable; all other API acquisition, validation, extraction and aggregation remain original. Baseline has 14 receipt ZIPs; mutation has 11 because early failing jobs produced no receipt. Full actual job outcomes remain authoritative. Original ZIPs remain external and their API digests are recorded. The observations directories preserve replay inputs without signed download URLs, credentials or private sessions.

Full hosted acceptance of a future activation commit, four representative normal/full pairs, local full profiles and final release installation checks remain separate conditions. This evidence does not assert those later checks have completed. Historical superseded failed/cancelled attempts remain diagnostic and are not activation authority.

## Exact-byte replay

Nine Windows receipt JSON files originally contain CRLF bytes. Git's existing text attributes normalize JSON line endings, so those nine passive copies are stored as `original.json.base64.json` envelopes. Each envelope declares its original observations-relative path, original SHA256, encoding and reversible data. Original extracted receipts remain unchanged outside Git. Collection and transport records retain their original hashes; no receipt was normalized or restamped.

For replay, copy each side's observations directory to an external scratch directory, decode each envelope's base64 data into its declared `original_relative_path` there, verify SHA256 against `original_sha256`, and remove the envelope files from that scratch copy. Then invoke the unchanged aggregate against those reconstructed observations and the exact original tested checkout/plan. The committed envelopes are passive evidence, not a new collector or execution engine.
