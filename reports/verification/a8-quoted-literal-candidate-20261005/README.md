# Quoted-literal R-10 repair candidate — 2026-10-05

Status: NON-APPLIED; independent technical audit pending. No human-apply instruction.

## Scope and authority

Prepared under the user's explicit limited read-only false-refusal repair authorization, relayed by the parent. This is not implementation of an A8 task: A8 tasks.md:32 explicitly says no task edits the guard runtimes. Existing guard-read-launch-repair-plan-20261003.md in the primary checkout is a related design-only plan (lines 3,17); RT-20260909-002 is handshake evidence and WFI-053 remains Draft. No approval/status/frozen artifact was changed.

Only candidate targets: plugins/sdd-quality-loop/scripts/sdd-hook-guard.{py,js,ps1}. Shell dispatcher, generated invariants, installed runtime, tool permissions, deny lists and hooks are unchanged.

## Defect and limited repair

B's exact blocked command is preserved in attempt-8/round-1/launch-command-diagnostic.json. A is explicitly reconstructed, not byte-exact launch proof. POSIX escaped apostrophes make the existing simple tokenizer return unmodeled; R-10 then scans raw command text and treats the prompt's quoted round>1 as a redirect. Python _shell_targets_protected_gate_file, JS shellTargetsProtectedGateFile, and PS Test-ShellTargetsProtectedGateFile share the raw write-regex check.

The candidate recognizes only the canonical argument bundle actually used here: rtk proxy claude, Sonnet, fixed option order, Read+Bash, dontAsk, explicit Write/Edit/NotebookEdit denial, exact hash/printf/test command rules, narrowly shaped debug path, and the exact read-only role/boundary cat substitution. UUID, manifest paths/hash text, receipt text, and bounded attempt/log numbers can vary. No wildcard Bash, unknown option, wrapper, changed substitution, alternate quote form, or shell suffix is accepted by this recognition.

Only greater-than glyphs in the terminal POSIX single-quoted prompt are projected to spaces for the existing write-regex check. No whole-prompt deletion occurs; writer vocabulary remains visible. All prior cwd/patch/protected-path checks still run. Nonmatching commands follow the original path unchanged. This is intentionally a launch-grammar adapter, not a general shell parser or universal Claude allowance; unsupported variants remain closed.

The tool bundle, not natural-language intent detection, supplies the capability boundary. The candidate does not claim to understand arbitrary instructions to write; the regression retains denial for explicit rm/python writer requests inside the prompt. Independent audit must examine CLI allow-rule semantics and future maintainability before adoption.

## Executed verification

Run from the owner checkout:

`rtk proxy node reports/verification/a8-quoted-literal-candidate-20261005/check.mjs`

Exit 0. Python, Node, PowerShell: 18 fixtures each in RED and GREEN, no mismatches (108 predicate observations). Original rejects exact B; candidate accepts it. Controls cover A, read-only cat, actual redirects, mixed commands, writer requests, arbitrary Bash, Write enabled, absent deny tools, non-dontAsk mode, bypass option, case variant, unclosed quote, newline writer, changed substitution and shell interpreter. No fixture command is executed. In-memory candidate functions only; guard entrypoints and formal review are not launched.

`rtk proxy git apply --check reports/verification/a8-quoted-literal-candidate-20261005/candidate.patch` exited 0. This was check-only, not apply.

check.mjs pins each original source SHA before constructing candidates and confirms the originals unchanged after tests. candidate.json contains all before hashes and exact insert/replace data; result.json contains candidate hashes and per-fixture decisions. candidate.patch is the same three-runtime delta.

## Related RT002 issue

The related plan lines 29–31 identifies raw compound matching of a pipe inside a quoted rg search pattern. Both failures confuse argument data with shell operators; their authorization contexts differ. A read-only rg adapter must validate its safe flags/path grammar independently. This patch does not alter the role guard, does not repair RT002, and does not weaken global compound/write regexes. Unifying these adapters or broadening the shell tokenizer requires separate design review.

## Remaining boundaries

- Independent technical audit NOT RUN.
- Full hook-entrypoint/suite regression NOT RUN; only exact R-10 predicates tested.
- Installed Python differs from owner baseline (installed 248b78aa0419e6693d3d1e29d20390af1a1de422a411c4fdd7e30b5066126227); no installed repair claimed.
- No protected application, native activation, CI, formal gate or delivery PASS.
- B reservation 1203 remains consumed/launch-blocked; do not retry/reuse it. No new reservation made.
- A evidence retained; driver remains unapplied. Technical audit is the next step, not human apply.

