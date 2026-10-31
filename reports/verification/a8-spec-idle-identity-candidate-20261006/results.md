# A8 idle identity candidate results — 2026-10-06

RELEASE_READY: false
Candidate only. Not a formal SDD verdict, protected application, native launch or authorization.

## Executed

All commands used `rtk proxy`, login=false, in the owner recorded in scope.md.

| Command | Result |
| --- | --- |
| `python3 -B reports/verification/a8-spec-idle-identity-candidate-20261006/candidate_test.py` | exit 0; isolated patch apply/reverse, static lifecycle retention, A/B exact role source, Sonnet/dontAsk/Read-Grep-Glob arguments, DEVNULL stdin, 3 invalid-role negatives; subprocess mocked, no native child |
| `git apply --check reports/verification/a8-spec-idle-identity-candidate-20261006/candidate.patch` | exit 0; owner unchanged |
| `bash tests/review-context-boundary.tests.sh` | exit 0; 32 citation anchors, RCB-001..010 plus 005b in Bash/PowerShell, 3 Python runtime tests, regular/hardlink/symlink investigation completeness suites; disposable fixture ledgers only |
| `python3 -B reports/verification/a8-spec-idle-identity-candidate-20261006/human_apply.py --check` | exit 0, `READ-ONLY CHECK OK; NOT APPLIED; no authorization inferred` |
| `python3 -B reports/verification/a8-spec-idle-identity-candidate-20261006/helper_test.py` | exit 0; 8 disposable-fixture cases: check, wrong patch, wrong preimage, wrong HEAD, symlink, nonTTY, wrong confirmation, apply+backup+readback |

Boundary regression retained independent run/session reuse rejection, double-reservation rejection, wrong sequence rejection and exact extension acceptance. It does not authenticate a live host receipt. Static prose assertions do not prove runtime role/idle validation.

Independent review identified unintended Bash inheritance from the A7 implementation-role helper. Repair 1 removed Bash from both custom-agent tools and CLI tools, and changed the assertions to match spec A/B frontmatter. Candidate tests were rerun successfully after this material correction. No permission setting was changed.

## Fixed hashes

- candidate.patch: `2dd88a0a4e6eb5b8754a194b118ac8b6b4f6477a560660647a13038ae4cc5d0d`
- human_apply.py: `a83a905ac543ee85e04d55e00506574a69d0c5184e5d907530656088c7eb27c0`
- idle_launcher_candidate.py: `0c53c738323d21273e86c95ecfec85bf73c7caffea728fd896b371d4ca5dfc2a`
- SKILL before, rechecked unchanged: `b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9`
- SKILL proposed after, observed in temporary fixture only: `96df5aa6fb219b7c231ad10381de33cedc3d6827a3d5a45e88c73dac25513d45`
- real identity ledger before/after unchanged: `c95ef67d1c227c8d31320a2dd526d50940dd52745240189e7e29eb9460986264`
- real A8 attempt4 round1 precheck before/after unchanged: `3718c701f23907c710c3c98cb1cc64faec5d906bdbd577b2882c92d5bca32467`

Human helper reuses the existing A8 blocked-continuation helper's fixed owner/HEAD/patch/preimage, backup, recheck, normal git apply and posthash pattern. Adds terminal+typed phrase; targets exactly one SKILL. Its default is read-only. Production --apply was NOT RUN.

## Pending boundary

Formal review of issuer-guarantee change and sanctioned protected application are required. The independent artifact review is separate. No reservation, real host allocation, first prompt, formal A/B verdict, CI or workflow-state transition occurred.

Before any future formal dispatch, verify actual A8 host-issued idle child receipt/configuration and first-turn byte fidelity. Existing Read/Grep/Glob-only native digest computation is unproved; the requirement must not be implemented by silently adding Bash or bypassing an actual refusal. This is a distinct possible residual contract inconsistency, not solved by the three-span identity repair.

Only after those gates permit application, the human-operated command is:

```text
cd /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
rtk proxy python3 -B reports/verification/a8-spec-idle-identity-candidate-20261006/human_apply.py --apply
```

Do not execute from an agent, update pins to force application, or treat this command as a released instruction before independent/formal approval. On any refusal preserve it and stop.
