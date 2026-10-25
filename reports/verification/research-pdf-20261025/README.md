# Optional PDF extraction and verification

Actual synthetic PDFs pass through the same isolated pypdf layout recipe used by acquisition and source-evidence re-verification. Existing reference-only output and local-cache rights boundaries remain unchanged. No third-party originals are stored in this report.

- `acquisition.txt`: 27 tests, including actual two-column PDF layout, parser version/source fingerprint, encrypted/image-only/malformed PDFs, extraction-order/recipe forgery, HTTP fixture acquisition metadata and parent transport handoff, plus existing SSRF/timeout/rights/cache-preservation cases.
- Namespace fault injection uses a clearly labeled synthetic parser: inherited environment and host fixture files/network are unavailable; writing and fork are denied. The actual PDF cases use installed pypdf 6.10.0, separately from those probes.
- The stdout-flood regression attempts 64 MiB; the regular anonymous output file stops at 3 MiB, `communicate` returns no stdout buffer and the result is rejected.
- `project-runner.txt`: 35 existing lifecycle tests confirm the reused supervisor's original runner behavior. `consumers.txt`: 14 existing original/quotation/graph/report tests. `mirrors.txt`: staged historical evidence remains intact.
- `independent-intermediate-findings.json` preserves an earlier 64 MiB parent-buffer finding and a pre-supervisor timeout zombie. These are historical failures, not final results.
- `independent-supervised-cleanup.json` records the final real timeout probes: all four PDF descendants and all six nested acquisition/PDF descendants disappeared, including zombies. The test budgets were explicitly shortened to 0.3/0.7 seconds; production parser budget remains ten seconds plus bounded cleanup.

The existing Linux project process subreaper is reused for both PDF and fetch supervision. Original project-runner stdin behavior remains default; only research opts into inherited input and bounded regular-file output. Parser mounts are read-only, namespace identity is non-root, capabilities are dropped, and inherited resource ceilings cannot be increased.

Scope: Linux with usable bubblewrap/user namespaces, pypdf and the installed shared supervisor. Unsupported hosts/dependencies fail explicitly; macOS/Windows PDF success is not claimed. Forced destruction of the calling application itself still depends on host init to reap the final controller. Normal timeout cleanup is the tested guarantee. Source string matching does not prove reading order or semantic support; no OCR, PDF actions, passwords or attachment execution is introduced.

Licensed shared storage and subtitle/video-time support remain separate implementation work. This checkpoint does not close all research Issues or claim final hosted CI success.
