#!/bin/sh
# Install-layout validation: every file the service ships must be present and non-empty.
cd "$(dirname "$0")/.." || exit 2
status=0
for path in README.md app/limits.py plugins/demo/scripts/check-limits.py config/limits.json web/limits-widget.js; do
  if [ ! -s "$path" ]; then
    echo "missing or empty: $path"
    status=1
  fi
done
head -n 1 plugins/demo/scripts/check-limits.py | grep -q '^#!/usr/bin/env python3$' || { echo "plugin guard lacks python3 shebang"; status=1; }
[ "$status" -eq 0 ] && echo "install layout ok"
exit "$status"
