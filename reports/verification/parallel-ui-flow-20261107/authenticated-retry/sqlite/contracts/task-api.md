# Task API v1 — Draft

Canonical record: {"id": positive integer, "title": trimmed string of 1–200 Unicode code points, "completed": boolean}. SQLite stores completed as 0/1. List order is ascending ID.

| Method/path | Input | Success | Failure |
|---|---|---|---|
| GET /api/tasks | none | 200 {"tasks": [Task]} | 500 safe error |
| POST /api/tasks | {"title": string} | 201 {"task": Task} | 400 invalid fields/title/JSON; 413 oversized; 415 media type |
| POST /api/tasks/{id}/complete | {} | 200 {"task": Task}; idempotent | 400 invalid ID/body; 404 absent |
| DELETE /api/tasks/{id} | no body | 200 {"deleted": id} | 400 invalid ID; 404 absent |

Error shape: {"error": safe string}. Reject unknown fields. Content-Type application/json for JSON bodies; reject negative/missing/oversized Content-Length, unsupported transfer encoding, and bodies >4096 bytes. UTF-8 strict JSON. 403 for foreign Host/Origin; 404 unknown routes; 405 unsupported method; 500 storage failure with transaction rollback and no internal details. Bodyless DELETE still checks Origin/Host. No CORS grants. Mutations respond only after commit. Completed tasks stay listed; IDs are never reused.
