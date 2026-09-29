# Issue 137 — Git HEAD object-ID contract addendum

Date: 2026-09-29
Scope: ProjectionV1.head only; non-frozen addendum.

## Authority and precedence

The main agent relayed the user's existing authorization for this single design/root-cause correction after independent Astra review identified the Git OID contract mismatch as Major. The received instruction authorizes this addendum and fixed regression RED first; production modification remains held until the main agent reviews these inputs. This record is not a review PASS, ledger reservation, task approval/status update, quality gate or implementation-completion claim.

The frozen `design.md:81` describes hashes as lowercase 64-hex SHA-256, while `design.md:91,137,141–143` separately defines ProjectionV1.head as Git HEAD/freshness rather than owner identity. The current implementation applies its SHA-256 helper (`plugins/sdd-context/validation.mjs:25`) to `value.head` at line 121; Git ownership/root validation is at lines 154–156. Pre-correction source SHA-256 is `e8378d8f121f5b44f522ff1ef0e23a2e4b8de72e164f7538ce0ed6b157885bae`.

At the affected checkout, actual read-only commands `rtk proxy git rev-parse --show-object-format=storage` and `rtk proxy git rev-parse HEAD` returned `sha1` and `40f1c79cdede2a67abe7e5e2b28b1d38a5b3fe78`. Git version was `2.54.0 (Apple Git-157)`. These are dated observations, not permanent repository-format assumptions: reverify actual root/format at every RED/GREEN run and at every production admission that consumes this contract. Do not cache format across owners or use caller input as format authority.

**Dated supersession, 2026-09-29:** for ProjectionV1.head only, this addendum takes precedence over applying the general `design.md:81` 64-hex digest grammar to Git HEAD, and over the prior implementation report's 64-hex HEAD interpretation. The frozen design, old contract-completion addendum, old fixed test snapshot, old RED/GREEN files and old manifests/receipts stay byte-identical. All non-HEAD SHA-256 digest contracts retain their original grammar.

## Corrected contract

1. `ProjectionV1.head` is a lowercase, complete Git object ID matching the **storage object format of the same independently verified canonical worktree/root and Git directory**: `sha1` means exactly 40 ASCII hex characters; `sha256` means exactly 64 ASCII hex characters.
2. Obtain the storage format from actual Git at that verified root (the runtime equivalent of `git -C <verified-root> rev-parse --show-object-format=storage`), under the original trusted deadline. Unsupported format, unavailable/erroring Git or ownership mismatch rejects without content or a writable result. A format in a request or a context hint does not select the rule.
3. Do not accept both lengths unconditionally. Wrong-format OIDs, abbreviated/wrong-length OIDs, uppercase and non-hex values reject. Do not hash, truncate, pad, normalize or convert a Git OID into a different digest to obtain admission.
4. Authority entry `sha256`, CursorV1 `hash`, DecisionV1 materialization `sha256`, and the other source/journal integrity digests remain lowercase 64-hex SHA-256. This exception is only for the `head` field.
5. T-001 validates type/format, owner and safe path admission. Correctly shaped OID admission does **not** claim equality with current HEAD, object existence, freshness, sync, publication or a safe/captured outcome. Current HEAD and authority changes invalidating stale projections remain the existing T-003 responsibility (`tasks.md:79`; `design.md:137,141–143`). A future caller must supply the saved full OID and revalidate actual owner/path at use; it cannot infer freshness from this admission.

## Fixed real-Git regression and mismatch preflight

The previous test used a synthetic 64-character `head` (`tests/sdd-context/validation.test.mjs:47–52` in old snapshot `validation-red-20260929-01a0ebb9/input-snapshot/tests/sdd-context/validation.test.mjs`) while initializing its normal fixture without an explicit object format (old lines 22–32). The new test retains all 28 cases, uses an explicitly sha256 baseline with an actual empty fixture commit/HEAD, and adds an explicitly sha1 committed fixture. Commits occur only inside disposable test repositories, with synthetic test-only author/committer identity; no project commit or push is authorized. Fixture setup uses actual Git via `rtk proxy`; no pseudo-Git or admission substitute is introduced.

| Candidate field / decision | Counterpart | Fixed mismatch or positive case |
|---|---|---|
| ProjectionV1.head complete lowercase OID | Actual verified fixture root's Git storage format and native HEAD | HEAD-VALID-sha1 / HEAD-VALID-sha256 accept real 40/64 OIDs despite contradictory context hints |
| Head length cannot select its own format | Actual Git storage format, not another repository's OID | HEAD-WRONG-FORMAT-sha1 / HEAD-WRONG-FORMAT-sha256 reject the other fixture's real OID |
| Head spelling/complete length | Same root's exact 40/64 rule | HEAD-MALFORMED-sha1 / HEAD-MALFORMED-sha256 reject length -1/+1, uppercase and non-hex |
| Request format field | Closed ProjectionV1 input | HEAD-CALLER-FORMAT rejects a caller-supplied objectFormat field |
| Invalid/unsupported storage-format configuration | Actual Git refusal, not a mocked output | HEAD-UNSUPPORTED-GIT rejects a real fixture whose Git format configuration is unsupported |
| Existing SHA-256 digest fields | Unchanged design/addendum and existing validation helper | Existing HASH-FORMAT / CURSOR-CLOSED assertions remain; no production digest change is authorized |

Current Git rejects an unsupported format configuration itself. That fixture therefore exercises actual Git failure and content-free admission rejection; it cannot prove a future Git version's successful output naming an additional algorithm. The production rule must independently allow only sha1/sha256. Real native lifecycle/ACL evidence, full T-001 contracts, T-003 freshness and formal gates remain outside this slice.

## Identifier sweep and unchanged sibling claims

Before review, `rg -n '64-hex|64.hex|HEAD|\bhead\b|ProjectionV1'` covered requirements, design, acceptance tests, all four layer specs and tasks. The only numeric general-hash rule was `design.md:81`; its HEAD application is superseded above. All other hits describe unchanged ownership/freshness behavior: `requirements.md:41,81`, `design.md:91,137,141,242`, `acceptance-tests.md:25–26`, `frontend-spec.md:36`, `security-spec.md:39`, `tasks.md:79`. UX and infra specs had no matching claim. Frozen siblings are retained; this dated addendum governs the narrow exception without rewriting them.

Execution results and exact input/output hashes belong in the new HEAD RED evidence and implementation-report addendum. The regression and preflight are not an executed RED claim until those records exist. No previous verdict is reclassified.
