# Claude HTML import and actual UI verification

The authenticated Claude artifact source was acquired from the existing source
panel, stored as artifact.html and executed in a fresh local Chromium session.
Actual add/Enter, complete, delete confirmation/cancel, empty-input association,
live feedback and mobile width checks passed. Inert markup became DOM markup,
and reload discarded in-memory tasks: this mockup was not copied wholesale.

Full and SQLite integration copies adopt action-specific live feedback; Full
also adds atomic announcements and explicit invalid-input/error association.
The existing approved tokens, safe DOM rendering, APIs and persistent stores
remain intact. Before/after focused checks show Full gains six missing feedback
properties and SQLite gains two state-specific announcements. All 11 focused
checks pass for each integrated app; unit and existing browser results are
recorded separately. Initial SQLite regression expected the old generic wording;
it was updated to require the new explicit completed-state message.

Application directories and exact baseline-to-integration patches are listed
in SUMMARY.json. Original completed workflows and their immutable evidence are
preserved. This is real browser-export integration, not native DesignSync or
another full specification/approval/implementation workflow completion.

Exact acquired bytes are retained in artifact.raw.html.gz; readable artifact.html
trims trailing whitespace only. The patches use zero context (`git apply --unidiff-zero`) and are already
applied in the separate integration copies.
