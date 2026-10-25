#!/bin/sh
# Thin POSIX dispatcher for research-evidence-tools (Python master).
# Dispatch logic (python3 -> python -> fail-closed exit 3) lives in
# lib/py-dispatch.sh, shared by every python-master wrapper.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Probe before sourcing: POSIX shells (dash among them) treat a failed `.`
# special builtin as fatal, so an if-guard around the dot itself can never
# run its else branch -- the readability test is what keeps the documented
# exit 3 reachable on a partial or damaged installation.
if [ ! -r "$dir/lib/py-dispatch.sh" ]; then
  echo 'research-evidence-tools: RESEARCH_EVIDENCE_TOOLS_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 3
fi
. "$dir/lib/py-dispatch.sh"

sdd_py_dispatch "$dir/research-evidence-tools.py" 'research-evidence-tools: RESEARCH_EVIDENCE_TOOLS_RUNTIME_UNAVAILABLE' "$@"
