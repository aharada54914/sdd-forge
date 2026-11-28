#!/bin/sh
# Self-contained POSIX dispatcher for finalize-domain-review (ADR-0055: py-dispatch.sh retired).
set -u

case "$0" in
  /*) dir_raw="${0%/*}"; [ -n "$dir_raw" ] || dir_raw="/" ;;
  */*) dir_raw="${0%/*}" ;;
  *) dir_raw="." ;;
esac
dir="$(CDPATH= cd -- "$dir_raw" && pwd)"
master="$dir/finalize-domain-review.py"

if [ ! -r "$master" ]; then
  echo 'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: finalize-domain-review.py unavailable beside this script' >&2
  echo 'finalize-domain-review: operation=finalize-domain-review cause=missing-python-master' >&2
  exit 3
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$master" --runtime bash "$@"
fi
if command -v python >/dev/null 2>&1; then
  exec python "$master" --runtime bash "$@"
fi
echo 'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH' >&2
exit 3
