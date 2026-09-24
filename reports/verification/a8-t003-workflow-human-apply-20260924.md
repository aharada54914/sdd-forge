# T-003 human apply: protected workflow registration

The live `.github/workflows/test.yml` is protected and was not edited in this
task. Apply the following insertion immediately after the existing step:

```yaml
      - name: Test uninstaller (pwsh)
        if: matrix.lane == 'all' || matrix.lane == 'context'
        shell: pwsh
        run: ./tests/uninstall.tests.ps1

      # epic-196-a8-integration T-003 (REQ-002, AC-007..AC-011, AC-024):
      # the local macOS run and this existing three-OS installer matrix use
      # the same isolated four-cell driver. No host client state is touched.
      - name: Test install/uninstall matrix (PowerShell; local macOS + existing 3-OS CI split)
        shell: pwsh
        run: ./tests/install-uninstall-matrix.tests.ps1

      - name: Test install/uninstall matrix (POSIX; local macOS + existing 3-OS CI split)
        if: runner.os != 'Windows'
        shell: bash
        run: bash ./tests/install-uninstall-matrix.tests.sh 2>&1 | tee "${{ runner.temp }}/install-uninstall-matrix-tests.log"
```

After applying, recompute the protected workflow digest and update the
corresponding human-copy manifest entry before the protected apply review.
