# RT004: apply the reviewed observer tests only

Independent limited static review by `/root/rt004_snapshot_static_review`
confirmed the current parent, observer and source hashes and found no new
Critical/Major blocking human original-path application and measurement.
This is not a formal PASS or runtime result. Production validators and review
verdicts are not changed. The existing 137/0 selection excludes this observer.

Human terminal: paste the complete block. It only applies three test files;
Codex will run original-path verification after receiving the output. Existing
files and both input patches are backed up. No automatic rollback or deletion.

```bash
rtk proxy bash <<'BASH'
set -euo pipefail
cd /Users/jrmag/sdd-forge
suite=tests/impl-review-adr-inputs.tests.sh
parent=reports/verification/adr-pwsh-boundary-parent-candidate-20260910.patch
observer=reports/verification/adr-pwsh-read-boundary-driver-candidate-20260910.patch
receipt=tests/fixtures/adr-pwsh-boundary-receipt.py
driver=tests/fixtures/adr-pwsh-read-boundary.ps1
validator=plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
hash() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
check() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(hash "$1")" = "$2" ] || stop "Hash/type mismatch: $1"; }
preflight() {
  check "$suite" 582357d2c246dc585710cbb2880dd64353529186a4c42c5b3c7d6d562ccb17dc
  check "$parent" 66ffa59b6e3cd2dcf87f1b00f047d2fd9eab40c02417a995f8b53b20f6f51187
  check "$observer" 01fe4aa4d5303e83b8faae7ad9dd7abf544ca69e3ab900d2c26aafdf444ced85
  check "$validator" 291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5
  for path in tests tests/fixtures reports reports/verification; do
    [ -d "$path" ] && [ ! -L "$path" ] || stop "Directory is missing or linked: $path"
  done
  for path in "$receipt" "$driver"; do
    [ ! -e "$path" ] && [ ! -L "$path" ] || stop "New target already exists: $path"
  done
}
preflight
git apply --check "$parent" "$observer"
backup=$(mktemp -d /tmp/sdd-rt004-observer.XXXXXX) || stop 'Backup allocation failed'
[ -d "$backup" ] || stop 'Backup directory missing'
printf 'Backup: %s\n' "$backup"
/bin/cp -p "$suite" "$backup/impl-review-adr-inputs.tests.sh.before"
/bin/cp -p "$parent" "$observer" "$backup/"
git diff -- "$suite" > "$backup/preexisting.diff"
preflight
git apply "$parent" "$observer"
check "$validator" 291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5
git diff --check -- "$suite" "$receipt" "$driver"
/usr/bin/shasum -a 256 "$suite" "$receipt" "$driver"
printf '\nテスト3ファイルの適用のみ完了。出力をCodexに送ってください。\n'
printf 'テスト実行・正式レビュー・CI・main統合は未完了。commit/push/mergeは未実行です。\n'
BASH
```

If any command fails, stop and send its complete output and backup location.
Do not rerun with relaxed patch flags. This helper assumes exclusive human
application without concurrent writers; it is not a race-resistant protected
copy implementation or production acquisition proof.
