# T-009 field/counterpart/mismatch preflight (before product edits)

No registry or policy field is added, removed or rewritten. Persisted notification rows have these consumers:

| Field | Producer | Counterpart / consumer | Failing mismatch fixture |
|---|---|---|---|
| model ID | existing family-token allowlist; policy models[].id mapping | candidate/deprecation issue row | policy-known ID must not be new; cross-vendor text cannot deprecate another vendor |
| kind | candidate discovery or explicit structured deprecation row | fixed candidate/deprecation enum label in issue | absent model is never deprecated; prose mention of deprecated is insufficient |
| source | per-fetch fixed anthropic/openai label; policy known metadata separate | issue row fixed canonical URL list | fetched URL/prose never copied |
| sourceDate | explicit source publication HTML meta article:published_time; explicit deprecation table date | calendar-validated date or unknown | impossible dates/command strings => unknown; fetch time never substituted |
| policySourceDate | existing policy top-level source_date | labelled policy provenance in report, never provider publication date | invalid policy dates => unknown |
| policy metadata | existing models[].id/lifecycle/source_date/source_url | read-only known set and validated metadata summary | malicious fields never copied; current/candidate/historical/retired only |

Deprecation parser deliberately accepts only whole Markdown table rows `| MODEL-ID | deprecated (or retired) | DATE |`, not free prose. Published dates use standard HTML article:published_time metadata; missing/ambiguous/invalid publication dates stay unknown. This is conservative discovery, not automatic verification or adoption. Candidate lines preserve original token discovery. Shared policy and legacy catalog are read-only, malformed policy must stop notification rather than imply a complete comparison. Existing fetch fail-soft and marker dedup semantics remain.
