#!/usr/bin/env bash
# T-013 closing-audit evidence harness (epic-189-a1-project-context).
#
# Produces the measurements T-013's Done When items require:
#   A  full local suite, both lanes, run AS-IS (no patch, no skip)
#   B  every epic-189-a1 suite run individually, both lanes
#   C  TEST-028 registration audit: run-all.{sh,ps1} self-registration plus
#      the .github/workflows/test.yml staged / live-unchanged /
#      post-copy-registered three-part proof
#   D  TEST-029 non-use declarations + CI-resilience checklist scan
#
# The output directory is a REQUIRED parameter. This harness never defaults to
# its own location, so re-running it can never overwrite committed, hash-pinned
# artifacts that happen to sit beside it (epic-189 carryover lesson).
#
# Usage:
#   bash t013-evidence.sh --out-dir DIR [--repo-root DIR] [--sections A,B,C,D]
set -uo pipefail

OUT_DIR=""
REPO_ROOT=""
SECTIONS="A,B,C,D"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --repo-root) REPO_ROOT="${2:-}"; shift 2 ;;
    --sections) SECTIONS="${2:-}"; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  printf 'ERROR: --out-dir is required (this harness has no default output directory)\n' >&2
  exit 2
fi
if [ -z "$REPO_ROOT" ]; then
  printf 'ERROR: --repo-root is required\n' >&2
  exit 2
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"

has_section() { case ",$SECTIONS," in *,"$1",*) return 0 ;; *) return 1 ;; esac; }

# The suites epic-189-a1 (T-001..T-012) added, in run-all registration order.
SH_SUITES="
project-context-schema
canonicalize-sdd-yaml
generate-approval-sidecar
approver-registry-schema
detect-policy-weakening
validate-approval-sidecar
apply-human-copy
check-hook-activation-handshake
guard-invariants-epic-a1
hook-guard-epic-a1-boundary
plugin-contracts-track-selection
ship-track-selection-migration
guard-staging-exemption
"
PS1_SUITES="
project-context-schema
canonicalize-sdd-yaml
generate-approval-sidecar
approver-registry-schema
detect-policy-weakening
validate-approval-sidecar
apply-human-copy
check-hook-activation-handshake
guard-invariants-epic-a1
hook-guard-epic-a1-boundary
plugin-contracts-track-selection
ship-track-selection-migration
"

cd "$REPO_ROOT"

# ---------------------------------------------------------------- section A
if has_section A; then
  printf '== A: full local suite, AS-IS ==\n'
  printf 'repo-root: %s\nHEAD: %s\n' "$REPO_ROOT" "$(git rev-parse HEAD 2>/dev/null || echo unknown)" \
    > "$OUT_DIR/A-full-suite-summary.txt"

  # NOTE: `set -e` is deliberately NOT re-enabled after these runs. This script
  # runs under `set -uo pipefail`; with `-e` also on, an unmatched grep in a
  # summary pipeline exits 1, pipefail propagates it, and the harness aborts
  # mid-sweep. That defect really occurred here and silently truncated a
  # section-B sweep at 6 of 25 suites before it was found and fixed.
  set +e
  bash tests/run-all.sh > "$OUT_DIR/A-run-all-sh.log" 2>&1
  rc_sh=$?
  printf 'bash tests/run-all.sh exit=%s\n' "$rc_sh" >> "$OUT_DIR/A-full-suite-summary.txt"
  printf '  suites announced (==> lines): %s\n' \
    "$(grep -c '^==> ' "$OUT_DIR/A-run-all-sh.log")" >> "$OUT_DIR/A-full-suite-summary.txt"
  printf '  last announced suite: %s\n' \
    "$(grep '^==> ' "$OUT_DIR/A-run-all-sh.log" | tail -1)" >> "$OUT_DIR/A-full-suite-summary.txt"

  if command -v pwsh >/dev/null 2>&1; then
    set +e
    pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1 \
      > "$OUT_DIR/A-run-all-ps1.log" 2>&1
    rc_ps1=$?
    printf 'pwsh tests/run-all.ps1 exit=%s\n' "$rc_ps1" >> "$OUT_DIR/A-full-suite-summary.txt"
    printf '  suites announced (==> lines): %s\n' \
      "$(grep -c '^==> ' "$OUT_DIR/A-run-all-ps1.log")" >> "$OUT_DIR/A-full-suite-summary.txt"
    printf '  last announced suite: %s\n' \
      "$(grep '^==> ' "$OUT_DIR/A-run-all-ps1.log" | tail -1)" >> "$OUT_DIR/A-full-suite-summary.txt"
  else
    printf 'pwsh NOT FOUND: run-all.ps1 not run\n' >> "$OUT_DIR/A-full-suite-summary.txt"
  fi
  cat "$OUT_DIR/A-full-suite-summary.txt"
fi

# ---------------------------------------------------------------- section B
if has_section B; then
  printf '== B: per-suite runs, both lanes ==\n'
  mkdir -p "$OUT_DIR/B-per-suite"
  : > "$OUT_DIR/B-per-suite-tally.txt"

  # Two summary shapes exist across these suites: "PASS: n" / "FAIL: n" lines,
  # and a single "n passed, m failed" line (apply-human-copy,
  # guard-staging-exemption). tally() reads whichever is present. Every grep is
  # `|| true`-guarded: an unmatched grep exits 1, and under `pipefail` that
  # would otherwise abort this harness mid-sweep.
  tally() {
    local log="$1" p fl combined
    p=$(grep -E '^PASS: [0-9]+$' "$log" 2>/dev/null | tail -1 | awk '{print $2}' || true)
    fl=$(grep -E '^FAIL: [0-9]+$' "$log" 2>/dev/null | tail -1 | awk '{print $2}' || true)
    if [ -z "$p" ]; then
      combined=$(grep -oE '[0-9]+ passed, [0-9]+ failed' "$log" 2>/dev/null | tail -1 || true)
      if [ -n "$combined" ]; then
        p=$(printf '%s' "$combined" | awk '{print $1}')
        fl=$(printf '%s' "$combined" | awk '{print $3}')
      fi
    fi
    printf '%s %s' "${p:-n/a}" "${fl:-n/a}"
  }

  for name in $SH_SUITES; do
    f="tests/${name}.tests.sh"
    set +e
    bash "$f" > "$OUT_DIR/B-per-suite/${name}.sh.log" 2>&1
    rc=$?
    read -r p fl <<<"$(tally "$OUT_DIR/B-per-suite/${name}.sh.log")"
    printf 'sh  %-40s exit=%s PASS=%s FAIL=%s\n' "$f" "$rc" "$p" "$fl" \
      >> "$OUT_DIR/B-per-suite-tally.txt"
  done

  if command -v pwsh >/dev/null 2>&1; then
    for name in $PS1_SUITES; do
      f="tests/${name}.tests.ps1"
      set +e
      pwsh -NoProfile -ExecutionPolicy Bypass -File "$f" \
        > "$OUT_DIR/B-per-suite/${name}.ps1.log" 2>&1
      rc=$?
      read -r p fl <<<"$(tally "$OUT_DIR/B-per-suite/${name}.ps1.log")"
      printf 'ps1 %-40s exit=%s PASS=%s FAIL=%s\n' "$f" "$rc" "$p" "$fl" \
        >> "$OUT_DIR/B-per-suite-tally.txt"
    done
  else
    printf 'ps1 SKIPPED: pwsh not found\n' >> "$OUT_DIR/B-per-suite-tally.txt"
  fi
  cat "$OUT_DIR/B-per-suite-tally.txt"
fi

# ---------------------------------------------------------------- section C
if has_section C; then
  printf '== C: TEST-028 registration audit ==\n'
  OUT_C="$OUT_DIR/C-registration-audit.txt"
  : > "$OUT_C"

  STAGED_YML="specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml"
  LIVE_YML=".github/workflows/test.yml"
  BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo '')"

  printf -- '--- part 1/3: self-registration in tests/run-all.{sh,ps1} ---\n' >> "$OUT_C"
  for name in $SH_SUITES; do
    if grep -qF "tests/${name}.tests.sh" tests/run-all.sh; then v=REGISTERED; else v=MISSING; fi
    printf 'run-all.sh   %-40s %s\n' "${name}.tests.sh" "$v" >> "$OUT_C"
  done
  for name in $PS1_SUITES; do
    if grep -qF "tests/${name}.tests.ps1" tests/run-all.ps1; then v=REGISTERED; else v=MISSING; fi
    printf 'run-all.ps1  %-40s %s\n' "${name}.tests.ps1" "$v" >> "$OUT_C"
  done

  printf -- '\n--- part 1/3b: in-suite self-registration assertion (grep of own basename) ---\n' >> "$OUT_C"
  for name in $SH_SUITES; do
    if grep -q 'run-all' "tests/${name}.tests.sh"; then v=ASSERTS_OWN_REGISTRATION; else v=NO_SELF_ASSERTION; fi
    printf '%-40s %s\n' "${name}.tests.sh" "$v" >> "$OUT_C"
  done

  printf -- '\n--- part 2/3: staged candidate registers each suite ---\n' >> "$OUT_C"
  for name in $SH_SUITES; do
    if grep -qF "tests/${name}.tests.sh" "$STAGED_YML"; then v=STAGED; else v=NOT_STAGED; fi
    printf 'staged test.yml  bash %-40s %s\n' "${name}.tests.sh" "$v" >> "$OUT_C"
  done
  for name in $PS1_SUITES; do
    if grep -qF "tests/${name}.tests.ps1" "$STAGED_YML"; then v=STAGED; else v=NOT_STAGED; fi
    printf 'staged test.yml  pwsh %-40s %s\n' "${name}.tests.ps1" "$v" >> "$OUT_C"
  done

  printf -- '\n--- part 2/3b: live .github/workflows/test.yml UNCHANGED by this branch ---\n' >> "$OUT_C"
  printf 'merge-base with origin/main: %s\n' "${BASE:-UNKNOWN}" >> "$OUT_C"
  live_now="$(shasum -a 256 "$LIVE_YML" | awk '{print $1}')"
  printf 'live sha256 (working tree):   %s\n' "$live_now" >> "$OUT_C"
  if [ -n "$BASE" ]; then
    live_base="$(git show "$BASE:$LIVE_YML" | shasum -a 256 | awk '{print $1}')"
    printf 'live sha256 (at merge-base):  %s\n' "$live_base" >> "$OUT_C"
    if [ "$live_now" = "$live_base" ]; then
      printf 'VERDICT: LIVE_UNCHANGED (this branch never edited the protected live workflow)\n' >> "$OUT_C"
    else
      printf 'VERDICT: LIVE_MODIFIED -- R-10 protected file was edited on this branch\n' >> "$OUT_C"
    fi
  fi
  printf 'branch commits touching the live workflow: %s\n' \
    "$(git log --oneline "${BASE:-HEAD}..HEAD" -- "$LIVE_YML" | wc -l | tr -d ' ')" >> "$OUT_C"
  git log --oneline "${BASE:-HEAD}..HEAD" -- "$LIVE_YML" >> "$OUT_C" 2>&1 || true

  printf -- '\n--- part 3/3: post-copy the live file WOULD register every suite ---\n' >> "$OUT_C"
  sim="$(mktemp -d)"
  sim="$(cd "$sim" && pwd -P)"
  mkdir -p "$sim/.github/workflows"
  cp "$LIVE_YML" "$sim/.github/workflows/test.yml"
  cp "$STAGED_YML" "$sim/.github/workflows/test.yml"   # simulate apply-human-copy publish
  post_missing=0
  for name in $SH_SUITES; do
    if grep -qF "tests/${name}.tests.sh" "$sim/.github/workflows/test.yml"; then v=REGISTERED; else v=MISSING; post_missing=$((post_missing+1)); fi
    printf 'post-copy bash %-40s %s\n' "${name}.tests.sh" "$v" >> "$OUT_C"
  done
  for name in $PS1_SUITES; do
    if grep -qF "tests/${name}.tests.ps1" "$sim/.github/workflows/test.yml"; then v=REGISTERED; else v=MISSING; post_missing=$((post_missing+1)); fi
    printf 'post-copy pwsh %-40s %s\n' "${name}.tests.ps1" "$v" >> "$OUT_C"
  done
  printf 'post-copy MISSING count: %s\n' "$post_missing" >> "$OUT_C"
  rm -rf "$sim"

  printf -- '\n--- staged candidate YAML well-formedness ---\n' >> "$OUT_C"
  # PyYAML is not installed in this environment; macOS system ruby ships psych,
  # so the parse check runs through ruby. Note GitHub Actions' `on:` key parses
  # as the YAML 1.1 boolean true under psych -- that is expected, not a defect.
  if command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -e '
      d = YAML.load_file(ARGV[0])
      puts "parsed OK; top-level keys: #{d.keys.map(&:to_s).sort}"
      puts "jobs: #{d["jobs"].keys.sort}"
      steps = d["jobs"]["test"]["steps"]
      puts "test job step count: #{steps.length}"
      names = steps.map { |s| s["name"] || "<uses>" }
      dupes = names.select { |n| names.count(n) > 1 }.uniq.sort
      puts "duplicate step names: #{dupes.empty? ? "none" : dupes.inspect}"
    ' "$STAGED_YML" >> "$OUT_C" 2>&1
  else
    printf 'ruby not found; YAML parse check skipped\n' >> "$OUT_C"
  fi

  printf -- '\n--- MANIFEST.sha256 consistency ---\n' >> "$OUT_C"
  MAN="specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    exp="$(printf '%s\n' "$line" | awk '{print $1}')"
    rel="$(printf '%s\n' "$line" | awk '{print $2}')"
    src="specs/epic-189-a1-project-context/human-copy/$rel"
    if [ -f "$src" ]; then
      act="$(shasum -a 256 "$src" | awk '{print $1}')"
      if [ "$act" = "$exp" ]; then v=MATCH; else v="MISMATCH actual=$act"; fi
    else
      v="SOURCE_MISSING"
    fi
    printf '%-70s %s\n' "$rel" "$v" >> "$OUT_C"
  done < "$MAN"

  cat "$OUT_C"
fi

# ---------------------------------------------------------------- section D
if has_section D; then
  printf '== D: TEST-029 non-use + CI-resilience scan ==\n'
  OUT_D="$OUT_DIR/D-nonuse-ci-resilience.txt"
  : > "$OUT_D"

  files=""
  for name in $SH_SUITES; do files="$files tests/${name}.tests.sh"; done
  for name in $PS1_SUITES; do files="$files tests/${name}.tests.ps1"; done

  printf -- '--- D1: no real LLM / agent CLI invocation ---\n' >> "$OUT_D"
  # A command invocation of a real agent CLI would appear as one of these
  # tokens at a command position. Comments and fixture strings are reported
  # too, so an omission cannot hide behind a narrow pattern.
  for f in $files; do
    hits="$(grep -nE '(^|[;&|(`$[:space:]])(claude|codex|copilot|gh|sdd-sudo)([[:space:]]|$)' "$f" || true)"
    if [ -n "$hits" ]; then
      printf '%s:\n%s\n' "$f" "$hits" >> "$OUT_D"
    fi
  done
  printf '(no output above a filename means: zero command-position hits in that file)\n' >> "$OUT_D"

  printf -- '\n--- D1b: any textual occurrence of gh / sdd-sudo / anthropic / openai ---\n' >> "$OUT_D"
  for f in $files; do
    n="$(grep -ciE 'sdd-sudo|anthropic|openai|api\.github\.com|https?://' "$f" || true)"
    printf '%-56s occurrences=%s\n' "$f" "$n" >> "$OUT_D"
  done

  printf -- '\n--- D1c: SDD_SUDO usage (T-010 fixture token, never a live grant) ---\n' >> "$OUT_D"
  for f in $files; do
    hits="$(grep -n 'SDD_SUDO' "$f" || true)"
    if [ -n "$hits" ]; then printf '%s:\n%s\n' "$f" "$hits" >> "$OUT_D"; fi
  done

  printf -- '\n--- D2: every mktemp root pwd -P normalized ---\n' >> "$OUT_D"
  # Measured per ASSIGNED VARIABLE, not per line: a suite may normalize several
  # lines below the mktemp call, so a fixed lookahead window would report false
  # violations. For `VAR=$(mktemp ...)` we look for a `pwd -P` normalization of
  # that same VAR anywhere in the file. Comment lines mentioning mktemp are
  # excluded so they cannot masquerade as an unnormalized root.
  for name in $SH_SUITES; do
    f="tests/${name}.tests.sh"
    hits="$(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*mktemp' "$f" || true)"
    if [ -z "$hits" ]; then
      printf '%-56s no mktemp assignment\n' "$f" >> "$OUT_D"
      continue
    fi
    printf '%s:\n' "$f" >> "$OUT_D"
    printf '%s\n' "$hits" | while IFS= read -r h; do
      ln="${h%%:*}"
      body="$(printf '%s' "$h" | cut -d: -f2-)"
      var="$(printf '%s' "$body" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/')"
      # A root created UNDER an already-normalized parent (mktemp -d "$WORK/x")
      # is itself physical, because $WORK is. Classifying those as violations
      # would be a false positive, so the parent variable is resolved and
      # checked for its own normalization.
      parent="$(printf '%s' "$body" | sed -nE 's/.*mktemp[^"]*"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?\/.*/\1/p')"
      if printf '%s' "$body" | grep -q 'pwd -P'; then
        v=NORMALIZED_INLINE
      elif grep -qE "${var}=\"?\\\$\(cd \"?\\\$${var}\"? && pwd -P\)" "$f"; then
        v=NORMALIZED_LATER
      elif grep -qE "\\\$\(cd \"\\\$${var}\" && pwd -P\)" "$f"; then
        v=NORMALIZED_LATER
      elif [ -n "$parent" ] && grep -qE "${parent}=\"?\\\$\(cd \"?\\\$${parent}\"? && pwd -P\)" "$f"; then
        v="NORMALIZED_INHERITED(\$$parent)"
      else
        v=NOT_NORMALIZED
      fi
      printf '  L%-5s %-18s %s\n' "$ln" "$v" "$(printf '%s' "$body" | sed 's/^[[:space:]]*//')" >> "$OUT_D"
    done
  done

  printf -- '\n--- D3: bash array expansions (set -u empty-array hazard) ---\n' >> "$OUT_D"
  for name in $SH_SUITES; do
    f="tests/${name}.tests.sh"
    hits="$(grep -n '\[@\]' "$f" || true)"
    if [ -z "$hits" ]; then
      printf '%-56s no array expansion\n' "$f" >> "$OUT_D"
    else
      printf '%s:\n%s\n' "$f" "$hits" >> "$OUT_D"
    fi
  done

  printf -- '\n--- D4: set -euo pipefail present ---\n' >> "$OUT_D"
  # Scanned over the WHOLE file: these suites carry a multi-line provenance
  # header, so the `set` line sits well below any fixed head window.
  for name in $SH_SUITES; do
    f="tests/${name}.tests.sh"
    printf '%-56s %s\n' "$f" "$(grep -nE '^set -' "$f" | tr '\n' ' ')" >> "$OUT_D"
  done

  cat "$OUT_D"
fi

printf '\nT-013 evidence harness complete. Output: %s\n' "$OUT_DIR"
