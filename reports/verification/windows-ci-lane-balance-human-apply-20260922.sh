#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

workflow_candidate="reports/verification/windows-ci-lane-balance-candidate-20260922.yml"
required_candidate="reports/verification/required-checks-posix.tests.py.candidate"
human_manifest_candidate="reports/verification/epic-190-human-copy-MANIFEST.sha256.candidate-20260922"
draft_manifest_candidate="reports/verification/epic-190-draft-MANIFEST.sha256.candidate-20260922"
epic194_manifest_candidate="reports/verification/epic-194-human-copy-MANIFEST.sha256.candidate-20260922"

targets=(
  ".github/workflows/test.yml"
  "tests/required-checks-posix.tests.py"
  "specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml"
  "specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256"
  "specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml"
  "specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256"
  "specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate"
  "specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/MANIFEST.sha256.candidate"
)

for path in "$workflow_candidate" "$required_candidate" "$human_manifest_candidate" "$draft_manifest_candidate" "$epic194_manifest_candidate"; do
  test -f "$path" || { printf 'missing candidate: %s\n' "$path" >&2; exit 1; }
done

expected_workflow='3e87e82f11894aef293ea6be4bbf96a56ad4669a39e0c9a01fd16f5500d4a5a8'
candidate_workflow='4522750f3e8cad74e992b61c5baba6bf4bb4cbc4e15dd12389b0c1b2ab3adad4'
expected_required='2d2ce8bb1b1d439bdecb49d05ea14cb9dd96940b8fbdf4295604d908271cb9d8'
candidate_required='b1515df04f38408a2007410df8d656c3dec68e1cee61b204e6df598ac6178f67'

actual_workflow="$(shasum -a 256 .github/workflows/test.yml | cut -d' ' -f1)"
actual_required="$(shasum -a 256 tests/required-checks-posix.tests.py | cut -d' ' -f1)"
case "$actual_workflow" in
  "$expected_workflow"|"$candidate_workflow") ;;
  *) printf 'live workflow changed unexpectedly: %s\n' "$actual_workflow" >&2; exit 1 ;;
esac
case "$actual_required" in
  "$expected_required"|"$candidate_required") ;;
  *) printf 'required-checks test changed unexpectedly: %s\n' "$actual_required" >&2; exit 1 ;;
esac
actual_epic194="$(shasum -a 256 specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml | cut -d' ' -f1)"
case "$actual_epic194" in
  "$expected_workflow"|"$candidate_workflow") ;;
  *) printf 'epic-194 human-copy workflow changed unexpectedly: %s\n' "$actual_epic194" >&2; exit 1 ;;
esac
test "$(shasum -a 256 "$workflow_candidate" | cut -d' ' -f1)" = "$candidate_workflow" || { printf 'workflow candidate hash mismatch\n' >&2; exit 1; }
test "$(shasum -a 256 "$required_candidate" | cut -d' ' -f1)" = "$candidate_required" || { printf 'required-checks candidate hash mismatch\n' >&2; exit 1; }

backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-win-ci-balance-XXXXXX")"
for path in "${targets[@]}"; do
  mkdir -p "$backup/$(dirname "$path")"
  cp -p "$path" "$backup/$path"
done

cp "$workflow_candidate" .github/workflows/test.yml
cp "$required_candidate" tests/required-checks-posix.tests.py
cp "$workflow_candidate" specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml
cp "$human_manifest_candidate" specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256
cp "$workflow_candidate" specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml
cp "$epic194_manifest_candidate" specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256
cp "$workflow_candidate" specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate
cp "$draft_manifest_candidate" specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/MANIFEST.sha256.candidate

test "$(shasum -a 256 .github/workflows/test.yml | cut -d' ' -f1)" = "$candidate_workflow"
test "$(shasum -a 256 tests/required-checks-posix.tests.py | cut -d' ' -f1)" = "$candidate_required"
test "$(grep -F 'workflows/test.yml' specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 | cut -d' ' -f1)" = "$candidate_workflow"
test "$(grep -F 'workflows/test.yml' specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 | cut -d' ' -f1)" = "$candidate_workflow"
test "$(grep -F 'workflows/test.yml' specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/MANIFEST.sha256.candidate | cut -d' ' -f1)" = "$candidate_workflow"

printf 'Applied Windows CI lane-balance candidates.\n'
printf 'Backup: %s\n' "$backup"
printf 'No commit, push, CI rerun, review-status change, or merge was performed.\n'
