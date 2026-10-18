#!/bin/bash
name=$1; shift
e=/workspace/sdd-forge/specs/cloud-orchestration/verification/T-008/attempt-2
printf '%q ' "$@" > "$e/$name.command"; printf '\n' >> "$e/$name.command"
"$@" > "$e/$name.log" 2>&1
code=$?
printf '%s\t%s\n' "$name" "$code" >> "$e/check-exits.tsv"
tail -12 "$e/$name.log"
echo "exit=$code"
exit 0
