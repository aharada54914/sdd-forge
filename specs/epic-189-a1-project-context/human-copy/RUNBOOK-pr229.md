# Human-copy runbook — PR #229 external-review fixes (3 findings) + publisher mode-preservation fix + Windows R-10 fail-open

Applies R-10-protected scripts from their staged candidates, as eight
single-target batches: batches 1-5 below, then batches 6-8 (the three
`sdd-hook-guard` twins — see "Batch 6-8"). The two groups are independent and
may be applied in either order. An agent cannot perform any step here; the hook
guard denies every write to these live paths and that denial must never be
bypassed.

The `apply-human-copy.{sh,ps1}` candidates in this batch additionally carry
a fourth fix, found while rehearsing this very runbook: the publisher now
preserves each file's permission bits — publish applies the STAGED
candidate's mode (never the live target's pre-existing mode, which is
exactly the drift/tamper surface a publish exists to overwrite), the
`pre/` backup captures the live target's PRE-transaction mode, and a
rollback restores it. Covered by `TEST-MODE-PRESERVE` in
`tests/apply-human-copy.tests.{sh,ps1}`.

Run every command from the repository root of the worktree
(`/Users/jrmag/Projects/active/sdd-forge-wt-epic-189`, branch
`feature/epic-189-a1-project-context`).

## What is being applied

| # | Live path (R-10 protected) | Basename | Finding |
|---|---|---|---|
| 1 | `plugins/sdd-quality-loop/scripts/apply-human-copy.sh` | `apply-human-copy.sh` | 1 (P1) + mode-preservation |
| 2 | `plugins/sdd-quality-loop/scripts/apply-human-copy.ps1` | `apply-human-copy.ps1` | 1 (P1) + mode-preservation |
| 3 | `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` | `generate-approval-sidecar.py` | 2 (P1) |
| 4 | `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `validate-approval-sidecar.py` | 3 (P2) |
| 5 | `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` | `canonicalize-sdd-yaml.py` | Windows CI (stack-size ValueError) |

All five basenames are distinct, so no pair would hit the publisher's
`DUPLICATE_BASENAME_IN_BATCH` refusal (exit 19). They are nonetheless applied
as **five separate single-target batches** below, so that a failure at any
step leaves the others untouched and needs no rollback reasoning.

## Step 0 — verify the staged bytes before touching anything

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
while read -r want path; do
  case "$path" in plugins/sdd-quality-loop/scripts/apply-human-copy.*|plugins/sdd-quality-loop/scripts/*-approval-sidecar.py|plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py) ;; *) continue ;; esac
  got=$(shasum -a 256 "$STAGE/$path" | awk '{print $1}')
  [ "$got" = "$want" ] && echo "OK   $path" || echo "STOP $path (got $got want $want)"
done < "$STAGE/MANIFEST.sha256"
```

Expect exactly five `OK` lines. Any `STOP` means the staged bytes and the
manifest disagree — do not proceed.

Expected digests (also in `MANIFEST.sha256`):

```
c24357d541701a3d9a0dd8fbf99f2e2bec7ef64f6464e745107577b9de75e970  plugins/sdd-quality-loop/scripts/apply-human-copy.sh
4b4eeaf3a53df2bb147f9355f155f6b189304fe6e2fb7f9a9c50ad5b6e0ea923  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1
b7f2feb691e3b32cc9d37af541844b92f38ec21d9a13b25d72a61b0cba6a5cd8  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py
a06f433d40a00252d7d17823df5ea3c74b834cb9d14f3fd1caee7c1ff21e4a74  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py
b357a8252a7ece91161f1eca6ec6ba434a0fa9f45a29abf77efb6f90477ee0ff  plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py
```

## Step 1 — apply, one single-target batch at a time

`apply-human-copy` reads staged bytes from `<staging-dir>/<manifest path>`,
so the staging dir is the `human-copy/` root and each per-batch manifest is
written to a scratch file outside it (a manifest inside the staging tree
would not itself be a target, but keeping it out avoids any ambiguity).

**Important — batch 1 replaces the publisher with itself.** That is safe:
`mv` swaps the directory entry while the running shell keeps reading its
original inode, so the in-flight invocation is unaffected.

**Important — batch 1 is executed by the OLD live publisher, which does NOT
preserve file mode.** The staged candidates in this batch fix that (the
publisher now applies the staged candidate's mode; `TEST-MODE-PRESERVE`),
but the fix only takes effect once it is itself live. Concretely:

1. Batch 1 (the publisher replacing itself) is performed by the old,
   mode-lossy live bytes, so `apply-human-copy.sh` lands at `0600` — the
   loop therefore invokes it as `sh "$APPLY"`, and Step 2 restores its
   `0755` with one final `chmod` (the last such chmod any apply will ever
   need).
2. Batches 2–5 are performed by the NEW live bytes (`mv` swapped them in
   during batch 1; `sh "$APPLY"` re-reads the path fresh each iteration),
   so those three targets land at their staged modes (`0644`)
   automatically — no chmod, no spurious `git diff --summary` entries.

Once this batch is applied, every future human-copy apply preserves modes
end to end (publish, `pre/` backup, and rollback alike).

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
APPLY=plugins/sdd-quality-loop/scripts/apply-human-copy.sh
M=$(mktemp -d)

for p in \
  plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py
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

## Step 2 — restore batch 1's mode, then verify (live == staged, byte for byte)

Only batch 1's own target needs a mode fix (it was published by the old,
mode-lossy publisher — see Step 1). Batches 2–5 landed at their staged
modes already; if `git diff --summary` below reports a mode change on any
of those three, stop and investigate rather than chmod-ing over it.

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy

chmod 755 plugins/sdd-quality-loop/scripts/apply-human-copy.sh

for p in \
  plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
  plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
  plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
  plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py
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
         canonicalize-sdd-yaml ship-track-selection-migration guard-invariants-epic-a1; do
  sh "tests/$t.tests.sh"   > "/tmp/$t.sh.log"  2>&1; echo "$t.sh  rc=$?  $(tail -2 /tmp/$t.sh.log | tr '\n' ' ')"
  pwsh -NoProfile -ExecutionPolicy Bypass -File "tests/$t.tests.ps1" > "/tmp/$t.ps1.log" 2>&1; echo "$t.ps1 rc=$?  $(tail -2 /tmp/$t.ps1.log | tr '\n' ' ')"
done
```

Expected (unchanged from the pre-apply run — the new assertions already
exercise the staged bytes, which are now also the live bytes):

| suite | bash | pwsh |
|---|---|---|
| apply-human-copy | 247 passed, 0 failed | 168 passed, 0 failed |
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

## Batch 6-8 — R-10 fail-open on native-Windows absolute paths (the three guard twins)

Independent of batches 1-5 above; apply in either order. The three basenames
(`sdd-hook-guard.ps1`, `sdd-hook-guard.py`, `sdd-hook-guard.js`) are distinct
from each other and from every basename in batches 1-5, so no pair can hit the
publisher's `DUPLICATE_BASENAME_IN_BATCH` refusal (exit 19). They are still
applied as three separate single-target batches, for the same
failure-isolation reason as above.

### What is wrong

CI run 31226882417, job `version-gates (windows-latest)`, step "Test hook-guard
epic-a1 write-boundary matrix (pwsh)": every **surface 05 (cwd-absolute)**
AC-023 cell in `tests/hook-guard-epic-a1-boundary.tests.ps1` failed with
`expected exit 2, got 0` — in BOTH sudo lanes. The live guard **ALLOWED** a
write to a protected gate file. This is a real fail-open in the enforcement
chain, not a test defect.

`Join-Path` emits the platform separator, so on native Windows the suite's
`$absolute` is `D:\...\sdd\project-context.approval.json`. That path:

1. makes the tokenizer return `$null`/`None`/`null` — an unquoted backslash is
   an unmodeled construct, by design since #117; and
2. does not contain the registry's POSIX-separator suffix
   `sdd/project-context.approval.json`, because its own separator is `\`.

The R-10 pre-filter's tokenizer-`null` fallback scanned only the **raw** command
text, so it missed the path and reported "no protected path" — and
`shell_targets_protected_gate_file` returns "allow" immediately on that. The
single-path matcher (`_is_protected_gate_file`) has always normalized
separators; this fallback did not. Only the separator immediately BEFORE the
registered suffix mattered, which is why POSIX never saw it.

Reproduced on macOS against the live twins with a hand-built Windows path
(all three ALLOWED, exit 0), and against the staged candidates (all three
DENY, exit 2). A POSIX-absolute control stayed DENY throughout.

### The fix

In each twin's `command_references_protected_path`, the fallback now scans a
separator-normalized copy of the command in addition to the raw text — the same
normalization the single-path matcher already applies. Scanning both can only
ADD matches, so no command that was denied before becomes allowed, and the
issue-#62 read-only short-circuit is untouched (read-only access to a protected
path still returns allow).

The `.js` candidate additionally gains a fix for a second, pre-existing gap
found in the same block: its fallback iterated `PROTECTED_GATE_SUFFIXES` only
and never `PROTECTED_GATE_PLUGIN_JSON_SUFFIXES`, which the `.py`/`.ps1` twins
have always scanned. The JS twin was the outlier; all three now agree.

| # | Live path (R-10 protected) | Basename |
|---|---|---|
| 6 | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `sdd-hook-guard.ps1` |
| 7 | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `sdd-hook-guard.py` |
| 8 | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `sdd-hook-guard.js` |

### Step A — verify the staged bytes

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
while read -r want path; do
  case "$path" in plugins/sdd-quality-loop/scripts/sdd-hook-guard.*) ;; *) continue ;; esac
  got=$(shasum -a 256 "$STAGE/$path" | awk '{print $1}')
  [ "$got" = "$want" ] && echo "OK   $path" || echo "STOP $path (got $got want $want)"
done < "$STAGE/MANIFEST.sha256"
```

Expect exactly three `OK` lines. Expected digests (also in `MANIFEST.sha256`):

```
28edb5796a6b557666f34655430b83f62f1266fd0628b9e40bd4a5d444e44e6f  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
d0bdab976c1f7321503cc61205fd2dbcbbd37631492e6689a38b6f334447894a  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
6e1e8c1a4225e36a593c61ae4f2d02a543f9f6f025569b31a3a9e966dce1f500  plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
```

### Step B — apply, one single-target batch at a time

**These three targets ARE the guard the hook runs.** Each `mv` swaps the
directory entry atomically, so an in-flight hook invocation keeps reading its
original inode and no tool call ever sees a half-written guard.

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
APPLY=plugins/sdd-quality-loop/scripts/apply-human-copy.sh
M=$(mktemp -d)

for p in \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
do
  grep -F "  $p" "$STAGE/MANIFEST.sha256" > "$M/one.sha256"
  echo "=== applying $p ==="
  cat "$M/one.sha256"
  sh "$APPLY" --staging-dir "$STAGE" --manifest "$M/one.sha256" || { echo "FAILED on $p — stop here"; break; }
done
```

Each batch must print `{"status":"ok","recovered":0,"targets":["<path>"]}`.

### Step C — verify (live == staged, byte for byte)

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
STAGE=specs/epic-189-a1-project-context/human-copy
for p in \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py \
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
do
  cmp -s "$STAGE/$p" "$p" && echo "OK   $p" || echo "STOP $p differs"
done
git diff --summary -- plugins/sdd-quality-loop/scripts/
```

`git diff --summary` should print nothing (all three targets are `0644` live
and staged; if batches 1-2 have already been applied the mode-preserving
publisher keeps it that way).

### Step D — re-run the affected suites in both lanes

```sh
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189
for t in hook-guard-epic-a1-boundary guard-invariants-epic-a1; do
  sh "tests/$t.tests.sh"   > "/tmp/$t.sh.log"  2>&1; echo "$t.sh  rc=$?  $(tail -2 /tmp/$t.sh.log | tr '\n' ' ')"
  pwsh -NoProfile -ExecutionPolicy Bypass -File "tests/$t.tests.ps1" > "/tmp/$t.ps1.log" 2>&1; echo "$t.ps1 rc=$?  $(tail -2 /tmp/$t.ps1.log | tr '\n' ' ')"
done
sh tests/guards.tests.sh > /tmp/guards.sh.log 2>&1; echo "guards.sh rc=$?"
```

Expected on macOS (unchanged from the pre-apply run — the `WIN05-*` assertions
already exercise the staged bytes, which are now also the live bytes):

| suite | bash | pwsh |
|---|---|---|
| hook-guard-epic-a1-boundary | 228 passed, 0 failed | 224 passed, 0 failed |
| guard-invariants-epic-a1 | 81 / 0 | 85 / 0 |

`tests/guards.tests.sh` exits `rc=2` with exactly one failure
(`sh: copilot deny -> JSON deny`) both BEFORE and AFTER this batch. That
failure is pre-existing on this branch and unrelated to these three targets —
do not treat it as caused by the apply, and do not "fix" it here.

**Only real Windows CI can confirm the headline result.** The 8 surface-05
AC-023 cells (4 basenames x 2 sudo lanes) in
`tests/hook-guard-epic-a1-boundary.tests.ps1` run against the LIVE guard, so
they stay red on `windows-latest` until this batch is applied, and no local
macOS run can turn them green. After the apply, re-run job
`version-gates (windows-latest)` and expect the boundary suite to report
0 failures.

## Rollback

Every target is tracked by git and nothing else on disk is touched:

```sh
git checkout -- plugins/sdd-quality-loop/scripts/apply-human-copy.sh \
                plugins/sdd-quality-loop/scripts/apply-human-copy.ps1 \
                plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py \
                plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
                plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py \
                plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 \
                plugins/sdd-quality-loop/scripts/sdd-hook-guard.py \
                plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
```

If a batch died mid-transaction, run `plugins/sdd-quality-loop/scripts/apply-human-copy.sh`
with no arguments first: its mandatory start-of-invocation recovery scan
drives the batch to a terminal state (fully applied or fully reverted) before
you touch git.
