# T-010 prospective contract repair — exact edit candidate (not applied)

Status: FROZEN NORMATIVE EDITS REMAIN CANDIDATES. Sections 2–4 were subsequently applied as a local, uncommitted T-010 implementation correction on 2026-10-04, with independently recorded RED/GREEN below; exact local test spelling differs from the proposal but preserves its assertions. No frozen artifact, task status, reservation, review verdict, Git index, or Git ref was changed by this correction. This is not Implementation Complete or quality-gate evidence. T-008 still owes the real-host invocation spy required by AC-004/AC-021; merge-activation alone is not that proof.

## Input and boundary

- Current PR #512 checkout HEAD at drafting: `d64cffcb22b114779202847be33e41700c4ba11f`. Recheck all hashes and cleanly rebase this candidate against the actual target before any authorized application.
- Current A5 `specs/epic-193-a5-capability-resolver/design.md` blob `93d4e7be262ca517451c3bd1026061a112e46937`, item 10 lines `2139-2179`, normalized LF/UTF-8/no trailing newline SHA-256 `1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c`. The former `1886-1915` window is now unrelated; its current normalized digest is `5bc45577017853b7fb8e74071036a9e1848b00588057c3374c753a2621c87db9`, not the frozen `9b549be9...` citation.
- Preserve AC-004 activation `merged(A5)` and AC-021 activation `merged(A1) AND merged(A5)`. The manifest and evaluator must not use `executable_contains` as a third primitive or as a substitute for T-008's live spy. Keep zero-SKIP drift audit independent of activation. No broad caller implementation belongs in T-010.
- The freeze under `AGENTS.md` means the normative edits below are **proposed re-review inputs**, not permission to edit frozen files in place. Preserve the old review evidence and bind a new approved revision through the ordinary spec/implementation-policy/task provenance gates as applicable. The historical `investigation.md:48` and `tests/loop-consistency.tests.{sh,ps1}` comments describing the old window remain historical evidence, not live normative citations. A dated design supersession note must explicitly override the investigation span (WFI-023).
- The current A5 item 10 is not merely relocated. Its current (b) covers absent and present disabled-legacy input, and (d) adds exactly-one effective context. The prior A7 design/tasks describe an older three-fixture boundary. The proposed citation update therefore **expands the admitted semantic surface** and must be independently reviewed as such; a hash-only substitution cannot authorize it. Do not delete the older three checks or treat T-008's real-host spy as satisfied by this broader static citation. Reconcile the A7 normative fixture list and T-008 acceptance in the formal amended review before claiming AC-004/AC-021 complete.
- A second mismatch is inside the current A5 item 10(a): it still requires live `SKILL.md:54-64`, digest `d969fa...`, heading ordinal 3 (`A5 design.md:2146-2157`). Current A7 `tests/loop-consistency.tests.sh:513-519,588-604` probes `SKILL.md:63-102`, digest `5f83fd...`, ordinal 4. The current SKILL has the capability phase at 63-102 followed by the full-profile heading. Therefore a bare A5-item-10 digest replacement would leave AC-036's source-defined expected window and A7's live probe in conflict. The normative amendment must either restore A5's original cited SKILL window/ordinal in the live skill or, if the current insertion point is the intended one, explicitly amend A5 item 10(a) to 63-102 / `5f83fd5a18c94571a28303b9c8773355bfcbbd9e3a23bf34a682e76b86938823` / ordinal 4 and bind that changed A5 design through its own review. A7 AC-036 and the existing probe can then cite the amended A5 contract; neither route may silently pass on the present mismatch.
- Detection test for the amended review: run the existing `_a5_anchor_fingerprint_check` against the live SKILL using the **A5-recorded** window/digest/ordinal and require it to reject the current mismatched source before amendment; then run it with the proposed 63-102/5f83.../4 values and require a match. Independently retain A7 TEST-018.5b relocation-negative fixture and TEST-018.5c current-skill check, but do not count their local success as proof that the frozen A5 normative citation was satisfied. The review must compare both contracts and the current SKILL bytes, not just the A7 test result.
- Local read-only detection on 2026-10-04 computed normalized current SHA-256 `cac9fa49c3f8a5dec8d0f1a998d45ff36335e34289a1b66744af09ae4d67ec22` for live lines 54-64 (not A5's `d969fa...`), `5f83fd5a18c94571a28303b9c8773355bfcbbd9e3a23bf34a682e76b86938823` for lines 63-102 (equal to A7's live probe), and Full-Profile heading ordinal `4` (not A5's `3`). These observations demonstrate the mismatch but do not amend either frozen contract.

### Proposed A5 source-contract amendment (not applied)

Choose the live insertion point already exercised by A7, rather than restoring an older SKILL layout: in A5 `design.md` item 10(a), replace the recorded SKILL `54-64` window with `63-102`, the recorded `d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64` digest with `5f83fd5a18c94571a28303b9c8773355bfcbbd9e3a23bf34a682e76b86938823`, and the Full-Profile heading ordinal `3` with `4`. Retain the same fingerprint normalization and fail-on-drift semantics. Recompute these values against the review input commit rather than accepting this prospective observation as new proof. A5's own frozen design needs its own amended implementation-policy review before A7 can bind the new item-10 text. A7's frozen AC-036 citation/fixture scope then needs its amended specification/task provenance review; neither old Passed verdict carries forward to changed bytes.

The A1/A5 merge activation bug is separately corrected only in local, uncommitted T-010 implementation: PR #229 merge receipt `a8d65c7316f53787121874968e14878bc90c75aa` and PR #245 merge receipt `fe646175ba62256f71a560662a292dd84f6af8b1` are now pinned on each corresponding manifest dependency. Both are ancestors of `origin/main`; the A5 first parent is a negative control. A comment-only AC-004/021 helper mention is no longer accepted as a real consumer call; the resulting AC-016 RED is preserved in `merge-receipt-and-ac016-red-20261004.md`. Do not change the normative activation condition to accommodate missing T-008 host evidence.

## 1. Normative candidate, exact substitutions

`specs/epic-195-a7-compatibility/requirements.md` AC-036 (currently lines 643-646):

```diff
-  `specs/epic-193-a5-capability-resolver/design.md:1886-1915`, `sha256:
-  9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`),
+  `specs/epic-193-a5-capability-resolver/design.md:2139-2179`, `sha256:
+  1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c`),
```

`specs/epic-195-a7-compatibility/design.md`: in the JSONC example for AC-004 and AC-021 only, replace each `"line_range": "1886-1915"` with `"line_range": "2139-2179"`, and its adjacent `"digest": "sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff"` with `"digest": "sha256:1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c"`. The JSONC activation strings already say `merged(A5)` and `merged(A1) AND merged(A5)` and must remain unchanged. At the active `FP-A5-CALLER-CONTRACT-10` definition (currently lines 904-909), make the same range/digest substitution and change `three-sub-item (a)/(b)/(c) body` to `four-sub-item (a)/(b)/(c)/(d) body`. Append immediately after that definition:

> 2026-10-04 prospective supersession of the live `FP-A5-CALLER-CONTRACT-10` citation: Epic A5's item 10 moved from the historical 1886-1915 / 9b549be9... window recorded by `investigation.md:48` and the earlier review to the current 2139-2179 / 1bf6f2e2... window. The old window and digest remain historical evidence only. Recompute against the reviewed A5 commit at review time; if either text or the four sub-item semantics differs, stop and re-review rather than updating a digest mechanically. This supersedes only the live citation, not AC-004/AC-021 merge activation or the T-008 host-spy obligation.

Keep `design.md:585`'s old digest and `:899`'s former-window narrative as **historical examples**, qualified by the above explicit supersession; do not silently rewrite the NEW-001 account. Do not edit `acceptance-tests.md`, task approval/status, or the A5 source to make this change. Sweep all A7 artifacts for `FP-A5-CALLER-CONTRACT-10`, `1886-1915`, and both digests before submitting review; historical hits must be identified as such. New normalized task/design hashes and independent review are required; the old Passed verdict is not proof of the amended bytes.

## 2. Manifest candidate (2 exact line replacements)

File: `tests/fixtures/skip-allowlist-manifest.json`:

```diff
-    "activation_condition": "merged(A5) AND executable_contains(plugins/sdd-bootstrap,resolve-project-context)"
+    "activation_condition": "merged(A5)"
-    "activation_condition": "merged(A1) AND merged(A5) AND executable_contains(plugins/sdd-bootstrap,resolve-project-context)"
+    "activation_condition": "merged(A1) AND merged(A5)"
```

Keep all five entries, dependencies, current A5 `2139-2179` digest, A1/A4/A6 fingerprints, and hard-fail behavior unchanged. Do not make a manifest entry `SKIP` merely because a live caller spy is missing; the spy is a separate required test, not a third activation predicate.

## 3. Evaluator candidates (both runtimes)

File `tests/lib/skip-allowlist-evaluator.sh`:

1. Delete the complete `skip_allowlist_file_contains()` and `skip_allowlist_executable_contains()` definitions (currently lines 58-88). They are used only by the extra predicate branches and direct helper dispatch, not by the two-primitive contract.
2. Delete the two `elif` branches of `skip_allowlist_condition()` that match `^file_contains...` and `^executable_contains...` (currently lines 101-104). Leave the `else return 2` path intact so unknown predicates are malformed, not inactive/valid.
3. Delete `file-contains)` and `executable-contains)` cases from the bottom command dispatch; change the usage string to `{merged|fingerprint-match|condition|audit|line}`. Preserve the `merged`/`fingerprint_match` branches, AND/OR grammar, `value > 1` error propagation, and independent all-dependencies audit.

File `tests/lib/skip-allowlist-evaluator.ps1`:

1. Delete the complete `Test-FileContains` and `Test-ExecutableContains` definitions (currently lines 71-99).
2. Delete only the two corresponding `elseif` branches in `Test-Condition` (currently lines 110-111). Preserve `else { throw "invalid activation primitive: ..." }`, case-sensitive token matching, AND/OR, and audit.
3. Delete their direct dispatch cases (currently lines 165-166); change the usage string to `{merged|fingerprint-match|condition|audit|line}`. Unknown primitive and unknown subcommand must exit nonzero, never pass as false evidence.

The above are deletions of a non-normative extension, not a change to how merge or fingerprint evidence is computed. No new network call, retry, or caller execution is introduced.

## 4. Regression candidate, exact replacements

File `tests/skip-allowlist-manifest.tests.sh`:

- In `case_manifest_contract`'s fixed `expected` array (currently lines 298 and 300), replace the AC-004 condition string with `merged(A5)` and AC-021 with `merged(A1) AND merged(A5)`; do not change their expected digests.
- In `case_primitives`, replace the whole caller-marker fixture block beginning `mkdir -p "$FIXTURE_REPO/plugins/sdd-bootstrap/scripts"` and ending with its final `executable_contains activates after ...` assertion (currently lines 261-288) with:

```bash
  local primitive rc
  for primitive in 'file_contains(path,marker)' 'executable_contains(plugins/sdd-bootstrap,resolve-project-context)'; do
    jq --arg condition "$primitive" '.[0].activation_condition = $condition' "$FIXTURE_MANIFEST" > "$WORK/condition.json"
    run_evaluator condition "$WORK/condition.json" AC-900 "$FIXTURE_REPO" main >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      pass "unsupported activation primitive $primitive is rejected as malformed"
    else
      fail "unsupported activation primitive $primitive must return 2 (actual $rc)"
    fi
  done
```

This deliberately checks error classification (`2`), not merely nonzero, because a false predicate (`1`) could preserve a stale SKIP. Existing merge/fingerprint/AND/OR positive and negative fixtures remain.

File `tests/skip-allowlist-manifest.tests.ps1`:

- Replace the caller-marker fixture block in `Test-Primitives`, from `$callerPath = ...` through the last `executable_contains activates after ...` assertion (currently lines 209-221), with:

```powershell
    foreach ($primitive in @('file_contains(path,marker)', 'executable_contains(plugins/sdd-bootstrap,resolve-project-context)')) {
        $document[0].activation_condition = $primitive
        [IO.File]::WriteAllText($conditionManifest, ($document | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $rc = Invoke-Evaluator @('condition', $conditionManifest, 'AC-900', $fixture.Repo, 'main')
        if ($rc -eq 2) { Pass "unsupported activation primitive $primitive is rejected as malformed" }
        else { Fail "unsupported activation primitive $primitive must return 2 (actual $rc)" }
    }
```

- In the fixed `$expectedLine` (currently line 275), replace `... until merged(A1) AND merged(A5) AND executable_contains(plugins/sdd-bootstrap,resolve-project-context);merged(A5) AND executable_contains(plugins/sdd-bootstrap,resolve-project-context)` with `... until merged(A1) AND merged(A5);merged(A5)`. Preserve the rest of the rendered line verbatim.
- Keep both runtimes' zero-SKIP fingerprint drift, unreadable manifest, missing/empty dependency, unknown SKIP, case-sensitive, and clean baseline tests. The existing `merged-fingerprint-match` fixture has no caller marker. After its existing `merged`+`fingerprint-match` positive assertion and **before** the next `create_fixture`, add the following explicit condition check to each runtime, respectively. The fixture's own A9 identity stands in for A5; this proves the evaluator admits a merged dependency without the former hidden caller-text gate:

```bash
  jq '.[0].activation_condition = "merged(A9)"' "$FIXTURE_MANIFEST" > "$WORK/merged-condition.json"
  if run_evaluator condition "$WORK/merged-condition.json" AC-900 "$FIXTURE_REPO" main >/dev/null 2>&1; then
    pass 'merged-only activation needs no caller marker'
  else
    fail 'merged-only activation needs no caller marker'
  fi
```

```powershell
    $document = @(Get-Content -Raw -LiteralPath $fixture.Manifest | ConvertFrom-Json)
    $document[0].activation_condition = 'merged(A9)'
    $mergedCondition = Join-Path $Work 'merged-condition.json'
    [IO.File]::WriteAllText($mergedCondition, ($document | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    if ((Invoke-Evaluator @('condition', $mergedCondition, 'AC-900', $fixture.Repo, 'main')) -eq 0) {
        Pass 'merged-only activation needs no caller marker'
    } else { Fail 'merged-only activation needs no caller marker' }
```

## 5. RED/GREEN and gate sequence (future application, not performed here)

1. On a controlled candidate application after authorized re-review, run the modified test suites against current evaluators to capture **real RED**: unsupported predicate remains accepted or activation-line mismatch. Do not call the pre-existing suite's GREEN a RED.
2. Apply the two evaluator removals and manifest normalization; run `bash tests/skip-allowlist-manifest.tests.sh` and `pwsh -NoProfile -File tests/skip-allowlist-manifest.tests.ps1` with exit codes and full logs, then relevant caller/loop suites and native CI on the resulting head. Windows PowerShell must run on actual Windows CI; macOS `pwsh` is not that proof.
3. Independently prove A5's current item-10 hash and the reviewed A5 commit identity; re-run the formal amended-spec/design/task gates, then T-010 implementation review and quality gate. T-008's actual host spy remains separately required. A PR head's green CI, this candidate, and a retrospective hash do not set T-010 Implementation Complete or Done.
