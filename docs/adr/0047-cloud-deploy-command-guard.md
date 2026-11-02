# ADR-0047: Deny cloud deploy commands in shell tools (accident prevention)

Status: Rejected (human decision, 2026-11-02): the guard is not adopted. The
prototype and its measurements are kept as a record. It does not amend ADR-0017,
ADR-0018, ADR-0046 or `docs/ai-dlc-foundation-decision-v2.md`.

Reason: a string match is bypassed by wrappers, scripts, SDK calls and MCP
tools (measured below), so it cannot be the control. Cloud-side permissions and
the CI approval flow (`docs/cloud/least-privilege.md`,
`docs/cloud/ci-deploy-pattern.md`) are the control, and the guard would add
three implementations and protected tests to maintain for accident prevention
only. Revisit only if accidental deploys by the agent are observed in practice.

## Context

The PreToolUse approval guard (`sdd-hook-guard.py` and its JS and PowerShell
counterparts) protects gate files and approval fields. Measured directly on the
Python guard, it allows `terraform apply -auto-approve`,
`az deployment group create ...` and `cdk deploy --require-approval never`
(exit 0), while a write to a protected gate file is denied (exit 2). No guard
treats a cloud deploy as a gated action.

Permission scoping on the cloud side is the main control
(`docs/cloud/least-privilege.md`). On Azure it cannot separate "preview" from
"deploy": what-if needs the same permissions as a deployment.

## Proposal (not adopted)

Add a string-match check for shell tools that denies common deploy/destroy
commands, as an **accident-prevention layer, not a security boundary**.

Denied (first non-flag argument, after env assignments and wrappers such as
`npx`): `terraform|tofu apply|destroy`, `cdk deploy|destroy`,
`azd up|provision|deploy|down`,
`aws cloudformation deploy|create-stack|update-stack|delete-stack|execute-change-set`,
and `az ... deployment ... create|delete`. Preview and validation commands
(`plan`, `validate`, `what-if`, `cdk diff`, `cdk synth`, `create-change-set`)
are not denied.

### Choices that were open

1. Always deny, or allow when a human has placed a marker. The prototype always
   denies.
2. Whether this belongs in the guard at all. Decided: no.

## Evidence (prototype, Python guard only)

The patch is `docs/cloud/prototypes/guard-deploy-commands.patch`. Applied to a
throwaway copy of `main`:

- All 12 deploy forms tried were denied (exit 2); the unpatched guard allowed
  them (exit 0): the examples above plus `npx cdk deploy`,
  `AWS_PROFILE=x cdk destroy`, `cd infra && terraform apply` and
  `echo hi; cdk deploy`.
- All 14 preview or ordinary commands tried were still allowed, including
  `terraform plan`, `az deployment group what-if`, `cdk diff`,
  `echo "terraform apply"` and `grep -rn "cdk deploy" docs`.
- Existing suites on that copy: `guards.tests.sh` 135 passed, 0 failed;
  `guard-negative-corpus.tests.sh` 38 passed, 0 failed, 11 skipped;
  `guard-parity.tests.sh` 262 passed, 0 failed.

## Limits

- The check is a string match. These forms were measured to pass it:
  `make deploy`, `bash -c "cdk deploy"`, `sh ./deploy.sh`, `eval "cdk deploy"`,
  `xargs cdk deploy`, `$(echo cdk) deploy`. SDK calls (for example boto3) and
  MCP tools also bypass it. It must not be described as preventing deployment.
- The prototype changes only the Python implementation. The JS and PowerShell
  guards are not changed (PowerShell could not be run in the authoring
  environment). The parity suite passes on its existing corpus, so it does not
  show that the new behavior is equivalent across the three implementations.
- A real change also needs: the three guard implementations, the generated
  guard invariants if the pattern list is shared, and new protected tests.
  These are protected gate files; a human applies them with
  `apply-human-copy.sh`. The agent does not edit them.

## Consequences

- The approval guard keeps not covering deploy commands. `docs/cloud/README.md`
  states this, and says that the cloud-side controls are the main line.
- The prototype patch must not be applied unless this ADR is superseded.
