# CI Workflow Audit Checklist

Check that CI includes:

- lint
- typecheck
- unit test
- integration test when applicable
- e2e test when applicable
- build
- OpenAPI lint when applicable
- JSON Schema validation when applicable
- dependency audit when configured
- secret scanning when configured
- minimal GitHub Actions permissions when applicable

If missing, report gaps. Do not silently add heavy tools unless asked.
