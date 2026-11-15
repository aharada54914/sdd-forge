# Visual specification decisions requirements
Spec-Review-Status: Pending

Human scope approval: the user explicitly approved B and required extending the
existing Artifacts/Sites progress visualization. This product decision is not a
claim that the formal spec review gate has passed. See `proposal.md` for the
approved comparison and `reports/verification/visual-spec-decisions/README.md`
for implementation/test evidence and verification limits.

| ID | Requirement | Acceptance |
| --- | --- | --- |
| REQ-001 | Important full/lite/domain specification choices show a problem, option diagrams, equal-axis comparison and justified recommendation, one decision at a time | AC-001 |
| REQ-002 | Extend the parent's retained private progress Site/Artifact, preserving the six existing views and optional v1 compatibility | AC-002 |
| REQ-003 | Options, other proposals and deferral produce only local drafts; explicit current conversational answers precede canonical recording and existing task approval | AC-003 |
| REQ-004 | Canonical Markdown stays authoritative; basis drift, stale data, source/transport errors and paused display prevent selection | AC-004 |
| REQ-005 | Bound and validate projection input through the existing path guard and render text safely | AC-005 |
| REQ-006 | Provide keyboard operation, narrow-screen reflow and text alternatives; unavailable hosts use conversation diagrams/tables | AC-006 |

No new service, workflow-write endpoint, dependency, public deployment, native
host API assumption or replacement approval authority is in scope. Native host
publication and model instruction-following require separate actual evidence;
local page/adapter testing must not be described as proof of either.
