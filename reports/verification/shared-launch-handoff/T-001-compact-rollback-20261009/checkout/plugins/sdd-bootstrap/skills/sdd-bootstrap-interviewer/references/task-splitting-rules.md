# Task Splitting Rules

Good task:

- Fits in one PR/MR
- Has one clear goal
- Has measurable Done When
- Includes tests
- Has limited file scope
- Can be reviewed independently

Bad task:

- "Implement the whole feature"
- Mixes frontend, backend, DB, auth, and E2E in one task
- Has no tests
- Depends on undocumented assumptions
- Changes unrelated files

Recommended order:

1. Project skeleton or domain model
2. API/data contract
3. Backend use case
4. Backend endpoint
5. Frontend form/view
6. Integration test
7. E2E scenario
8. Documentation and traceability update
