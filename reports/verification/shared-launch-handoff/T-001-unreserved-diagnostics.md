# T-001 unreserved diagnostics — 2026-10-08

This is diagnostic evidence, not a review verdict, reservation, lifecycle transition, or permission to launch a formal reviewer. No global configuration or hooks were changed. Existing failed histories are preserved.

## Native actual-permission probe

- Command, from `T-001-output/staged`: `rtk proxy python3 plugins/sdd-review-loop/scripts/probe-nontty-review.py reports/review-context/T-001-unreserved-diagnostic-source.json`.
- Native diagnostic session: `2191c623-ec05-4e81-92e2-f49d8f796742`; reservation: not performed.
- Native child exit: 0; probe exit: 1, `admitted Read did not execute`.
- Log: `T-001-output/verification/T-001/native-permission-impl.txt`.
- Native transcript: `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-shared-review-launch-integration-sdd-forge-reports-verification-shared-launch-handoff-T-001-output-staged/2191c623-ec05-4e81-92e2-f49d8f796742.jsonl`.
- Exact hash batches executed after the normal Fact-Forcing Gate response; no hook was disabled. The model resolved relative Read paths against the owner repository root, not the staged working directory. The pinned guard rejected those absolute paths, including the supposed admitted Reads. A compound hash-plus-pwd Bash call was also denied. No denied operation was rerouted or repeated with an alternative executor.
- Because the probe stopped on the missing admitted Read, admitted-Read success, the intended outside-fixture Read assertion, and fresh-session collision rejection are NOT VERIFIED by this run. The native child returning 0 is not probe success.
- Canonical and staged identity-ledger SHA-256 remained `97fdfb3a72276dc8141abca03dfd9ccd477c6ed2f5893cf34ea38de302ddee26` after this diagnostic. Its source invocation is diagnostic-only and is not a complete formal reviewer manifest.
- The probe's temporary files were cleaned by its existing TemporaryDirectory behavior. The transcript is retained; missing temporary receipts are not reconstructed as evidence.

## Literal disposable Git checkout rollback

- Independent local clone: `T-001-git-rollback`, created using `git clone --no-hardlinks --no-checkout` from the owner checkout.
- Detached checkout: `9ce19abe90df0cb83e385f96855e4843318a8807` (also verified as the owner HEAD).
- Copied 26 immutable snapshot files after validating each before hash, preserving the original bytes.
- Candidate-copy setup failed with EACCES because immutable snapshot mode 0444 propagated into the disposable clone. The first candidate overwrite, `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`, was refused. No chmod, deletion/recreation, alternative executor, or retry was performed.
- Setup evidence: `T-001-output/verification/T-001/git-rollback-setup.txt`.
- Read-only baseline execution in that literal Git checkout passed all four suites (7 + 18 + 9 + 8 = 42 tests), using `python3 -B`; log: `T-001-output/verification/T-001/git-rollback-baseline.txt`. This confirms the before-byte fixture runs, not a completed candidate-to-baseline rollback.
- Literal checkout candidate/apply/restore cycle is NOT COMPLETE. Earlier `T-001-output/verification/T-001/rollback.txt` proves only the separately identified disposable source-tree rollback, not this Git checkout cycle.

## Implementation report location

The native implementation report remains at `T-001-output/staged/reports/implementation/shared-review-launch-repair/T-001.md`. It was not placed directly beneath `T-001-output/reports/`. These diagnostics do not revise that report's implementation provenance or claim a formal review.

## Authorized follow-up: isolated Read-path candidate

The preceding failed run and setup remain historical evidence. The following follow-up was explicitly authorized without reviewer reservation or owner adoption.

- Actual transcript tool inputs confirmed that all six Reads used the owner root rather than the staged root. `probe-nontty-review.py` rendered relative Read requests; the shared formal `expected_prompt` also exposed only relative invocation/manifest/boundary paths. Relative identities were correct, but tool-target presentation was ambiguous.
- Separate candidate directory: `T-001-path-candidate`, copied from the completed native output. Changes are limited to `validate-nontty-spec-launch.py`, `probe-nontty-review.py`, and `quality-nontty-transport.tests.py`. The original native output, immutable snapshot, owner code, guards, policy scope, relative manifest identities, receipt identities and hash commands are unchanged by this follow-up.
- Candidate adds one shared absolute Read-path renderer. The diagnostic renders requested Reads, including the deliberately unadmitted fixture, as canonical absolute paths. Enforced formal prompts list the canonical absolute admitted targets while explicitly preserving relative output/hash/manifest identities. Legacy non-strict spec prompt bytes remain unchanged. Formal callers use this shared builder; no separate caller-specific widening was added.
- Focused regression asserts the renderer matches pinned policy paths, diagnostic samples stay inside that policy, formal prompts contain the same targets and preserve relative invocation identity. Existing native guard tests still exercise denied outside paths. Initial regression failed with the missing renderer, then all four affected suites passed (43 tests).
- Candidate is **not adopted into owner** and is not attributed to the original native implementation turn. No formal independent review or quality-gate verdict is claimed.
- Patch: `T-001-output/verification/T-001/path-candidate.patch`; SHA-256 `38fa4a7ba6a5600e141b9c378317b1acf281485d733cb52506a0b57621c1e0d7`. `git apply --check` against owner succeeded; no apply was performed. File-by-file before/candidate hashes: `T-001-output/verification/T-001/path-candidate-hashes.json`.
- Test logs: `T-001-output/verification/T-001/path-red.txt` and `path-green.txt`.

### Fresh unreserved native follow-up

- Command from the separate candidate directory: `rtk proxy python3 plugins/sdd-review-loop/scripts/probe-nontty-review.py reports/review-context/T-001-unreserved-diagnostic-source.json`.
- Fresh native diagnostic session: `96643428-9b95-4152-9603-a15cd63f13e3`; no reservation; overall exit 0.
- Log: `T-001-output/verification/T-001/path-native-permission.txt`.
- Admitted/control/source-invocation Reads executed; the intended outside fixture Read and compound Bash were denied by the pinned guard; seven ordered hash results were verified; reuse of the same session was rejected without changing its transcript. Normal first-Bash Fact-Forcing retry was observed with identical command bytes. No actual pinned-guard refusal was retried or rerouted.
- Transcript: `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-shared-review-launch-integration-sdd-forge-reports-verification-shared-launch-handoff-T-001-path-candidate/96643428-9b95-4152-9603-a15cd63f13e3.jsonl`; SHA-256 `31f3844ec29cce6923e19059d5391dec47bf5b94ff5d3ea84c37d7eaa5923bec`.
- Native guard SHA-256 remained `0a3d9961c53d01520a37fc41bf86ef7a7e5e6cc3254d427789b6115634e1369b`. Owner and candidate ledger hashes both remained `97fdfb3a72276dc8141abca03dfd9ccd477c6ed2f5893cf34ea38de302ddee26` after execution.
- This proves the unreserved diagnostic path on this host. It is not execution of a formal reviewer or evidence that a reserved review passed.

### Completed literal checkout before-byte restore cycle

Both task-owned files are untracked at the fixed HEAD, so there is no Git index mode or Git-stored baseline for them. Parent explicitly authorized using observed owner/staged mode 0644 in the disposable fixture only. Exact real paths, uid 501, before SHA-256, candidate SHA-256, and source mode 0644 were checked before correcting the two fixture modes. Original owner and snapshot permissions were not changed.

The original completed T-001 two-file candidate (not the later Read-path candidate) was copied into `T-001-git-rollback`: 43 tests passed. Then its two files were restored from the immutable snapshot; all 26 baseline hashes matched; all four baseline suites passed (42 tests). This completes a before-byte restore cycle **on a literal detached Git checkout**, not restoration from Git of untracked files.

Evidence under `T-001-output/verification/T-001/`:

- `git-rollback-apply.txt`: exact fixture targets, modes and candidate hashes.
- `git-rollback-candidate-green.txt`: candidate 43 tests passed.
- `git-rollback-restored-hashes.txt`: all 26 before hashes after restore.
- `git-rollback-restored-green.txt`: restored baseline 42 tests passed.

The earlier EACCES log is retained. No ledger, task status, verdict, source permission or global permission change was made.
