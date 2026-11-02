#!/bin/sh
# design-sync-scan.sh -- pre-upload egress-hygiene scanner for
# design-sync-loop (issue #139, DS-30, epic #136).
#
# Scope (REQ-005 / AC-018): this check is limited to egress hygiene --
# placeholder/stub-marker, secret-shaped, and PII-shaped string detection
# over HTML mockups about to leave the repository via claude.ai/design. It
# performs no assessment of mockup quality, design fidelity, accessibility,
# or design-system/ adherence -- those are design-system-contract's and
# human review's job, not this script's.
#
# Usage: design-sync-scan.sh <target-dir>
#   <target-dir>  required, the ONLY positional argument. Scanned
#                 recursively for *.html files; the extension match is
#                 case-insensitive (.html, .HTML, .Html are all scanned).
#                 A file with any other extension is outside the scan
#                 entirely -- no finding, no block, even if its content
#                 would match a secret or PII pattern. All three detection
#                 categories (placeholder, secret, PII) run in every
#                 invocation; no flag selects a subset.
#
# Exit codes (precedence: a tool-error condition always yields 2, decided
# before either detection outcome -- a scan that does not complete is
# never reported as 0 or 1, regardless of what it would have found):
#   0  the scan COMPLETED and found zero matches in any category --
#      caller may proceed to push.
#   1  the scan COMPLETED and found at least one match -- caller must not
#      push without an explicit, human-granted override recorded per
#      design-sync-loop/SKILL.md step 5; that override applies only to
#      THIS scan's disclosed findings.
#   2  the scan DID NOT COMPLETE (bad/missing/extra argument, a
#      nonexistent target directory, or an unreadable .html file under an
#      otherwise valid target) -- a tool-error outcome, not a detection
#      outcome. Blocking is unconditional here and there is no override
#      path: an override is a decision about disclosed findings, and a
#      scan that did not complete discloses none.
#
# This script presumes no interactive human at its own invocation -- it
# reads no stdin and prompts for nothing; its exit code plus its finding
# report are sufficient for a caller to gate on. It performs no runtime-
# or host-specific branching: the same command against the same input
# produces the same verdict whether the caller is Claude Code, Codex, or
# a bare terminal.

set -u

# ---------------------------------------------------------------------------
# Argument validation (AC-001, AC-007 branches 1-2, AC-008). Usage errors
# exit 2, never 1 -- a deliberate divergence from check-placeholders.sh's
# own exit-1 usage convention (check-placeholders.sh:6-9): this script's
# two failure codes carry different caller-facing meanings ("here is what
# was found" vs "the tool did not run") and must not be collapsed into
# one. No override affordance is offered anywhere below.
# ---------------------------------------------------------------------------
if [ "$#" -eq 0 ]; then
  echo "usage: design-sync-scan.sh <target-dir>" >&2
  exit 2
fi
if [ "$#" -gt 1 ]; then
  echo "usage: design-sync-scan.sh <target-dir> (exactly one argument required, got $#)" >&2
  exit 2
fi

target_dir="$1"
case "$target_dir" in -*) target_dir="./$target_dir" ;; esac

if [ ! -d "$target_dir" ]; then
  echo "design-sync-scan: target directory not found: $target_dir" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Selection: *.html recursively, extension match case-insensitive (AC-002,
# AC-039). Anything else (a .json fixture, an image, stray notes) is
# outside the scan entirely -- no finding, no block, even with matching
# content.
# ---------------------------------------------------------------------------
scan_error() {
  echo "design-sync-scan: $*" >&2
  exit 2
}
scan_work="$(mktemp -d)" || scan_error 'cannot create scan workspace'
files_list="$scan_work/files"
findings_list="$scan_work/findings"
matches_list="$scan_work/matches"
cleanup() { rm -rf "$scan_work"; }
trap cleanup 0
: > "$findings_list" || scan_error 'cannot initialize findings'
# Separate commands preserve enumeration failures on POSIX shells without pipefail.
# Newlines cannot be represented by this line-based scanner; reject explicitly.
find "$target_dir" -type f -iname '*.html' -exec sh -c '
  for path do
    case "$path" in *"
"*) exit 1 ;; esac
    printf "%s\n" "$path" || exit 1
  done
' sh {} + > "$scan_work/unsorted" 2>/dev/null || scan_error 'cannot enumerate target directory'
sort "$scan_work/unsorted" > "$files_list" || scan_error 'cannot sort selected files'

# Fail closed: every selected file must be readable before scanning begins
# (AC-007 branch 4) -- an unreadable file is a tool error, not silently
# skipped while the rest of the set is reported clean.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ ! -r "$f" ]; then
    echo "design-sync-scan: cannot read file: $f" >&2
    exit 2
  fi
done < "$files_list"

# ---------------------------------------------------------------------------
# Detection pattern catalogue (design.md's Detection pattern catalogue and
# S7/P2 dual-form block). Placeholder patterns are reused verbatim from
# check-placeholders.sh:18-19 (AC-009); the secret and PII sets are this
# feature's own (AC-010, AC-011). S7 and P2 use the POSIX ERE forms of
# design.md's dual-form block (AC-038); the .ps1 twin uses the .NET forms.
# ---------------------------------------------------------------------------

# Placeholder -- reused verbatim from check-placeholders.sh:18-19. ALL-CAPS
# stub markers are case-sensitive (their lowercase occurrences are ordinary
# prose); multi-word phrases are case-insensitive (unambiguous in any
# casing).
placeholder_pattern_cs='TODO|FIXME|HACK\b|NotImplemented|PLACEHOLDER|TODO_REPLACE_WITH_PROJECT_COMMANDS'
placeholder_pattern_ci='not[ _-]implemented|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)'

# Secret -- S1-S6 (case-sensitive fixed vendor-format prefixes; the format
# IS the casing) combined as one alternation; S7 (case-insensitive generic
# keyword-plus-assignment shape) is its own pattern.
secret_pattern_cs='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}'
secret_pattern_s7="(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*['\"][^'\"[:space:]]{8,}['\"]"

# PII -- exactly two patterns. P1 (email-shaped) is matched here without
# the RFC 2606/6761 domain exclusion; the exclusion is applied afterward
# per matched address (below), since a bracket-expression regex cannot
# express "except these specific domains" directly. P2 (E.164-shaped
# phone, bounded on both sides so it cannot match a substring of a longer
# digit run) needs no such post-filter.
pii_pattern_p1='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
pii_pattern_p2='(^|[^0-9])\+[1-9][0-9]{7,14}([^0-9]|$)'

# emit_finding: append one TAB-separated finding record. A file append is
# used to retain findings across pattern scans until all tools complete.
tab="$(printf '\t')"
emit_finding() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$findings_list" || scan_error 'cannot record finding'
}

is_reserved_domain() {
  domain_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" || scan_error 'cannot normalize domain'
  case "$domain_lc" in
    example.com|example.net|example.org|*.test|*.example|*.invalid|*.localhost)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# scan_pattern <category> <grep-flags> <pattern> <display> <file>
#   One rule of the detection table below. display selects what reaches the
#   findings list:
#     match         emit the matched text (flags must carry -o)
#     redact        emit [REDACTED]; only the line number is read
#     email-filter  like match, but drop RFC 2606/6761 reserved
#                   domains/TLDs per matched address, and redact what is
#                   emitted (a bracket-expression regex cannot express
#                   "except these specific domains" directly)
#   Read captured matches only after grep completed; exit 1 means no match,
#   while every other nonzero status means the scan failed, not a clean file.
scan_pattern() {
  sp_category="$1"; sp_flags="$2"; sp_pattern="$3"; sp_display="$4"; sp_file="$5"
  sp_status=0
  grep "$sp_flags" -e "$sp_pattern" -- "$sp_file" > "$matches_list" 2>/dev/null || sp_status=$?
  case "$sp_status" in
    0|1) ;;
    *) scan_error 'pattern scan did not complete' ;;
  esac
  while IFS=: read -r lineno match; do
    [ -z "$lineno" ] && continue
    case "$sp_display" in
      match) emit_finding "$sp_category" "$sp_file" "$lineno" "$match" ;;
      redact) emit_finding "$sp_category" "$sp_file" "$lineno" "[REDACTED]" ;;
      email-filter)
        domain="${match#*@}"
        if ! is_reserved_domain "$domain"; then
          emit_finding "$sp_category" "$sp_file" "$lineno" "[REDACTED]"
        fi
        ;;
    esac
  done < "$matches_list"
}

# The detection table: category, grep flags, pattern, display mode. The six
# rules were previously six copy-pasted scan blocks; the semantics of each
# row are unchanged (same flags, same pattern, same emitted display).
while IFS= read -r f; do
  [ -z "$f" ] && continue
  scan_pattern placeholder -noE  "$placeholder_pattern_cs" match        "$f"
  scan_pattern placeholder -noEi "$placeholder_pattern_ci" match        "$f"
  scan_pattern secret      -nE   "$secret_pattern_cs"      redact       "$f"
  scan_pattern secret      -nEi  "$secret_pattern_s7"      redact       "$f"
  scan_pattern PII         -noE  "$pii_pattern_p1"         email-filter "$f"
  scan_pattern PII         -nE   "$pii_pattern_p2"         redact       "$f"
done < "$files_list"

# ---------------------------------------------------------------------------
# Exit-code decision and report (AC-005, AC-006, AC-012, AC-013, AC-014).
# ---------------------------------------------------------------------------
count="$(wc -l < "$findings_list")" || scan_error 'cannot count findings'
count="$(printf '%s' "$count" | tr -d '[:space:]')" || scan_error 'cannot normalize count'

if [ "$count" -eq 0 ]; then
  echo "Design-Sync Scan passed (0 findings)."
  exit 0
fi

echo "Design-Sync Scan FAILED (${count} finding(s)):"
while IFS="$tab" read -r category file line display; do
  printf ' - %-11s %s:%s: %s\n' "$category" "$file" "$line" "$display"
done < "$findings_list"
echo "Findings must be reviewed. Continuing past a FAILED scan requires an"
echo "explicit human override, recorded in Design-Source as"
echo "Egress-Scan: overridden."
exit 1
