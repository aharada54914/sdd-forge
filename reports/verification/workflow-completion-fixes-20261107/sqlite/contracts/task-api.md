# Task API v1

Task: {id: positive integer,title: trimmed 1–200-Unicode-codepoint string,completed: boolean}. Count after trimming; each astral character counts once, not as two UTF-16 units or multiple UTF-8 bytes. Exactly 200 including astral characters is valid without truncation. Ascending id order. REQ-002–005/008; AC-002–005/008.

- GET /api/tasks → 200 {tasks:[Task]}.
- POST /api/tasks {title:string} → 201 {task:Task}, initially unchecked.
- PATCH /api/tasks/{id} {completed:boolean} → 200 {task:Task}.
- DELETE /api/tasks/{id} → 200 {deleted:id}.
- JSON errors {error:string code}: invalid JSON/input 400, foreign Host/Origin 403, missing task/path 404, method 405, oversized body 413, non-JSON mutation 415, storage failure 500. No internal details.

Mutations require one valid nonnegative decimal Content-Length and no Transfer-Encoding. Missing length: 411; malformed/negative/duplicate length or any Transfer-Encoding: 400 before mutation. Maximum body: 4096 raw transmitted UTF-8 JSON bytes including syntax, escaping and whitespace, excluding headers. Validate declared size before reading/decoding/parsing; >4096 returns 413 before reading or mutation. Exactly 4096 is supported for otherwise valid JSON/input. Read complete declared body with bounded timeout; truncation returns 400 without mutation. POST/PATCH require JSON content type/body; DELETE uses Content-Length: 0, no body and no required JSON content type. Apply cap to every mutation, including DELETE. No chunked/compressed request bodies. GET is bodyless and non-mutating.

Title codepoints and raw body bytes are separate limits. Escaped and literal UTF-8 representations can have different transmitted sizes for the same decoded title. TEST-002/008 define successful astral/200-codepoint cases, 4096/4097-byte padded valid JSON and framing negatives.

Validate then parameterized transaction, commit before success. Host must match bound loopback/localhost and configured port; supplied Origin must match request origin, reject null/foreign. No CORS or automatic mutation retries. Explicit static routes only; no database/reference serving.
