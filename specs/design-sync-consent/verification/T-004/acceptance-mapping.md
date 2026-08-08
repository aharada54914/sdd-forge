# T-004 — Stage the lite-spec Design-Source destination candidate for human application: acceptance-first mapping, RED baseline, and GREEN evidence

Written before either artifact below was created, per `Required Workflow:
acceptance-first` (tasks.md T-004). Every `file:line` citation below was
re-verified against the live tree at the time this document was authored,
not carried forward from tasks.md's own citations (WFI-011 discipline).

## Protected-boundary re-verification (done first, per tasks.md instruction)

Re-read at implementation start, not assumed from tasks.md's snapshot:

- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` —
  `PROTECTED_GATE_SUFFIXES` contains
  `'plugins/sdd-lite/skills/lite-spec/SKILL.md'` (42-entry tuple).
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:18` —
  `PHASE2_HUMAN_COPY_TARGETS` also contains
  `'plugins/sdd-lite/skills/lite-spec/SKILL.md'` (19-entry tuple).
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1001-1015`
  (`_is_protected_gate_file`) — the matcher normalizes the path
  (`os.path.normpath`, backslash-to-slash, `.lower()`) and tests
  `normalized.endswith(suffix.lower())` for every entry in
  `_PROTECTED_GATE_SUFFIXES`. There is no `human-copy/` carve-out anywhere
  in this function: any path whose normalized, lower-cased form ends with
  the protected suffix is denied, regardless of what directory precedes it.
- **Empirically confirmed, not just read**: an attempt during this task to
  write a byte-identical copy of the draft to a path ending
  `.../plugins/sdd-lite/skills/lite-spec/SKILL.md` **outside this
  repository entirely** (under the session scratchpad, to locally exercise
  `shasum -a 256 -c` before reporting) was denied by the same guard message
  this section's citations predict, before any file was created — the
  purest form of "suffix match, no path-root carve-out" this task's
  citations describe. No file was left behind; the multi-line command was
  denied atomically. This task therefore does not include a local
  `shasum -a 256 -c` dry run; the MANIFEST format is instead verified by
  direct comparison of the recorded hash against `shasum -a 256` run
  against the draft (see below), which needs no write to a protected path.

Conclusion: the draft candidate is written only at the non-protected path
`specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md`;
`specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`
is not attempted by this task, in any form.

## Scope

One protected target staged, one companion manifest created, the live file
confirmed untouched:

| # | Artifact | Disposition | Task Done-When item |
|---|---|---|---|
| 1 | `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md` | **created** (agent) | item 1 |
| 2 | `specs/design-sync-consent/human-copy/MANIFEST.sha256` | **created** (agent) | item 2 |
| 3 | `plugins/sdd-lite/skills/lite-spec/SKILL.md` (live) | **confirmed unmodified** by diff | item 3 |
| — | `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` | **not attempted** | item 3 (negative half) |

## Field-shape source re-verification (T-002's landed table, not this task plan's snapshot)

Read directly from the committed
`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` at implementation
start:

- `:18-20` — "The layer file this loop records into is
  `specs/<feature>/ux-spec.md` for the full profile and
  `specs/<feature>/design.md` for the lite profile" — the destination fact
  this task's edit to `lite-spec/SKILL.md` must be consistent with, for the
  lite leg.
- `:160-181` (`## Design-Source consent record`) — the landed field table:
  `Egress-Consent` (`granted` / `not-permitted` / `withdrawn`),
  `Egress-Consent-Scope` (feature AND session), `Egress-Consent-Subject`
  (domain left open, OQ-7), `Egress-Destination` (the claude.ai/design
  project id), `Egress-Consent-Expiry` (end of session, never `none`).
  `lite-spec/SKILL.md` does not restate this field table (it is owned by
  `design-sync-loop/SKILL.md`, which `lite-spec` invokes as an internal
  skill per the live Process step 4) — this task's edit is scoped to the
  one destination-path fact the design.md Components table
  (`plugins/sdd-lite/skills/lite-spec/SKILL.md:62-66` row) names, not a
  duplication of the field table itself.

## Acceptance-first mapping: TEST-ID -> assertion -> target -> planned edit

| Test ID | AC | Target | Assertion (from `tests/design-system-contract.tests.sh`) | Planned edit |
|---|---|---|---|---|
| TEST-017 | AC-011 (lite leg) | `$DSC_DRAFT` = `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md` | file exists **and** contains the literal substring `specs/<feature>/design.md` | create the draft as a full copy of the live `lite-spec/SKILL.md`, with Process step 4 (pre-edit `:62-66`) reworded so the `Design-Source`/`Mockup-Status` destination clause reads `` `specs/<feature>/design.md` `` instead of the live file's bare `` `design.md` `` |
| TEST-038 | AC-023 | `$DSC_DRAFT`, `$DSC_MANIFEST` = `specs/design-sync-consent/human-copy/MANIFEST.sha256`, `$LITE_LIVE` | (1) draft file exists; (2) manifest exists and contains a line matching `^<draft-sha256>[[:space:]]+.*plugins/sdd-lite/skills/lite-spec/SKILL\.md$`; (3) `sha256_of("$LITE_LIVE")` equals the suite's recorded `LITE_LIVE_SHA256_AT_T001` constant | create `MANIFEST.sha256` recording the draft's SHA-256 under the destination name `plugins/sdd-lite/skills/lite-spec/SKILL.md`; do **not** touch the live file |

Both rows' targets are read directly from `tests/design-system-contract.tests.sh:164-172` (path variables) and `:359-363`/`:547-560` (the two assertion bodies) at authoring time, not assumed from `acceptance-tests.md`'s prose alone.

## Live-file baseline (captured before any artifact in this task existed)

- `shasum -a 256 plugins/sdd-lite/skills/lite-spec/SKILL.md` =
  `40fdba6f1849effb06a8439a09b92a192a36b42a708c3cf1a253d7d48a50fc74` —
  identical to the suite's own `LITE_LIVE_SHA256_AT_T001` constant
  (`tests/design-system-contract.tests.sh:172`), confirming that constant
  is accurate before this task changes anything.
- `git diff --stat -- plugins/sdd-lite/skills/lite-spec/SKILL.md` = empty
  (no local modifications pending at task start).

## RED baseline, captured before the draft or manifest existed

`bash tests/design-system-contract.tests.sh` and
`pwsh -NoProfile -File tests/design-system-contract.tests.ps1`, both run
directly against the tree with neither artifact present:

| Test ID | `.sh` | `.ps1` |
|---|---|---|
| TEST-017 | FAIL | FAIL |
| TEST-038 | FAIL | FAIL |
| TEST-039 (designed-red, out of scope) | FAIL | FAIL |

Full logs: `red-baseline-sh.log`, `red-baseline-ps1.log` (this directory).
`.sh` totals: `PASS: 117 / FAIL: 4` — the four FAILs are TEST-017, TEST-038,
TEST-039 (designed red, R-OQ-8 part 3, not this task's concern), and the
pre-existing, unrelated `DS-010` failure (noted in prior tasks' verification
records; not touched or caused by this task). `.ps1` totals: `PASS: 48 /
FAIL: 3` — TEST-017, TEST-038, TEST-039 (designed red); no `.ps1` analogue
of the `DS-010` FAIL is present. Neither runtime's exit code is 0, expected.

## Actual result (after creating the draft and the manifest)

`bash tests/design-system-contract.tests.sh` and
`pwsh -NoProfile -File tests/design-system-contract.tests.ps1`, re-run after
both artifacts were created and the live file confirmed unmodified:

| Test ID | `.sh` before -> after | `.ps1` before -> after |
|---|---|---|
| TEST-017 | FAIL -> **PASS** | FAIL -> **PASS** |
| TEST-038 | FAIL -> **PASS** | FAIL -> **PASS** |
| TEST-039 (designed-red, unaffected) | FAIL -> FAIL | FAIL -> FAIL |

Whole-suite totals:

- `.sh`: `PASS: 117 / FAIL: 4` -> `PASS: 119 / FAIL: 2` (net +2/-2, exactly
  TEST-017 and TEST-038; verified by diffing the full sorted `PASS:` line
  set before and after — the only two lines added are TEST-017's and
  TEST-038's, none removed, none of any other Test ID changed). Remaining
  FAILs: TEST-039 (designed red, R-OQ-8 part 3) and the pre-existing,
  unrelated `DS-010` failure — neither in this task's Done-When.
- `.ps1`: `PASS: 48 / FAIL: 3` -> `PASS: 50 / FAIL: 1` (net +2/-2, same two
  Test IDs, same diff method — no other line changed). Remaining FAIL:
  TEST-039 (designed red).
- Neither runtime's overall exit code is 0 (both still exit 1): expected —
  TEST-039 stays red against the live tree until a human applies the
  separately staged CI workflow patch (R-OQ-8 part 3, BL-005), and that is
  by design, not this task's scope.

Full logs: `green-evidence-sh.log`, `green-evidence-ps1.log` (this
directory).

## Live-file no-op verification (post-staging)

- `git diff -- plugins/sdd-lite/skills/lite-spec/SKILL.md` = empty (the
  live protected file was never written by this task).
- `shasum -a 256 plugins/sdd-lite/skills/lite-spec/SKILL.md` =
  `40fdba6f1849effb06a8439a09b92a192a36b42a708c3cf1a253d7d48a50fc74` —
  unchanged from the pre-task baseline above, and equal to
  `LITE_LIVE_SHA256_AT_T001`, which is what TEST-038's third clause checks.
- `git diff -- tests/design-system-contract.tests.sh
  tests/design-system-contract.tests.ps1` = empty (read-only per task
  instructions; the suite was only executed, never edited, by this task).
- `find specs/design-sync-consent/human-copy -type f` = exactly one file,
  `MANIFEST.sha256` — the designed state (design.md Done-When item 4;
  matches `find specs/epic-136-phase3/human-copy -type f`'s precedent).

## Diff of the draft against the live file (the only change staged)

```
--- plugins/sdd-lite/skills/lite-spec/SKILL.md
+++ specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md
@@ -62,8 +62,9 @@
 4. UI アプリで人間が希望する場合のみ、`design-sync-loop` スキル
    （sdd-bootstrap プラグインの内部スキル）を実行する。モックアップは
    `specs/<feature>/mockups/` に、`Design-Source` / `Mockup-Status` は
-   `design.md` に記録される。任意・非ブロッキングで、ツールがない環境では
-   手動手順にフォールバックする。希望しない場合はこのステップを飛ばす。
+   `specs/<feature>/design.md` に記録される。任意・非ブロッキングで、ツール
+   がない環境では手動手順にフォールバックする。希望しない場合はこのステップ
+   を飛ばす。
 5. 各タスクは `Approval: Draft` / `Status: Planned` で生成する。`Risk:` 行は付けない（lite は階層強制を使わない）。
 6. 不明な製品判断は `Open Questions` に残す。勝手に埋めない。
```

One clause, one line's worth of content (rewrapped across three source
lines because the added `specs/<feature>/` prefix no longer fits the
original wrap width) — nothing else in the 84-line file differs from the
live 83-line file. The line-count difference is the rewrap, not scope creep
(cf. T-003's `acceptance-mapping.md`, where its own `:84` edit similarly
shifted the following guarantee from `:86-87` to `:87-88`; content, not
line number, is what BL-004 requires).

## Files created by this task

- `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md`
  — non-protected draft candidate; `shasum -a 256` =
  `d428b0dff8fec5b64917e7fd66796e470dc4d3462ddc2139d428f8bc96681bd8`.
- `specs/design-sync-consent/human-copy/MANIFEST.sha256` — records the hash
  above under the destination name
  `plugins/sdd-lite/skills/lite-spec/SKILL.md`, following the header
  convention `specs/epic-136-phase3/human-copy/MANIFEST.sha256` established.
- `specs/design-sync-consent/verification/T-004/{red-baseline,green-evidence}-{sh,ps1}.log`
  — this document's evidence.

No other file was written by this task. `git status --porcelain` at the end
of this task shows no change to `plugins/sdd-lite/skills/lite-spec/SKILL.md`,
`tests/`, or any file outside `specs/design-sync-consent/human-copy/` and
`specs/design-sync-consent/verification/T-004/`. (`tests/run-all.sh`,
`tests/run-all.ps1`, `specs/design-sync-consent/tasks.md`, and
`specs/mcp-readonly-preflight/verification/qg/run-all.log` show as modified
in the working tree at the time of this task but were **not** edited by
this task — they are pre-existing/concurrent changes from outside this
task's scope, per BL-004's protected-file rollback rules the file set
above is disjoint from.)

## Human handoff (none of the three steps below is performed by this task)

Recorded per `infra-spec.md`'s CI/CD Sequence and this task's own MANIFEST
header:

1. Copy the draft to
   `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`.
2. Verify:
   `cd specs/design-sync-consent/human-copy && shasum -a 256 -c MANIFEST.sha256`
   (must report `OK`).
3. Apply the staged candidate to the live
   `plugins/sdd-lite/skills/lite-spec/SKILL.md`.

Until step 3 lands, TEST-017 stays red against the live tree — the designed
fail-closed state (tasks.md T-004 Done-When; acceptance-tests.md TEST-017
note), not a defect in this task.
