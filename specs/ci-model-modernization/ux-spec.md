# Ux spec: CI efficiency and current model selection

## Scope and User Journeys

### CI workstream

REQ-001–010 / AC-001–010. Entry is the ordinary GitHub PR checks page or existing manual workflow dispatch. No graphical application is added. Contributors see stable required native contexts and a final aggregate. The summary explains full versus affected execution, selected work, planned omissions and any inability to prove execution.

### Model workstream

REQ-011–REQ-020 / AC-011–AC-020. Existing implementation, investigation, review, evaluation and maintenance commands are the entry points. A user sees the requested policy, selected native model/effort, source date and reason. Explicit pinning is discoverable in the same command/configuration documentation. No graphical app or additional approval flow is introduced.

## Information Architecture

### CI workstream

Use one run summary linking the plan and actual observations. List short reason codes and bounded escaped paths; never render raw file text or credentials as HTML/Markdown instructions. Historical timings remain attached to their own commit.

### Model workstream

One selection record and one delivery record per managed run link policy/catalog/availability hashes to run/session. Display configured/resolved and actual-reported model identities separately. Unknown execution identity is labelled unverified; a configured model name is not presented as execution telemetry.

## Main Flows

### CI workstream

PR → trusted planning → native integrity checks and selected groups → aggregate. Unknown information selects full. Missing selected evidence yields failure with the missing obligation. Operator force-full bypasses selective rules and runs the existing complete workflow. A failed selected test is still a failure.

### Model workstream

Ordinary command → validated latest-compatible role policy → host availability → existing capability selector → fixed launch → identity-aware completion. Explicit model override → pinned policy → same access/capability checks. Unknown successor → update-candidate notice and latest-verified selection only when policy permits, never a false newest-available claim. No eligible current candidate → typed blocked reason and documented explicit pinning route.

## UI Integration Checklist

### CI workstream

TEST-016 demonstrates actual PR reachability and four contexts. TEST-026 demonstrates operator full recovery. Do not add a new application menu or approval dialog. No mockup provided — optional visualization skipped.

### Model workstream

Installed-host tests exercise the actual managed command/role path, not only generated comments. Unsupported native host validation is labelled unverified. No mockup provided — optional visualization skipped.

## Interaction States

### CI workstream

Planning, full, affected, running, NOT_SELECTED, failed, cancelled and completed are distinct. NOT_SELECTED does not mean PASS. Unavailable real-event validation is pending and is not counted as hosted success.

### Model workstream

Discovering, current-compatible selected, explicit pinned, unknown update candidate, unavailable, unsupported discovery, identity unverified, rerouted/mismatched, blocked and completed are distinct. A required actual-ID gate cannot start when the necessary proof surface is unavailable. Normal permitted runs expose the limitation instead of claiming exact execution identity.

## Design Tokens

### CI workstream

ds_profile: none. N/A — no change: CI text summaries only.

### Model workstream

ds_profile: none. N/A — no change: command-line and text evidence only.

## Accessibility

### CI workstream

Use readable plain-text reasons and links; do not communicate success/failure solely by color. Keep all failure reasons available in logs as text.

### Model workstream

Use clear text labels and actionable reason codes, not color alone. Show override provenance so users can diagnose native agent precedence. Do not print account credentials or large raw transport traces.

## Open Questions

### CI workstream

OQ-001 is owned by the repository administrator and resolved as documented in requirements: actual merge queue availability, not a new product flow.

### Model workstream

OQ-002: host metadata availability; integration maintainer owns official/schema validation and documented unsupported behavior. No additional product preference is required for the already-approved default.

## Target Views

### CI workstream

Existing PR checks, workflow run summary and downloadable plan/evidence. REQ-004/009; AC-004/009.

### Model workstream

Existing command output, per-run records, maintenance report and README/runbook. REQ-015/REQ-017/REQ-020; AC-015/AC-017/AC-020.

## Component States

### CI workstream

Use the Interaction States above. Native contexts remain present during both full and affected modes; an omitted optional lane has NOT_SELECTED status.

### Model workstream

Every selection has a policy and reason. Every proof field has an explicit value or unknown state; unknown price/identity is never rendered as zero or as a copied requested value.

## Interaction Sequence

### CI workstream

See Main Flows; each failure includes its missing/failed obligation and a full-run recovery instruction.

### Model workstream

See Main Flows. When model choice changes during resume, stop continuation and create a new attempt rather than silently mixing evidence.

## Wireframe Attachments

### CI workstream

No mockup provided — optional visualization skipped

### Model workstream

No mockup provided — optional visualization skipped

## Navigation Map

### CI workstream

PR → Checks → current run → summary → plan/evidence artifact. Manual run → existing Actions workflow dispatch.

### Model workstream

Existing SDD entry → selection summary → selection/delivery record → maintenance instructions when an update is needed.

## Responsive Behavior

### CI workstream

N/A — no change: GitHub owns responsive rendering; use short plain-text tables.

### Model workstream

N/A — no change: no responsive frontend.

