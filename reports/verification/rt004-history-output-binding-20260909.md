# RT004 historical reviewer output binding — partial candidate

Status: candidate data only; NOT applied, executed, independently reviewed or merged.

Candidate: `adr-precheck-powershell-generation-candidate-20260909.patch`
SHA-256: `2a20fe9a8249c88ad6d8a230aa3691c6cba5b67548df95444500962f0046cce8`
Supersedes `533a24fe12a44e1098f0032330cf977b6bfc8af4b441d359d74b2c5112b2d070`.

## Newly confirmed integration gap

The previous report's reliance on unchanged workflow-state identity/summary
checks is insufficient for a failed round reopened with a verified opening.
`plugins/sdd-quality-loop/scripts/check-workflow-state.ps1:1059` returns on
that path before contract checks at 1063 and reviewer manifest checks at 1184.
Loading JSON before the return does not validate its contents.
This corrects the assumption in `rt004-powershell-history-candidate-20260909.md`;
it does not reclassify any old failed review as passed.

## Candidate change

The prior-round helper now reads both canonical reviewer output files through
the same safe-path checks, validates their actual impl reviewer schema/role,
and matches nonempty run/session IDs to the corresponding contract reviewer.
For BOTH each output manifest and each contract manifest, it requires one
exact precheck pin, one exact design pin and the complete unique raw canonical
ADR path/hash set. Recognized relocated ADR aliases are rejected before use.
Each output's raw hash is checked again after validation to detect replacement
during that read/validation interval. Historical ADR content is still not
compared to current ADR bytes: legitimate ADR remediation must remain possible.

The current real reviewer output files were inspected: schemas are
impl-reviewer-a/v1 and impl-reviewer-b/v1, stage impl, manifests live under
allowed_input_manifest. They do NOT have feature/attempt/round top-level fields;
the candidate does not invent such a requirement.

## Verification and remaining work

- All seven patch hunk counts, offsets and removed-line anchors matched a fresh
  complete read of the actual precheck source. This is patch-data validation,
  NOT a runtime test.
- The actual protected precheck has an empty git diff; no protection bypass.
- Main-agent review: output path derivation maps impl-reviewer-a/b to
  reviewer-a/b.json; empty/singleton arrays remain explicit; string comparisons
  are case-sensitive. No claim of independent approval.
- Still needed: failed-round verdict/summary/identity isolation verification in
  the workflow-state consumer BEFORE its opening return, full Bash parity,
  workflow-state PS5.1-compatible integration, and executable regressions.
- New mandatory regression cases: correct historical output with changed
  current ADR; output-only missing/duplicate/wrong-hash ADR; wrong output
  precheck/design pin; wrong role/schema/run/session; linked/missing output;
  canonical-path alias; output replacement; no-extension legacy unchanged.
- The helper is NOT a complete historical gate. Distinct reviewers/sessions,
  final verdict linkage and narrative isolation must not be assumed checked by
  the opening return. Complete these consumers before human application.

PR list was refreshed: open PRs 401, 400, 394, 390, 381, 371, 245. No new
running CI handle was established and no merge readiness was claimed.
