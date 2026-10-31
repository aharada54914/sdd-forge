## Project Settings

Project-level configuration keys agents must honor. An absent key, or an
absent section entirely, uses the stated default. Both absences are
independently tested (`requirements.md` AC-003). A present key whose value
is not exactly one of the listed lowercase literals -- a typo, a case
variant such as `Standing`, or an unknown value -- also uses the stated
default, by case-insensitive matching that folds case (round 3, ruling F /
`requirements.md` AC-031): never `standing`, never `off`.

| Key | Values | Default | Meaning |
|---|---|---|---|
| `ds_upload_consent` | `standing` \| `per-feature` \| `off` | `per-feature` | Governs `design-sync-loop`'s egress behaviour for uploads to claude.ai/design (SKILL.md step 3), identically on every host, re-read at every resolution of that step (never cached per session -- round 2, ruling A). `per-feature`: DS-29's shipped behaviour -- one confirmation per feature and session. `standing`: skip the per-feature confirmation; write one audit record to `Design-Source` per feature-and-destination, the first time, as `granted` (round 2, ruling B). `off`: forbid the upload on every host; step 3 always resolves to its "not permitted" outcome and the loop takes the manual fallback. |
