# PR394 Windows deadline comparison

This is diagnostic evidence, not a quality-gate verdict or merge approval.

## Compared runs

- Failed PR394: run `34023439393`, Windows job `101460103174`, head
  `423edd3b0f9f6710e1de00183e4040fdd8de8ef3`.
- Successful main: run `34023069455`, Windows job `101459085716`, head
  `4366438f3b243210a4ece5a17f873ca2d920600a`.

Primary retrieved green job measurement lines with `gh run view
34023069455 --repo aharada54914/sdd-forge --job 101459085716 --log`,
filtered using output-consuming grep (command result dc4224, exit 0).

## Measurements

Green main Gemini TEST-004(c), iterations 1 through 5:

| Iteration | elapsed_ms | stub_launch_ms | deadline_ms | exit | verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | 1688 | 567 | 2000 | 0 | 1 |
| 2 | 1690 | 570 | 2000 | 0 | 1 |
| 3 | 1692 | 568 | 2000 | 0 | 1 |
| 4 | 1711 | 575 | 2000 | 0 | 1 |
| 5 | 1718 | 576 | 2000 | 0 | 1 |

Green job summary: 64 passed, 0 failed. The investigator reports PR394
iterations 4 and 5 failed respectively at elapsed_ms 2908/3459,
stub_launch_ms 978/729, exit 1, verdict 0; its summary was 62 passed,
2 failed. Primary subsequently retrieved the failed job with the same
output-consuming filter (command result c6f07f, exit 0), confirming these
values. Its earlier Gemini iterations 1/2/3 passed with elapsed_ms
1825/1818/1833 and stub_launch_ms 710/726/711, respectively. The fifth
failure's launch cost of 729 ms is close to the passing second iteration's
726 ms: launch cost alone cannot explain the different outcome.

## Interpretation and remaining work

The green run is a different head, not a successful same-head retry.
It demonstrates that the same named acceptance condition can complete
within the deadline on Windows; it does not establish the failed run's
root cause. Launch overhead differs, but these measurements alone do not
isolate launch, output drainage, wait completion, or process termination.
The completion requirement remains product behavior and must not be
dismissed as merely a test problem. No timeout, margin, repetition or
mandatory check was weakened. No rerun or merge was requested by this
diagnostic operation. The approved phase-timestamp diagnostics remain the
next evidence needed to distinguish these phases on the failing path.
