# A8 T-001 minimal driver patch — preparation only

Date: 2026-10-05

Candidate: `reports/verification/a8-nonce-driver-minimal-candidate-20261005.patch`

SHA-256: `446b149577681c3f69f3561796f6d0b69eee67871725ff1192bff273c881ca61`

Unapplied. No frozen spec, protected original, lifecycle field, reservation or verdict was changed. Current AGENTS.md and T-001 tasks.md:136-310 were read; T-001 remains Approved / Planned, medium risk, acceptance-first. The tester skill confines this work to reviewable test changes and static verification. Design adoption/re-review remains prerequisite to implementation; this candidate does not resolve that gate by itself.

## Exact scope and pins

| Target | Original lines | Base SHA-256 | Candidate SHA-256 (in memory) |
|---|---|---|---|
| tests/cross-runtime-handoff.tests.sh | 128-131, 214, 218 | 479ab524fae57a47c117129f16fcf045b7010af9544f181bb369389d957027ae | fe2dfc070e6290f2afc399d5a21176d19876c647de0edec98a0c17603ae26d25 |
| tests/cross-runtime-handoff.tests.ps1 | 154-156, 200, 204 | 8a01086d9612cf4f21a243ac407fef5cb26af9f94082209927e12e118daf29f9 | 4d87f40fb97f33c4f80d6eb0bdbedc615b94844f33b775f59f7f6fb9a154eab6 |

Six hunks only. The live prompts read both input artifacts without supplied nonce values; expected output bytes include both nonces. Each fixture consumer reads both temporary files, while expected digest is independently constructed from producer-owned values. Two isolated mutations alter nonce1 only and nonce2 only, reject the original output digest, then verify freshly consumed output against the independent expectation. Fixtures are restored afterward. Models, Auto rejection, permission flags, schemas, registration, T-004 and activation behavior are untouched.

## Static checks actually executed

1. `rtk proxy git apply --check --unidiff-zero reports/verification/a8-nonce-driver-minimal-candidate-20261005.patch` — exit 0, empty stdout/stderr; check only, no apply.
2. `rtk proxy python3 reports/verification/a8-nonce-driver-static-check-20261005.py` — exit 0. Validated exact base hashes, exactly two targets / three exact hunks each, then parsed candidate Bash with `bash -n`, compiled its embedded Python without executing it, and parsed candidate PowerShell through its AST parser. Candidate text remained in memory; no candidate driver or native CLI executed.

```text
tests/cross-runtime-handoff.tests.sh: pinned base, 3 exact hunks, syntax valid; candidate sha256=fe2dfc070e6290f2afc399d5a21176d19876c647de0edec98a0c17603ae26d25
tests/cross-runtime-handoff.tests.ps1: pinned base, 3 exact hunks, syntax valid; candidate sha256=4d87f40fb97f33c4f80d6eb0bdbedc615b94844f33b775f59f7f6fb9a154eab6
No candidate execution or file application performed.
```

Static checker SHA-256: `ac24238096495ae05634c53b4c38da27c1c7d7bedd1ce31c27f23c71052c5964`.

Existing runtime RED/GREEN evidence remains in `a8-nonce-runtime-feasibility-result-20261005.md`; it was not rerun and does not certify this newly added fixture loop. No tool refusal occurred in this preparation.

## Required verification after legitimate adoption/application (NOT RUN)

From the A8 owner checkout, first recheck the two base hashes before application, then verify candidate readback hashes. Run the actual updated fixture suites, not a copied candidate via an alternate executor:

```sh
rtk proxy bash tests/cross-runtime-handoff.tests.sh
rtk proxy pwsh -NoLogo -NoProfile -NonInteractive -File tests/cross-runtime-handoff.tests.ps1
```

These run fixture and activation checks; they are not native-host proof. Their existing main-ref/activation prerequisites still apply unchanged. Confirm that the newly added two-input loops execute in both runtimes. For acceptance sensitivity, the approved verification should also demonstrate that reverting either candidate consumer or oracle to nonce2-only makes the fixture assertions fail, rather than accepting test self-consistency alone.

Native final-consumer read/write evidence remains separately necessary. Only after current CLI/model/permission and formal launch contracts are satisfied, the actual driver entry points are:

```sh
rtk proxy bash tests/cross-runtime-handoff.tests.sh --live-e2e
rtk proxy pwsh -NoLogo -NoProfile -NonInteractive -File tests/cross-runtime-handoff.tests.ps1 -LiveE2E
```

These are future gated commands, not permission to launch now. Supply the separately verified explicit supported `SDD_A8_COPILOT_MODEL` and confirmed executable configuration; no model or permission values are invented here. CI, independent verification and Done remain outstanding.
