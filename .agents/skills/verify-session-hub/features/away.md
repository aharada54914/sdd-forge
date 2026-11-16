# Away execution

## Sub-features
Default-off, explicit job approval, local allowlist, resource waiting, cancellation and uncertainty.

## How to get to it (user POV)
Use `/hub` → 離席モード. Enable the mode and add a task using a registered session
and an allowlisted local command ID. Inspect the task result or request stop.

## Driving it with the harness
The browser harness submits the form, runs the actual worker against that queue and
checks a disposable file plus displayed success. HTTP tests drive pause, resource shortage,
unlisted commands, cancellation, timeout and uncertain leases.

## Gotchas
No execution after OS shutdown. Resource checks gate start, not runtime consumption.
Never repeat uncertain tasks until their process and effects have been examined.
