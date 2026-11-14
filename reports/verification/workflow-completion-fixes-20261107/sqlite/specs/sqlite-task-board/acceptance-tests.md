# Acceptance Tests: SQLite Task Board

| Acceptance Criterion | Requirement | Test ID | Type | Target | Status |
|---|---|---|---|---|---|
| AC-001: Root URL directly displays Japanese heading, labelled title input, Add and list. | REQ-001 | TEST-001 | browser | root page | Planned |
| AC-002: Actual browser button and Enter add Japanese titles exactly once unchecked; duplicate titles create distinct rows. Exactly-200-codepoint titles including astral characters succeed without truncation in browser and API; blank/whitespace and 201-codepoint inputs create none. Verify exact saved titles after reload; boundary cases below. | REQ-002 | TEST-002 | browser/API | addition | Planned |
| AC-003: Browser checkbox toggles completed styling both ways; reload preserves the saved value. | REQ-003 | TEST-003 | browser | completion | Planned |
| AC-004: Browser delete cancellation preserves task; confirmation removes only selected task and reload keeps it absent. | REQ-004 | TEST-004 | browser | deletion | Planned |
| AC-005: Browser adds two survivors and a third task, completes one survivor and deletes third; stop process, start new PID with same temporary DB, reload browser and verify exact titles, completion and deletion. Save PID and browser evidence. | REQ-005 | TEST-005 | browser/process | durability | Planned |
| AC-006: Actual 375×812 and 1280×900 screenshots show white/blue Japanese UI, usable controls, wrapping and no horizontal overflow; compare tokens and supplied reference. | REQ-006 | TEST-006 | browser visual | responsive page | Planned |
| AC-007: Keyboard can add/toggle/delete, names and focus are visible; loading/empty/success/error feedback announced; forced read failure supports retry, forced write failure retains draft and saved list without success. | REQ-007 | TEST-007 | browser | states/accessibility | Planned |
| AC-008: Loopback binding and local assets only; malformed JSON, wrong types, invalid/unknown IDs, foreign Host/Origin and unsupported paths return 4xx; HTML/SQL-like titles remain literal and schema intact. Accept valid exactly-4096-byte raw UTF-8 JSON bodies; reject 4097 bytes with 413 before mutation. Require supported Content-Length framing; boundary cases below. | REQ-008 | TEST-008 | API/browser | boundaries | Planned |

## UI Integration Checklist
- [ ] AC-001: `/` directly reaches the only page without shell navigation or authentication.
- [ ] AC-002: Title validation enforced at insertion, not only in browser.
- [ ] AC-004: Every row exposes deletion with confirmation before mutation.
- [ ] AC-007: Pending operations disable repeat submission and recover on failure.

## Reproducible Boundary Cases
TEST-002: In separate browser and API scenarios, successfully add `あ` repeated 200 times, then `あ` repeated 199 times followed by `😀` (U+1F600). The latter has 200 codepoints and 201 UTF-16 units. Also accept 200 repetitions of `😀` (200 codepoints, 400 UTF-16 units). Verify exact text, one unchecked insertion and reload persistence for each. Reject `あ` repeated 200 times followed by `😀` (201 codepoints): API 400 with no insertion, browser Japanese validation feedback with no insertion. A whitespace-padded title trimming to exactly 200 codepoints succeeds. Record codepoint counts independently; JavaScript string.length/native maxlength must not substitute UTF-16 units.

TEST-008: Encode `{"title":"日本語😀"}` as UTF-8 and append legal trailing JSON spaces until exactly 4096 raw bytes. Send POST with matching Content-Length: expect 201 and exactly one unpadded title. Append one extra space (4097 bytes), declare 4097: expect 413 and unchanged rows. Repeat with a valid PATCH completion object padded to 4096 (200, intended state change) and 4097 (413, unchanged state). Send an oversized declaration without transmitting the body: 413 must arrive without waiting for it, proving rejection precedes body reading and mutation. Count raw bytes including JSON syntax/escapes/whitespace, not decoded characters or parsed title length. Repeat with literal-UTF-8 and JSON-escaped Unicode representations, measuring each encoded size independently.

Use raw HTTP for framing negatives: missing Content-Length returns 411; negative/nondecimal/duplicate Content-Length or any Transfer-Encoding returns 400; short body followed by write-side connection close returns 400, with a bounded read timeout also returning 400. Every rejection leaves task IDs/titles/completion unchanged. Oversized DELETE returns 413; normal DELETE uses Content-Length: 0 with no body. A 201-codepoint title in a small valid JSON request returns 400, not 413. Preserve byte counts, headers, response statuses and unchanged-state observations.

## Evidence
Fresh temporary databases only; never earlier fixtures. Real browser operations required, HTTP substitutes insufficient. Preserve raw test logs, screenshots and stop/start PIDs under reports/. No result is asserted before execution.
