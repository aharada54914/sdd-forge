#!/bin/sh
# Thin POSIX dispatcher for validate-concept-test.
# One behavioral implementation lives in validate-concept-test.py beside this file.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ -r "$dir/../runtime/lib/py-dispatch.sh" ]; then
  dispatch_lib="$dir/../runtime/lib/py-dispatch.sh"
elif [ -r "$dir/../../sdd-quality-loop/scripts/lib/py-dispatch.sh" ]; then
  dispatch_lib="$dir/../../sdd-quality-loop/scripts/lib/py-dispatch.sh"
else
  echo 'validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script' >&2
  exit 1
fi
. "$dispatch_lib"

sdd_py_dispatch "$dir/validate-concept-test.py" 'validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE' "$@"
