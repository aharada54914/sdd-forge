# Frontend spec: CI efficiency and current model selection

## Technology Stack

### CI workstream

N/A — no change: no browser or desktop frontend. Existing GitHub Actions UI renders statuses and text summaries.

### Model workstream

N/A — no change: this feature adds no graphical frontend. Host CLI and text evidence are covered by ux-spec.md.

## Components and State

N/A — no change: there is no product frontend state. REQ-004/005 summaries are owned by the workflow and aggregate.

## API Integration

### CI workstream

N/A — no frontend API. Read-only Actions metadata access is infrastructure, described in infra-spec.md.

### Model workstream

N/A — no frontend integration. Host protocol adapters are infrastructure, with typed discovery and delivery contracts.

## Testing

### CI workstream

TEST-016 and TEST-036 inspect hosted contexts and summary data; no visual UI test is needed.

### Model workstream

No graphical screenshots or UI tests. Installed-host reachability, selector and protocol tests cover the actual surface.

## Open Questions

### CI workstream

None specific to this layer.

### Model workstream

None for this layer. OQ-002 belongs to infrastructure.

## Component Tree

### CI workstream

N/A — no change: GitHub owns the frontend.

### Model workstream

N/A — no graphical component tree; existing host command entries are covered in UX.

## State Shape

### CI workstream

N/A — no frontend state; CI plan contract is defined in design.md.

### Model workstream

N/A — no frontend state. Runtime selection and delivery records are defined in design.md.

## Routes and Components

### CI workstream

N/A — no new application route.

### Model workstream

N/A — no application routes or graphical components.

## API Client Strategy

### CI workstream

N/A — no browser API client; Actions metadata is read in the aggregate job.

### Model workstream

N/A — no frontend API client. Host adapters are infrastructure.

## Code Splitting and Size Budget

### CI workstream

N/A — no frontend bundle.

### Model workstream

N/A — no frontend bundle.

## Performance Budget

### CI workstream

N/A — no frontend performance change; job timing is measured under REQ-009.

### Model workstream

No frontend timing budget. Discovery has bounded timeout/size in infrastructure.

## Empty, Loading, Error, and Success Behavior

### CI workstream

Existing GitHub status rendering; plan/result semantics are in ux-spec.md.

### Model workstream

Existing CLI displays typed states from ux-spec.md; no new graphical view.

## Dependencies

### CI workstream

No frontend dependency added.

### Model workstream

No frontend dependency added.

## Component Architecture

N/A — no change: existing command entry points remain.

## State Management

N/A — no change: per-run model records are runtime evidence, specified in design.md.

## Routing

N/A — no change: no application routes.

## Form Validation

N/A — no forms. CLI/config validation belongs to the existing selector and host helper.

## Error Handling

REQ-016 / AC-016: existing CLI output displays typed blocked/unverified/mismatch reasons; no new frontend error view.

## Accessibility

REQ-020 / AC-020: plain text diagnostics and documentation, specified in ux-spec.md.

## Performance

No UI performance target. Discovery runs once before a new managed attempt; no recurring inference merely to refresh a display.

