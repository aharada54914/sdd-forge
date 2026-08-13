#!/usr/bin/env bash
# Cross-script parity and installed-layout invocation harness
# (T-007, REQ-006; TEST-031/AC-031, TEST-033/AC-033).
#
# TEST-031 -- golden-fixture parity: for all four scripts, the `.sh` and
#   `.ps1` wrapper invocations of the identical fixture input produce
#   byte-identical stdout/output, and `generate-registry-digest`'s `.js`
#   wrapper matches its `.sh`/`.ps1` siblings. Each comparison is ALSO
#   pinned to a committed golden (or, for the digest, to an independently
#   reconstructed value), so all wrappers drifting together is still caught.
# TEST-033 -- 3-runtime invocation parity: each script's wrapper pair is
#   invoked from within a simulated Claude Code, Codex CLI, and Copilot CLI
#   installed-plugin context (the three
#   tests/fixtures/capability-registry/parity-runtime-*.json descriptors,
#   reusing T-003's TEST-027 installed-layout pattern) against the identical
#   fixture input, asserting identical exit codes and stdout across all
#   three runtimes.
#
# This suite changes no production script; it only invokes the four already-
# shipped wrapper sets (T-002, T-004, T-005, T-006). Every fixture is
# disposable, offline and self-contained -- no live LLM, Provider API, or
# network call anywhere.
#
# Acceptance-first RED reproduction: set SDD_PARITY_INJECT=wrapper (a
# cross-wrapper divergence in the reference runtime) or
# SDD_PARITY_INJECT=runtime (a cross-runtime divergence in the copilot-cli
# context) to deliberately break the parity matrix. The injection only ever
# patches the disposable staged copy inside this suite's own mktemp tree --
# never a file in this repository.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SOURCE_DIR="$ROOT/plugins/sdd-quality-loop/scripts"
FIXTURES="$ROOT/tests/fixtures/capability-registry"
REPO_CONTRACTS="$ROOT/contracts"
REFERENCE_RUNTIME="claude-code"
RUNTIMES="claude-code codex-cli copilot-cli"
INJECT="${SDD_PARITY_INJECT:-}"

PASS=0
FAIL=0
DESIGNED_RED=0
ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }
# A DESIGNED-RED result is a check that is red *by design* until a human
# performs a step agents are structurally forbidden from performing
# (writing under specs/<feature>/human-copy/). It is counted separately
# from FAIL -- following tests/generate-gate-capabilities.tests.sh's own
# T-006 precedent -- but still makes this suite's exit code non-zero.
designed_red() { DESIGNED_RED=$((DESIGNED_RED + 1)); printf 'DESIGNED-RED (pre-human-copy): %s\n' "$1" >&2; }

# CI resilience (tasks.md Global Constraints): normalize the mktemp root
# with `pwd -P` immediately after creation.
WORKDIR="$(mktemp -d)"
WORKDIR="$(cd "$WORKDIR" && pwd -P)"
trap 'rm -rf "$WORKDIR"' EXIT
OUTDIR="$WORKDIR/out"
mkdir -p "$OUTDIR"

# =====================================================================
# Preconditions -- fail loudly rather than silently skipping a runtime.
# =====================================================================
missing_tool=""
for tool in python3 pwsh node; do
  command -v "$tool" >/dev/null 2>&1 || missing_tool="$missing_tool $tool"
done
if [[ -n "$missing_tool" ]]; then
  printf 'capability-registry-parity: required tool(s) not available:%s\n' "$missing_tool" >&2
  printf -- '---- summary: pass=0 fail=1 designed-red=0 ----\n'
  exit 1
fi

# =====================================================================
# Shared fixture input -- written ONCE, at one absolute path, and handed
# unchanged to every runtime context, so "identical fixture input"
# (AC-031/AC-033) is literally true rather than merely equivalent.
# =====================================================================
SHARED_INPUT="$WORKDIR/shared-input"
mkdir -p "$SHARED_INPUT"
python3 - "$FIXTURES/predicate-trigger-context.json" "$SHARED_INPUT" <<'PY'
import json
import sys
from pathlib import Path

document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
target = Path(sys.argv[2])
(target / "predicate.json").write_text(json.dumps(document["predicate"], indent=2) + "\n", encoding="utf-8")
(target / "component-properties.json").write_text(
    json.dumps(document["properties"], indent=2) + "\n", encoding="utf-8"
)
PY
PREDICATE_INPUT="$SHARED_INPUT/predicate.json"
PROPERTIES_INPUT="$SHARED_INPUT/component-properties.json"
REGISTRY_INPUT="$FIXTURES/validate-registry-fully-clean.json"

# =====================================================================
# Simulated installed-plugin context builder.
#
# Reuses T-003's TEST-027 fixture pattern: only the packaged copy at the
# script-relative offset `../contracts/` is present, the tree lives outside
# this repository (mktemp) so no `.git` is reachable, and no runtime
# environment variable is set for any of the three contexts. The codex-cli
# descriptor additionally reaches the scripts through per-file symlinks
# into a separate real tree, exactly as T-003's own codex-cli fixture does.
# =====================================================================
build_context() {
  # $1 = runtime descriptor basename, $2 = optional extra root segment.
  # Writes "<install_root>\n<entry_root>" to stdout.
  python3 - "$FIXTURES/$1.json" "$WORKDIR" "$SOURCE_DIR" "$FIXTURES" "$REPO_CONTRACTS" "${2:-}" <<'PY'
import json
import os
import shutil
import sys
from pathlib import Path

descriptor = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
workdir = Path(sys.argv[2])
source_dir = Path(sys.argv[3])
fixtures = Path(sys.argv[4])
repo_contracts = Path(sys.argv[5])
suffix = sys.argv[6]

STAGED_SCRIPTS = [
    "evaluate-predicate.py", "evaluate-predicate.sh", "evaluate-predicate.ps1",
    "validate-capability-registry.py", "validate-capability-registry.sh",
    "validate-capability-registry.ps1",
    "generate-registry-digest.py", "generate-registry-digest.sh",
    "generate-registry-digest.ps1", "generate-registry-digest.js",
    "generate-gate-capabilities.py", "generate-gate-capabilities.sh",
    "generate-gate-capabilities.ps1",
    "registry_discovery.py", "canonicalize-sdd-yaml.py",
    # The two `check-*.py` masters validate-registry-fully-clean.json's
    # implementation_ref entries name; an installed plugin ships them, and
    # their presence is what makes the validator's checks (b) and (c)
    # non-vacuous inside each simulated context.
    "check-contract.py", "check-hook-activation-handshake.py",
]


def root_for(key):
    segments = list(descriptor[key])
    if suffix:
        segments.append(suffix)
    return workdir.joinpath(*segments)


def populate_shared(root):
    """Everything an installed plugin carries apart from the scripts."""
    packaged = root / "plugins" / "sdd-quality-loop" / "contracts"
    references = root / "plugins" / "sdd-quality-loop" / "references"
    monorepo_contracts = root / "contracts"
    for directory in (packaged, references, monorepo_contracts):
        directory.mkdir(parents=True, exist_ok=True)
    registry_fixture = fixtures / "gate-capabilities-clean-registry.json"
    shutil.copyfile(registry_fixture, packaged / "capability-registry.json")
    # generate-gate-capabilities.py is the packaged copy's own producer and
    # therefore reads the monorepo-relative offset, not registry_discovery's
    # packaged-copy-first contract (T-006's implementation report). Both
    # locations hold the identical fixture bytes so the two scripts see one
    # Registry.
    shutil.copyfile(registry_fixture, monorepo_contracts / "capability-registry.json")
    shutil.copyfile(
        repo_contracts / "capability-registry.schema.json",
        packaged / "capability-registry.schema.json",
    )
    shutil.copyfile(
        repo_contracts / "lite-upgrade-reason-catalog.json",
        packaged / "lite-upgrade-reason-catalog.json",
    )
    shutil.copyfile(
        source_dir.parent / "references" / "provider-terms.json",
        references / "provider-terms.json",
    )
    marker = root / descriptor["host_marker_path"]
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(descriptor["host_marker_content"], encoding="utf-8")


install_root = root_for("install_root_segments")
entry_root = root_for("entry_root_segments")

install_scripts = install_root / "plugins" / "sdd-quality-loop" / "scripts"
install_scripts.mkdir(parents=True, exist_ok=True)
for name in STAGED_SCRIPTS:
    shutil.copyfile(source_dir / name, install_scripts / name)
    os.chmod(install_scripts / name, 0o755)
populate_shared(install_root)

if descriptor["entry_via_symlink"]:
    entry_scripts = entry_root / "plugins" / "sdd-quality-loop" / "scripts"
    entry_scripts.mkdir(parents=True, exist_ok=True)
    for name in STAGED_SCRIPTS:
        link = entry_scripts / name
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(install_scripts / name)
    populate_shared(entry_root)

print(install_root)
print(entry_root)
PY
}

inject_divergence() {
  # Patch a staged wrapper copy inside the disposable mktemp tree so its
  # stdout gains one extra token. Both wrapper families hand control to
  # python via `exec`/`exit`, so the injection is PREPENDED (an appended
  # line would never run).
  # $1 = scripts dir, $2 = wrapper basename
  python3 - "$1/$2" <<'PY'
import sys
from pathlib import Path

target = Path(sys.argv[1])
text = target.read_text(encoding="utf-8")
if target.suffix == ".ps1":
    patched = '[Console]::Out.Write("divergence-canary")\n' + text
else:
    lines = text.splitlines(keepends=True)
    shebang = lines[0] if lines and lines[0].startswith("#!") else ""
    rest = "".join(lines[1:]) if shebang else text
    patched = shebang + 'printf %s "divergence-canary"\n' + rest
# Write through resolve() so a symlinked staged copy patches its real
# target rather than replacing the link.
target.resolve().write_text(patched, encoding="utf-8")
PY
}

RC=0
run_wrapper() {
  # $1 = kind (sh|ps1|js), $2 = scripts dir, $3 = script basename without
  # extension, $4 = stdout capture path, remaining = arguments.
  local kind="$1" scripts_dir="$2" base="$3" outfile="$4"
  shift 4
  case "$kind" in
    sh) bash "$scripts_dir/$base.sh" "$@" >"$outfile" 2>"$outfile.err" ;;
    ps1) pwsh -NoProfile -ExecutionPolicy Bypass -File "$scripts_dir/$base.ps1" "$@" >"$outfile" 2>"$outfile.err" ;;
    js) node "$scripts_dir/$base.js" "$@" >"$outfile" 2>"$outfile.err" ;;
    *) printf 'unknown wrapper kind: %s\n' "$kind" >&2; return 2 ;;
  esac
  RC=$?
  printf '%s' "$RC" >"$outfile.rc"
}

describe_difference() {
  # Human-readable classification of why two capture files differ -- in
  # particular, distinguishes a pure line-terminator difference (the most
  # likely cross-runtime wrapper defect) from a content difference.
  python3 - "$1" "$2" <<'PY'
import sys
from pathlib import Path

left_path = Path(sys.argv[1])
right_path = Path(sys.argv[2])
for side, path in (("left", left_path), ("right", right_path)):
    if not path.is_file():
        print(f"{side} capture is missing ({path.name})")
        raise SystemExit(0)
left = left_path.read_bytes()
right = right_path.read_bytes()
if left == right:
    print("identical")
elif left.replace(b"\r\n", b"\n") == right.replace(b"\r\n", b"\n"):
    print(f"line-terminator-only difference ({len(left)} vs {len(right)} bytes)")
else:
    print(f"content difference ({len(left)} vs {len(right)} bytes)")
PY
}

capture_path() { printf '%s/%s.%s.%s' "$OUTDIR" "$1" "$2" "$3"; }

read_rc() { tr -d '\r\n' <"$1.rc"; }

# =====================================================================
# Invoke every wrapper of every script inside every runtime context.
# =====================================================================
for runtime in $RUNTIMES; do
  context="$(build_context "parity-runtime-$runtime")"
  install_root="$(printf '%s' "$context" | sed -n '1p')"
  entry_root="$(printf '%s' "$context" | sed -n '2p')"
  scripts_dir="$entry_root/plugins/sdd-quality-loop/scripts"
  generated="$install_root/plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json"
  printf '%s\n' "$entry_root" >"$OUTDIR/$runtime.entry-root"
  printf '%s\n' "$generated" >"$OUTDIR/$runtime.generated-path"

  if [[ "$INJECT" == "wrapper" && "$runtime" == "$REFERENCE_RUNTIME" ]]; then
    inject_divergence "$scripts_dir" evaluate-predicate.ps1
  fi
  if [[ "$INJECT" == "runtime" && "$runtime" == "copilot-cli" ]]; then
    inject_divergence "$scripts_dir" evaluate-predicate.sh
  fi

  for kind in sh ps1; do
    run_wrapper "$kind" "$scripts_dir" evaluate-predicate "$(capture_path "$runtime" evaluate-predicate "$kind")" \
      --predicate "$PREDICATE_INPUT" --component-properties "$PROPERTIES_INPUT"
    run_wrapper "$kind" "$scripts_dir" validate-capability-registry "$(capture_path "$runtime" validate "$kind")" \
      --registry "$REGISTRY_INPUT" --repo-root "$entry_root"
  done

  for kind in sh ps1 js; do
    run_wrapper "$kind" "$scripts_dir" generate-registry-digest "$(capture_path "$runtime" digest "$kind")" --whole
  done

  # generate-gate-capabilities' observable output is the file it writes, so
  # parity is asserted on those bytes as well as on stdout/exit code. Each
  # wrapper writes into a cleared slot so neither can pass by inheriting the
  # other's output.
  for kind in sh ps1; do
    rm -f "$generated"
    run_wrapper "$kind" "$scripts_dir" generate-gate-capabilities "$(capture_path "$runtime" gatecap "$kind")"
    if [[ -f "$generated" ]]; then
      cp "$generated" "$(capture_path "$runtime" gatecap "$kind").file"
    fi
    run_wrapper "$kind" "$scripts_dir" generate-gate-capabilities "$(capture_path "$runtime" gatecapcheck "$kind")" --check
  done
done

# =====================================================================
# TEST-031 / AC-031 -- golden-fixture parity inside one fixed context.
# =====================================================================
assert_wrapper_parity() {
  # $1 = check label, $2 = golden file (or "-" for none), $3.. = kinds
  local label="$1" golden="$2"
  shift 2
  local slot="$1"
  shift
  local reference="" problems="" kind rc
  for kind in "$@"; do
    local capture
    capture="$(capture_path "$REFERENCE_RUNTIME" "$slot" "$kind")"
    rc="$(read_rc "$capture")"
    if [[ "$rc" != "0" ]]; then
      problems="$problems ${kind}:exit=${rc}"
      continue
    fi
    if [[ -z "$reference" ]]; then
      reference="$capture"
      continue
    fi
    if ! cmp -s "$reference" "$capture"; then
      problems="$problems ${kind}:$(describe_difference "$reference" "$capture")"
    fi
  done
  if [[ -n "$reference" && "$golden" != "-" ]] && ! cmp -s "$reference" "$golden"; then
    problems="$problems golden:$(describe_difference "$reference" "$golden")"
  fi
  if [[ -z "$problems" ]]; then
    ok "$label"
  else
    fail "$label --$problems"
  fi
}

assert_wrapper_parity \
  "TEST-031(1): evaluate-predicate .sh/.ps1 stdout is byte-identical and matches the committed golden" \
  "$FIXTURES/parity-golden-evaluate-predicate.json" evaluate-predicate sh ps1

assert_wrapper_parity \
  "TEST-031(2): validate-capability-registry .sh/.ps1 stdout is byte-identical and matches the committed golden" \
  "$FIXTURES/parity-golden-validate-capability-registry.txt" validate sh ps1

assert_wrapper_parity \
  "TEST-031(3): generate-registry-digest .sh/.ps1/.js stdout is byte-identical" \
  "-" digest sh ps1 js

# The digest golden is reconstructed independently of the digest generator
# itself (the canonicalizer is invoked directly on the same fixture
# Registry) so this row cannot pass by all three wrappers echoing one
# common defect.
expected_digest="$(python3 "$SOURCE_DIR/canonicalize-sdd-yaml.py" "$FIXTURES/gate-capabilities-clean-registry.json" \
  --input-format json --hash-only | tr -d '\r\n' | sed 's/^sha256://')"
actual_digest="$(tr -d '\r\n' <"$(capture_path "$REFERENCE_RUNTIME" digest sh)")"
if [[ -n "$expected_digest" && "$actual_digest" == "$expected_digest" ]]; then
  ok "TEST-031(4): the parity digest matches an independently reconstructed canonicalization of the same fixture Registry"
else
  fail "TEST-031(4): digest '$actual_digest' does not match the independently reconstructed '$expected_digest'"
fi

assert_wrapper_parity \
  "TEST-031(5): generate-gate-capabilities .sh/.ps1 stdout is byte-identical" \
  "-" gatecap sh ps1

gatecap_sh_file="$(capture_path "$REFERENCE_RUNTIME" gatecap sh).file"
gatecap_ps1_file="$(capture_path "$REFERENCE_RUNTIME" gatecap ps1).file"
gatecap_golden="$FIXTURES/gate-capabilities-clean-expected.json"
if [[ -f "$gatecap_sh_file" && -f "$gatecap_ps1_file" ]] \
  && cmp -s "$gatecap_sh_file" "$gatecap_ps1_file" \
  && cmp -s "$gatecap_sh_file" "$gatecap_golden"; then
  ok "TEST-031(6): generate-gate-capabilities .sh/.ps1 write byte-identical projections matching the committed golden"
else
  fail "TEST-031(6): generate-gate-capabilities projection bytes differ between wrappers or from the committed golden"
fi

# =====================================================================
# TEST-033 / AC-033 -- 3-runtime invocation parity.
# =====================================================================
assert_runtime_parity() {
  # $1 = check label, $2 = slot, $3 = "" or ".file" suffix, $4.. = kinds
  local label="$1" slot="$2" suffix="$3"
  shift 3
  local problems="" kind runtime reference reference_rc capture rc
  for kind in "$@"; do
    reference=""
    reference_rc=""
    for runtime in $RUNTIMES; do
      capture="$(capture_path "$runtime" "$slot" "$kind")"
      rc="$(read_rc "$capture")"
      if [[ -z "$reference" ]]; then
        reference="$capture"
        reference_rc="$rc"
        continue
      fi
      if [[ "$rc" != "$reference_rc" ]]; then
        problems="$problems ${kind}/${runtime}:exit=${rc}!=${reference_rc}"
      fi
      if ! cmp -s "$reference$suffix" "$capture$suffix"; then
        problems="$problems ${kind}/${runtime}:$(describe_difference "$reference$suffix" "$capture$suffix")"
      fi
    done
  done
  if [[ -z "$problems" ]]; then
    ok "$label"
  else
    fail "$label --$problems"
  fi
}

assert_runtime_parity \
  "TEST-033(1): evaluate-predicate yields identical exit codes and stdout in all three installed-plugin contexts" \
  evaluate-predicate "" sh ps1

assert_runtime_parity \
  "TEST-033(2): validate-capability-registry yields identical exit codes and stdout in all three installed-plugin contexts" \
  validate "" sh ps1

assert_runtime_parity \
  "TEST-033(3): generate-registry-digest yields identical exit codes and stdout in all three installed-plugin contexts" \
  digest "" sh ps1 js

assert_runtime_parity \
  "TEST-033(4): generate-gate-capabilities yields identical exit codes and stdout in all three installed-plugin contexts" \
  gatecap "" sh ps1

assert_runtime_parity \
  "TEST-033(5): generate-gate-capabilities writes an identical projection in all three installed-plugin contexts" \
  gatecap ".file" sh ps1

check_problems=""
for kind in sh ps1; do
  for runtime in $RUNTIMES; do
    rc="$(read_rc "$(capture_path "$runtime" gatecapcheck "$kind")")"
    [[ "$rc" == "0" ]] || check_problems="$check_problems ${kind}/${runtime}:exit=${rc}"
  done
done
if [[ -z "$check_problems" ]]; then
  ok "TEST-033(6): generate-gate-capabilities --check exits zero in all three installed-plugin contexts, via both wrappers"
else
  fail "TEST-033(6): --check exit codes diverged --$check_problems"
fi

# All three contexts resolved their Registry/catalog through the packaged
# copy alone: none of the four scripts printed a registry-discovery
# fail-closed diagnostic, and no runtime environment variable was set for
# any context (AC-027's contract, re-asserted at invocation level here).
discovery_problems=""
for runtime in $RUNTIMES; do
  for slot in evaluate-predicate validate digest gatecap gatecapcheck; do
    for kind in sh ps1 js; do
      errfile="$(capture_path "$runtime" "$slot" "$kind").err"
      if [[ -f "$errfile" ]] && grep -q 'registry-discovery' "$errfile"; then
        discovery_problems="$discovery_problems ${runtime}/${slot}/${kind}"
      fi
    done
  done
done
if [[ -z "$discovery_problems" ]]; then
  ok "TEST-033(7): no invocation in any of the three contexts fell back or failed closed on artifact discovery"
else
  fail "TEST-033(7): registry-discovery diagnostics appeared in --$discovery_problems"
fi

# =====================================================================
# Non-vacuity canary: the same comparison logic, run against a context
# whose staged `.ps1` wrapper carries a deliberately injected divergence,
# must REPORT that divergence. Without this, a comparator that silently
# compared a file against itself would look green forever.
# =====================================================================
canary_context="$(build_context "parity-runtime-$REFERENCE_RUNTIME" canary)"
canary_install="$(printf '%s' "$canary_context" | sed -n '1p')"
canary_entry="$(printf '%s' "$canary_context" | sed -n '2p')"
canary_scripts="$canary_entry/plugins/sdd-quality-loop/scripts"
run_wrapper sh "$canary_scripts" evaluate-predicate "$OUTDIR/canary.evaluate-predicate.sh" \
  --predicate "$PREDICATE_INPUT" --component-properties "$PROPERTIES_INPUT"
inject_divergence "$canary_scripts" evaluate-predicate.ps1
run_wrapper ps1 "$canary_scripts" evaluate-predicate "$OUTDIR/canary.evaluate-predicate.ps1" \
  --predicate "$PREDICATE_INPUT" --component-properties "$PROPERTIES_INPUT"
if cmp -s "$OUTDIR/canary.evaluate-predicate.sh" "$OUTDIR/canary.evaluate-predicate.ps1"; then
  fail "non-vacuity canary: an injected cross-wrapper divergence went undetected by the byte comparison"
else
  ok "non-vacuity canary: an injected cross-wrapper divergence is detected ($(describe_difference "$OUTDIR/canary.evaluate-predicate.sh" "$OUTDIR/canary.evaluate-predicate.ps1"))"
fi
rm -rf "$canary_install" "$canary_entry"

# =====================================================================
# Done When #3 -- suite/CI registration and the final cumulative check.
# =====================================================================
if grep -q 'tests/capability-registry-parity.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "self-registration: capability-registry-parity.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: capability-registry-parity.tests.sh NOT registered in tests/run-all.sh"
fi
if grep -q 'tests/capability-registry-parity.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  ok "self-registration: capability-registry-parity.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: capability-registry-parity.tests.ps1 NOT registered in tests/run-all.ps1"
fi

# This feature's suites, in task order (T-001..T-007). design.md's Test
# Strategy enumerates EIGHT items, but items 2 and 6 (Registry-validation
# policy and provider-name contamination) share a single suite file:
# acceptance-tests.md's TEST-020 row places the provider-name fixtures in
# "same suite" as TEST-014, i.e. validate-capability-registry. Eight
# strategy items therefore land as seven physical suite pairs, and this is
# the complete set.
SUITE_ORDER="capability-registry-schema evaluate-predicate registry-discovery validate-capability-registry generate-registry-digest generate-gate-capabilities capability-registry-parity"

workflow_registers_all_suites() {
  # $1 = workflow file. Prints "ok" or a diagnostic; non-zero on failure.
  python3 - "$1" "$SUITE_ORDER" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
suites = sys.argv[2].split()
missing = []
positions = []
for suite in suites:
    sh_marker = f"tests/{suite}.tests.sh"
    ps1_marker = f"tests/{suite}.tests.ps1"
    if sh_marker not in text:
        missing.append(sh_marker)
        continue
    if ps1_marker not in text:
        missing.append(ps1_marker)
        continue
    positions.append((suite, text.index(sh_marker)))
if missing:
    print("missing CI steps: " + ", ".join(missing))
    sys.exit(1)
ordered = [suite for suite, _ in sorted(positions, key=lambda item: item[1])]
if ordered != suites:
    print("CI steps present but out of task order: " + " -> ".join(ordered))
    sys.exit(1)
print("ok")
PY
}

CANDIDATE_DIR="$ROOT/specs/epic-190-a2-capability-registry/drafts/human-copy-candidate"
CANDIDATE_WORKFLOW="$CANDIDATE_DIR/.github/workflows/test.yml.candidate"
CANDIDATE_MANIFEST="$CANDIDATE_DIR/MANIFEST.sha256.candidate"
HUMAN_COPY_DIR="$ROOT/specs/epic-190-a2-capability-registry/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY_DIR/.github/workflows/test.yml"
STAGED_MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"
LIVE_WORKFLOW="$ROOT/.github/workflows/test.yml"

if [[ -f "$CANDIDATE_WORKFLOW" ]]; then
  candidate_report="$(workflow_registers_all_suites "$CANDIDATE_WORKFLOW")"
  if [[ "$candidate_report" == "ok" ]]; then
    ok "AC-030 (cumulative): the rebuilt CI workflow candidate carries every one of this feature's seven suite pairs in task order"
  else
    fail "AC-030 (cumulative): rebuilt CI workflow candidate -- $candidate_report"
  fi
else
  fail "AC-030 (cumulative): rebuilt CI workflow candidate is missing at $CANDIDATE_WORKFLOW"
fi

if [[ -f "$CANDIDATE_MANIFEST" && -f "$CANDIDATE_WORKFLOW" ]]; then
  candidate_hash="$(shasum -a 256 "$CANDIDATE_WORKFLOW" | awk '{print $1}')"
  candidate_manifest_hash="$(grep -F 'workflows/test.yml' "$CANDIDATE_MANIFEST" | awk '{print $1}')"
  if [[ -n "$candidate_manifest_hash" && "$candidate_hash" == "$candidate_manifest_hash" ]]; then
    ok "AC-030 (cumulative): the rebuilt CI workflow candidate's sha256 matches its own MANIFEST.sha256.candidate entry"
  else
    fail "AC-030 (cumulative): rebuilt CI workflow candidate sha256 does not match its MANIFEST.sha256.candidate entry"
  fi
else
  fail "AC-030 (cumulative): MANIFEST.sha256.candidate missing alongside the rebuilt CI workflow candidate"
fi

# The candidate above is what a human actually applies (T-006's own
# quality-gate remediation established `drafts/human-copy-candidate/` as
# the correct, live-derived bundle, because agents may not write under
# `human-copy/`). tasks.md Done When #3 nonetheless points at
# `human-copy/`, so the real staged location is checked directly and is
# DESIGNED-RED until that human apply lands.
if [[ -f "$STAGED_WORKFLOW" ]]; then
  staged_report="$(workflow_registers_all_suites "$STAGED_WORKFLOW")"
  if [[ "$staged_report" == "ok" ]]; then
    ok "human-copy/ staged workflow carries every one of this feature's suite pairs in task order (human apply already landed)"
  else
    designed_red "human-copy/ staged workflow does not yet carry this feature's full, task-ordered suite registration -- $staged_report -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory's README.md), then re-run this suite"
  fi
else
  fail "human-copy/ staged .github/workflows/test.yml candidate is missing"
fi

# Internal self-consistency only: proves the staged file matches the hash
# its own MANIFEST records, NOT that the staged file is current. The
# DESIGNED-RED check above is the freshness question.
if [[ -f "$STAGED_MANIFEST" && -f "$STAGED_WORKFLOW" ]]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  staged_manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [[ -n "$staged_manifest_hash" && "$staged_hash" == "$staged_manifest_hash" ]]; then
    ok "human-copy: staged workflow sha256 matches MANIFEST.sha256 (self-consistency only, not a freshness proof)"
  else
    fail "human-copy: staged workflow sha256 does not match MANIFEST.sha256"
  fi
else
  fail "human-copy: MANIFEST.sha256 missing"
fi

# Done When #3: the LIVE, R-10-protected workflow must be byte-unchanged by
# this task. Compared against its committed blob rather than a pinned hash,
# so a legitimate, unrelated CI change does not turn this suite red.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$ROOT" diff --quiet HEAD -- .github/workflows/test.yml; then
    ok "Done When #3: the live .github/workflows/test.yml is byte-unchanged relative to its committed state"
  else
    fail "Done When #3: the live .github/workflows/test.yml has an uncommitted modification -- this task must never write to it"
  fi
else
  fail "Done When #3: cannot verify the live workflow is unmodified (no git repository resolved at $ROOT)"
fi

# Done When #3: no version string was mutated outside scripts/bump-version.sh.
# This task ships no production file, so the grep is applied to everything it
# does add: both suite twins and its own fixtures.
version_hit=""
for candidate in \
  "$ROOT/tests/capability-registry-parity.tests.sh" \
  "$ROOT/tests/capability-registry-parity.tests.ps1" \
  "$FIXTURES/parity-runtime-claude-code.json" \
  "$FIXTURES/parity-runtime-codex-cli.json" \
  "$FIXTURES/parity-runtime-copilot-cli.json" \
  "$FIXTURES/parity-golden-evaluate-predicate.json" \
  "$FIXTURES/parity-golden-validate-capability-registry.txt"
do
  if [[ -f "$candidate" ]] && grep -qE '[0-9]+\.[0-9]+\.[0-9]+' "$candidate"; then
    version_hit="$version_hit $(basename "$candidate")"
  fi
done
if [[ -z "$version_hit" ]]; then
  ok "Done When #3: no semver-looking version string was hand-mutated in this task's own files (grep self-check)"
else
  fail "Done When #3: a semver-looking version string was found in --$version_hit"
fi

printf -- '---- summary: pass=%d fail=%d designed-red=%d ----\n' "$PASS" "$FAIL" "$DESIGNED_RED"
if [[ "$FAIL" -eq 0 && "$DESIGNED_RED" -eq 0 ]]; then
  printf 'capability-registry-parity suite passed (%d checks)\n' "$PASS"
  exit 0
fi
if [[ "$FAIL" -eq 0 ]]; then
  printf 'capability-registry-parity suite is DESIGNED-RED (%d passed, %d designed-red, 0 genuine failures)\n' "$PASS" "$DESIGNED_RED"
  printf 'HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory'"'"'s README.md "Human apply step"), then re-run this suite.\n'
  exit 1
fi
printf 'capability-registry-parity suite FAILED (%d passed, %d failed, %d designed-red)\n' "$PASS" "$FAIL" "$DESIGNED_RED"
exit 1
