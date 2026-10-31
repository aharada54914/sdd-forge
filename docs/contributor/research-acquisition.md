# Bounded research acquisition

The installed bootstrap helper `research-acquire.py` retrieves a specified
public URL only for explicitly allowed hosts. It checks DNS addresses and each
redirect, bounds response size and time, and defaults to reference-only metadata
rather than retaining the original. Its direct transport refuses an inherited
proxy; it does not claim to enforce a remote proxy's DNS or peer boundary.

Local caching requires an explicit permission basis and expiry. Shared storage
uses a separate constrained local adapter; it does not establish legal rights.
PDF extraction requires the Linux-owned process supervisor and an available
isolated extractor. Unsupported PDF environments report the limitation. Non-Linux
network work uses a bounded direct worker and has not been demonstrated to own
detached process trees.

The quality-plugin `research-evidence-tools.py` exposes local quote checking,
graph, impact and report operations against the evidence contract. These are
checks over supplied bytes and metadata; they do not establish source truth,
permission to distribute, human approval or gate PASS.

## Source-pinned verification

Historical evaluations remain at source commit
`b1c828355d3b3ff5633f23c4b1d8f28b030817b0`:

- [HTML display and keyboard fixture](https://github.com/aharada54914/sdd-forge/blob/b1c828355d3b3ff5633f23c4b1d8f28b030817b0/reports/verification/research-display-20261025/README.md)
- [Linux PDF extraction](https://github.com/aharada54914/sdd-forge/blob/b1c828355d3b3ff5633f23c4b1d8f28b030817b0/reports/verification/research-pdf-20261025/README.md)
- [Subtitle extraction and display](https://github.com/aharada54914/sdd-forge/blob/b1c828355d3b3ff5633f23c4b1d8f28b030817b0/reports/verification/research-subtitles-20261025/README.md)
- [Shared storage and distinct-reader checks](https://github.com/aharada54914/sdd-forge/blob/b1c828355d3b3ff5633f23c4b1d8f28b030817b0/reports/verification/research-shared-store-20261025/README.md)
- [Bounded research procedure and unavailable acquisition](https://github.com/aharada54914/sdd-forge/blob/b1c828355d3b3ff5633f23c4b1d8f28b030817b0/reports/verification/research-workflow-20261025/README.md)

These records preserve their original inputs and limitations. They do not certify
new native platforms or turn blocked live acquisition into a successful fetch.
Current combined workflow-owner validation is recorded in the
[integration report](../../reports/verification/research-workflow-integration-20261031/README.md).
