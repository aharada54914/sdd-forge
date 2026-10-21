# Hosted platform follow-up: failed baseline 6c2b4e713915

This preserves two real CI failures and their bounded candidate corrections. The original baseline, mutation and restore runs are **superseded diagnostic evidence**, not passing rollout acceptance. No category was activated by this work.

The ownership failure was `UNOWNED: install-payload.txt`. The candidate adds that exact path to the existing installer ownership rule; validators and acceptance criteria are unchanged. The retained focused baseline fails 2 of 3 tests, the corrected full A9 suite passes 32, and explicit original/restored candidate inputs reproduce failure and recovery. Original commands, timestamps, Red/Green logs and candidate hashes remain in `ownership/`.

The Windows failure came from native `tar.exe` rejecting the Python PAX special-name fixture. The candidate test helper uses actual Git write-tree/archive production, preserving exact Unicode/quote/tab filenames and byte assertions. The targeted test passes under Linux Bash and Linux PowerShell; deliberately archiving the wrong HEAD tree still fails the name assertion. This is local producer/consumer evidence, not native Windows success or a downloaded GitHub archive. Long Unicode Git names can also require PAX; native Windows charset behavior remains unresolved.

Ruff and diff checks passed in the retained original verification. Exploratory mypy **failed on both source variants**, with 53 baseline versus 52 candidate diagnostics and zero newly introduced diagnostics; it was outside the configured typed-source list and is not a passing required typecheck.

`hosted/` contains bounded contiguous failure excerpts from both version-validation jobs and the Windows installer job. `evidence-receipt.json` records each full original log hash and excerpt line range, source before/after hashes, timestamps and the supersession record. Published text normalizes CRLF/CR to LF and strips trailing ASCII spaces/tabs; `evidence-receipt.json` preserves original external and pre-normalization hashes plus each transformation. Setup/tool headers and original full logs remain unchanged outside Git. `ownership/candidate.patch` and `archive-fixture/candidate.patch` preserve the narrow source changes; no executable probe copies or binary archives are published.

Native Windows and fresh exact-commit full CI remain pending. Source pins describe the observed candidate bytes, not a claim that subsequent commits or CI passed.
