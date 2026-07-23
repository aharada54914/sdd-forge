# HUMAN APPLY STEP — epic-192-a4-facet-manifest CI staging

## Why this file exists (not the real path)

`sdd-hook-guard.sh` rejects any write to
`specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
(the intended human-copy staging path) as a hard, sudo-immune deterministic
gate denial, even though this task's own Protected Files section documents
that exact path as agent-editable staging. The denial was reproduced 3
times (Bash `cp`, Write tool ×2) and is tracked as a known guard defect
(session task `task_b3fae260`, independently confirmed on Epic A1/A6 too;
options under human consideration: (A) add a human-copy exemption to the
guard, (B) apply via a non-protected proposal file + human copy — what this
file is, or (C) rescope). Per operating instructions, no further workaround
was attempted; this directory holds the **prepared content only**, for a
human to review and apply.

## What to apply

`github-workflows-test.yml.PROPOSED` in this same directory is the complete,
corrected `.github/workflows/test.yml` — the current live file
(`.github/workflows/test.yml`, sha256
`3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4`) with
exactly one insertion: T-001's two new CI step-pairs (`Test
facet-manifest-schema suite (bash/pwsh)` and `Test facet-manifest-semantics
suite (bash/pwsh)`), inserted immediately after the existing `Test
model-freshness-check suite (pwsh)` step, matching this repository's
established insertion-point convention for newly landed suites. Confirmed
via `diff .github/workflows/test.yml
specs/epic-192-a4-facet-manifest/human-copy/github-workflows-test.yml.PROPOSED`:
the only diff is that pure insertion (see below) — no other line changed,
reordered, or removed.

```
215a216,240
>       # epic-192-a4-facet-manifest T-001 (REQ-001/REQ-006): schema conformance
>       # + semantic checks for contracts/facet-manifest.schema.json /
>       # validate-facet-manifest.{py,sh,ps1}.
>       - name: Test facet-manifest-schema suite (bash)
>         if: runner.os != 'Windows'
>         shell: bash
>         run: bash ./tests/facet-manifest-schema.tests.sh
>
>       - name: Test facet-manifest-schema suite (pwsh)
>         shell: pwsh
>         run: ./tests/facet-manifest-schema.tests.ps1
>
>       - name: Test facet-manifest-semantics suite (bash)
>         if: runner.os != 'Windows'
>         shell: bash
>         run: bash ./tests/facet-manifest-semantics.tests.sh
>
>       - name: Test facet-manifest-semantics suite (pwsh)
>         shell: pwsh
>         run: ./tests/facet-manifest-semantics.tests.ps1
```

## How to apply (human, outside any agent session)

```sh
cp specs/epic-192-a4-facet-manifest/human-copy/github-workflows-test.yml.PROPOSED \
   .github/workflows/test.yml
shasum -a 256 .github/workflows/test.yml
# must equal:
```

Expected post-apply hash of `.github/workflows/test.yml`:
`fb3eae629068a37c46f86c9da8a3a87cf14548c3901ace2f49c2557e39bd5e34`

Then re-run `bash tests/run-all.sh` / `pwsh tests/run-all.ps1` against the
applied tree to confirm the two new suites execute cleanly in CI's own
invocation style, before marking any task that depends on a green CI as
`Done` (AGENTS.md Protected Files convention for this feature).

## Proposal manifest

| File | SHA-256 |
|---|---|
| `github-workflows-test.yml.PROPOSED` | `fb3eae629068a37c46f86c9da8a3a87cf14548c3901ace2f49c2557e39bd5e34` |
| Live `.github/workflows/test.yml` (pre-apply, current) | `3fe8466c4208dc89ea18811e71c5533b87fcc1977d49d83702697210482f86f4` |
| Live `.github/workflows/test.yml` (expected post-apply) | `fb3eae629068a37c46f86c9da8a3a87cf14548c3901ace2f49c2557e39bd5e34` |

## Status

This is the **T-001** proposal only. If T-002/T-003/T-004/T-005 land CI
steps of their own before this is applied, each will append its own steps
to a freshly regenerated `.PROPOSED` file built from the then-current live
`test.yml` plus all pending tasks' steps in landing order (T-001 → T-002 →
... ), per this feature's Global Constraints serialization rule — not by
editing this file after the fact once it is superseded. Check this
directory's file mtimes / this feature's `tasks.md` Blocker notes for the
most current proposal before applying.
