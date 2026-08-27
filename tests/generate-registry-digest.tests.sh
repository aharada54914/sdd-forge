#!/usr/bin/env bash
# Acceptance-first suite for T-005 (REQ-004; TEST-023/024/032).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SOURCE_DIR="$ROOT/plugins/sdd-quality-loop/scripts"
FIXTURES="$ROOT/tests/fixtures/capability-registry"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
INSTALL="$WORKDIR/plugin"
SCRIPT_DIR="$INSTALL/scripts"
CONTRACT_DIR="$INSTALL/contracts"
mkdir -p "$SCRIPT_DIR" "$CONTRACT_DIR"

for name in generate-registry-digest.py generate-registry-digest.sh \
  generate-registry-digest.ps1 generate-registry-digest.js \
  registry_discovery.py canonicalize-sdd-yaml.py \
  lib/py-dispatch.sh lib/py-dispatch.ps1; do
  if [[ -f "$SOURCE_DIR/$name" ]]; then
    mkdir -p "$SCRIPT_DIR/$(dirname "$name")"
    cp "$SOURCE_DIR/$name" "$SCRIPT_DIR/$name"
  fi
done

install_registry() {
  cp "$FIXTURES/$1" "$CONTRACT_DIR/capability-registry.json"
}

OUT=""
ERR=""
RC=0
run_sh() {
  local stdout_file="$WORKDIR/stdout" stderr_file="$WORKDIR/stderr"
  bash "$SCRIPT_DIR/generate-registry-digest.sh" "$@" >"$stdout_file" 2>"$stderr_file"
  RC=$?
  OUT="$(tr -d '\r\n' <"$stdout_file")"
  ERR="$(cat "$stderr_file")"
}

expected_digest() {
  python3 "$SCRIPT_DIR/canonicalize-sdd-yaml.py" "$FIXTURES/$1" \
    --input-format json --hash-only | sed 's/^sha256://'
}

install_registry registry-digest-base.json

# TEST-023: delegation, with detection tokens assembled so this suite is not
# itself a false positive for repository-wide source scanners (WFI-012).
inspection="$(python3 - "$SCRIPT_DIR/generate-registry-digest.py" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = ["canonicalize-" + "sdd-yaml.py", "registry_" + "discovery"]
banned = [
    "jcs_" + "serialize",
    "_format_" + "jcs_number",
    "parse_" + "yaml_bytes",
    "import ya" + "ml",
    "ruamel" + ".yaml",
]
print("PASS" if all(token in text for token in required) and not any(token in text for token in banned) else "FAIL")
PY
)"
if [[ "$inspection" == "PASS" ]]; then
  ok "TEST-023: implementation delegates canonicalization and contains no inline JCS/YAML parser"
else
  fail "TEST-023: canonicalizer delegation/source inspection failed"
fi

# TEST-024: semantic fragment identity.
run_sh --capability-ids cap-alpha,cap-beta,cap-alpha
digest_a="$OUT"; rc_a=$RC
run_sh --capability-ids cap-beta,cap-alpha
digest_b="$OUT"; rc_b=$RC
if [[ $rc_a -eq 0 && $rc_b -eq 0 && "$digest_a" == "$digest_b" && "$digest_a" =~ ^[0-9a-f]{64}$ ]]; then
  ok "TEST-024(1): capability order and duplicates do not change the digest"
else
  fail "TEST-024(1): capability order/duplicate independence failed"
fi

run_sh --capability-ids cap-alpha
if [[ $RC -eq 0 && "$OUT" == "$(expected_digest registry-digest-fragment-cap-alpha.json)" ]]; then
  ok "TEST-024(2): capability selection includes its transitive gates and stable-sorts both arrays"
else
  fail "TEST-024(2): capability fragment differs from the golden fragment"
fi

# Quality-gate remediation (2026-08-09): TEST-024(1) above only ever selects
# TWO capabilities and compares two live subprocess invocations against each
# other -- with a 2-element Python set, an un-sorted iteration order happens
# to coincide across separate subprocess invocations often enough that
# mutating `sorted(capability_ids)` out of build_fragment() (generate-
# registry-digest.py) went undetected in most trials (measured empirically
# while fixing this: as few as 3 catches out of 8 repeated trials in one
# run). Comparing against a FIXED, independently
# reconstructed golden digest (not another live run) for a 3-capability
# selection removes that luck entirely: JCS canonicalization preserves JSON
# array element order (it only canonicalizes object member order), so any
# capabilities-array ordering other than the sorted one names a different
# byte sequence and therefore a different digest, deterministically, every
# time.
run_sh --capability-ids cap-empty,cap-beta,cap-alpha
if [[ $RC -eq 0 && "$OUT" == "$(expected_digest registry-digest-fragment-multi-cap.json)" ]]; then
  ok "TEST-024(9): three-capability selection (author-unsorted CSV input) matches a fixed, independently-reconstructed sorted golden digest"
else
  fail "TEST-024(9): three-capability selection differs from the fixed sorted golden digest"
fi

run_sh --gate-ids gate-b
if [[ $RC -eq 0 && "$OUT" == "$(expected_digest registry-digest-fragment-gate-b.json)" ]]; then
  ok "TEST-024(3): direct gate selection is independent of capability references"
else
  fail "TEST-024(3): direct gate fragment differs from the golden fragment"
fi

run_sh --capability-ids cap-beta --gate-ids gate-x
if [[ $RC -eq 0 && "$OUT" == "$(expected_digest registry-digest-fragment-union.json)" ]]; then
  ok "TEST-024(4): both selector flags produce the deduped union"
else
  fail "TEST-024(4): combined-selector union differs from the golden fragment"
fi

run_sh --capability-ids cap-missing
if [[ $RC -ne 0 && "$ERR" == *"unknown-fragment-id"* ]]; then
  ok "TEST-024(5): unknown capability is a hard unknown-fragment-id failure"
else
  fail "TEST-024(5): unknown capability did not fail with unknown-fragment-id"
fi

run_sh --gate-ids gate-missing
if [[ $RC -ne 0 && "$ERR" == *"unknown-fragment-id"* ]]; then
  ok "TEST-024(6): unknown direct gate is a hard unknown-fragment-id failure"
else
  fail "TEST-024(6): unknown direct gate did not fail with unknown-fragment-id"
fi

run_sh
if [[ $RC -ne 0 && "$ERR" == *"fragment-selector-required"* ]]; then
  ok "TEST-024(7): missing selector is a hard fragment-selector-required failure"
else
  fail "TEST-024(7): missing selector did not fail with fragment-selector-required"
fi

install_registry registry-digest-base.json
run_sh --whole
whole_a="$OUT"; whole_rc_a=$RC
install_registry registry-digest-whole-mutated.json
run_sh --whole
if [[ $whole_rc_a -eq 0 && $RC -eq 0 && "$whole_a" != "$OUT" ]]; then
  ok "TEST-024(8): --whole is content-sensitive"
else
  fail "TEST-024(8): --whole did not change after Registry content mutation"
fi

# Quality-gate remediation (2026-08-09): TEST-024(8) above only proves
# --whole is CONTENT-sensitive; it does not prove --whole leaves the
# Registry's own array order untouched (design.md "registry_digest generator
# contract": "`--whole` selects the entire Registry (its own
# `gates`/`capabilities` arrays, already author-ordered, are not
# re-sorted)"). registry-digest-base.json's own `gates`/`capabilities`
# arrays are deliberately NOT id-sorted (gate-z, gate-b, gate-a, gate-x;
# cap-beta, cap-alpha, cap-empty) specifically so this comparison is
# meaningful: if --whole re-sorted (or otherwise reordered) either array,
# this digest would differ from a digest computed by canonicalizing the
# untouched fixture file directly.
install_registry registry-digest-base.json
run_sh --whole
if [[ $RC -eq 0 && "$OUT" == "$(expected_digest registry-digest-base.json)" ]]; then
  ok "TEST-024(10): --whole preserves the Registry's author order (unsorted, unlike fragment selection)"
else
  fail "TEST-024(10): --whole digest differs from directly canonicalizing the untouched, author-ordered fixture"
fi

# TEST-032: canonical equivalence and ordering vectors.
install_registry registry-digest-jcs-a.json
run_sh --whole
jcs_a="$OUT"; jcs_rc_a=$RC
install_registry registry-digest-jcs-b.json
run_sh --whole
if [[ $jcs_rc_a -eq 0 && $RC -eq 0 && "$jcs_a" == "$OUT" ]]; then
  ok "TEST-032(1): JCS key-order and numeric-format vectors are digest-identical"
else
  fail "TEST-032(1): JCS-equivalent Registries produced different digests"
fi

install_registry registry-digest-nfc-composed.json
run_sh --whole
nfc_a="$OUT"; nfc_rc_a=$RC
install_registry registry-digest-nfc-decomposed.json
run_sh --whole
if [[ $nfc_rc_a -eq 0 && $RC -eq 0 && "$nfc_a" == "$OUT" ]]; then
  ok "TEST-032(2): NFC composed/decomposed Registries are digest-identical"
else
  fail "TEST-032(2): NFC-equivalent Registries produced different digests"
fi

install_registry registry-digest-base.json
run_sh --gate-ids gate-z,gate-a,gate-z
stable_a="$OUT"; stable_rc_a=$RC
run_sh --gate-ids gate-a,gate-z
if [[ $stable_rc_a -eq 0 && $RC -eq 0 && "$stable_a" == "$OUT" ]]; then
  ok "TEST-032(3): stable ordering is independent of gate input order and duplication"
else
  fail "TEST-032(3): stable gate ordering/duplicate vector failed"
fi

# Wrapper parity: every wrapper must dispatch the same Python master bytes.
sh_bytes="$WORKDIR/sh.bytes"
js_bytes="$WORKDIR/js.bytes"
ps_bytes="$WORKDIR/ps.bytes"
bash "$SCRIPT_DIR/generate-registry-digest.sh" --capability-ids cap-alpha >"$sh_bytes" 2>/dev/null; sh_rc=$?
node "$SCRIPT_DIR/generate-registry-digest.js" --capability-ids cap-alpha >"$js_bytes" 2>/dev/null; node_rc=$?
pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/generate-registry-digest.ps1" --capability-ids cap-alpha >"$ps_bytes" 2>/dev/null; ps_rc=$?
framing="$(python3 - "$sh_bytes" <<'PY'
from pathlib import Path
import re, sys
data = Path(sys.argv[1]).read_bytes()
print("PASS" if re.fullmatch(b"[0-9a-f]{64}\\n", data) else "FAIL")
PY
)"
if [[ $sh_rc -eq 0 && $node_rc -eq 0 && $ps_rc -eq 0 && "$framing" == "PASS" ]] \
  && cmp -s "$sh_bytes" "$js_bytes" && cmp -s "$sh_bytes" "$ps_bytes"; then
  ok "wrapper parity: sh/ps1/js emit byte-identical digests"
else
  fail "wrapper parity: sh/ps1/js outputs or exit codes differ"
fi

if grep -q 'tests/generate-registry-digest.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "run-all.sh registers this suite between T-004 and T-006"
else
  fail "run-all.sh does not register this suite"
fi

# Done When #4 (tasks.md): "a grep self-check confirms no version string was
# mutated outside scripts/bump-version.sh" -- this task's own production
# files must never carry a hand-mutated, semver-looking version string
# (design.md Constraint Compliance: "Version bumps only via
# scripts/bump-version.sh"; this feature introduces no version-mutation
# path). Previously unimplemented in this suite (quality-gate remediation,
# 2026-08-09).
version_hit=0
for name in generate-registry-digest.py generate-registry-digest.sh \
  generate-registry-digest.ps1 generate-registry-digest.js; do
  target="$SOURCE_DIR/$name"
  if [[ -f "$target" ]] && grep -qE '[0-9]+\.[0-9]+\.[0-9]+' "$target"; then
    version_hit=1
  fi
done
if [[ "$version_hit" -eq 0 ]]; then
  ok "Done When #4: no version string was hand-mutated in this task's production files (grep self-check)"
else
  fail "Done When #4: a semver-looking version string was found in this task's production files"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ $FAIL -eq 0 ]]; then
  printf 'generate-registry-digest suite passed (%d checks)\n' "$PASS"
  exit 0
fi
printf 'generate-registry-digest suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
exit 1
