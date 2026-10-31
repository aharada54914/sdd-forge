# A7 history caller verification

Owner: a7-t005-intake/sdd-forge. No task status, acceptance verdict, commit,
push, CI or merge is claimed by this record.

## Applied caller regressions

- `rtk proxy env TMPDIR=/private/tmp python3 -u specs/epic-195-a7-compatibility/verification/spec-review-fresh-chain.fixture.py`: exit 0, 32 PASS (16 Bash, 16 macOS PowerShell).
- `rtk proxy env TMPDIR=/private/tmp python3 -u specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py`: exit 0, 24 PASS (12 Bash, 12 macOS PowerShell).
- Attempt 14 round 1 original precheck: exit 0. Do not overwrite or replay it.

## Independent launch diagnostic

Reserved reviewer A run `871dee47`, host session
`871dee47-0330-43b0-9c10-5e5981fa550c`, sequence 1197, ended BLOCKED
with no evaluated checks. Its raw JSON is preserved in the attempt directory;
it is diagnostic evidence, not a specification failure or accepted review.
Reviewer B was not launched.

The launcher allowed `rtk proxy shasum -a 256`, but the reviewer selected
`rtk proxy sha256sum`. The first Bash call also required the host's initial
purpose statement. After that statement, sha256sum remained denied by
the dontAsk allowlist. No hook was disabled or bypassed.

A separate nonformal Claude Sonnet capability probe then executed
`printf '%s' 'abc' | rtk proxy shasum -a 256` after the host-authorized
purpose-statement retry. It returned
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -`
and exited 0. This proves the literal hash command is usable, not review success.

## Resume boundary

The separate file probe also exited 0: `rtk proxy shasum -a 256 -- specs/epic-195-a7-compatibility/requirements.md` returned `b04eff0242f5143c52c8c92a7d05ee90cc2034e9e9635379601946a35c950acc`. The host required the purpose-statement retry; no identity was reserved and no review was performed by this diagnostic context.

Preserve attempt 14 and its reservation. Do not send another review turn in
that consumed context. A subsequent authorized fresh-history admission must
include attempt 14's original precheck, native allocation receipt, invocation
and raw diagnostic. Before reservation, probe the exact file-hash command
as well as the literal-input hash command. The fresh first-turn instructions
must explicitly name the permitted `shasum` procedure and comply with the
host purpose-statement requirement. Do not substitute sha256sum.

Independent specification review, downstream gates, native activation,
current-head CI and main integration remain unverified.
