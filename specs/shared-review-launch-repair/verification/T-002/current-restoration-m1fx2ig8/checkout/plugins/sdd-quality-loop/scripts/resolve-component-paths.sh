#!/bin/sh
# Component path ownership resolver — thin dispatcher (INV-008 convention,
# mirrors check-contract.sh: python3 -> pwsh/powershell -> error exit).
#
# epic-191-a3-path-ownership T-001. See resolve-component-paths.py for the
# full usage/exit-code contract; both this dispatcher's targets implement
# it identically (Python master + PowerShell twin, T-006 verifies parity).
dir="$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  py_script="${dir}/resolve-component-paths.py"
  if [ ! -f "$py_script" ]; then
    echo "resolve-component-paths: resolve-component-paths.py not found alongside resolve-component-paths.sh" >&2
    exit 1
  fi
  exec python3 "$py_script" "$@"
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    ps_script="${dir}/resolve-component-paths.ps1"
    # Translate this dispatcher's long-option CLI into the .ps1 script's
    # PowerShell parameter names (Python's argparse and PowerShell's param()
    # block use different flag-naming conventions by convention in this
    # repository; check-contract.sh/.ps1 sidesteps this because it takes
    # only positional arguments — this script has none, so it maps here).
    # Rebuilt via `set --` (never `eval`) so a path argument containing
    # spaces or quote characters is passed through unmodified. `for arg in
    # "$@"` expands the original positional-parameter list exactly once at
    # loop start, so reassigning "$@" with `set --` inside the loop body
    # (to accumulate the mapped/translated arguments) does not disturb the
    # list still being iterated.
    # Every option the Python master declares must appear below. An option
    # that is missing here is NOT rejected: it falls through the `*` arm
    # unchanged, PowerShell leaves it in $args, and the twin's unknown-argument
    # check exits 2 — so the failure is loud, but only for flags. A missing
    # VALUE-taking option is worse: `--repo-root /x` arrives as two stray
    # tokens and the run dies on an unrelated diagnostic. Keep this table in
    # sync with resolve-component-paths.py's parser and the .ps1 param() block.
    #
    # -IncludeUntracked is [bool], not [switch], so it cannot be passed bare
    # under `pwsh -File`; and a bare string value cannot bind either
    # ("Cannot convert value \"System.String\" to type \"System.Boolean\"",
    # measured on PowerShell 7.6.2 for `$false`, `false`, and `0` alike).
    # The `-Name:$value` colon form is the one that binds under -File, and it
    # is what argparse's --include-untracked/--no-include-untracked pair maps
    # onto. Single quotes keep `$true`/`$false` literal for PowerShell to read
    # rather than letting this shell expand them to the empty string.
    first=true
    for arg in "$@"; do
      case "$arg" in
        --config) mapped="-Config" ;;
        --changed-paths-file) mapped="-ChangedPathsFile" ;;
        --source-rev) mapped="-SourceRev" ;;
        --target-rev) mapped="-TargetRev" ;;
        --repo-root) mapped="-RepoRoot" ;;
        --include-untracked) mapped='-IncludeUntracked:$true' ;;
        --no-include-untracked) mapped='-IncludeUntracked:$false' ;;
        --check-schema-conformance) mapped="-CheckSchemaConformance" ;;
        --schema) mapped="-Schema" ;;
        --schema-contract) mapped="-SchemaContract" ;;
        --diagnose) mapped="-Diagnose" ;;
        --provider-bindings) mapped="-ProviderBindings" ;;
        --json) mapped="-Json" ;;
        *) mapped="$arg" ;;
      esac
      if [ "$first" = true ]; then
        set -- "$mapped"
        first=false
      else
        set -- "$@" "$mapped"
      fi
    done
    # (if the dispatcher was invoked with zero arguments, the loop above
    # never executes and "$@" is left as its original, already-empty list)
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "$ps_script" "$@"
    exit $?
  fi
done

echo "resolve-component-paths: needs python3 or PowerShell. Install one, or run resolve-component-paths.ps1 directly." >&2
exit 1
