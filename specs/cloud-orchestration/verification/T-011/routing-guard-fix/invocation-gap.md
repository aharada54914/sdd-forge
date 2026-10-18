# Canonical literal environment-prefix invocation gap

After exact registration, the real Python, generated Node consumer, Bash
wrapper and PowerShell guard reject:

```sh
CLOUD_WORKSPACE_ROOT=/tmp/workspace CLOUD_SHARED_RUNTIME_ROOT=/opt/runtime/scripts python3 -B /opt/plugins/sdd-azure-cloud/scripts/cloud.py route --request request.json --output result.json
```

The same command was allowed before registration. AWS and bootstrap canonical
paths produce the same result. The bare `python3 <canonical-script> ...` and
the public skills' unexpanded `$PLUGIN_ROOT` environment-variable example remain
allowed. No provider operation was executed by these decision tests.

Cause: `_command_references_protected_path` in the Python guard (1693–1713)
excludes only a first bare interpreter's immediately following file operand;
inline environment assignments and `-B` do not satisfy it. The equivalent Node
and PowerShell consumers share that rule. Interpreter vocabulary then fails
closed on the protected path. This is a concrete integration gap, not missing
cloud implementation or a reason to exempt paths from the scanner.

The positive resolved-environment assertion remains in the regression suite.
No broad exemption or parser/readonly contract redesign is attempted under this
five-member registration repair. Root must decide/authorize the bounded shared
guard invocation compatibility extension before the repair can pass caller
checks. The independent evaluator must not be invoked on these failing checks.
Native host follow-up with all resolved current dependencies remains pending.

Test fixture correction: initial Set-Content/Get-Content payloads used the
unrecognized tool name `powershell`, which the existing guards ignore. Corrected
to the established `shell` tool alias before final tests. Earlier such controls
are not guard enforcement evidence; direct Write/Bash redirects were genuine
Red. Corrected tests are rerun against the captured entry modules below.

## Resolution within the same repair

Root explicitly confirmed minimal shared guard fixes are already authorized.
The three existing consumers now recognize only literal assignments for the two
already documented cloud metadata variables and Python's `-B`, retaining the
first-command/literal-context checks and scanning all other operands. No test
was relaxed. Actual final parity: 403 PASS / 0 FAIL. Mis-cased metadata/flag,
PATH/PYTHONPATH rebinding, prior-command, redirect and protected output controls
all deny. Twelve actual guard-admitted installed subprocess calls pass routes
and retain direct prepare/apply denial. Native model-host trial2 remains root
owned; these fixture subprocesses do not replace it.
