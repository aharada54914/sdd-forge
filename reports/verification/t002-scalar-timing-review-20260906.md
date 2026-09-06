# T-002 scalar diagnostic review

Base: c3b3dd21f56a923baf0ca5ac3c8b9ec6f359398d
Ticket: RT-20260906-001
Review cycle: 3
Verdict: NEEDS_WORK — further repair paused pending continuation approval

The worker changed only tests/cross-model.tests.ps1 and reported syntax and
diff checks passing. Primary inspected the actual diff, not just that report.

1. Major: both scalar writes still occur after ConvertTo-Json. The claimed
   pre-output wait-end persistence is absent, leaving the very same lost-stage
   evidence gap this change must address. Move the wait-end write into the
   generated child at the existing wait-end observation point, independently
   of the later output-complete write.
2. Major: parent scalar reads use Get-Content outside try/catch. Unlike the
   old JSON diagnostic reader, missing-after-check, read errors or null content
   can interrupt the test under Stop instead of preserving -1 and the original
   runner result. Isolate each diagnostic read without swallowing runner failure.
3. Minor: unrelated partial indentation changes obscure the generated script.

No timeout, margin, repetition, assertion or production runner change is part
of the permitted repair. Diagnostic I/O before verdict emission consumes time
and may perturb boundary cases; missing records remain ambiguous. Syntax success
does not establish either functional correctness or a timeout fix. Full suite
and Windows verification have not been run for this rejected candidate.

The dirty candidate is retained for inspection, not committed or pushed. The
ticket cycle count moved from 2 to 3 and a narrow continuation decision was
requested. No Done task, frozen evidence or issue status was rewritten.

## Cycle 4 — explicitly approved continuation

The user approved the pending one-additional-cycle request. Primary inspected
the complete final diff: wait-end is now written by the child before verdict
serialization; output-complete is written independently after pipeline return.
Each new scalar reader isolates path checks, reads and parsing in its own
try/catch, retaining -1 on unavailable diagnostics. Unrelated indentation and
start-file reader edits were removed. Timeout, margin, repetitions, assertions
and production runners are unchanged. The two cycle-3 code findings are addressed.

Source SHA256: 30d834639e5ec0de077018bcbe999d601dde8879f96f3ae58a577f546c626947
Worker reports parse exit 0 and suite exit 0. Primary independently ran diff
check (exit 0) and read the suite log ending in 64 passed, 0 failed, including
real boundary timestamp values. Log: /tmp/t002-cycle4-cross-model-v2.log
Log SHA256: b0c2dcba58325377e387f2663f5063ede7fbe9211a5bbbeff7422fcd92dfe328

Disposition: scoped code findings addressed; Windows CI, diagnostic failure-path
regression and formal independent quality gate still pending. No commit/push,
Done decision or root-cause resolution is claimed. Pre-output diagnostic I/O
still perturbs timing; missing timestamps remain ambiguous. Cycle count is 4;
no fifth automatic repair/review is authorized.

Primary subsequently executed the actual scalar-reader source span as a
PowerShell scriptblock with controlled Test-Path/Get-Content inputs. Seven
cases (valid, missing, empty, malformed, mixed valid/invalid, read exception,
path-check exception) all matched the expected independent values and retained
`script:panelistExit=37`. Actual tool chunk acc749, exit 0. No test/product
file was edited by this probe. This supplies diagnostic-reader failure-path
evidence, not Windows CI or the formal quality-gate verdict. The delegated
source-only report was insufficient and was not used as executed-test evidence.
