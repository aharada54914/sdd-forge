# Repair scope and parity sweep

RT-20261018-CLOUD-INSTALL-SELECTION-RUNTIME only. Production delta is install.sh/install.ps1, relative to preserved entry bytes (not git HEAD, which still lacks older candidate work). Tests preserve the existing check_runtime_and_cli method byte for byte; the new methods call it rather than replacing its canonical predecessor controls. No source provider modules, schemas, manifests, defaults, registration loops, uninstall logic, task status, frozen spec or original report changed.

## Operator sweep

Bash comma-delimited exact selected-name case matches PowerShell -cnotcontains. Existing selection validation remains exact case: Bash valid-name equality, PowerShell ValidateSet IgnoreCase=false and case-sensitive dependency switch/-cnotcontains. New presence tests consume only two fixed known names. No registration list is expanded by runtime retention.

## Independent cmdlet/language sweep

PowerShell uses Test-Path -LiteralPath with Container/Leaf to match Bash -d/-f. The only new raw string method is Split('-')[1] over a fixed allowlisted plugin name; it is not a case-insensitive comparison. Existing schema discovery keeps Where-Object Name -cmatch, matching Bash's lowercase cloud glob, not Get-ChildItem -Filter. New entry path lists are shared by pre-export checks and staged retained-entry checks. Required paths are tested in the staging tree before replacement. Existing wrong-case provider and uppercase-schema negative fixtures run in both interpreters in the final packaging suite.

## Trust and compatibility

Previously materialized runtime directory presence requests regeneration only. No old executable or schema bytes are copied. Every copied runtime file comes from the fresh trusted Git-tracked/archive staging tree. The staged entry must also have all three host manifests, orchestrate skill, cloud.py and its provider-local helper; omitted export files cannot be recovered from untracked source files. Staging failures leave the old whole destination unchanged and its CLI usable. Source content remains trusted release input; this repair does not add a Python/JSON semantic validator or new installer state/authority.

No new SKIP condition or environment branch was enabled. PowerShell executes on Linux here; native Windows/macOS remain untested. No real host registration, account calls, provider network calls or cloud actions. Existing suite CLI stubs and payload-cache fixtures are offline integration, not native host acceptance (T011).

Presence retention cannot infer a historical registration after an older broken installer already removed the runtime directory; explicitly reselect that provider to rebuild it. No host-wide discovery/state engine is added.
