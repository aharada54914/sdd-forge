# Questions and delivery

## Sub-features
Shared inbox, real component alternatives, selection, delivery, receipt, freshness and isolation.

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
