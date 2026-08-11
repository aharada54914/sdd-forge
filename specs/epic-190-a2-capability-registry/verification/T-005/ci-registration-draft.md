# T-005 CI registration draft

This is a non-protected draft only. The implementation session was explicitly
instructed not to write under `specs/*/human-copy/`, so the staged workflow and
its manifest were not changed.

Insert these steps in the staged candidate immediately after the
`validate-capability-registry` PowerShell step and before the
`generate-gate-capabilities` bash step:

```yaml
      - name: Test generate-registry-digest suite (bash)
        if: runner.os != 'Windows'
        shell: bash
        # Invoked via bash explicitly so the step does not depend on the
        # committed exec bit (Windows-authored commits record mode 100644).
        run: bash ./tests/generate-registry-digest.tests.sh

      - name: Test generate-registry-digest suite (pwsh)
        shell: pwsh
        run: ./tests/generate-registry-digest.tests.ps1
```

After applying the draft to the staged candidate, recompute the candidate's
SHA-256 and replace its existing `workflows/test.yml` entry in
`MANIFEST.sha256`.

The live `.github/workflows/test.yml` remained byte-identical to `HEAD` during
T-005 implementation: both SHA-256 values were
`8beba70cd04800f9ab79c24b911c9f43043968edf3362bbcd2ac50e76c380998`.
