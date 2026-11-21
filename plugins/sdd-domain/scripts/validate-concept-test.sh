#!/bin/sh
# Thin POSIX dispatcher for validate-concept-test.
# One behavioral implementation lives in validate-concept-test.py beside this file.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ ! -r "$dir/../../sdd-quality-loop/scripts/lib/py-dispatch.sh" ]; then
  echo 'validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 1
fi
. "$dir/../../sdd-quality-loop/scripts/lib/py-dispatch.sh"

sdd_py_dispatch "$dir/validate-concept-test.py" 'validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE' "$@"
