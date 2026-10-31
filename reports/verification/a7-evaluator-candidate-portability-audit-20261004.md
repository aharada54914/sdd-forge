# A7 evaluator candidate audit — 2026-10-04

Scope: current code reproduction and unapplied candidate inspection. No task status, review verdict, protected source, or Git history changed.

## Current defect reproduced

At `a1bf96a6d7348dc6c4f48494d68b964dfe56fa20`, invoke each twin with:

`file-contains . HEAD specs/epic-195-a7-compatibility/requirements.md 'Spec-Review-Statu?'`

- Bash evaluator: exit 1, no output.
- PowerShell evaluator: exit 0, no output.

The PowerShell wildcard comparison accepts an absent literal. Current PR #512 has 38 successful check results at this exact head; those results do not disprove this independently reproduced behavior.

## Candidate fixture defects to fix before adoption

The unapplied `verification/T-010/file-contains-literal-candidate-20261003.patch` creates `not-executable.SH` and `not-executable.sh` in the same directory. These names collide on common case-insensitive macOS and Windows filesystems. Use distinct basenames while retaining the upper/lower extension distinction.

The PowerShell candidate invokes external `chmod` to control executable bits, without checking its exit code. Native Windows does not guarantee this command or Unix filesystem mode behavior. Since the evaluator consumes Git tree mode, stage the fixture files and set their index mode with checked `git update-index --chmod=-x` / `--chmod=+x` commands before committing. Assert the committed tree modes so the fixture tests the intended mode rather than host defaults.

Neither portability finding is a measured native Windows test result. The candidate has not been applied or behaviorally validated in this audit. Existing AC-035 checks must remain intact.
