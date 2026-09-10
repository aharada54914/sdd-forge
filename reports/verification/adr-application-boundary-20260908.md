# RT-20260908-004 — protected application boundary

Date: 2026-09-08
Ticket remains open. No product change, commit, push, merge or issue closure.

After the second independent plan review passed and the actual validators
produced the recorded RED baseline, the root attempted an `apply_patch` update
to `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`.
The proposed first slice added complete-set precheck/invocation validation; it
did not authorize ADR reads and was not a complete implementation of the ticket.

PreToolUse rejected the edit with the SDD deterministic enforcement-chain
protection message. A subsequent `git diff --` for the target was empty.
Do not retry this change through a renamed target, copied validator, alternate
wrapper, plugin cache, or changed hook. The user scope approval is retained but
does not disable this boundary. A partial first slice must not be presented to
the human as a complete ADR fix.

Human application is required for the completed, independently reviewed patch.
That complete patch has not yet been prepared. Required remaining work includes
the restricted design lexer, case-exact filesystem checks, both admission
implementations, precheck generation/verification, contract binding, persisted
and task-stage consumers, lifecycle/next-round semantics, and regression suites.
Only after those candidate bytes and application instructions are ready should
the human be asked to apply them. Existing plan and first/second review records
remain the governing inputs.

## Fresh external state

All reported Actions jobs were terminal when queried; no live job was being
waited on. Exact open PR heads and disposition:

| PR | Head | Evidence |
| --- | --- | --- |
| 400 | 8fa3eb8561d6f59b692ec574900f87e181145928 | 25 Actions checks successful; formal local findings unresolved |
| 394 | 423edd3b0f9f6710e1de00183e4040fdd8de8ef3 | Windows test and required-checks failed |
| 390 | ade304948907b5bdc94e9975f80528a0dfbb9e14 | Windows test and required-checks failed; behind |
| 381 | 3971c93a5705dc15f86ba56cc62118613e4b19db | POSIX inventory, tests, loops, version gates and required-checks failed |
| 371 | 9e39c396f4ca8f9abe3c9aabb090868ada17b53f | Windows test, Linux/macOS MCP tests and required-checks failed |
| 245 | 54b1ff247081971e0560cf20d45f4369e01b5c0d | merge conflict; only non-Actions status present |

PR400 CI does not cover the uncommitted specification changes. No green CI
result substitutes for the unresolved independent review requirements.

## Human evidence consumption

The supplied pasted-text attachment was decoded as four JSON observations;
its ending reports `errors=0`. The two generated-inventory observations include
line 4 with the shell runner and common-shell-helper literals. This is human
source evidence, not computed enforcement coverage. An expanded read-only
attachment summarization command naming the full component target list was also
rejected by PreToolUse. That command was not executed and was not retried.
Full target classification and fresh formal review remain unresolved.
