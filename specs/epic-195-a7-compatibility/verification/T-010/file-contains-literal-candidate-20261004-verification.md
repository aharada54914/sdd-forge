# A7 T-010 literal evaluator candidate portability verification (2026-10-04)

Status: candidate only. The owner source, task status, review state, and Git history were not changed.

## Candidate

- Original retained: `file-contains-literal-candidate-20261003.patch`.
- Revised: `file-contains-literal-candidate-20261004.patch` (SHA-256 `1b6887a9eea1305042546a683ba1f8e4f34063e592b89c98468cfdccd3a40ca1`).
- Exact source delta is the new patch file. Relative to the original candidate, the upper- and lower-case extension fixtures now have distinct basenames; external `chmod` was removed from the PowerShell fixture. Both suites set index mode with checked `git update-index --chmod` and assert the committed `100644`/`100755` tree modes.
- `git apply --check <revised patch>` in the owner checkout: exit 0, no output. The patch was not applied there.

## Isolated before/after execution

The tracked owner HEAD was cloned locally to `/tmp/a7-evaluator-candidate-3YozJi/repo`. Only this disposable clone received `git apply <revised patch>` (exit 0). The clone's pre-application primitive results were Bash 14 passed / 0 failed, exit 0, and PowerShell 14 passed / 0 failed, exit 0.

After application:

| Command in isolated clone | Exit | Result |
| --- | ---: | --- |
| `bash tests/skip-allowlist-manifest.tests.sh --case=primitives` | 0 | 35 passed, 0 failed |
| `pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case primitives` | 0 | 35 passed, 0 failed |
| `bash tests/skip-allowlist-manifest.tests.sh --all` | 0 | 41 passed, 0 failed |
| `pwsh -NoLogo -NoProfile -File tests/skip-allowlist-manifest.tests.ps1 -Case all` | 0 | 44 passed, 0 failed |

Both patched primitive runs printed four committed-mode PASS lines: the markdown, uppercase-extension, and lowercase-extension fixtures are `100644`; the extensionless executable fixture is `100755`. Both printed the expected evaluator exits: `md-marker=1`, `upper-marker=1`, `lower-marker=0`, `mode-marker=0`. Existing AC-035 hard-failure checks remained passing in the full runs.

The PowerShell full run printed expected `ERROR` diagnostics for intentionally invalid inputs and hard-failure fixtures while ending `44 passed, 0 failed`, exit 0. These checks ran on macOS PowerShell, not native Windows or a case-insensitive filesystem; that platform validation remains pending. This candidate is not an implementation review, quality-gate verdict, or merge proof.
