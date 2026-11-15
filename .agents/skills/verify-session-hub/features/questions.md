# Questions and delivery

## Sub-features
Shared inbox, real component alternatives, selection, delivery, receipt, freshness, isolation and existing-session push.

## How to get to it (user POV)
Open `/hub`, enter the local owner token, choose a component, switch to receipt-waiting
or resolved questions. The target session retrieves its answer and confirms requestId.

## Driving it with the harness
Run `tests/session-hub-browser.mjs`. It drives login/selection/filter and records screenshots;
`tests/session-hub.tests.mjs` covers competing answers, restart and cross-session denial.
Success is the selected option at the real session API, then visible received state.

## Gotchas
Native Artifact requires real read/write adapters and consent. Missing adapters must remain
visible failures. Browser screenshots do not prove native hosted connectivity.

## Existing conversation push

Register a Codex UUID or Claude Code cloud ID as owner, then use the real send form.
`tests/session-hub.tests.mjs` drives the bridge through the actual HTTP outbox with
controlled native-process transports, checking single dispatch and exact target.
For native proof, start the existing host outside this harness, send to an explicitly
authorized test conversation, and read its transcript. Store the host receipt separately
from completion. No fixture can establish production Claude login or native OAuth.
