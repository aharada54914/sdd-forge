# Human-copy runbook — PR #229 external-review fixes (3 findings)

Applies four R-10-protected scripts from their staged candidates. An agent
cannot perform any step here; the hook guard denies every write to these
live paths and that denial must never be bypassed.

Run every command from the repository root of the worktree
(`/Users/jrmag/Projects/active/sdd-forge-wt-epic-189`, branch
`feature/epic-189-a1-project-context`).

## What is being applied

| # | Live path (R-10 protected) | Basename | Finding |
|---|---|---|---|
| 1 | `plugins/sdd-quality-loop/scripts/apply-human-copy.sh` | `apply-human-copy.sh` | 1 (P1) |
| 2 | `plugins/sdd-quality-loop/scripts/apply-human-copy.ps1` | `apply-human-copy.ps1` | 1 (P1) |
| 3 | `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` | `generate-approval-sidecar.py` | 2 (P1) |
| 4 | `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `validate-approval-sidecar.py` | 3 (P2) |

All four basenames are distinct, so no pair would hit the publisher's
`DUPLICATE_BASENAME_IN_BATCH` refusal (exit 19). They are nonetheless applied
as **four separate single-target batches** below, so that a failure at any
step leaves the other three untouched and needs no rollback reasoning.

## Step 0 — verify the staged bytes before touching anything

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
while read -r want path; do
  case "$path" in plugins/sdd-quality-loop/scripts/apply-human-copy.*|plugins/sdd-quality-loop/scripts/*-approval-sidecar.py) ;; *) continue ;; esac
  got=$(shasum -a 256 "$STAGE/$path" | awk '{print $1}')
  [ "$got" = "$want" ] && echo "OK   $path" || echo "STOP $path (got $got want $want)"
done < "$STAGE/MANIFEST.sha256"
```

Expect exactly four `OK` lines. Any `STOP` means the staged bytes and the
manifest disagree — do not proceed.

Expected digests (also in `MANIFEST.sha256`):

```
a3814265af176d1abc527c4c2a3c5bb35d3070e29a955f417c738f6c679aab3c  plugins/sdd-quality-loop/scripts/apply-human-copy.sh
b5867e25e05f6614f158b7aec9181dd7efa02ee30fcb23889b9a88e068f479cb  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1
b7f2feb691e3b32cc9d37af541844b92f38ec21d9a13b25d72a61b0cba6a5cd8  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py
a06f433d40a00252d7d17823df5ea3c74b834cb9d14f3fd1caee7c1ff21e4a74  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py
```

## Step 1 — apply, one single-target batch at a time

`apply-human-copy` reads staged bytes from `<staging-dir>/<manifest path>`,
so the staging dir is the `human-copy/` root and each per-batch manifest is
written to a scratch file outside it (a manifest inside the staging tree
would not itself be a target, but keeping it out avoids any ambiguity).

**Important — batch 1 replaces the publisher with itself.** That is safe:
`mv` swaps the directory entry while the running shell keeps reading its
original inode, so the in-flight invocation is unaffected.

**Important — the publisher does NOT preserve file mode.** Verified by
rehearsing this exact procedure against a scratch mirror of the repo: every
published target lands at `0600`, because the publisher writes through
`mktemp` and commits with an atomic rename, and the staged file's mode is
never copied. Two consequences, both handled below:

1. `apply-human-copy.sh` is `0755` live and would become `0600` after batch
   1, so batches 2–4 would die with `Permission denied` if the loop invoked
   it as `"$APPLY"`. The loop therefore invokes it as `sh "$APPLY"`.
2. Modes must be restored explicitly afterwards (Step 2), or `git status`
   will show spurious mode changes on all four files.

This mode behaviour is a property of the publisher, not of these fixes, and
applies to every human-copy apply in this epic.

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
APPLY=plugins/sdd-quality-loop/scripts/apply-human-copy.sh
M=$(mktemp -d)

for p in \
  plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py
do
  grep -F "  $p" "$STAGE/MANIFEST.sha256" > "$M/one.sha256"
  echo "=== applying $p ==="
  cat "$M/one.sha256"
  sh "$APPLY" --staging-dir "$STAGE" --manifest "$M/one.sha256" || { echo "FAILED on $p — stop here"; break; }
done
```

Each batch must print `{"status":"ok","recovered":0,"targets":["<path>"]}`.
Any other output: stop, do not continue to the next batch, and read the
`category` field. `sdd/.staging/<nonce>/TRANSACTION.json` is retained on
failure by design — leave it in place for the next invocation's recovery
scan.

## Step 2 — restore modes, then verify (live == staged, byte for byte)

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy

chmod 755 plugins/sdd-quality-loop/scripts/apply-human-copy.sh
chmod 644 plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
          plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
          plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py

for p in \
  plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py
do
  cmp -s "$STAGE/$p" "$p" && echo "OK   $p" || echo "STOP $p differs"
done
test -x plugins/sdd-quality-loop/scripts/apply-human-copy.sh && echo "OK   exec bit" || echo "STOP exec bit lost"

# No file mode should differ from HEAD once the chmods above have run.
git diff --summary -- plugins/sdd-quality-loop/scripts/
```

`git diff --summary` should print nothing (content changes are reported by
`git diff --stat`; `--summary` reports only mode changes and adds/deletes).

## Step 3 — re-run the affected suites in both lanes

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
for t in apply-human-copy generate-approval-sidecar validate-approval-sidecar \
         ship-track-selection-migration guard-invariants-epic-a1; do
  sh "tests/$t.tests.sh"   > "/tmp/$t.sh.log"  2>&1; echo "$t.sh  rc=$?  $(tail -2 /tmp/$t.sh.log | tr '\n' ' ')"
  pwsh -NoProfile -ExecutionPolicy Bypass -File "tests/$t.tests.ps1" > "/tmp/$t.ps1.log" 2>&1; echo "$t.ps1 rc=$?  $(tail -2 /tmp/$t.ps1.log | tr '\n' ' ')"
done
```

Expected (unchanged from the pre-apply run — the new assertions already
exercise the staged bytes, which are now also the live bytes):

| suite | bash | pwsh |
|---|---|---|
| apply-human-copy | 234 passed, 0 failed | 159 passed, 0 failed |
| generate-approval-sidecar | 69 / 0 | 67 / 0 |
| validate-approval-sidecar | 50 / 0 | 49 / 0 |
| ship-track-selection-migration | 139 / 0 | 139 / 0 |
| guard-invariants-epic-a1 | 81 / 0 | 85 / 0 |

## Step 4 — optional: re-point the new assertions at the live scripts

Not required (the staged and live bytes are now identical, so the assertions
pass either way), and safe to skip. If you prefer the suites to name the live
scripts after the apply, change these variables — each is defined once, in a
block commented with this same instruction:

- `tests/apply-human-copy.tests.sh` → `APPLY_SH_PR229` / `APPLY_PS1_PR229`
- `tests/apply-human-copy.tests.ps1` → `$ApplyPs1Pr229`
- `tests/generate-approval-sidecar.tests.sh` → `STAGED_GEN_PY` / `STAGED_APPLY_SH`
- `tests/generate-approval-sidecar.tests.ps1` → `$StagedGenPy` / `$StagedApplyPs1`
- `tests/validate-approval-sidecar.tests.sh` → `STAGED_VAL_PY`
- `tests/validate-approval-sidecar.tests.ps1` → `$StagedValPy`

The layout resolvers in the two generator suites (`staged_rel_sidecar` /
`Get-StagedRelSidecar` and their snapshot twins) need no change: they already
report whichever layout the generator produced, and after the apply that is
always the new one.

## Rollback

Every target is tracked by git and nothing else on disk is touched:

```sh
git checkout -- plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
                plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
                plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
                plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py
```

If a batch died mid-transaction, run `plugins/sdd-quality-loop/scripts/apply-human-copy.sh`
with no arguments first: its mandatory start-of-invocation recovery scan
drives the batch to a terminal state (fully applied or fully reverted) before
you touch git.
