# T-001 fix-cycle evidence — QG Major: prose in `tests/design-system-contract.tests.{sh,ps1}` embedded the banned phrases as contiguous literals

## Defect

`acceptance-tests.md:172` ("Authoring constraint on these four tests
(AGENTS.md "Author-time sweeps", item 2)"): TEST-033..TEST-036's negative
half must not embed, as a contiguous literal, the per-upload phrase it
asserts is absent from product source — in the suite's own body, comments,
or pass/fail messages. It must be assembled at runtime from non-contiguous
parts. This applies to the `.ps1` twin identically.

The QG evaluator found the runtime-assembly itself correct (`BANNED_PER_UPLOAD`
/ `BANNED_EVERY_TIME` / `BANNED_JA_PER_UPLOAD` in `.sh`; `$bannedPerUpload` /
`$bannedEveryTime` / `$bannedJaPerUpload` in `.ps1`) but found the phrases
re-embedded as contiguous literals around that assembly: in one header
comment and in eight pass/fail message strings, split across both files.

## Fix approach

Only the two suite files were edited. The runtime-assembled marker
variables (`BANNED_PER_UPLOAD` / `BANNED_EVERY_TIME` / `$bannedPerUpload` /
`$bannedEveryTime`) already hold exactly the retired phrase text
(`"per-up" + "load"` = `per-upload`; `"every" + " time"` = `every time`), so
each offending message was changed to interpolate the existing variable
instead of typing the phrase again. Because the variable's *value* is
unchanged, the string each test prints at runtime is byte-identical to
before the fix — only the *source* stopped containing the phrase as a
contiguous literal. The one offending comment (a header above the marker
assembly, not a message) was reworded to describe the two retired phrases
generically ("frequency-model markers") instead of naming one of them.

No assertion logic, no scan target, and no runtime marker-assembly line was
touched. `git diff` confirms the edit surface is exactly these two kinds of
change (see full diff below).

## Sites fixed

### `tests/design-system-contract.tests.sh`

| Line(s) | Before | After |
|---|---|---|
| `:210` (comment, now `:210`) | `# Runtime-assembled banned per-upload markers (AGENTS.md "Author-time` | `# Runtime-assembled banned frequency-model markers, retired by this feature` |
| `:494` (TEST-033 pass) | `pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"` | `pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"` |
| `:496` (TEST-033 fail) | `fail "TEST-033 ... not per-upload (AC-021)"` | `fail "TEST-033 ... not ${BANNED_PER_UPLOAD} (AC-021)"` |
| `:502` (TEST-034 pass) | `pass "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"` | `pass "TEST-034 ... not ${BANNED_EVERY_TIME} (AC-021)"` |
| `:504` (TEST-034 fail) | `fail "TEST-034 ... not every time (AC-021)"` | `fail "TEST-034 ... not ${BANNED_EVERY_TIME} (AC-021)"` |
| `:510` (TEST-035 pass) | `pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"` | `pass "TEST-035 ... not ${BANNED_PER_UPLOAD} (AC-021)"` |
| `:512` (TEST-035 fail) | `fail "TEST-035 ... not per-upload (AC-021)"` | `fail "TEST-035 ... not ${BANNED_PER_UPLOAD} (AC-021)"` |

### `tests/design-system-contract.tests.ps1`

| Line(s) | Before | After |
|---|---|---|
| `:291` (comment) | `# Runtime-assembled banned per-upload markers (AGENTS.md "Author-time` | `# Runtime-assembled banned frequency-model markers, retired by this feature` |
| `:566` (TEST-033 pass) | `Test-Pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"` | `Test-Pass "TEST-033 ... not $bannedPerUpload (AC-021)"` |
| `:568` (TEST-033 fail) | `Test-Fail "TEST-033 ... not per-upload (AC-021)"` | `Test-Fail "TEST-033 ... not $bannedPerUpload (AC-021)"` |
| `:573` (TEST-034 pass) | `Test-Pass "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"` | `Test-Pass "TEST-034 ... not $bannedEveryTime (AC-021)"` |
| `:575` (TEST-034 fail) | `Test-Fail "TEST-034 ... not every time (AC-021)"` | `Test-Fail "TEST-034 ... not $bannedEveryTime (AC-021)"` |
| `:580` (TEST-035 pass) | `Test-Pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"` | `Test-Pass "TEST-035 ... not $bannedPerUpload (AC-021)"` |
| `:582` (TEST-035 fail) | `Test-Fail "TEST-035 ... not per-upload (AC-021)"` | `Test-Fail "TEST-035 ... not $bannedPerUpload (AC-021)"` |

(PowerShell double-quoted strings interpolate a bare `$name` reference
directly, so no extra syntax was needed for the `.ps1` twin.)

TEST-036's messages already used the Japanese marker only inside the
runtime-assembled `$bannedJaPerUpload` / `BANNED_JA_PER_UPLOAD` variables and
never repeated it as a literal in prose — that pair was the existing
conforming precedent this fix follows.

### Full diff (`git diff -- tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1`)

```diff
diff --git a/tests/design-system-contract.tests.ps1 b/tests/design-system-contract.tests.ps1
index 3f595853..939822bb 100644
--- a/tests/design-system-contract.tests.ps1
+++ b/tests/design-system-contract.tests.ps1
@@ -288,10 +288,10 @@ function Get-FirstLineIndex([string[]]$lines, [string]$pattern) {
     return -1
 }
 
-# Runtime-assembled banned per-upload markers (AGENTS.md "Author-time
-# sweeps" item 2; requirements.md Edge Case 8). TEST-033..TEST-036's
-# negative half must never embed the phrase this feature removes as a
-# contiguous literal in this suite's own source, comments or messages --
+# Runtime-assembled banned frequency-model markers, retired by this feature
+# (AGENTS.md "Author-time sweeps" item 2; requirements.md Edge Case 8).
+# TEST-033..TEST-036's negative half must never embed either retired phrase
+# as a contiguous literal in this suite's own source, comments or messages --
 # assembled here from non-contiguous parts instead. The Japanese marker
 # and the TEST-036 positive marker are additionally built from Unicode
 # code points rather than as literal characters: PS5.1 reads a BOM-less
@@ -563,23 +563,23 @@ $dslDescLine = ($dslLines | Where-Object { $_ -cmatch '^description:' } | Select
 if ($null -eq $dslDescLine) { $dslDescLine = "" }
 if (($dslDescLine -ne "") -and -not $dslDescLine.Contains($bannedPerUpload) `
         -and ($dslDescLine -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
-    Test-Pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"
+    Test-Pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not $bannedPerUpload (AC-021)"
 } else {
-    Test-Fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"
+    Test-Fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not $bannedPerUpload (AC-021)"
 }
 
 if (($boundariesLines.Count -gt 0) -and -not $boundariesFlat.Contains($bannedEveryTime) `
         -and ($boundariesFlat -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
-    Test-Pass "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"
+    Test-Pass "TEST-034 site 2 (Boundaries) states the per-feature model, not $bannedEveryTime (AC-021)"
 } else {
-    Test-Fail "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"
+    Test-Fail "TEST-034 site 2 (Boundaries) states the per-feature model, not $bannedEveryTime (AC-021)"
 }
 
 if (($bsiUiBulletLines.Count -gt 0) -and -not $bsiUiBulletFlat.Contains($bannedPerUpload) `
         -and ($bsiUiBulletFlat -match 'per-feature|feature.{0,15}(and|AND).{0,15}session')) {
-    Test-Pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"
+    Test-Pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not $bannedPerUpload (AC-021)"
 } else {
-    Test-Fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"
+    Test-Fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not $bannedPerUpload (AC-021)"
 }
 
 if (($wfgSectionLines.Count -gt 0) -and -not $wfgSectionFlat.Contains($bannedJaPerUpload) `
diff --git a/tests/design-system-contract.tests.sh b/tests/design-system-contract.tests.sh
index 00a7168f..1433c994 100644
--- a/tests/design-system-contract.tests.sh
+++ b/tests/design-system-contract.tests.sh
@@ -207,10 +207,10 @@ sha256_of() {
   fi
 }
 
-# Runtime-assembled banned per-upload markers (AGENTS.md "Author-time
-# sweeps" item 2; requirements.md Edge Case 8). TEST-033..TEST-036's
-# negative half must never embed the phrase this feature removes as a
-# contiguous literal in this suite's own source, comments or messages --
+# Runtime-assembled banned frequency-model markers, retired by this feature
+# (AGENTS.md "Author-time sweeps" item 2; requirements.md Edge Case 8).
+# TEST-033..TEST-036's negative half must never embed either retired phrase
+# as a contiguous literal in this suite's own source, comments or messages --
 # assembled here from non-contiguous parts instead, so this suite cannot
 # become a false-positive target of any vocabulary scan run over tests/.
 BANNED_PER_UPLOAD="$(printf '%s' 'per-up')$(printf '%s' 'load')"
@@ -491,25 +491,25 @@ DSL_DESC_LINE=$(grep -m1 '^description:' "$DSL")
 if [ -n "$DSL_DESC_LINE" ] \
    && ! printf '%s' "$DSL_DESC_LINE" | grep -Fq "$BANNED_PER_UPLOAD" \
    && printf '%s' "$DSL_DESC_LINE" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
-  pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"
+  pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
 else
-  fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not per-upload (AC-021)"
+  fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
 fi
 
 if [ -n "$BOUNDARIES_SECTION" ] \
    && ! printf '%s' "$BOUNDARIES_FLAT" | grep -Fq "$BANNED_EVERY_TIME" \
    && printf '%s' "$BOUNDARIES_FLAT" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
-  pass "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"
+  pass "TEST-034 site 2 (Boundaries) states the per-feature model, not ${BANNED_EVERY_TIME} (AC-021)"
 else
-  fail "TEST-034 site 2 (Boundaries) states the per-feature model, not every time (AC-021)"
+  fail "TEST-034 site 2 (Boundaries) states the per-feature model, not ${BANNED_EVERY_TIME} (AC-021)"
 fi
 
 if [ -n "$BSI_UI_BULLET" ] \
    && ! printf '%s' "$BSI_UI_BULLET_FLAT" | grep -Fq "$BANNED_PER_UPLOAD" \
    && printf '%s' "$BSI_UI_BULLET_FLAT" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
-  pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"
+  pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
 else
-  fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not per-upload (AC-021)"
+  fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
 fi
 
 if [ -n "$WFG_SECTION" ] \
```

## Verification 1 — `bash tests/design-system-contract.tests.sh`

Method: captured a baseline run against the pre-fix files (via
`git stash push -- tests/design-system-contract.tests.sh
tests/design-system-contract.tests.ps1`, run, then `git stash pop` to
restore the fix — the two allowed files were the only ones ever touched),
then diffed baseline vs. post-fix full output.

```
$ bash tests/design-system-contract.tests.sh
... (full 124-line output; final 4 lines:)
PASS: TEST-051 push-failure rule, all four parts (AC-030)
PASS: 119
FAIL: 2
EXIT:1
```

Only two FAIL lines in the whole run, exactly as required:

```
FAIL: DS-010 impl count updated
FAIL: TEST-039 this feature's assertions are reachable from a CI entry point (AC-024) -- DESIGNED RED: staged workflow patch not yet applied (R-OQ-8 part 3)
```

**PASS/FAIL line-set diff against the pre-fix baseline is empty** (the full
run outputs are byte-identical, because the message text each test prints
is unchanged — only the source stopped containing the phrase as a literal):

```
$ diff sh_baseline.log sh_fixed.log
$ echo "exit code of diff: $?"
exit code of diff: 0
```

## Verification 2 — `pwsh -NoProfile -File tests/design-system-contract.tests.ps1`

Same method (baseline via `git stash`, then diffed against post-fix).

```
$ pwsh -NoProfile -File tests/design-system-contract.tests.ps1
... (full 71-line output; final 4 lines:)
PASS: TEST-051 push-failure rule, all four parts (AC-030)
PASS: 50
FAIL: 1
EXIT:1
```

Only one FAIL line, exactly as required:

```
FAIL: TEST-039 this feature's assertions are reachable from a CI entry point (AC-024) -- DESIGNED RED: staged workflow patch not yet applied (R-OQ-8 part 3)
```

(The `.ps1` twin has no `DS-010`-equivalent counter entry — the same
pre-existing asymmetry documented in `T-002/tdd-evidence.md`, unrelated to
this fix.)

**PASS/FAIL line-set diff against the pre-fix baseline is empty:**

```
$ diff ps1_baseline.log ps1_fixed.log
$ echo "exit code of diff: $?"
exit code of diff: 0
```

## Verification 3 — self-referential-literal sweep

The three markers were built at runtime in the verification shell exactly
as the suite builds them (`per-up` + `load`, `every` + ` time`, and the
Japanese marker via the same two-part concatenation used at
`tests/design-system-contract.tests.sh:218`), then grepped for as fixed
strings (`grep -F`) across `tests/` — never typed as a contiguous literal
in this evidence-gathering command itself:

```
$ BANNED_1="$(printf '%s' 'per-up')$(printf '%s' 'load')"
$ BANNED_2="$(printf '%s' 'every')$(printf '%s' ' time')"
$ BANNED_3="<built via python3 concatenation of the two Japanese halves>"
$ grep -rn -F -- "$BANNED_1" tests/ ; echo "grep exit: $?"
grep exit: 1
$ grep -rn -F -- "$BANNED_2" tests/ ; echo "grep exit: $?"
tests/loop-inventory.tests.sh:359:# forced threshold of 0 must therefore turn red every time.
grep exit: 0
$ grep -rn -F -- "$BANNED_3" tests/ ; echo "grep exit: $?"
grep exit: 1
```

Marker 1 (the per-upload phrase) and marker 3 (the Japanese phrase): **0
hits across all of `tests/`.**

Marker 2 (the "every time" phrase) has **one hit, and it is out of this
fix's scope**: `tests/loop-inventory.tests.sh:359`, an ordinary English
sentence about test-runtime determinism ("a forced threshold of 0 must
therefore turn red every time"), unrelated to the retired consent-frequency
phrase this feature governs. That file:

- is not one of the two files this fix cycle is scoped to edit (the task's
  own prohibition: "上記2スイートファイルと新規evidenceファイル以外への
  書き込み" — writing outside the two suite files and this evidence file is
  prohibited);
- predates this feature entirely (`git log -1` on that file:
  `c756a5ae`, 2026-07-15, `fix(tests): cross-OS CI fixes for loop suites`,
  unrelated commit, unrelated feature);
- is not read, referenced, or targeted by any AC-021/TEST-033..036
  assertion in `tests/design-system-contract.tests.{sh,ps1}` — the
  self-referentiality hazard `acceptance-tests.md:172` describes is scoped
  to *this* suite's own source, not to every file under `tests/`.

Recorded as a concern for the reviewer/orchestrator rather than patched:
fixing it is out of this fix cycle's edit scope, and doing so would also
require rewording an unrelated suite's own comment, which is a decision for
whoever owns that suite.

## Scope discipline

Files written by this fix cycle: `tests/design-system-contract.tests.sh`,
`tests/design-system-contract.tests.ps1`, and this evidence file. No other
file was written. No existing verification record was edited. No `git add`
/ `git commit` was performed.
