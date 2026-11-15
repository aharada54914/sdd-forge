# Visual specification decisions

Before asking for an important product/specification choice or approval, show
the problem, a diagram for each viable option, a comparison on the same axes
(benefit, drawback, scope), and a recommendation with its reason. Normally use
2–3 real options, one decision at a time; accept another proposal or deferral.
Simple factual questions do not need a board. Never fabricate options or metrics.

## Extend the existing status surface

The initiating parent uses the status skill's existing Site/Artifact identity,
read-only snapshot, authentication, freshness and publication lifecycle. Open
its **仕様の相談** (`#decisions`) view; do not create another Site, approval
service, inbox application or write endpoint. Use the actual host tools only.
If presentation is unavailable, report `PRESENTATION_UNAVAILABLE` and present
Mermaid plus a Markdown comparison table in conversation; if diagram rendering
is unavailable too, use a numbered text flow plus the table. Keep working within
the authorized scope. Optional DesignSync/product mockups remain optional and
do not replace this decision presentation.

The parent writes an optional `specs/<feature>/decisions.json` projection, schema
`sdd-decisions/v1`, with `decisions: []` before asking the question. Missing means
no registered questions, not an error; invalid data produces a source error and
last-good display, never an empty success. Domain-stage choices use the owning
feature's specification directory, not a new domain approval channel. If no
feature specification exists yet, use the conversation fallback until one exists;
do not invent a specification or task approval merely to populate the dashboard.

Each decision contains exactly:

- `id` (stable uppercase ID such as `Q-001`), `title`, `problem`, `status`
  (`pending`, `deferred`, or `decided`).
- `basis`: 1–10 `{path, sha256}` references to current sibling specification
  files: requirements, design, ux-spec, frontend-spec, infra-spec or security-spec
  Markdown. Hash raw UTF-8 bytes. Do not hash or edit frozen specs to refresh a
  display; follow existing amendment/re-review rules for substantive changes.
- `options`: 2–3 records with stable `id`, `title`, `benefit`, `drawback`, `impact`
  and `diagram: {kind, steps}`. Kind is `flow`, `states`, or `screen`; 1–8 steps
  label the flow/state sequence or screen elements in top-to-bottom order. Use
  the same diagram kind when comparing equivalent options. Screens are schematic,
  not a claim of pixel fidelity. All content is plain text, never executable HTML.
- `recommended` (an option ID), `reason` (recommendation rationale), `selected`
  and `resolution`. For pending/deferred both latter fields are null; for decided
  they contain the chosen option ID and a concise record reference/rationale.

Maximum 100 decisions per feature; text fields are nonempty and at most 2000
characters. IDs are unique within their decision/file. Full bounds live in
`contracts/sdd-dashboard.v1.schema.json` and the shared runtime validator.

## Selection, response and canonical recording

The view shows one decision at a time, option diagrams, a comparison table,
recommendation and explicit status. Native buttons support keyboard selection.
Other proposal and deferral remain available. Selection creates a browser-local
draft and a plain text response containing feature, decision ID, option ID and
display revision. The user sends that response through the conversation.
No browser action writes tasks, approvals, decisions, evidence or a gate verdict.
Drafts survive refresh only while the source revision matches, not page reload.

Do not infer approval from defaults, button presses, local state or a copied
response. Confirm the explicit conversational answer against the current
decision and specification revision. If it is stale, ambiguous or a new proposal,
resolve that first. Record the decision ID, choice, rationale, actual user-message
reference and related requirement IDs in the canonical Markdown specification
(or its sanctioned non-frozen addendum). Then regenerate the projection and its
basis hashes. `decided` describes a recorded product choice, never task approval.
Deferral keeps the question open and does not authorize dependent implementation.

Any basis mismatch visibly disables selection until the diagrams and comparison
are regenerated. Important scope changes require explicit reapproval under the
existing workflow. Do not silently refresh hashes to hide obsolete content.
The projection is not authoritative or proof of human authorship. Unknown facts
stay unknown. Include a text alternative for diagrams; narrow screens stack the
options, with a horizontally scrollable comparison only if necessary.
