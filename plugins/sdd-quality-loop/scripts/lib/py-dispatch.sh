#!/bin/sh
# Shared python-master dispatcher, sourced by every thin wrapper whose ONLY
# job is to run the Python implementation beside it (the sdd-hook-guard.sh
# sourced-library convention; the INV-008 family — check-contract,
# check-component-coverage, resolve-component-paths — falls back to a
# PowerShell twin instead and deliberately does not use this).
#
# Contract (the one dialect-A wrappers documented and their tests pin):
#   - locate python3, else python, on PATH and exec the master unchanged,
#     with stdin/stdout/stderr passed through as-is (`exec` replaces the
#     wrapper process, so nothing is buffered or altered here);
#   - when neither interpreter exists, deny fail-closed: one stderr line
#     "<diagnostic-prefix>: no python3 or python interpreter found on PATH"
#     and exit 3, producing no stdout. Exit 3 keeps runtime absence
#     distinguishable from the master's own validation failures (exit 1).
#
# sdd_py_dispatch <absolute-master.py> <diagnostic-prefix> [args...]
#   diagnostic-prefix carries each wrapper's documented token, e.g.
#   "canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE" — tests grep
#   for these, so the caller owns the prefix and this library never
#   rewrites it.
sdd_py_dispatch() {
  _sdd_py_master="$1"
  _sdd_py_prefix="$2"
  shift 2
  if command -v python3 >/dev/null 2>&1; then
    exec python3 "$_sdd_py_master" "$@"
  fi
  if command -v python >/dev/null 2>&1; then
    exec python "$_sdd_py_master" "$@"
  fi
  echo "${_sdd_py_prefix}: no python3 or python interpreter found on PATH" >&2
  exit 3
}
