#!/usr/bin/env bash
# REQ-004 pairwise path, EOL, and Unicode regression fixture.
set -u

PASS=0
FAIL=0
ok() { printf 'ok: %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; FAIL=$((FAIL + 1)); }
assert_equal() {
  if [ "$1" = "$2" ]; then ok "$3"; else fail "$3 (expected '$2', got '$1')"; fi
}

if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  printf 'FAIL: python3 or python is required\n'
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)"
FIXTURES="$SCRIPT_DIR/fixtures/path-lineending-regression"
MATRIX="$FIXTURES/matrix.tsv"
LAYERS="$FIXTURES/layer-dispositions.tsv"
WORK="$(mktemp -d "$ROOT/.path-lineending.XXXXXX")"
cleanup() {
  case "$WORK" in "$ROOT"/.path-lineending.*) rm -rf -- "$WORK" ;; esac
}
trap cleanup EXIT HUP INT TERM

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print "sha256:" $1}'
  else
    sha256sum "$1" | awk '{print "sha256:" $1}'
  fi
}

NFC_NAME='café-skill.md'
NFD_NAME="$($PYTHON -c "print('cafe\\u0301-skill.md')")"
NFD_SOURCE="$FIXTURES/unicode-source-nfd.txt"
NFC_COPY="$WORK/unicode-copy-nfc.txt"
LF_SOURCE="$FIXTURES/eol-lf.txt"
CRLF_SOURCE="$WORK/eol-crlf.txt"
LF_COPY="$WORK/eol-normalized.txt"

NFD_CONTENT_SHA='sha256:22937d29caf43b99b40e1679cd3990180e1d415bdaebad013571f3e84a6eb16e'
NFC_CONTENT_SHA='sha256:d4b52a8b4ce9cd40ebfee654dc9d290862a3e57b82d3d2f7c618bf86af98963b'
LF_CONTENT_SHA='sha256:e49c81e2d2f84e259d40e2fb8192f3bcd198b355184845d76d8f58807d0d78ee'
CRLF_CONTENT_SHA='sha256:98ab4d3aeab1e120560e942e2df6a0db1147bf94bafcf1590000ffb3c2b6fc80'

$PYTHON - "$FIXTURES/eol-crlf.hex" "$CRLF_SOURCE" "$NFD_SOURCE" "$NFC_COPY" <<'PY'
from pathlib import Path
import sys, unicodedata
hex_path, crlf_path, nfd_path, nfc_path = map(Path, sys.argv[1:])
crlf_path.write_bytes(bytes.fromhex(hex_path.read_text(encoding="ascii").strip()))
with nfc_path.open("w", encoding="utf-8", newline="") as stream:
    stream.write(unicodedata.normalize("NFC", nfd_path.read_text(encoding="utf-8")))
PY
$PYTHON - "$CRLF_SOURCE" "$LF_COPY" <<'PY'
from pathlib import Path
import sys
source, target = map(Path, sys.argv[1:])
target.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))
PY

assert_equal "$(sha256_file "$NFD_SOURCE")" "$NFD_CONTENT_SHA" 'NFD source bytes are fixed'
assert_equal "$(sha256_file "$NFC_COPY")" "$NFC_CONTENT_SHA" 'NFC copied bytes are fixed'
assert_equal "$(sha256_file "$LF_SOURCE")" "$LF_CONTENT_SHA" 'LF source bytes are fixed'
assert_equal "$(sha256_file "$CRLF_SOURCE")" "$CRLF_CONTENT_SHA" 'CRLF source bytes are fixed'
assert_equal "$(sha256_file "$LF_COPY")" "$LF_CONTENT_SHA" 'CRLF is corrected to LF bytes'

if $PYTHON - "$NFD_SOURCE" <<'PY'
from pathlib import Path
import sys, unicodedata
value = Path(sys.argv[1]).read_text(encoding="utf-8")
raise SystemExit(0 if unicodedata.is_normalized("NFD", value) and not unicodedata.is_normalized("NFC", value) else 1)
PY
then ok 'committed Unicode source is NFD and not NFC'; else fail 'committed Unicode source is not strict NFD'; fi

ATTR="$(git -C "$ROOT" check-attr eol -- "tests/fixtures/path-lineending-regression/eol-lf.txt")"
case "$ATTR" in *': eol: lf') ok '.gitattributes assigns LF to the text fixture' ;; *) fail "unexpected git eol attribute: $ATTR" ;; esac

GENERATED="$WORK/generated-matrix.tsv"
printf 'row\tos\tscript\tseparator\teol\tnormalization\tphase\n' >"$GENERATED"
row=0
for script in sh ps1; do
  for eol in LF CRLF; do
    for normalization in NFC NFD; do
      for phase in install uninstall; do
        row=$((row + 1))
        case $(((row - 1) % 3)) in 0) os=windows ;; 1) os=linux ;; *) os=macos ;; esac
        separator=forward-slash
        if [ "$os" = windows ] && [ "$script" = ps1 ]; then separator=backslash; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$row" "$os" "$script" "$separator" "$eol" "$normalization" "$phase" >>"$GENERATED"
      done
    done
  done
done
if cmp -s "$GENERATED" "$MATRIX"; then ok '16-row generation algorithm matches the fixed matrix'; else fail 'generated matrix differs from fixture'; fi

if $PYTHON - "$MATRIX" <<'PY'
import csv, itertools, sys
rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8", newline=""), delimiter="\t"))
axes = {"os": ["windows", "linux", "macos"], "script": ["sh", "ps1"], "eol": ["LF", "CRLF"], "normalization": ["NFC", "NFD"], "phase": ["install", "uninstall"]}
valid = len(rows) == 16
for a, b in itertools.combinations(axes, 2):
    observed = {(row[a], row[b]) for row in rows}
    required = set(itertools.product(axes[a], axes[b]))
    valid = valid and required <= observed
raise SystemExit(0 if valid else 1)
PY
then ok 'all 10 independent-axis pairs are covered'; else fail 'pairwise coverage is incomplete'; fi

if $PYTHON - "$NFC_NAME" "$NFD_NAME" <<'PY'
import sys, unicodedata
names = sys.argv[1:]
canonical = [unicodedata.normalize("NFC", name) for name in names]
raise SystemExit(0 if len(set(canonical)) != len(canonical) else 1)
PY
then ok 'dual NFC/NFD names trigger the collision oracle'; else fail 'dual-form collision was accepted'; fi

native_path() {
  local os="$1" separator="$2" name="$3"
  if [ "$os" = windows ]; then
    if [ "$separator" = backslash ]; then
      name="$(printf '%s' "$name" | tr '/' '\\\\')"
      printf 'C:\\sdd-fixture\\%s' "$name"
    else
      printf 'C:/sdd-fixture/%s' "$name"
    fi
  else
    printf '/tmp/sdd-fixture/%s' "$name"
  fi
}

uninstall_residue() {
  $PYTHON - "$NFC_NAME" "$NFD_NAME" <<'PY'
import json, sys, unicodedata
installed = [sys.argv[1], sys.argv[2]]
target = unicodedata.normalize("NFC", sys.argv[2])
installed = [name for name in installed if unicodedata.normalize("NFC", name) != target]
print(json.dumps(installed, ensure_ascii=False, separators=(",", ":")))
PY
}

harness_cell() {
  local os="$1" separator="$2" eol="$3" normalization="$4" phase="$5" case_name="$6"
  local result=PASS source_sha="$NFD_CONTENT_SHA" source_name="$NFD_NAME"
  local path copied_sha="$NFC_CONTENT_SHA" stdout residue='[]' registration
  path="$(native_path "$os" "$separator" "$NFC_NAME")"
  if [ "$normalization" = NFC ]; then source_sha="$NFC_CONTENT_SHA"; source_name="$NFC_NAME"; fi
  case "$case_name" in
    windows-path-separator)
      if [ "$separator" != backslash ]; then
        result='N/A'
      else
        registration="$(native_path "$os" "$separator" 'registry/sdd-forge')"
        case "$path|$registration" in *'/'*) result=FAIL ;; esac
      fi
      ;;
    crlf-lf-gitattributes-layer)
      source_name="eol-$(printf '%s' "$eol" | tr '[:upper:]' '[:lower:]').txt"
      if [ "$eol" = LF ]; then source_sha="$(sha256_file "$LF_SOURCE")"; else source_sha="$(sha256_file "$CRLF_SOURCE")"; fi
      path="$(native_path "$os" "$separator" 'eol-normalized.txt')"
      copied_sha="$(sha256_file "$LF_COPY")"
      ;;
    nfc-nfd-filename)
      copied_sha="$(sha256_file "$NFC_COPY")"
      ;;
    *) result=FAIL ;;
  esac
  if [ "$phase" = uninstall ]; then stdout="uninstalled $path"; residue="$(uninstall_residue)"; else stdout="installed $path"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$result" "$source_sha" "$source_name" "$path" "$copied_sha" "$stdout" "$residue"
}

RESULTS="$WORK/results.tsv"
printf 'os\tseparator\teol\tnormalization\truntime_script\tphase\tcase\tresult\tsource_bytes_sha256\tsource_name\tresolved_path\tcopied_bytes_sha256\tstdout_substring\tuninstall_residue\n' >"$RESULTS"
exec 3<"$MATRIX"
IFS= read -r _matrix_header <&3
while IFS="$(printf '\t')" read -r matrix_row os script separator eol normalization phase <&3; do
  for case_name in windows-path-separator crlf-lf-gitattributes-layer nfc-nfd-filename; do
    expected_result=PASS
    if [ "$normalization" = NFC ]; then
      expected_source_sha="$NFC_CONTENT_SHA"
      expected_source_name="$NFC_NAME"
    else
      expected_source_sha="$NFD_CONTENT_SHA"
      expected_source_name="$NFD_NAME"
    fi
    expected_path="$(native_path "$os" "$separator" "$NFC_NAME")"
    expected_copied_sha="$NFC_CONTENT_SHA"
    if [ "$case_name" = windows-path-separator ] && [ "$separator" != backslash ]; then expected_result='N/A'; fi
    if [ "$case_name" = crlf-lf-gitattributes-layer ]; then
      expected_source_name="eol-$(printf '%s' "$eol" | tr '[:upper:]' '[:lower:]').txt"
      if [ "$eol" = LF ]; then expected_source_sha="$LF_CONTENT_SHA"; else expected_source_sha="$CRLF_CONTENT_SHA"; fi
      expected_path="$(native_path "$os" "$separator" 'eol-normalized.txt')"
      expected_copied_sha="$LF_CONTENT_SHA"
    fi
    if [ "$phase" = uninstall ]; then expected_stdout="uninstalled $expected_path"; else expected_stdout="installed $expected_path"; fi
    expected_residue='[]'
    IFS="$(printf '\t')" read -r actual_result actual_source_sha actual_source_name actual_path actual_copied_sha actual_stdout actual_residue <<EOF
$(harness_cell "$os" "$separator" "$eol" "$normalization" "$phase" "$case_name")
EOF
    if [ "$actual_result" = "$expected_result" ] && [ "$actual_source_sha" = "$expected_source_sha" ] &&
       [ "$actual_source_name" = "$expected_source_name" ] && [ "$actual_path" = "$expected_path" ] &&
       [ "$actual_copied_sha" = "$expected_copied_sha" ] && [ "$actual_stdout" = "$expected_stdout" ] &&
       [ "$actual_residue" = "$expected_residue" ]; then
      ok "row $matrix_row $case_name fixed oracle"
    else
      fail "row $matrix_row $case_name oracle mismatch"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$os" "$separator" "$eol" "$normalization" "$script" "$phase" "$case_name" "$actual_result" "$actual_source_sha" "$actual_source_name" "$actual_path" "$actual_copied_sha" "$actual_stdout" "$actual_residue" >>"$RESULTS"
  done
done
exec 3<&-

if $PYTHON - "$RESULTS" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8", newline=""), delimiter="\t"))
required = {"os", "separator", "eol", "normalization", "runtime_script", "phase", "case", "result", "source_bytes_sha256", "source_name", "resolved_path", "copied_bytes_sha256", "stdout_substring", "uninstall_residue"}
valid = len(rows) == 48 and all(required == set(row) and row["result"] in {"PASS", "FAIL", "N/A"} for row in rows)
raise SystemExit(0 if valid else 1)
PY
then ok 'path-lineending-fixture-result/v1 has 48 complete cells'; else fail 'result schema/count validation failed'; fi

exec 3<"$LAYERS"
IFS= read -r _layer_header <&3
while IFS="$(printf '\t')" read -r layer disposition <&3; do
  case "$layer" in
    windows-path-resolution|crlf-lf-gitattributes|nfc-nfd-normalization) actual=ASSERT ;;
    generated-text-canonicalizer) actual='N/A for this package' ;;
    *) actual=UNKNOWN ;;
  esac
  assert_equal "$actual" "$disposition" "layer $layer disposition"
done
exec 3<&-

printf '\npath-lineending-regression: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
