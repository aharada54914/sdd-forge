# Python

Apply [common rules](common.md), especially CS-001, CS-003, CS-004, CS-007, CS-008, CS-017, CS-018, CS-020, CS-022, CS-023.

Keep existing Ruff and mypy profiles; extend scope with explicit evidence. Parse external JSON as unknown until the canonical validator accepts it. bool is an int subclass, which matters for schema integers. Catch expected operational exceptions; broad outer catches may emit a diagnostic and fail. Use subprocess arguments, check status and the existing supervisor; bat/cmd on Windows needs separate review even with shell=False. Use context managers for resource ownership and explicit encoding for persisted text.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.
