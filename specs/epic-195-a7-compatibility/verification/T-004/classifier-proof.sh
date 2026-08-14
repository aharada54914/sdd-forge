#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
HARNESS="$ROOT/specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/t004-classifier-proof.XXXXXX")"
trap 'rm -rf "$work"' EXIT
ansi_mutant="$work/mutation-proof-no-ansi.sh"
wrap_mutant="$work/mutation-proof-no-wrap.sh"

cp "$HARNESS" "$ansi_mutant"
cp "$HARNESS" "$wrap_mutant"

before="$(shasum -a 256 "$ansi_mutant" | awk '{print $1}')"
perl -0pi -e 's/s\/\\e\\\[\[0-\?\]\*\[ -\\\/\]\*\[@-~\]\/\/g; //' "$ansi_mutant"
after="$(shasum -a 256 "$ansi_mutant" | awk '{print $1}')"
[[ "$before" != "$after" ]] || { printf '%s\n' 'CLASSIFIER-PROOF ERROR: ANSI mutant source did not change' >&2; exit 2; }

printf '%s\n' 'VIOLATE ANSI: remove escape-sequence stripping from the diagnostic classifier'
set +e
MUTATION_CLASSIFIER_SELFTEST_ONLY=1 bash "$ansi_mutant"
ansi_rc=$?
set -e
printf 'ANSI_VIOLATED_EXIT_CODE=%d\n' "$ansi_rc"
[[ "$ansi_rc" -ne 0 ]] || { printf '%s\n' 'CLASSIFIER-PROOF FAIL: ANSI-blind classifier stayed green' >&2; exit 1; }

before="$(shasum -a 256 "$wrap_mutant" | awk '{print $1}')"
perl -0pi -e 's/s\/\[\[:space:\]\]\+\/\/g/s\/[ \\t]+\/\/g/' "$wrap_mutant"
after="$(shasum -a 256 "$wrap_mutant" | awk '{print $1}')"
[[ "$before" != "$after" ]] || { printf '%s\n' 'CLASSIFIER-PROOF ERROR: wrap mutant source did not change' >&2; exit 2; }

printf '%s\n' 'VIOLATE WRAP: remove newline compaction from the diagnostic classifier'
set +e
MUTATION_CLASSIFIER_SELFTEST_ONLY=1 bash "$wrap_mutant"
wrap_rc=$?
set -e
printf 'WRAP_VIOLATED_EXIT_CODE=%d\n' "$wrap_rc"
[[ "$wrap_rc" -ne 0 ]] || { printf '%s\n' 'CLASSIFIER-PROOF FAIL: wrap-dependent classifier stayed green' >&2; exit 1; }

printf '%s\n' 'RESTORE: run the delivered ANSI/wrapped diagnostic classifier'
MUTATION_CLASSIFIER_SELFTEST_ONLY=1 bash "$HARNESS"
printf '%s\n' 'RESTORED_EXIT_CODE=0'
printf '%s\n' 'CLASSIFIER-PROOF PASS: violation failed and restored classifier passed'
