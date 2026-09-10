# RT004 outer-stage source evidence received

Status: partial source inspection completed; no candidate application or PASS.

Human-provided source: `/Users/jrmag/.codex/attachments/92ed9379-fddb-4950-8d96-f2c9dca9ebe0/pasted-text.txt`.
The supplied before/after SHA-256 values both equal
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`.
They identify the reported source revision; they do not establish atomic
acquisition. The requested lines 700–1020 end inside the final jq program at
`. as $a |`, not at the end of validate_passed_stage.

## Findings supported by the supplied excerpt

- `validate_passed_stage` selects the latest attempt/round and calls
  `stage_is_being_opened` unconditionally before evaluating the saved verdict.
  The immediately preceding comments say this establishes downstream tolerance
  even when the current stage already has a valid PASS. The preceding
  `stage_downstream_of_opening` reads `OPENING_VERIFIED_STAGE`. A whole-function
  subshell conversion therefore cannot be assumed behavior-preserving: shell
  state propagation to subsequent stage checks must remain intact.
- The failed verdict branch calls `stage_is_being_opened` again and may return
  success. ADR saved-output validation must still precede that early return;
  it must not be moved solely into the success tail.
- Contract, verdict, reviewer and summary paths are reused by multiple jq and
  manifest checks. Capturing only helper output does not bind those later
  reads to the bytes that the helper verified.
- Manifest paths are resolved against REPO_ROOT, REPO_ROOT_ALIAS and the
  recorded repository root. Redirecting all manifest paths to temporary paths
  would change the contract; snapshot storage paths must stay separate from
  the original logical evidence identities.
- The precheck path is reconstructed later from round_dir and falls back to
  /dev/null when absent. Any composed snapshot fix must cover that later read
  and preserve the explicitly permitted legacy absence rule, not accidentally
  reopen the original file.

## Remaining exact source request

The earlier 700–1020 request was too short. Obtain the rest once, from line
1020 through EOF, so cleanup, remaining helper calls and stage callers can be
reviewed together. Do not retrieve the denied protected source via an alternate
executor, agent or copy.

```bash
cd /Users/jrmag/sdd-forge || exit 1
/bin/bash <<'BASH'
set -eu
source_file='plugins/sdd-quality-loop/scripts/check-workflow-state.sh'
/usr/bin/shasum -a 256 "$source_file"
/usr/bin/sed -n '1020,$p' "$source_file"
/usr/bin/shasum -a 256 "$source_file"
printf '\nRead-only remaining source collection complete. Send all output to Codex.\n'
BASH
```

Next: choose snapshot ownership and cleanup only after all return/exit and
caller paths are visible. Retain opening-state propagation, snapshot continuity,
legacy behavior and fail-closed cleanup. Independent candidate review and
original-path regression GREEN remain required. Prior 14-pass/104-fail evidence
is unchanged; no identical test rerun is claimed as progress.
