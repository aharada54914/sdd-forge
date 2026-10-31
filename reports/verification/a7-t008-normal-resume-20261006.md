# A7 T-008 normal native continuation — 2026-10-06

Diagnostic only. No acceptance, formal verdict, task state, reservation, CI or merge is established by this record.

The existing session `c3811461-1e2d-4571-8afc-e1979980b656` was resumed in its original `/private/tmp/a7-realhost-spy.nhCxLM/repo` directory using Sonnet and the same two plugin directories. No matching A7 process was running before launch. No permission flags, hook-disable flags, settings edits or alternate executors were used.

1. Ordinary interactive resume without a prompt exited 1: `No deferred tool marker found in the resumed session` and requested a continuation prompt.
2. Normal resume with a bounded diagnostic prompt exited 0, but the requested command did not execute. The prompt requested only `bash scripts/check-sdd-structure.sh`, stopping on denial without writes or reservations.
3. The actual session transcript confirms tool `toolu_01DW99tG15TffbuaGaKwxBRc` was stopped by Fact-Forcing Gate at `2026-10-05T16:44:20.452Z`. After stating the required facts, the same command's tool `toolu_01AAocmCEZKAuLud4X5Hw3TR` was denied with `This command requires approval` at `2026-10-05T16:44:24.631Z`. The hook-disable suggestion was not followed.

Evidence source: `/Users/jrmag/.claude/projects/-private-tmp-a7-realhost-spy-nhCxLM-repo/c3811461-1e2d-4571-8afc-e1979980b656.jsonl`. These are new observed tool results, not a reinterpretation of the historical zero-call trace.

The separately prepared positive checkout `/private/tmp/a7-t008-native-preparation.LN0bu0/repo` still has none of `sdd/project-context.yaml`, `sdd/project-context.approval.json`, or `sdd/approver-registry.yaml` (literal-path existence check, exit 1). Therefore it cannot supply a valid signed positive input. The existing signing contract requires a genuine human/CI signer; no key was read and no signing or registry publication was attempted.

Remaining minimum conditions: normal approval of the precise native prerequisite command, and genuine signed positive-input publication. Then validate that sidecar, run the host's own hook handshake, and observe the real interviewer dispatcher path before accepting positive/negative spy evidence. PATH-only zero observations are not sufficient. The inventory repair's two protected targets remain on the separate sanctioned-application path; no new formal reservation was made here.
