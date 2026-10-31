# Install/uninstall matrix fixtures

The matrix drivers create isolated Codex, VS Code, Cursor, and CLI surfaces at
runtime. The fixture directory is intentionally documentation-only: no host
configuration is read or modified, and every generated surface is removed in
the driver `finally` path.

The four target cells are `All`, `Codex`, `Claude`, and `Copilot`. `FilesOnly`
is deliberately outside this matrix because it has no client registration
surface to verify. The same driver is run locally on macOS and by the existing
three-OS CI jobs.
