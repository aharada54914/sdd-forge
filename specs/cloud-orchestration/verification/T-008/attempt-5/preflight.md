# T-008 attempt 5 acceptance-first preflight

Recorded before product edits. Medium risk; no commit per explicit launch boundary.
No new persisted product fields, contracts or verdicts. Reuse only report bytes and
listing diagnostics within a synchronous operation; never task/bundle results.

| Field / invariant | Counterpart | Executed mismatch / matched control planned |
|---|---|---|
| Full task result, failures/messages | Legacy parser over identical data | Full real-root parse outputs byte comparison; synthetic Done missing/invalid bundles/contracts, report FAIL/no mention vs PASS controls |
| Report reads bounded per request | One guarded directory snapshot per root + directory | Existing parseTaskState/listActiveSpecs with multiple completed tasks must read each report once, measured with pass-through fs spy; legacy excess must actually fail assertion |
| Report match paths/order/boundaries and diagnostics | Existing report helpers with no optional snapshot | Compare missing/denied/oversize/symlink/partial-read results; wholeword negative and later PASS positive controls |
| Freshness, no stale PASS | New request obtains new guarded bytes | Rewrite, replace, delete and deny report between parser requests; restore PASS control |
| Independent roots | Root identity supplied at guard boundary | Shared operation context must not return first root contents to second root |
| Done bundle/contract checks uncached | Existing live guarded reads | Change contract risk/id and bundle between requests; retain all original failure text |

A lazy directory snapshot observes report bytes at first scan, not an atomic
filesystem transaction. Within one synchronous call it reuses those bytes;
external mid-call mutations are not promised atomic visibility. No context is
stored on server/root/module or reused across requests. Legacy helper calls with
no snapshot retain their existing read behavior. Guards execute on snapshot load.
Timing is observational only, never a portable test threshold.
