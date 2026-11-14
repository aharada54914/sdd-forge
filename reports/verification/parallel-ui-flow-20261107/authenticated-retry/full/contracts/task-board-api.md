# Task Board API / v1

Base: http://127.0.0.1:3000 (port is operator-selectable). JSON UTF-8, no CORS. Host must exactly match 127.0.0.1:bound-port. POST/PATCH/DELETE require exact Origin http://127.0.0.1:bound-port. No authentication by explicit local-single-user scope.

## Data

Task = {id: UUID string, title: string (trimmed 1–200 Unicode code points), completed: boolean}. JS validates length by code points to match Python len. Persisted document: {version:1,tasks:Task[]}; IDs unique; order is creation order. Unknown version, invalid schema or malformed JSON blocks startup without overwrite. First run with missing file starts empty. title is always plain text.

## Operations

| Method | Path | Body | Success |
|---|---|---|---|
| GET | /api/tasks | none | 200 {tasks:Task[]} |
| POST | /api/tasks | {title:string} | 201 {tasks:Task[]} including generated UUID and completed:false |
| PATCH | /api/tasks/:id | {completed:boolean} | 200 {tasks:Task[]} |
| DELETE | /api/tasks/:id | none | 200 {tasks:Task[]} |

Unknown fields in change bodies are rejected; PATCH is explicit setting, not implicit toggle. Unknown ID ->404. POST/PATCH require Content-Type application/json (UTF-8 parameter allowed), valid integer Content-Length <=8192 and JSON object; invalid JSON/shape/title/type ->400, invalid Content-Length ->400, over limit ->413, unsupported Content-Type ->415. DELETE body empty. Missing/mismatched Host or mutation Origin ->403. Unknown route ->404, known route unsupported method ->405. API error: {error:{code:string,message:string}} with stable code invalid_request/forbidden/not_found/payload_too_large/unsupported_media_type/method_not_allowed/storage_error; message is Japanese and contains no stack trace/path/body.

All writes are serialized by one server process. Success is sent only after atomic file replace. Write failure ->500 storage_error, old memory/file retained for failures before replace. Mutating requests are not automatically retried; after timeout/lost response, UI must GET state before allowing the next mutation. Explicit PATCH and DELETE target IDs; repeated DELETE of absent ID returns404. GET responses no-store. Exact static allowlist: /, /app.js, /style.css, with appropriate content types. No generic filesystem serving.

REQ-001〜005,008,010 / AC-001〜005,009,010,012,013。
