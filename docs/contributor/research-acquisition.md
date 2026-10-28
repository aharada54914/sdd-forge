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
