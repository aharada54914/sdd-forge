#!/bin/sh
# T-002 (epic-189-a1-project-context, REQ-003): acceptance checks for
# plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py and its
# .sh/.ps1/.js dispatcher wrappers.
#
# TEST-005 rejection-category lock (anchor / alias / custom tag / duplicate
#   key), each with a category-specific diagnostic and exit code — AC-005.
# TEST-006 YAML-1.2-core-schema boolean-coercion avoidance (on/off/yes/no
#   stay strings, any casing) — AC-006.
# TEST-007 NFC-normalization proof: precomposed vs. decomposed Unicode
#   fixtures produce byte-identical canonical output and SHA-256 — AC-007.
# TEST-008 JCS-compliance proof: canonical JSON output matches a
#   hand-computed golden byte sequence for a fixture with non-canonical key
#   order and number formatting — AC-008.
# TEST-009 multi-runtime hash-equality + dispatch-target proof for
#   .py/.sh/.ps1/.js — AC-009.
# TEST-037 accepted-domain boundary vectors: multi-document rejection;
#   non-string-key rejection; post-NFC duplicate-key collision rejection;
#   non-finite/out-of-range-number rejection; an RFC 8785 §3.2.2.3 numeric-
#   formatting boundary vector; byte-exact stdout-framing + exit-code
#   assertion for success and every rejection path — AC-037.
#
# This suite invokes the tool through canonicalize-sdd-yaml.sh (the real
# dispatcher surface), except TEST-009, which also exercises .py/.ps1/.js
# directly to prove multi-runtime hash equality and that each wrapper
# dispatches to the single Python implementation rather than reimplementing
# it (design.md Canonicalization procedure).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/canon-yaml-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12; see
# tests/lib/loop-driver.sh:124): macOS $TMPDIR is itself a symlink.
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

CANON_SH="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh"
CANON_PY="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
CANON_PS1="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.ps1"
CANON_JS="$ROOT/plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.js"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# run_canon <file> [extra args...] -- invokes the .sh dispatcher, capturing
# stdout to $WORK/out, stderr to $WORK/err, and returning its exit code.
run_canon() {
  file=$1
  shift
  "$CANON_SH" "$file" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

# expect_reject <desc> <file> <category> <exit_code> [extra args...] --
# asserts: exit code matches, stderr names the category, and stdout is
# BYTE-EXACT EMPTY (part of TEST-037's byte-exact-framing requirement,
# applied to every rejection path in this suite).
expect_reject() {
  desc=$1; file=$2; category=$3; exit_code=$4
  shift 4
  run_canon "$file" "$@"
  actual=$?
  if [ "$actual" != "$exit_code" ]; then
    fail "$desc (exit code: got $actual, want $exit_code)"
    return
  fi
  if ! grep -q "$category" "$WORK/err"; then
    fail "$desc (stderr does not name category $category: $(cat "$WORK/err")"
    return
  fi
  if [ -s "$WORK/out" ]; then
    fail "$desc (stdout not empty on rejection: $(cat "$WORK/out")"
    return
  fi
  pass "$desc"
}

# expect_stdout_bytes <desc> <file> <expected_bytes_file> [extra args...] --
# asserts exit 0 and byte-exact stdout match against expected_bytes_file.
expect_stdout_bytes() {
  desc=$1; file=$2; expected=$3
  shift 3
  run_canon "$file" "$@"
  actual=$?
  if [ "$actual" != 0 ]; then
    fail "$desc (exit code: got $actual, want 0; stderr: $(cat "$WORK/err")"
    return
  fi
  if ! cmp -s "$WORK/out" "$expected"; then
    fail "$desc (stdout mismatch: got $(cat "$WORK/out") want $(cat "$expected")"
    return
  fi
  pass "$desc"
}

# ---------------------------------------------------------------------------
# TEST-005: rejection-category lock -- anchor / alias / custom tag /
# duplicate key, each with a category-specific diagnostic (AC-005).
# ---------------------------------------------------------------------------

printf 'key: &anchor value\nother: value2\n' > "$WORK/t005_anchor.yaml"
expect_reject "TEST-005 anchor rejected" "$WORK/t005_anchor.yaml" ANCHOR_REJECTED 20

printf 'key: value\nother: *key\n' > "$WORK/t005_alias.yaml"
expect_reject "TEST-005 alias rejected" "$WORK/t005_alias.yaml" ALIAS_REJECTED 21

printf 'key: !!str value\n' > "$WORK/t005_tag.yaml"
expect_reject "TEST-005 custom tag rejected" "$WORK/t005_tag.yaml" CUSTOM_TAG_REJECTED 22

printf 'a: 1\nb: 2\na: 3\n' > "$WORK/t005_dup.yaml"
expect_reject "TEST-005 duplicate key rejected" "$WORK/t005_dup.yaml" DUPLICATE_KEY_REJECTED 23

# ---------------------------------------------------------------------------
# TEST-006: YAML-1.2-core-schema boolean-coercion avoidance (AC-006).
# ---------------------------------------------------------------------------

printf 'a: yes\nb: no\nc: on\nd: off\ne: Yes\nf: TRUE\ng: FALSE\n' > "$WORK/t006_tokens.yaml"
printf '{"a":"yes","b":"no","c":"on","d":"off","e":"Yes","f":true,"g":false}' > "$WORK/t006_expected.json"
expect_stdout_bytes "TEST-006 1.1-only tokens (yes/no/on/off, any casing) stay strings; true/TRUE/FALSE resolve as booleans" \
  "$WORK/t006_tokens.yaml" "$WORK/t006_expected.json"

# ---------------------------------------------------------------------------
# TEST-007: NFC-normalization proof (AC-007).
# ---------------------------------------------------------------------------

# precomposed U+00E9 (é) vs. decomposed e (U+0065) + combining acute (U+0301)
printf 'a: caf\xc3\xa9\n' > "$WORK/t007_precomposed.yaml"
printf 'a: cafe\xcc\x81\n' > "$WORK/t007_decomposed.yaml"

run_canon "$WORK/t007_precomposed.yaml"
precomposed_out="$WORK/t007_precomposed.out"
cp "$WORK/out" "$precomposed_out"
run_canon "$WORK/t007_decomposed.yaml"
if cmp -s "$precomposed_out" "$WORK/out"; then
  pass "TEST-007 precomposed vs. decomposed NFC fixture pair produce byte-identical canonical output"
else
  fail "TEST-007 precomposed vs. decomposed NFC fixture pair produce byte-identical canonical output"
fi

run_canon "$WORK/t007_precomposed.yaml" --hash-only
hash_precomposed=$(cat "$WORK/out")
run_canon "$WORK/t007_decomposed.yaml" --hash-only
hash_decomposed=$(cat "$WORK/out")
if [ "$hash_precomposed" = "$hash_decomposed" ] && [ -n "$hash_precomposed" ]; then
  pass "TEST-007 precomposed vs. decomposed NFC fixture pair produce an identical SHA-256"
else
  fail "TEST-007 precomposed vs. decomposed NFC fixture pair produce an identical SHA-256 (got '$hash_precomposed' vs '$hash_decomposed')"
fi

# ---------------------------------------------------------------------------
# TEST-008: JCS-compliance proof against a hand-computed golden byte
# sequence for a fixture with non-canonical key order and number formatting
# (AC-008).
# ---------------------------------------------------------------------------

cat > "$WORK/t008_golden.yaml" <<'YAMLEOF'
zebra: 1.50
apple: 100
middle:
  b: 2
  a: 1
count: 0x1F
flag: TRUE
nothing: null
empty_list: []
YAMLEOF
printf '{"apple":100,"count":31,"empty_list":[],"flag":true,"middle":{"a":1,"b":2},"nothing":null,"zebra":1.5}' \
  > "$WORK/t008_expected.json"
expect_stdout_bytes "TEST-008 JCS golden byte sequence (key sort, hex int, trailing-zero float, bool/null)" \
  "$WORK/t008_golden.yaml" "$WORK/t008_expected.json"

# ---------------------------------------------------------------------------
# TEST-009: multi-runtime hash equality + dispatch-target proof for
# .py/.sh/.ps1/.js (AC-009).
# ---------------------------------------------------------------------------

printf 'schema: sdd-project-context/v1\ncomponents: []\n' > "$WORK/t009_fixture.yaml"

hash_py=$("$PY" "$CANON_PY" "$WORK/t009_fixture.yaml" --hash-only 2>"$WORK/err_py")
hash_sh=$("$CANON_SH" "$WORK/t009_fixture.yaml" --hash-only 2>"$WORK/err_sh")

if [ -n "$hash_py" ] && [ "$hash_py" = "$hash_sh" ]; then
  pass "TEST-009 .py and .sh produce an identical SHA-256"
else
  fail "TEST-009 .py and .sh produce an identical SHA-256 (py='$hash_py' sh='$hash_sh')"
fi

if command -v pwsh >/dev/null 2>&1; then
  hash_ps1=$(pwsh -NoProfile -ExecutionPolicy Bypass -File "$CANON_PS1" "$WORK/t009_fixture.yaml" --hash-only 2>"$WORK/err_ps1")
  if [ "$hash_ps1" = "$hash_py" ]; then
    pass "TEST-009 .ps1 produces the identical SHA-256 as .py"
  else
    fail "TEST-009 .ps1 produces the identical SHA-256 as .py (ps1='$hash_ps1' py='$hash_py')"
  fi
else
  printf 'SKIP: TEST-009 .ps1 hash-equality (pwsh not found)\n'
fi

if command -v node >/dev/null 2>&1; then
  hash_js=$(node "$CANON_JS" "$WORK/t009_fixture.yaml" --hash-only 2>"$WORK/err_js")
  if [ "$hash_js" = "$hash_py" ]; then
    pass "TEST-009 .js produces the identical SHA-256 as .py"
  else
    fail "TEST-009 .js produces the identical SHA-256 as .py (js='$hash_js' py='$hash_py')"
  fi
else
  printf 'SKIP: TEST-009 .js hash-equality (node not found)\n'
fi

# Dispatch-target proof: copy each wrapper ALONE (no canonicalize-sdd-yaml.py
# beside it) and confirm it FAILS -- proving each wrapper truly depends on,
# and dispatches to, the single .py implementation rather than reimplementing
# canonicalization natively (the sdd-hook-guard.sh .ps1-native-fallback shape
# this design explicitly does NOT use, design.md Design Decisions).
DISPATCH_ONLY="$WORK/dispatch-only"
mkdir -p "$DISPATCH_ONLY"
cp "$CANON_SH" "$DISPATCH_ONLY/"
cp "$WORK/t009_fixture.yaml" "$DISPATCH_ONLY/fixture.yaml"
if "$DISPATCH_ONLY/canonicalize-sdd-yaml.sh" "$DISPATCH_ONLY/fixture.yaml" >"$WORK/out" 2>"$WORK/err"; then
  fail "TEST-009 .sh dispatch-not-reimplement proof (.sh alone, without .py, unexpectedly succeeded)"
else
  pass "TEST-009 .sh dispatch-not-reimplement proof (.sh alone, without .py, fails -- it truly dispatches to canonicalize-sdd-yaml.py)"
fi

if command -v pwsh >/dev/null 2>&1; then
  cp "$CANON_PS1" "$DISPATCH_ONLY/"
  if pwsh -NoProfile -ExecutionPolicy Bypass -File "$DISPATCH_ONLY/canonicalize-sdd-yaml.ps1" "$DISPATCH_ONLY/fixture.yaml" >"$WORK/out" 2>"$WORK/err"; then
    fail "TEST-009 .ps1 dispatch-not-reimplement proof (.ps1 alone, without .py, unexpectedly succeeded)"
  else
    pass "TEST-009 .ps1 dispatch-not-reimplement proof (.ps1 alone, without .py, fails -- no native PowerShell fallback exists)"
  fi
fi

if command -v node >/dev/null 2>&1; then
  cp "$CANON_JS" "$DISPATCH_ONLY/"
  if node "$DISPATCH_ONLY/canonicalize-sdd-yaml.js" "$DISPATCH_ONLY/fixture.yaml" >"$WORK/out" 2>"$WORK/err"; then
    fail "TEST-009 .js dispatch-not-reimplement proof (.js alone, without .py, unexpectedly succeeded)"
  else
    pass "TEST-009 .js dispatch-not-reimplement proof (.js alone, without .py, fails -- it truly dispatches to canonicalize-sdd-yaml.py)"
  fi
fi

# CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) fail-closed proof: a PATH with
# ordinary system utilities but no python3/python must deny every wrapper
# with the SAME documented exit code and diagnostic, and write nothing to
# stdout.
MINBIN="$WORK/minbin"
mkdir -p "$MINBIN"
for tool in dirname cat printf command; do
  real=$(command -v "$tool" 2>/dev/null) || continue
  ln -sf "$real" "$MINBIN/$tool"
done

if env PATH="$MINBIN" "$CANON_SH" "$WORK/t009_fixture.yaml" >"$WORK/out" 2>"$WORK/err"; then
  fail "TEST-009 .sh CANONICALIZER_RUNTIME_UNAVAILABLE fail-closed proof (unexpectedly succeeded with no python on PATH)"
else
  rc=$?
  if [ "$rc" = 3 ] && grep -q CANONICALIZER_RUNTIME_UNAVAILABLE "$WORK/err" && [ ! -s "$WORK/out" ]; then
    pass "TEST-009 .sh denies fail-closed with CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) when no python3/python is on PATH"
  else
    fail "TEST-009 .sh denies fail-closed with CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3) when no python3/python is on PATH (exit=$rc stdout=$(cat "$WORK/out") stderr=$(cat "$WORK/err"))"
  fi
fi

# ---------------------------------------------------------------------------
# TEST-037: accepted-domain boundary vectors (AC-037).
# ---------------------------------------------------------------------------

# (1) multi-document rejection: content before AND after a single '---'
# still yields two non-empty documents.
printf 'a: 1\n---\nb: 2\n' > "$WORK/t037_multidoc.yaml"
expect_reject "TEST-037 multi-document rejection" "$WORK/t037_multidoc.yaml" MULTI_DOCUMENT_REJECTED 25

# (2) non-string-key rejection: an integer-resolving plain key.
printf '123: value\n' > "$WORK/t037_nonstringkey.yaml"
expect_reject "TEST-037 non-string-key rejection" "$WORK/t037_nonstringkey.yaml" NON_STRING_KEY_REJECTED 24

# (3) post-NFC duplicate-key collision: two distinct source keys (precomposed
# vs. decomposed é) that normalize to the same NFC string.
printf 'caf\xc3\xa9: 1\ncafe\xcc\x81: 2\n' > "$WORK/t037_postnfcdup.yaml"
expect_reject "TEST-037 post-NFC duplicate-key collision rejection" "$WORK/t037_postnfcdup.yaml" POST_NFC_DUPLICATE_KEY_REJECTED 27

# (4) non-finite/out-of-range number rejection: both .inf and .nan.
printf 'a: .inf\n' > "$WORK/t037_inf.yaml"
expect_reject "TEST-037 non-finite number rejection (.inf)" "$WORK/t037_inf.yaml" NUMBER_OUT_OF_RANGE_REJECTED 28
printf 'a: .nan\n' > "$WORK/t037_nan.yaml"
expect_reject "TEST-037 non-finite number rejection (.nan)" "$WORK/t037_nan.yaml" NUMBER_OUT_OF_RANGE_REJECTED 28

# (5) RFC 8785 §3.2.2.3 numeric-formatting boundary vector: the fixed/
# exponential notation switchover at 10**21 and at 10**-6, independent of
# TEST-008's own golden fixture.
printf 'huge: 1e21\nbig: 1e20\ntiny: 1.0e-6\nsmaller: 1.0e-7\n' > "$WORK/t037_numboundary.yaml"
printf '{"big":100000000000000000000,"huge":1e+21,"smaller":1e-7,"tiny":0.000001}' > "$WORK/t037_numboundary_expected.json"
expect_stdout_bytes "TEST-037 RFC 8785 §3.2.2.3 numeric-formatting boundary vector (1e20/1e21, 1e-6/1e-7)" \
  "$WORK/t037_numboundary.yaml" "$WORK/t037_numboundary_expected.json"

# (6) byte-exact stdout-framing + documented exit-code assertion for success
# and every rejection path. Every expect_reject call above already asserted
# byte-exact-empty stdout on rejection; here we additionally assert the
# SUCCESS path has no extraneous trailing byte (no newline the
# canonicalization step itself did not produce) and that --hash-only's
# framing is exactly 'sha256:' + 64 lowercase hex + one trailing newline,
# plus a full cross-check of the documented category -> exit-code table.
run_canon "$WORK/t009_fixture.yaml"
out_size=$(wc -c < "$WORK/out" | tr -d ' ')
last_byte=$(tail -c 1 "$WORK/out" | od -An -tx1 | tr -d ' \n')
if [ "$last_byte" != "0a" ]; then
  pass "TEST-037 byte-exact stdout framing: default mode has no trailing newline byte"
else
  fail "TEST-037 byte-exact stdout framing: default mode has no trailing newline byte (found trailing 0x0a)"
fi
expected_out=$(printf '{"components":[],"schema":"sdd-project-context/v1"}')
expected_size=${#expected_out}
if [ "$out_size" = "$expected_size" ]; then
  pass "TEST-037 byte-exact stdout framing: default mode byte count matches exactly ($out_size bytes)"
else
  fail "TEST-037 byte-exact stdout framing: default mode byte count matches exactly (got $out_size want $expected_size)"
fi

run_canon "$WORK/t009_fixture.yaml" --hash-only
hash_line=$(cat "$WORK/out")
if printf '%s' "$hash_line" | grep -Eq '^sha256:[0-9a-f]{64}$'; then
  pass "TEST-037 byte-exact stdout framing: --hash-only emits exactly 'sha256:' + 64 hex chars"
else
  fail "TEST-037 byte-exact stdout framing: --hash-only emits exactly 'sha256:' + 64 hex chars (got '$hash_line')"
fi
last_byte_hash=$(tail -c 1 "$WORK/out" | od -An -tx1 | tr -d ' \n')
if [ "$last_byte_hash" = "0a" ]; then
  pass "TEST-037 byte-exact stdout framing: --hash-only output ends with exactly one trailing newline"
else
  fail "TEST-037 byte-exact stdout framing: --hash-only output ends with exactly one trailing newline"
fi

# Documented exit-code table cross-check (remedy, quality-gate seq0346 Minor
# finding: the prior version asserted only literals typed into THIS file and
# never read the script's own table, so it could not detect drift). Reads
# CATEGORY_EXIT_CODES directly out of canonicalize-sdd-yaml.py via
# importlib and diffs it against the documented table below -- a real,
# non-tautological comparison that fails if the two diverge.
actual_table=$("$PY" -c "
import importlib.util
spec = importlib.util.spec_from_file_location('canon', '$CANON_PY')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
for k, v in sorted(mod.CATEGORY_EXIT_CODES.items()):
    print('%s=%s' % (k, v))
")
expected_table='ALIAS_REJECTED=21
ANCHOR_REJECTED=20
CANONICALIZER_RUNTIME_UNAVAILABLE=3
CUSTOM_TAG_REJECTED=22
DUPLICATE_KEY_REJECTED=23
INVALID_JSON_REJECTED=11
INVALID_UTF8_REJECTED=10
MULTI_DOCUMENT_REJECTED=25
NON_STRING_KEY_REJECTED=24
NUMBER_OUT_OF_RANGE_REJECTED=28
POST_NFC_DUPLICATE_KEY_REJECTED=27
UNSUPPORTED_SYNTAX_REJECTED=26'
if [ "$actual_table" = "$expected_table" ]; then
  pass "TEST-037(remedy) CATEGORY_EXIT_CODES read from canonicalize-sdd-yaml.py itself matches the documented table"
else
  fail "TEST-037(remedy) CATEGORY_EXIT_CODES read from canonicalize-sdd-yaml.py itself matches the documented table (got: $actual_table)"
fi

# ---------------------------------------------------------------------------
# Remedy (quality-gate seq0346, NEEDS_WORK): lone-surrogate escapes,
# plain-scalar embedded ": " rejection, previously-uncovered exit codes
# (26/10/11), and JSON input mode.
# ---------------------------------------------------------------------------

# (a) Lone (unpaired) UTF-16 surrogate -> INVALID_UTF8_REJECTED (10), never
# an uncaught UnicodeEncodeError. Value + key position, YAML + JSON mode.
printf 'a: "\\ud800"\n' > "$WORK/remedy_surrogate_val.yaml"
expect_reject "TEST-REMEDY lone surrogate in a double-quoted scalar VALUE (YAML mode) is INVALID_UTF8_REJECTED, not an uncaught exception" \
  "$WORK/remedy_surrogate_val.yaml" INVALID_UTF8_REJECTED 10
expect_reject "TEST-REMEDY lone surrogate in a double-quoted scalar VALUE (YAML mode, --hash-only) is INVALID_UTF8_REJECTED" \
  "$WORK/remedy_surrogate_val.yaml" INVALID_UTF8_REJECTED 10 --hash-only

printf '"\\udfff": 1\n' > "$WORK/remedy_surrogate_key.yaml"
expect_reject "TEST-REMEDY lone surrogate in a quoted mapping KEY (YAML mode) is INVALID_UTF8_REJECTED" \
  "$WORK/remedy_surrogate_key.yaml" INVALID_UTF8_REJECTED 10

printf '{"a":"\\ud800"}' > "$WORK/remedy_surrogate_val.json"
expect_reject "TEST-REMEDY lone surrogate in a string VALUE (JSON input mode) is INVALID_UTF8_REJECTED" \
  "$WORK/remedy_surrogate_val.json" INVALID_UTF8_REJECTED 10

printf '{"\\udfff":1}' > "$WORK/remedy_surrogate_key.json"
expect_reject "TEST-REMEDY lone surrogate in an object KEY (JSON input mode) is INVALID_UTF8_REJECTED" \
  "$WORK/remedy_surrogate_key.json" INVALID_UTF8_REJECTED 10

# Regression guard: a correctly-paired surrogate escape (a real astral
# character) must keep succeeding -- the fix must not over-reject.
printf 'a: "\\ud83d\\ude00"\n' > "$WORK/remedy_pair.yaml"
printf '{"a":"\xf0\x9f\x98\x80"}' > "$WORK/remedy_pair_expected.json"
expect_stdout_bytes "TEST-REMEDY a correctly-paired surrogate escape (astral character) still succeeds" \
  "$WORK/remedy_pair.yaml" "$WORK/remedy_pair_expected.json"

# (b) A plain scalar containing ": " or ending with ":" is ambiguous with a
# nested mapping entry -> UNSUPPORTED_SYNTAX_REJECTED (26) with a
# quote-the-scalar hint, never best-effort-kept as scalar text.
printf 'a: b: c\n' > "$WORK/remedy_embedded_colon.yaml"
expect_reject "TEST-REMEDY plain scalar value 'b: c' (embedded ': ') is rejected, not best-effort-interpreted as \"b: c\"" \
  "$WORK/remedy_embedded_colon.yaml" UNSUPPORTED_SYNTAX_REJECTED 26
run_canon "$WORK/remedy_embedded_colon.yaml"
if grep -q 'quote the scalar' "$WORK/err"; then
  pass "TEST-REMEDY embedded ': ' rejection carries the quote-the-scalar hint"
else
  fail "TEST-REMEDY embedded ': ' rejection carries the quote-the-scalar hint (stderr: $(cat "$WORK/err"))"
fi

printf 'key: value:\n' > "$WORK/remedy_trailing_colon.yaml"
expect_reject "TEST-REMEDY plain scalar value 'value:' (trailing ':') is rejected" \
  "$WORK/remedy_trailing_colon.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

printf -- '- a: b: c\n' > "$WORK/remedy_seq_embedded_colon.yaml"
expect_reject "TEST-REMEDY embedded ': ' is rejected inside an inline '- key: value' mapping too" \
  "$WORK/remedy_seq_embedded_colon.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

# Regression guards: legitimate ':'-bearing content must keep working.
printf 'a: http://example.com\n' > "$WORK/remedy_url.yaml"
printf '{"a":"http://example.com"}' > "$WORK/remedy_url_expected.json"
expect_stdout_bytes "TEST-REMEDY a URL value (':' not followed by a space) still succeeds" \
  "$WORK/remedy_url.yaml" "$WORK/remedy_url_expected.json"
printf 'a: "b: c"\n' > "$WORK/remedy_quoted_colon.yaml"
printf '{"a":"b: c"}' > "$WORK/remedy_quoted_colon_expected.json"
expect_stdout_bytes "TEST-REMEDY a QUOTED value containing ': ' still succeeds" \
  "$WORK/remedy_quoted_colon.yaml" "$WORK/remedy_quoted_colon_expected.json"

# (c) Previously-uncovered exit codes: UNSUPPORTED_SYNTAX_REJECTED (26) via
# several independent out-of-subset constructs, INVALID_UTF8_REJECTED (10)
# via genuinely invalid input bytes (not just a surrogate escape), and
# INVALID_JSON_REJECTED (11) via malformed JSON.
printf 'a: |\n  block\n  scalar\n' > "$WORK/remedy_blockscalar.yaml"
expect_reject "TEST-REMEDY(26) block scalar indicator is UNSUPPORTED_SYNTAX_REJECTED" \
  "$WORK/remedy_blockscalar.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

printf 'a: [1, 2]\n' > "$WORK/remedy_flow.yaml"
expect_reject "TEST-REMEDY(26) non-empty flow sequence is UNSUPPORTED_SYNTAX_REJECTED" \
  "$WORK/remedy_flow.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

printf '\ta: 1\n' > "$WORK/remedy_tab.yaml"
expect_reject "TEST-REMEDY(26) tab indentation is UNSUPPORTED_SYNTAX_REJECTED" \
  "$WORK/remedy_tab.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

printf -- '---\nkey: value\n' > "$WORK/remedy_leadmarker.yaml"
expect_reject "TEST-REMEDY(26) a leading '---' marker on a single document is UNSUPPORTED_SYNTAX_REJECTED" \
  "$WORK/remedy_leadmarker.yaml" UNSUPPORTED_SYNTAX_REJECTED 26

printf '\xff\xfe invalid utf-8 bytes\n' > "$WORK/remedy_badutf8.yaml"
expect_reject "TEST-REMEDY(10) genuinely invalid UTF-8 input BYTES (not an escape) is INVALID_UTF8_REJECTED" \
  "$WORK/remedy_badutf8.yaml" INVALID_UTF8_REJECTED 10

printf '{"a": 1,}' > "$WORK/remedy_badjson.json"
expect_reject "TEST-REMEDY(11) malformed JSON input is INVALID_JSON_REJECTED" \
  "$WORK/remedy_badjson.json" INVALID_JSON_REJECTED 11

# JSON input mode generally (REQ-003's second declared input mode; the
# T-003 HMAC-preimage path). Extension auto-detection, explicit
# --input-format override, duplicate-key rejection, and non-finite
# constant rejection.
printf '{"b":2,"a":1}' > "$WORK/remedy_json_roundtrip.json"
printf '{"a":1,"b":2}' > "$WORK/remedy_json_roundtrip_expected.json"
expect_stdout_bytes "TEST-REMEDY JSON input mode round-trips and re-sorts keys (extension auto-detection)" \
  "$WORK/remedy_json_roundtrip.json" "$WORK/remedy_json_roundtrip_expected.json"

cp "$WORK/remedy_json_roundtrip.json" "$WORK/remedy_json_roundtrip.noext"
expect_stdout_bytes "TEST-REMEDY JSON input mode round-trips via explicit --input-format json (no .json extension)" \
  "$WORK/remedy_json_roundtrip.noext" "$WORK/remedy_json_roundtrip_expected.json" --input-format json

printf '{"a":1,"a":2}' > "$WORK/remedy_json_dup.json"
expect_reject "TEST-REMEDY JSON input mode rejects a duplicate object key" \
  "$WORK/remedy_json_dup.json" DUPLICATE_KEY_REJECTED 23

printf '{"a": NaN}' > "$WORK/remedy_json_nan.json"
expect_reject "TEST-REMEDY JSON input mode rejects the non-standard NaN constant" \
  "$WORK/remedy_json_nan.json" NUMBER_OUT_OF_RANGE_REJECTED 28

printf '{"a": Infinity}' > "$WORK/remedy_json_inf.json"
expect_reject "TEST-REMEDY JSON input mode rejects the non-standard Infinity constant" \
  "$WORK/remedy_json_inf.json" NUMBER_OUT_OF_RANGE_REJECTED 28

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

if grep -q 'canonicalize-sdd-yaml\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/canonicalize-sdd-yaml.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/canonicalize-sdd-yaml.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'canonicalize-sdd-yaml\.tests\.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/canonicalize-sdd-yaml.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/canonicalize-sdd-yaml.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/canonicalize-sdd-yaml.tests.ps1" ]; then
  pass "self-registration: tests/canonicalize-sdd-yaml.tests.ps1 twin exists"
else
  fail "self-registration: tests/canonicalize-sdd-yaml.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
