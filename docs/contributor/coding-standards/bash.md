# Bash

Apply [common rules](common.md), especially CS-001, CS-002, CS-004, CS-005, CS-009, CS-012, CS-019, CS-025, CS-026.

Use arrays and quoted expansions; use printf with a literal format. Quoted heredocs prevent shell expansion inside Python/JS. Check native status, command substitutions and pipeline producers deliberately; set -e has conditional-context exceptions. Use the existing supervisor for process trees and deadlines. Validate paths and option grammar separately from quoting. ShellCheck does not prove that a dynamically constructed program is safe.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.
