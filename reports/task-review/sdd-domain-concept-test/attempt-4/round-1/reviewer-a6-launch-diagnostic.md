# Native formal Reviewer A launch

CLI: 0.160.0. Model: gpt-5.6-sol. Effort: high. Model fallback: false.
The actual owner-cwd hooks/list returned both SDD protective PreToolUse hooks enabled and trusted, with empty warnings/errors. Existing hook/config/trust settings were not changed. The standard-tier registration was independently audited; that audit is not task-review PASS evidence.

Actual fresh native thread/session: `01a10072-e1fa-7702-8c4a-71a2fee21070`.
thread/start response: turns=[], forkedFromId=null, parentThreadId=null; actual model=gpt-5.6-sol, reasoningEffort=high, approvalPolicy=never, sandbox={type:readOnly,networkAccess:false}.
Run ID: fcb98fa3-61c2-464e-b5d1-5759a187c472.
Invocation: reports/review-context/sdd-domain-concept-test-task-a4r1-a6-invocation.json.
Immediately-before-launch task-review-precheck --verify-inputs: exit 0.
Canonical reservation: exactly once, exit 0; task-stage input_binding/scratch_binding absent.

```
REVIEW_CONTEXT_OK ae61f5a16f181bdc27db4156fc8deb20c64642a55524bffae7ff15007e598dcd sequence=1210 previous_record_sha256=2d31ab73e3d93d88430bf0f6b445f15ed5cf64887dbed9c9f4b488935fe83bcf pre_append_tip_sequence=1209 identity_unique=yes
```

Only after reservation, first input was sent in native turn `01a10073-7509-7d80-977e-e9dc3109b2c6`. Requests are preserved in reports/verification/issue290-a6-thread-start.json and issue290-a6-turn-start.json. Exact native events: reviewer-a6-native-events.jsonl (this directory). Reviewer read its envelope and independently reproduced receipt hash, both commands exit 0. Review still in progress at creation of this record.

Transport-only a5 was stopped before any thread/start reached the server: its PTY input exceeded the canonical line limit. Its events contain initialization only; no identity was allocated/reserved and no review output exists. Those a5 events are preserved. The bridge now sends persisted requests through short SEND-path controls; permission controls are unchanged. Prior reservations 1206–1209 and their unadopted outputs remain unchanged.

Completion: native turn/completed status=completed, error=null, completedAt=1791009127. Exact final JSON was persisted as reviewer-a.json without changing the verdict/checks/findings. Result: PASS, 14 PASS, 0 FAIL/SKIP, findings=[]. All 17 reviewer shell reads/checks completed exit 0. Only the manifest envelope and admitted paths were read. Counts-only integrated-summary.json was derived deterministically from checks. The bridge was closed after completion; bridge shutdown exit 1 is not the already-completed review turn's status.
