# Independent review of quoted-evidence classifier

Reviewed the Python AST allowlist and Python/Node/PowerShell/native-shell callers, in a separate supervisor context from the implementation author.

Found and fixed before acceptance:

1. Non-isolated Python could import a project-local transitive dependency (`fnmatch.py`) during `from pathlib import Path`, changing a temporary tasks fixture to Approved although the classifier returned true. Reproduced in an isolated temporary directory. The actual writer now requires `python[3] -I -`; ordinary non-isolated writers fail closed.
2. An exported Bash function named python3 could intercept the permitted command. Exported functions and BASH_ENV/ENV now reject the exception; the shell guard dispatcher invokes `command python3` so its own interpreter selection is not intercepted by an imported function.

Final independent checks: 13/13 recorded in security-review.json (helper hash recorded), including actual isolated execution with malicious local fnmatch/json/pathlib modules, non-isolated rejection, function/startup environment rejection, direct authority/traversal/exec/shell-tail/unquoted-heredoc rejection, and symlink/hardlink rejection. No production or user task was altered; exploit demonstrations used disposable temp fixtures only.

Final cross-runtime command: `python3 tests/guard-quoted-patch-evidence.tests.py --powershell /workspace/.tools/sdd-forge-dev/bin/pwsh` from /workspace/sdd-forge. Result: 6 tests, all Python/Node/shell/PowerShell subcases PASS, 28.201 seconds. An earlier run overlapped the shell-dispatcher update and failed one shell subcase; the final run used the completed change.

The bounded AST rejects arbitrary imports, executable expressions and non-diagnostic destinations. It does not claim to secure a previously compromised host interpreter/startup configuration, or atomic filesystem behavior against an independent concurrent actor swapping paths after validation. Linux pwsh was exercised, not Windows PowerShell 5.1. No gate disabling or invented native evidence was used.
