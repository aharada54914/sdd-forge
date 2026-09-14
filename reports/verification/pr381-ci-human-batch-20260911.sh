#!/usr/bin/env bash
# Human-run batch: preserve CI semantics, apply the reviewed candidate, sync
# only the already-applied A6 workflow mirror, and retain recovery copies.
set -euo pipefail
cd /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
patch=reports/verification/pr381-current-lane-20260911.patch
workflow=.github/workflows/test.yml
mirror=specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml
manifest=specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256
candidate=/tmp/sdd-pr381-required-checks.Dlsfoh/current-lane-candidate.draft.yml
for path in "$patch" "$workflow" "$mirror" "$manifest" "$candidate"; do
  test -f "$path" && test ! -L "$path"
done
shasum -a 256 -c <<'HASHES'
2d1de010e27d8f663e84638a51c5651a23ce06ee9719acae81cfe6fdd6ad2c50  reports/verification/pr381-current-lane-20260911.patch
01b900897b2f6baabfa13da1abf2b3877e8dfd03b40927b83b992029b89c0453  .github/workflows/test.yml
dc0cc24c18c7edda87c7591f4cc1f0938ea10c5c6788eeb986426c168141d2b0  specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml
588b516ce03830e8635865ce8fea65908ece7d10b4e806151dd43082bf3183e6  specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256
982e5036bbaa970c27276dbba7efc588b583fd151500454b85df3664d4195308  /tmp/sdd-pr381-required-checks.Dlsfoh/current-lane-candidate.draft.yml
HASHES
git apply --check "$patch"
ruby -ryaml - "$workflow" "$candidate" <<'RUBY'
old = YAML.load_file(ARGV[0])
new = YAML.load_file(ARGV[1])
abort 'workflow header changed' unless old.reject { |k, _| k == 'jobs' } == new.reject { |k, _| k == 'jobs' }
a = old.fetch('jobs')
b = new.fetch('jobs')
abort 'job set changed' unless a.keys.sort == b.keys.sort
a.each do |id, job|
  next if id == 'required-checks' # Executed independently by Python regression below.
  other = b.fetch(id)
  abort "job configuration changed: #{id}" unless job.reject { |k, _| k == 'steps' } == other.reject { |k, _| k == 'steps' }
  strip_name = ->(step) { step.reject { |k, _| k == 'name' } }
  expected = job.fetch('steps').map(&strip_name)
  actual = other.fetch('steps').map(&strip_name)
  cursor = 0
  actual.each { |step| cursor += 1 if cursor < expected.size && step == expected[cursor] }
  abort "existing step changed or removed: #{id}" unless cursor == expected.size
end
puts 'PASS: existing jobs, job settings and ordered step semantics preserved'
RUBY
python3 tests/required-checks-posix.tests.py "$candidate"
backup=$(mktemp -d /tmp/sdd-pr381-ci-backup.XXXXXX)
cp "$workflow" "$backup/workflow.yml"
cp "$mirror" "$backup/mirror.yml"
cp "$manifest" "$backup/MANIFEST.sha256"
printf 'Backup: %s\n' "$backup"
git apply "$patch"
cmp "$workflow" "$candidate"
cp "$workflow" "$mirror"
sed 's/^dc0cc24c18c7edda87c7591f4cc1f0938ea10c5c6788eeb986426c168141d2b0  \.github\/workflows\/test.yml$/982e5036bbaa970c27276dbba7efc588b583fd151500454b85df3664d4195308  .github\/workflows\/test.yml/' "$manifest" > "$backup/MANIFEST.updated"
test "$(grep -Fxc '982e5036bbaa970c27276dbba7efc588b583fd151500454b85df3664d4195308  .github/workflows/test.yml' "$backup/MANIFEST.updated")" -eq 1
cp "$backup/MANIFEST.updated" "$manifest"
git diff --check
python3 tests/required-checks-posix.tests.py
bash tests/deterministic-lane-selfcheck.tests.sh
bash tests/human-copy-mirror-freshness.tests.sh
git diff --stat -- "$workflow" "$mirror" "$manifest"
printf '\n適用・限定検証完了。出力を Codex へ送ってください。commit/push/merge は未実行です。\n'
