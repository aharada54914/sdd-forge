# Local file collector and publisher

`collect-progress.py` reads explicitly configured roots, without editing them, and
publishes the existing `sdd-dashboard/v1` and `sdd-monitor/v1` contracts. It uses
Python's standard library for transport. In production, configure the existing
built sdd-forge MCP server and its supported Node runtime; the bundled
`read-workflow-metadata.mjs` uses that server's installed MCP SDK and real stdio
tools. `list_active_specs` preserves registered features without tasks, while
`get_next_sdd_command` and `get_task_state` supply canonical workflow metadata
and validation findings. Publisher/service secrets are excluded from both child
process environments. Task titles/body text still come from readable task files. Source IDs namespace feature and
task IDs across repositories. Unknown/duplicate states or an unavailable source
fail collection; the last successfully published data remains visible with an
error rather than silently omitting the source.

A config is an object with `project` (the existing production project name) and
`sources`, an array of `{ "id": "unique-alias", "label": "Display label",
"root": "/absolute/source/root" }`. An explicit `namespace: ""` preserves an
existing main project's feature IDs, task keys and source paths. Otherwise the
source ID is used as namespace. Optional `displayNames` maps existing feature
names to their already-published display labels. Include only intended roots.
For the canonical read model, configure `readModel: { "node": "/path/to/node",
"server": "/path/to/sdd-forge-mcp/dist/index.js" }`. Build that existing package
using its supported Node version and installed dependencies before running the
collector. The adapter is read-only and never invokes implementation tools.
The initial authenticated dashboard GET checks existing project identity before
any write. An existing project cannot be replaced by choosing another name.

The runtime requires `SDD_PUBLISHER_TOKEN` to contain an already authorized
publisher credential. On private Sites, `SDD_SITES_SERVICE_TOKEN` may additionally
be required by the platform. Supply secrets through the execution environment,
not config/source files, command arguments, logs or committed artifacts. The
client refuses redirects so credentials cannot be forwarded to another URL.
This script cannot recover or rotate an existing Site secret or renew a platform
service token by itself.

```
python3 scripts/collect-progress.py --config /path/to/sources.json \
  --endpoint https://your-existing-site.chatgpt.site --cycles 3
python3 scripts/collect-progress.py --config /path/to/sources.json \
  --endpoint https://your-existing-site.chatgpt.site --watch --interval 5
```

Default execution is one bounded cycle. `--watch` is explicit foreground polling;
no daemon, cloud-startup hook or unattended scheduling is installed. Interrupting
it stops publication. Use the normal host's process manager only when authorized
for ongoing operation. Restarts read the previous snapshot, preserve unchanged
content age, and resume observation time. `collectorRestarts: 0` means this process
has no internally supervised child restarts; it is not a machine-lifetime count.
The frontend shows source age and failed collections, so a stopped process must
not be described as a live connection after the timestamp becomes stale.

The snapshots report source task state and the canonical MCP read model; they
do not run a new independent quality review. MCP-reported failures remain visible.
The adapter does not duplicate workflow rules. If MCP cannot determine a phase,
that feature remains `unknown` with an explicit warning. An intentionally
configured filesystem-only run (no `readModel`) reports every phase as `unknown`
and next-command empty, with a warning; it must not claim canonical phase coverage. A conflict re-fetches and checks project identity before the next cycle;
an authorization failure stops instead of endlessly retrying the same credential.
The old three-session static verification section remains a separate saved
snapshot until its frontend is deliberately revised.

Successful snapshot and health publication are required for a zero final exit.
Publisher errors are classified without echoing response bodies or credentials.
A production end-to-end claim still requires actual authorized publication and
observation in the real authenticated browser; local in-memory R2 tests are not
that claim.

For this managed workspace, the verified runtime is Node 26.13.0 at
`/workspace/.tools/sdd-forge-dev/verification-tools/node-v26.13.0-linux-x64/bin/node`
and the existing built server is
`/workspace/sdd-forge/mcp/sdd-forge-mcp/dist/index.js`. Keep both paths explicit
in the local source config; they are not installed by the Site Worker. The
metadata adapter has a 180-second process timeout and an 8 MiB output ceiling;
timeout or interruption terminates its owned process group. Only PATH, locale
and timezone enter that process group, never the publisher or service secrets.
