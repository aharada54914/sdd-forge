# Issue 295: installer extraction and documentation findings

Base: 4366438f3b243210a4ece5a17f873ca2d920600a.

## Root causes and changes

- `install.ps1` did not inspect the native tar exit code before discovering a
  marketplace directory. A failed extraction can leave a partial directory
  that passes that discovery check. Reject nonzero exit immediately, using
  the existing exception/cleanup path. No change to successful extraction.
- The contributor guide link was one parent directory short. Correct it.
- The standalone review README cited a nonexistent handoff document. Remove
  that citation while preserving its stated promotion criterion.

## Executed verification

- Local-link filesystem check of both Markdown documents: before, two missing
  targets and exit 1; after, zero missing targets and exit 0. This checks local
  file existence, not remote URLs or Markdown fragment anchors.
- Test-first PowerShell regression: execute the actual installer's archive
  branch obtained from its AST, with a fake download and fake tar. The fixture
  leaves a marketplace-shaped partial directory even on tar failure. Before
  the production fix, exit 0 passes and exit 2 incorrectly proceeds (suite
  exits 1 with the expected regression diagnostic).
- After the fix, both exit 0 and exit 2 cases pass. Full
  `pwsh -NoProfile -File tests/install.tests.ps1` completed with
  `Installer integration tests passed.` and exit 0 on macOS. Local log:
  `/tmp/issue295-install-pwsh-20260911.log`.
- Full changed diff reviewed; `git diff --check` passed. The regression runs
  in the existing installer suite; no test removed or skip condition added.

The focused regression does not claim to execute a real corrupted archive or
the full installer's cleanup path. It executes the production branch with a
controlled native exit-code substitute; the existing full suite also passed.

## Not complete

Latest-head CI, required third-party approval, merge, and post-merge verification
are still required. Issue 295 also includes hook parity (PR 402) and missing
CI coverage; this PR must not close the entire issue automatically. Historical
review records are unchanged.
