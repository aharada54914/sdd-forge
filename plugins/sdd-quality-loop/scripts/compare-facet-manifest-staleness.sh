#!/bin/sh
# Thin POSIX dispatcher for compare-facet-manifest-staleness (Python
# master). The master's exit vocabulary is 0/1/2 verdicts + 3 for a
# diagnostic failure that yields no verdict; a missing interpreter is a
# no-verdict condition, so the shared dispatcher's exit 3 is coherent
# with the recorded design rather than a collision.
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Probe before sourcing: POSIX shells (dash among them) treat a failed `.`
# special builtin as fatal, so an if-guard around the dot itself can never
# run its else branch -- the readability test is what keeps the documented
# exit 3 reachable on a partial or damaged installation.
if [ ! -r "$dir/lib/py-dispatch.sh" ]; then
  echo 'compare-facet-manifest-staleness: COMPARE_FACET_MANIFEST_STALENESS_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi
. "$dir/lib/py-dispatch.sh"

sdd_py_dispatch "$dir/compare-facet-manifest-staleness.py" 'compare-facet-manifest-staleness: COMPARE_FACET_MANIFEST_STALENESS_RUNTIME_UNAVAILABLE' "$@"
