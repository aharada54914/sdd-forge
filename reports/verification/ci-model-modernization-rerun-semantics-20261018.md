# Partial-rerun execution provenance

The read-only comparison in ci-model-modernization-rerun-comparison-20261018.json found that all 42 attempt-2 job observations had new job IDs and reported run_attempt 2. Thirty-nine logical jobs retained their attempt-1 start timestamps. For example, test (windows-latest) changed API ID from 117775708617 to 117785121655 while preserving 20:04:04–20:28:39 UTC execution times. The aggregate itself has a genuinely new execution interval.

The frozen design requires actual execution source attempts, distinct from planning attempts. Its returned API run_attempt field alone cannot establish execution origin. Collect prior attempts, retain raw metadata, derive unambiguous logical job/step/runner/time lineage, and bind original source execution IDs/attempts to original receipts. A copied latest observation must never relabel old execution as new. Missing or conflicting lineage fails. This note resolves the observed API interpretation within the existing contract; it changes no frozen requirement or approved behavior.

Implementation fixtures must cover copied-success observations with changed API IDs/reported attempts and unchanged execution times, genuine reruns, missing original receipts and ambiguous matches. These observations concern the prior cloud run and are not implementation acceptance evidence.
