#!/bin/sh
# check-component-coverage — thin dispatcher (INV-008 convention, mirrors
# resolve-component-paths.sh: python3 -> pwsh/powershell -> error exit).
# epic-191-a3-path-ownership T-004. See check-component-coverage.py for the
# full usage/exit-code contract; both targets implement it identically.
dir="$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  py_script="${dir}/check-component-coverage.py"
  if [ ! -f "$py_script" ]; then
    echo "check-component-coverage: check-component-coverage.py not found alongside check-component-coverage.sh" >&2
    exit 1
  fi
  exec python3 "$py_script" "$@"
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    ps_script="${dir}/check-component-coverage.ps1"
    first=true
    for arg in "$@"; do
      case "$arg" in
        --config) mapped="-Config" ;;
        --facet-manifest) mapped="-FacetManifest" ;;
        --provider-bindings) mapped="-ProviderBindings" ;;
        --changed-paths-file) mapped="-ChangedPathsFile" ;;
        --source-rev) mapped="-SourceRev" ;;
        --target-rev) mapped="-TargetRev" ;;
        --repo-root) mapped="-RepoRoot" ;;
        *) mapped="$arg" ;;
      esac
      if [ "$first" = true ]; then
        set -- "$mapped"
        first=false
      else
        set -- "$@" "$mapped"
      fi
    done
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "$ps_script" "$@"
    exit $?
  fi
done

echo "check-component-coverage: needs python3 or PowerShell. Install one, or run check-component-coverage.ps1 directly." >&2
exit 1
