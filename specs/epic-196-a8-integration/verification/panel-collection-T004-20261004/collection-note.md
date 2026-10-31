# A8 T-004 blind panel collection — 2026-10-04

This record covers collection and JSON integrity only. No primary evaluator
verdict was supplied, no consensus gate was run, and no task status changed.

## Bound input

- Whole bundle SHA-256: `79a74fd5abfe5609b4fd2f6f93bd796dcb57e2629ba0c588ca444b0add8a2ead`.
- Sanitized-body `input_digest`: `3dc43bd2241d3e746a9cacdb6de3dcdb331f8d9b507b95c3d294cf1c9cfb181a`.
  This differs from the whole-file hash because prepare-panelist-input hashes
  the body before adding its eight-line header (script lines 1339, 1465–1475).
- Consent: T-004 `Cross-Model: enabled`. Coverage manifest contains 14 elements;
  all marker/assertion strings were found in its declared current source.
- Applied repository skill admits the task's own implementation report as
  author claims, not an independent verdict. No peer or primary verdict was
  supplied to either reviewer.

## Execution and integrity

Attempt 1 used the requested application executable path; it did not exist,
so the GPT runner exited 1 without a review. The Claude dispatcher was stopped
with exit 143 before its Agent call to replace inefficient full-text forwarding.
Both exits and original logs are retained; no verdict was produced by attempt 1.

Attempt 2 simultaneously launched the existing GPT runner with the verified
official npm Codex CLI 0.160.0 and Claude CLI with a fresh Sonnet Agent. The
parent authorized the executable substitution. Both processes exited 0.
The three SDD key variables were removed. GPT used read-only sandbox and an
isolated cwd; its persisted session shows no tool calls. Claude retained hooks,
used an isolated cwd, allowed only Agent on the dispatcher and zero tools on
the child; there was no permission bypass or Gemini invocation.

The full bundle was embedded verbatim in the fresh custom Agent definition,
not generated again by the dispatcher. `validate.py` verified byte equality,
exactly one real Agent call, a forwarded child verdict, and equality with the
dispatcher result. Only Markdown fences were removed when serializing the
Anthropic JSON; no verdict fields or findings were altered. Existing verdict
paths were absent before launch and extraction uses exclusive creation.

## Collected results

| Vendor | Observed runtime model | Verdict | Findings |
|---|---|---|---|
| OpenAI | `gpt-6.1-sol` | PASS | 0 |
| Anthropic | `claude-sonnet-5-5` | PASS | 4 Minor |

OpenAI's JSON self-reports `GPT-6`; it is preserved as emitted. Its exact
runtime identifier is independently recorded in `attempt-2/runtime-provenance.json`
from the matching persisted Codex exec session's turn_context. That record
supersedes the earlier validation.json note that only self-report was available.
Anthropic runtime model is confirmed by the CLI modelUsage record.

The four Minor observations concern weak synthetic toggle/subagent regression
value, task-plan versus report suite-registration claims and historical-line
proof, and PR-merge-ref CI that is not current-main integration proof. The
complete original findings remain in T-004.panelist-anthropic.verdict.json.

`attempt-2/validation.json` confirms both schema identities, consent, boolean
blind fields, matching input digest and findings structure. This validation
PASS is not consensus PASS, a primary quality-gate verdict, or completion.

## Handoff

Use the existing two T-004.panelist-*.verdict.json files with a separately
obtained formal primary evaluator verdict and the expected body digest above.
Do not rerun collection or overwrite these outputs without a new admitted
input/review need. Investigate the Minor observations in the primary review;
do not silently delete them. The CLI logs and failed first launch are retained
in this directory. Temporary isolated agent input directories were retained
for byte-audit reproducibility; no user data was deleted.
