# A7 security contract supplement — review handoff

Date: 2026-10-04
Status: candidate only; independent re-review NOT PERFORMED. No formal gate verdict or task status changed.

## Fixed inputs

- Existing five-document candidate: `contract-amendment-candidate-20261001.patch`, SHA256 `ef99dc8a5e0da14164c07da63350dbdd84b61ae7666ed1e005d5747125403cf5`.
- Supplemental candidate: `security-contract-supplement-20261004.patch`, SHA256 `dc27734d6d5663098c6a5221b309b0ecf8e349075d5f641b0698c14de0301e1e`.
- Frozen security input: `specs/epic-195-a7-compatibility/security-spec.md`, SHA256 `4b31d724cd326ee89b87de867e0f857cf2b7ca69d794956ebb7ce4edc6ff8d31`.
- Proposed security bytes after the supplement, computed in memory without adoption: SHA256 `6323026f1b1b867364cab929b056f55c3ef06e08f0609fe4de3c403362db25e5`.

Review the existing candidate and supplement together. These hashes bind technical audit inputs only; they are not a replacement for any stage's complete manifest or independent review.

## Scope and identifier sweep

Swept all four layer specifications for `REQ-007`, `AC-034`, `AC-035`, `activation_condition`, `dependency-present`, `merged(...)`, `FP-A5-CALLER-CONTRACT-10`, `1886-1915`, and `9b549be9`.

- security-spec.md: lines 50, 63, 73, 174 replaced the superseded merge-only SKIP rule with complete activation-condition semantics. Line 63 names all four case-sensitive predicates and A5 caller conditions. Fingerprint drift remains independently enforced when merged, even if complete activation is false. Line 94's old two-predicate runtime shorthand was also replaced. No other sweep hit asserted the superseded rule.
- ux-spec.md: no matching identifiers; no change required.
- frontend-spec.md: lines 22 and 69 describe the manifest generically; no conflicting predicate membership or activation rule.
- infra-spec.md: lines 6, 32, 145–147, 155, 169, 218–224 describe manifest storage, independent merged fingerprint drift, or rollback/reverification; no conflicting activation rule.

Layer originals rehashed unchanged:

- ux-spec.md: `5324dcaeffe2cccab149d3365f9ea63df579d95b22263a5d4066e0ddeae5bdba`
- frontend-spec.md: `78ef6c214ed677c49ee61c4456b04f3588bd1f05990c4e1b7daa99fcca5209f1`
- infra-spec.md: `a62bd5d421590fed03945fa12826d29ab9450bf4ccc8e20f4dff319e9433b96c`
- security-spec.md: hash above.

## Applicability evidence

Shell used `rtk proxy`, login=false. From the owner checkout, the following command exited 0 with empty stdout/stderr:

```text
rtk proxy git apply --unidiff-zero --check specs/epic-195-a7-compatibility/verification/T-010/contract-amendment-candidate-20261001.patch specs/epic-195-a7-compatibility/verification/T-010/security-contract-supplement-20261004.patch
```

The supplement uses zero-context single-line hunks and therefore requires `--unidiff-zero`. An earlier plain `git apply --check` rejected that patch format; this was an ordinary applicability diagnostic, not a protection refusal. No patch was applied to frozen originals. Existing candidates and logs were preserved.

## Remaining boundaries

This handoff provides an applicable, hash-fixed six-document contract candidate, not formal acceptance. Independent specification/design/task provenance re-review, source adoption authorization/mechanism, implementation review and quality gate remain separate requirements. Existing head CI and focused suite successes do not validate these newly proposed specification bytes. No reservation, Git mutation, protected-file bypass, or Done transition was performed.
