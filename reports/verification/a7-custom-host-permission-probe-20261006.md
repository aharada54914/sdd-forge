# A7 custom-host permission diagnostic (unreserved)

Diagnostic only, not a formal review or authorization. Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`. No formal inputs, reservation, ledger, protected settings/code, old output or verdict changed. The synthetic diagnostic was explicitly requested by the orchestrator. That instruction is not treated as approval of a future formal-host permission delta.

## Allocation and observed acceptance

Executed `rtk proxy python3 -B reports/verification/a7-custom-host-permission-probe-20261006.py`: exit 0. Helper SHA256 `cd8a5253cd59dac52a01d465eb64ae21ecc836d3a829f98bb854e7efa7737704`. It records the exact argv and commands, uses DEVNULL stdin, existing plugin, Sonnet, dontAsk, Read/Grep/Glob/Bash and Write/Edit/NotebookEdit denial. Only exact synthetic Bash rules were added; no wildcard or settings modification.

Parent allocation warned `no agent named 'a7-permission-diagnostic-only-20261006' — spawning with default template`. Child native transcript independently recorded custom `agent-setting` at line 3, dontAsk at line 5, zero user messages before delivery, and subsequent model `claude-sonnet-5-5`. Attached UI also displayed the custom name and Sonnet 5.5. This diagnostic role is deliberately not the formal reviewer role; acceptance here cannot prove a future formal role's identity/body.

Native transcript: `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/79bb1cdc-feff-417b-bf12-221dddc92142.jsonl`.
State/argv: `/Users/jrmag/.claude/jobs/79bb1cdc/state.json`.
Child: `79bb1cdc-feff-417b-bf12-221dddc92142`; attached exec handle `31644`.

## Bounded result

One diagnostic prompt delivered at 2026-10-06T04:03:00.963Z. End-turn at 04:03:16.781Z (about 16 seconds). No restart or further dispatch. Last state `blocked`, inFlight tasks 0 / queued 0. Background process/attachment retained, so there is no process-exit assertion; allocator exit 0 is not diagnostic success.

1. Exact `rtk proxy shasum -a 256 reports/verification/a7-exact-hash-permission-probe-20261006.txt`: first routine Fact-Forcing refusal, then identical retry permitted. Tool result `is_error:false`, output `7117325bcf161faf04bee60d4dea0153494cb0b4401a6c21e2478ff50afd00ed  reports/verification/a7-exact-hash-permission-probe-20261006.txt`; child reported exit 0. Successful tool ID `toolu_01NEXECWo3h5kTJEuuahUdDu`, command at native line 44.
2. Synthetic input-digest pipeline: native permission-rule refusal, no shell exit code because it did not execute. Tool ID `toolu_01TAQ5uKMQzAZxPMPZo8ApPh`, refusal at native line 68: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.` Stopped immediately, without alternate executor or retry.
3. Receipt digest: NOT RUN.
4. `rtk proxy test -d domain`: NOT RUN.

Critical distinction: helper/respawnFlags authorized a printf literal containing actual TAB characters, but the native user prompt at line 13 already contains FOUR SPACES in each place. The actual tool command also uses those four spaces. Thus command bytes differ from the exact allow rule and from canonical TAB-separated digest serialization. The transformation occurred before the reviewer consumed the prompt. A pipeline permission limitation is NOT established by this result, notwithstanding the child's tentative explanation. The expected digest `cce7fb17b52a7f54263578114b1bc526f5bc4f53318604c4832299fca3633c05` was not computed. No modified input or output is promoted to canonical evidence.

## Formal remaining conditions and minimum proposal

Ordinary impl skill STEP 2/4 requires current verify-inputs, exact manifests, real independent contexts and one successful reservation. Boundary digest serialization requires TAB/LF and no terminal newline. No closed CLI argv list prohibiting scoped allowedTools was found, but the skill does not itself authorize host permission changes. Existing role's read-only Bash capability is not a native allow rule.

The supplied parent authorization covers this unreserved synthetic diagnostic. The currently available evidence does not establish a separately explicit formal-host permission delta approval; do not infer it from successful hash execution, prior A21 application, or general review authorization. Parent must map the actual user approval to the precise future argv delta before formal launch. No broad Bash grant, dontAsk change, hook bypass, A6 reuse or A22 exception is proposed.

Minimum candidate to evaluate, not implemented: transport a printable, exact stdout-only serialization command (e.g. fixed `printf` format with literal backslash t/n escapes), with the SAME inspected bytes in the scoped rule and supplied command; independently verify that its output is canonical TAB/LF/no-final-newline. Do not allow the observed four-space variant. This is a prospective diagnostic/permission repair, not permission to retry the refused child or another executor. The exact receipt permission also must be tied to the actual future identity and reservation receipt; the synthetic receipt here is no proof of that sequencing. Receipt/domain execution and full intended host acceptance remain unverified.

No formal launch is released. Read-only follow-up observation, if needed: `rtk proxy claude logs 79bb1cdc` and inspect the native state/transcript paths above. Preserve this child and failure history; no restart or reservation is needed to read the result.

## Read-only transport comparison

The current delivery used bracketed TTY paste (`ESC[200~` / `ESC[201~`) containing actual TAB and LF bytes, then Enter. The supplied allow rule retained actual TAB in native respawnFlags. The first persisted user message already had four spaces instead, before any model tool request. This localizes the observed mismatch to the TTY input/paste path, not model reformatting or shell execution. The exact internal CLI function performing expansion has not been identified; no source-level implementation cause is asserted.

Existing non-TTY path differs materially: `reports/verification/a7-attempt22-candidate-20261006/launch-reviewer-a.candidate.py:13` obtains prompt bytes, line 57 passes them as `subprocess.run(..., input=prompt, ...)`; no TTY paste. Its line 50 argv uses print mode, a pinned session ID and the spec-stage custom role. `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py:184-186` requires native first-user UTF-8 bytes exactly equal the saved prompt. Lines 111-115 construct stdout hash commands. This existing path is spec-stage-only; it was not executed here and must not be imported as an impl transport exception or used to work around the current denial.

Existing regression locations: `reports/verification/a7-attempt21-original-path-regression-20261006.py` runs applied-source `a7-attempt21-recovery-candidate-20261006/recovery.tests.py` and `additional.tests.py`; previous 53-case evidence remains in `a7-attempt21-independent-postapply-20261006.md`. Saved non-review transport fixture: `reports/verification/a7-nontty-prompt-transport-probe-20261005.txt`. Those checks are not a regression for TTY TAB expansion; no such existing test was established. A minimum future synthetic regression must compare command bytes before delivery, native user bytes and actual tool bytes, then independently check canonical digest output. No such additional execution, repair, permission expansion or reservation was performed after the refusal.
