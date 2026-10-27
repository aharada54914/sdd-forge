# Issue 601: evidence and remaining structural safeguards

This record maps three recurring classes to existing enforcement and remaining
work. The cited historical records are retained unchanged. Fixture results do
not measure a reduction in recurrence or establish approval.

| Class and recorded observations | Structural protection and negative/control | Remaining judgment or work |
| --- | --- | --- |
| Shared-file mirrors diverge: [WFI-039](../workflow-improvements/WFI-039.md) records repeated CI failures; [WFI-043](../workflow-improvements/WFI-043.md) records the second-edit ambiguity. | `scripts/human_copy_mirrors.py` classifies the reviewed snapshot against live and main. `tests/human-copy-mirrors-classification.tests.py` exercises pending, stale and fresh states and checks that classification does not rewrite the snapshot. The shared Python CI profile executes it. | Unequal bytes alone cannot decide whether a snapshot represents pending human work. The second edit remains pending and requires human judgment; the test does not claim automatic safe resynchronization. |
| Runtime defaults change a producer/consumer contract: [WFI-044](../workflow-improvements/WFI-044.md) documents case mismatches; [#619](https://github.com/aharada54914/sdd-forge/issues/619) documents cross-model UTF-8 serialization. | The issue-619 producer fix from [PR #629](https://github.com/aharada54914/sdd-forge/pull/629) and a producer/strict-consumer fixture are ported here. The fixture tests an intentionally BOM-prefixed negative and unprefixed controls. Windows PowerShell 5.1 and PowerShell 7 have different UTF-8 BOM defaults; the fixture identifies the producer runtime. | The PowerShell Core producer and strict Python/Node controls passed locally. Windows PowerShell 5.1 and hosted CI remain unverified until their runs complete. Historical BOM files are not rewritten. |
| Missing or ambiguous execution evidence is promoted to a conclusion: [WFI-055](../workflow-improvements/WFI-055.md) records suites omitted from CI and [WFI-051](../workflow-improvements/WFI-051.md) records a misleading diagnostic. [#620](https://github.com/aharada54914/sdd-forge/issues/620) concerned incomplete audit execution. | `tests/verification-catalog.tests.py` covers registration and missing runtimes. The `tests/golden/unrun-pass` case retains a finding and unknown cause while incomplete or fabricated PASS artifacts fail the offline grader; `tests/golden-eval.tests.py` executes negative and legitimate controls. | An execution assertion is not independent evidence. A completed audit with zero findings is distinct from an unrun audit, and a process failure is not proof of a product defect. Attribution and later retention measurements require review. |

The mirror classifier is already shared by the sync tool and the Bash and
PowerShell freshness wrappers; adding another classifier would duplicate its
safety boundary. Two further candidates need consumer-specific design before
consolidation: implementation-report parsing has strict admission and tolerant
historical consumers, while Full and Lite approval annotations share syntax but
not policy. Neither is removed here.

The golden cases are reduced source-backed controls, not exact replays of every
historical incident. The main-based portfolio and this mapping are pending CI
and review. Held-out model trials, subsequent retention measurements, and Windows PowerShell
5.1 execution remain unverified. No task approval, historical
report, or pending human-copy artifact is changed by this record.
