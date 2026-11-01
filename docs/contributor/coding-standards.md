# Coding standards

These rules apply to current runtime code, tests, CI, configuration and shipped examples in Bash, PowerShell, Python and TypeScript/JavaScript. They specify product properties, not a new approval process. Existing Full/Lite gates, registry, process supervision, collectors and mirror ownership remain authoritative. Existing violations are in scope; a baseline is not an exemption.

Start with [common rules](coding-standards/common.md) and the relevant [Bash](coding-standards/bash.md), [PowerShell](coding-standards/powershell.md), [Python](coding-standards/python.md) or [TypeScript/JavaScript](coding-standards/typescript-javascript.md) boundary notes. The [research map](coding-standards/research/map.md) distinguishes reports, official advice and experimental evidence; none establishes the prevalence of defects in every model. [Audit contract](coding-standards/audit/README.md) defines the whole-population ledger and unresolved states.

A native tool can prove only the rules it actually executes over the recorded files. Lexical matches are candidates, not a data-flow proof. Context rules require named review evidence; missing runtimes, unknown results and unsupported hosts never become zero findings or PASS. Normal display interpolation, schema literals, mathematical constants and intentional fixtures are not banned. A documented exception includes its precise input assumptions, scope, rationale and negative/control verification.

Rule IDs below are a reference index, not a second gate registry. Check ownership is #687; implementation ownership is #688 (shell/CI), #689 (Python), #690 (TS/JS), #691 (shared responsibilities); final integration and population closure belong to #692.

The [native-check contract](../../tests/coding-standards/README.md) records the actual installed versions and enforced subset. Only CS-001/010/012/019/020/021 have selected native checks, each with narrower coverage than its complete rule. All other rules and remaining contextual parts still require review; native zero findings does not close the whole-population audit.
