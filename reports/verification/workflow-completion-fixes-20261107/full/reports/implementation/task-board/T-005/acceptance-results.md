# T-005 acceptance results

Implementation acceptance observations, not an independent gate verdict. Plan was saved before both test runs.

| AC | Test | Result | Actual observation |
|---|---|---|---|
| AC-001 | TEST-001 | PASS | crud / mobile-crud: / returns 200; Japanese heading, labeled input, empty list; lang=ja. |
| AC-002 | TEST-001 | PASS | crud / mobile-crud: Enter adds one trimmed 買い物; GET confirms one item; input clears and receives focus. |
| AC-003 | TEST-002 | PASS | validation: four blank variants send zero writes; 500 astral characters saved, 501 rejected with identical disk bytes. unittest titles/type cases pass. |
| AC-004 | TEST-003 | PASS | crud / mobile-crud: checked/reload and unchecked/reload persisted; Space keyboard toggle passes. |
| AC-005 | TEST-004 | PASS | crud / mobile-crud: Enter cancel and Escape restore focus, cancel preserves disk bytes, confirm removes row after reload; next/previous/input focus passes. |
| AC-006 | TEST-005 | PASS | restart: child stopped/restarted, same complete task snapshot and JSON bytes; separate-process store and HTTP CLI restart tests pass. |
| AC-007 | TEST-006 | PASS | pending: exactly one delayed POST despite repeated submit/change/click/Enter/Space; controls disabled, then subsequent checkbox update succeeds. |
| AC-008 | TEST-007 | PASS | failures: rejected POST/PATCH/DELETE preserve disk, POST draft retained, checkbox restored; lost committed response sends one POST then reload recovers. Malformed response retains snapshot. Timeout 10.453s, one POST, no automatic retry. |
| AC-009 | TEST-008 | PASS | visual: actual 1440/390/320px screenshots and computed widths show no horizontal overflow; 44px minimum controls, long Japanese wrapping; reference hash matches and image inspected. CSS zoom 2 passes reflow only. 100 tasks: input 0.300ms, checkbox 12.800ms; initial assets 14,521 bytes. |
| AC-010 | TEST-009 | PASS | validation: literal HTML title, no injected img/script or window marker. HTTP unittest negatives reject malformed/duplicate JSON, types, UUID/unknown ID, size/content type/framing/method, external Origin/Host and traversal. |
| AC-011 | TEST-010 | PASS | loading: delayed GET disables updates, empty only after success, injected GET 500 has recovery guidance; reload recovers. crud keyboard Tab/Enter/Space, cancel/focus pass on desktop and 390px. |
| AC-012 | TEST-011 | PASS | unittest: corruption GET/mutations fail with 500 and exact bytes retained; filesystem failure injections cover creation/write/flush/fsync/close/replace/unlink/directory and no candidate publication. Recovery passes. |
| AC-013 | TEST-012 | PASS | sockets: PID 90652 port 36391; sole listener tcp 0100007F (127.0.0.1), inode 167057 owned by PID, no tcp6 listener; loopback GET 200; direct sockets to 172.26.91.233 and 172.31.5.142 return errno 111 (refused), no proxy. |

Evidence: `unittest.log` (43 tests, exit 0), `unittest-execution.json`, `browser-rerun-execution.json`, and `reports/visual-evidence/task-board/T-005/acceptance-rerun/results.json` (11 cases, exit 0). Detailed API statuses are in each case server log and HTTP unittest assertions; timings and request counts are in results.json. Socket raw OS tables and direct probes are in `acceptance-rerun/sockets/socket-evidence.json`.

First browser attempt exited 1 before any test scenario: task TMPDIR exceeded Chromium UNIX socket path length. Its `browser.log` and `browser-execution.json` are retained. Rerun changed only TMPDIR to ordinary /tmp, with parent authorization; profile cleanup is automatic. No app/test repair was needed.

All 11 cases had zero page errors. Console errors: four expected injected failures in failures (three 500 responses plus lost-response ERR_FAILED), one expected 500 in loading; all others empty. These are failure-injection observations, not unexpected runtime errors.

Visual inspection: viewed the hash-verified reference plus board-1440.png, board-390.png, board-320.png, board-200pct.png, save-error.png and mobile delete-dialog.png. White surface, navy hierarchy, teal primary action, outlined rounded rows and spacing match the selected reference direction. Long titles wrap while controls remain visible; mobile form is stacked. The reference navigation/count/filter content is excluded by the approved specification. CSS zoom=2 changes rendered content geometry; native browser menu/keyboard zoom was not exercised. No claim of pixel-identical rendering or complete WCAG conformance.

README documents observed CLI, storage location, tests, recovery and operational limits. No application, test or shared lifecycle files were changed. All admitted snapshot input hashes were rechecked unchanged; no own server process remains.
