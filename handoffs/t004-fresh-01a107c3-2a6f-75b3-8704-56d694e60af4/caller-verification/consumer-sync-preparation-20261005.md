# Consumer synchronization preparation — 2026-10-05

Status: candidate-only correction verified; eight product consumers NOT applied.
No native allocation, turn, reservation, review verdict, status change or guard activation.

## Candidate correction

Root: `/private/tmp/sdd-guard-main.3JEj4I/repo`.
Original candidate: `reports/verification/spec-boundary-consumers-human-apply.py`.
Original SHA-256: `af68c3c4fce78163d9bcaddbbf87adb7c8270b7f88318020de5f7ecbab636997`.
Raw original backup: sibling `spec-boundary-consumer-candidate-original.py`.

The original dry run matched all eight BEFORE pins and prepared transformations
without writes. It did not establish semantic correctness.
The boundary insertion after calibration in candidate lines 108–123 shifted the
manifest arrays, but existing `tests/lib/loop-driver.sh:795,810` reconstructed
fixed indices. With investigation present A lost precheck and B lost summary.

Regression command (A8 owner, login=false):
`rtk proxy python3 -B handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/consumer-candidate-manifest-test.py`

RED: exit 1; 1 unittest, four subcases, two failures: A/investigation and
B/investigation. The missing members were respectively
`reports/synthetic/precheck-result.json` and
`reports/synthetic/integrated-summary.json`.
The test executes only two extracted manifest-building functions against inert
temporary paths, not gate/guard commands or historical rejected operations.

Minimal candidate correction via apply_patch: replace both fixed tail copies
with `"${entries[@]:2}"`, preserving all trailing manifest members. The original
candidate backup was saved first. GREEN: exit 0, `Ran 1 test in 0.028s`, `OK`,
all four subcases. This is not the full consumer regression suite.

## Exact actual refusal — operation stopped

Before any product apply, read-only raw-backup/diff preparation attempted:

```text
rtk proxy python3 -B -c 'import runpy,json,difflib,hashlib; m=runpy.run_path("reports/verification/spec-boundary-consumers-human-apply.py"); p="plugins/sdd-review-loop/scripts/spec-review-precheck.sh"; b=(m["ROOT"]/p).read_text(); assert hashlib.sha256(b.encode()).hexdigest()==m["PINS"][p]; a=m["transform"](p,b); print(json.dumps({"path":p,"before":b,"after_hash":hashlib.sha256(a.encode()).hexdigest(),"diff":"".join(difflib.unified_diff(b.splitlines(True),a.splitlines(True)))}))'
```

Tool response (PreToolUse, command did not run):

```text
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo..
```

No retry via another executor/tool, no apply_patch fallback for the refused
operation, no human-only `--apply-human` invocation. Product consumer application
and its full regression remain unperformed. This refusal is distinct from the
historical proxy-cat and unknown-argv rg refusals; no common cause is asserted.

## Static human-only application assessment

The already-read original `main()` and the exact applied candidate-only patch
were inspected, without rereading or executing the refused preparation command.
The patch modifies only transformation return construction. `PINS`, `ROOT` and
`main()` are unchanged. Thus all eight BEFORE pins and the existing human-only
application mechanism remain enforced. Current post-correction dry-run and full
consumer regressions were NOT executed; the human command below is application,
not a claim of completed verification or a bypass instruction for an agent.

Human-operated normal application command (not run by this agent):

```text
rtk proxy python3 -B /private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/spec-boundary-consumers-human-apply.py --apply-human
```

The script itself resolves its fixed root `/tmp/sdd-guard-main.3JEj4I/repo`
(the previously observed alias of the canonical `/private/tmp/...` checkout),
checks regular/non-symlink files and all original SHA-256 pins, constructs all
candidates before writes, saves every raw original under a new temporary
`sdd-boundary-consumers-*` backup directory with relative paths, prints `BACKUP:`,
rechecks all source bytes/symlink state, writes the eight candidates and compares
each byte-for-byte readback. It prints each `APPLIED` path. It does not run gates,
alter ledger/status, commit, or activate an installed guard. It is not atomic:
a write/readback failure after earlier writes requires restoring from its printed
backup; no automatic rollback or concurrency lock is claimed. Any refusal or pin
mismatch stops this operation and must not be routed around.

Eight targets and retained BEFORE pins:

| Relative path | Before SHA-256 |
|---|---|
| plugins/sdd-review-loop/scripts/spec-review-precheck.sh | 81e345db1d1d96acec6a5ddd2159e01d6653cfb879ad2cf2a032e20b887b4c1b |
| plugins/sdd-review-loop/scripts/spec-review-precheck.ps1 | ac2532f6450dde24b78e4ab7b577a04ef9b1e8d165a180152737789b5ac6fb85 |
| plugins/sdd-quality-loop/scripts/check-workflow-state.sh | 001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f |
| plugins/sdd-quality-loop/scripts/check-workflow-state.ps1 | 13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db |
| plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md | b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9 |
| tests/spec-review-loop.tests.sh | 30fe033359d0660feaad0656581cdd5f60db09b76b52bf770703fae12d2fa602 |
| tests/lib/loop-driver.sh | fc75d56e0118099f553367adf042aa5865808f3ace2ad48ff403cff0e75ca9de |
| tests/lib/loop-driver.ps1 | 44283cc14f6377230bb4b9799585c8de6e364a4ce1ea1a4b2ba4454ffd0ed3f0 |

After application, syntax checks and focused consumer/boundary regressions remain
required before any formal launch. The candidate's earlier printed AFTER hash
for `tests/lib/loop-driver.sh` is superseded by the candidate-only fix and must
not be reused. No new AFTER hash for that file is asserted in this note.
