# Independent Implementation Review: T-005 Attempt 3

## Identity

- Task: `T-005`
- Reviewer run ID: `agent-cost-context-isolation-T-005-review-run-03`
- Reviewer session ID: `agent-cost-context-isolation-T-005-review-session-03`
- Reviewer agent instance ID: `agent-cost-context-isolation-T-005-review-agent-03`
- Model tier: `standard`
- Provider/model: `openai/gpt-5.2-codex`
- Isolation mode: `fresh-agent`
- Fallback mode: `none`
- Input manifest:
  `reports/implementation/agent-cost-context-isolation/manifests/T-005-review-3.json`

## Hash Gate

PASS. The input manifest was read before substantive inputs. The initial hash
command was unusable because this session's default PATH did not expose
`shasum` or `awk`; its empty results were discarded. The gate was rerun with
absolute `/usr/bin/openssl` and all 23 allowed inputs matched their declared
SHA-256 values before any allowed input was substantively inspected.

Exact successful command:

```bash
jq -r '.allowed_inputs[] | [.sha256,.path] | @tsv' \
  reports/implementation/agent-cost-context-isolation/manifests/T-005-review-3.json |
while IFS=$'\t' read -r expected path; do
  line=$(/usr/bin/openssl dgst -sha256 "$path")
  actual=${line##*= }
  if [ "$actual" = "$expected" ]; then
    printf 'OK  %s  %s\n' "$actual" "$path"
  else
    printf 'BAD expected=%s actual=%s path=%s\n' \
      "$expected" "$actual" "$path"
  fi
done
```

Observed result: 23 `OK` lines, zero `BAD` lines.

## Commands and Results

1. Syntax checks:

   ```bash
   /bin/bash -n \
     plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
     tests/review-agent-isolation.tests.sh
   ```

   Result: exit 0.

   ```powershell
   $tokens=$null
   $errors=$null
   [void][System.Management.Automation.Language.Parser]::ParseFile(
     (Resolve-Path "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"),
     [ref]$tokens,
     [ref]$errors
   )
   if ($errors.Count) { exit 1 }
   "POWERSHELL_PARSE_OK"
   ```

   Result: exit 0, `POWERSHELL_PARSE_OK`.

2. Focused suite:

   ```bash
   PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin \
     /bin/bash tests/review-agent-isolation.tests.sh
   ```

   Result: exit 0:

   ```text
   ok: sequential reviewer and evaluator contexts are distinct, authorized, and hash-chained
   ```

3. Wrong-task evaluator fixture. An isolated repository declared feature `f`
   and a current review target of T-005, but its invocation manifest contained
   only `reports/implementation/f/T-999.md` and an output whose exact path/SHA
   appeared in that report. The manifest schema has no task ID.

   ```bash
   plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
     /tmp/t005-r3-fixture/manifest.json /tmp/t005-r3-fixture
   pwsh -NoLogo -NoProfile \
     -File plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
     -Manifest /tmp/t005-r3-fixture/manifest.json \
     -RepositoryRoot /tmp/t005-r3-fixture
   ```

   Results:

   ```text
   REVIEW_CONTEXT_OK 9bc7408c1fd2c921e9e483f6bbbf73367eb681a9ef3d0a734ed252c8f8d81e78
   REVIEW_CONTEXT_OK 9bc7408c1fd2c921e9e483f6bbbf73367eb681a9ef3d0a734ed252c8f8d81e78
   T-999_AS_T-005_TARGET statuses Bash=0 PowerShell=0
   ```

4. Output-table parser parity fixture. The same isolated report used this
   malformed three-column row beneath the two-column `## Outputs` header:

   ```text
   | `plugins/task/out.txt` | `<correct lowercase SHA-256>` | extra-column
   ```

   Exact validator commands were the same as command 3.

   Results:

   ```text
   Bash:
   REVIEW_CONTEXT_OK 9bc7408c1fd2c921e9e483f6bbbf73367eb681a9ef3d0a734ed252c8f8d81e78
   exit 0

   PowerShell:
   REVIEW_CONTEXT_PATH: sdd-evaluator contains a real but role-unlisted path: plugins/task/out.txt
   exit 1
   ```

## Attempt-2 Finding Retest

| Attempt-2 finding | Result | Evidence |
|---|---|---|
| Unrelated real plugin/test/contract/ADR/verification input accepted without exact report path/SHA | PASS for the reported defect | Both implementations now require exactly one implementation report and match non-spec evaluator inputs to its output path/SHA set. The focused suite rejects the real unrelated plugin fixture and accepts the exactly declared output. |
| PowerShell deletes a foreign reservation lock | PASS | PowerShell tracks `$lockAcquired` and removes the lock only when true. The focused suite verifies that both runtimes reject reservation while preserving the foreign lock byte-for-byte. |
| Object-valued `allowed_input_manifest` accepted by PowerShell | PASS | Both runtimes require an array; the focused suite rejects the object form as `REVIEW_CONTEXT_CONTRACT`. |
| Object-valued ledger `records` accepted by PowerShell | PASS | Both runtimes require an array; the focused suite rejects the object form as `REVIEW_CONTEXT_IDENTITY`. |
| String-valued invocation/ledger sequences accepted by PowerShell | PASS | Both runtimes require JSON numeric integers; the focused suite rejects the invocation string as `REVIEW_CONTEXT_CONTRACT` and ledger string as `REVIEW_CONTEXT_IDENTITY`. |

The chronological ledger, persisted identity reuse checks, reviewer/evaluator
one-role boundaries, symlink rejection, foreign-lock ownership, and atomic
ledger replacement were also inspected. No additional Critical/Major finding
was established in those areas.

## Findings

### Critical

1. **The Done-evaluator validator is not bound to the current task and accepts
   any single T-NNN implementation report from the feature.**

   The invocation contracts contain `feature` but no `task_id`
   (`validate-review-context-set.sh:122-159`;
   `validate-review-context-set.ps1:138-158`). At the evaluator boundary, both
   validators merely count one path matching
   `reports/implementation/<feature>/T-[0-9]{3}.md`
   (`validate-review-context-set.sh:248-258`;
   `validate-review-context-set.ps1:246-259`). They never compare that T-NNN
   with the quality gate's current task.

   The isolated adversarial fixture substituted `T-999.md` while evaluating
   T-005; Bash and PowerShell both returned exit 0 and the same
   `REVIEW_CONTEXT_OK` record hash. Exact output path/SHA binding therefore
   binds files to whichever report the caller supplies, not to the task whose
   Done decision is being made. A stale, unrelated, or easier task report can
   define the evaluator's evidence set for the current task, invalidating the
   independent Done boundary required by REQ-005 and AC-002.

   Minimum correction: add the current `task_id` to the closed invocation
   contract (or pass it as a separately authenticated validator argument) and
   require the sole report path and report heading/task field to match exactly
   before parsing its Outputs table. Add same-feature wrong-task rejection
   fixtures for both runtimes.

### Major

1. **Bash and PowerShell recognize different `## Outputs` table grammars.**

   Bash splits any line beginning `| \`` on backticks and accepts the second
   and fourth fields when at least five fields exist
   (`validate-review-context-set.sh:63-77`). PowerShell requires the entire
   canonical two-column row to match
   `^\| \`<path>\` \| \`<sha>\` \|$`
   (`validate-review-context-set.ps1:264-276`).

   Consequently Bash authorized an output from a row with an extra third
   column while PowerShell rejected the identical manifest as
   `REVIEW_CONTEXT_PATH`. This violates REQ-010 and leaves authorization
   dependent on which runtime launches the evaluator.

   Minimum correction: make Bash enforce the same anchored two-column grammar
   as PowerShell (or define one shared deterministic table contract), then add
   malformed-row parity fixtures including extra columns, trailing text,
   missing delimiters, and embedded backticks.

### Minor

None.

## Verdict

**FAIL**

T-005 attempt 3 still has one Critical and one Major defect. It must not
proceed to a passing quality-gate decision until the evaluator is
cryptographically bound to the current task and both runtimes parse the
implementation report's Outputs table equivalently.
