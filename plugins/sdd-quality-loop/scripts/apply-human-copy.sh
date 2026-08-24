#!/bin/sh
# apply-human-copy.sh (REQ-007, epic-189-a1-project-context T-007)
#
# Anchored-publisher-equivalent human-copy tool: generalizes
# docs/adr/0011-phase2-handle-relative-protected-copy.md's guarantee to a
# cross-platform sh/ps1 pair (never a reuse of, or extension to,
# specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1, which
# is frozen/out of scope, INV-011). NO Python master: this file, and its
# .ps1 twin, each implement the FULL publisher logic independently
# (design.md Components; T-007's own architecture constraint) -- neither
# dispatches to the other, and neither dispatches to a shared .py.
#
# Held-handle technique note (read before modifying): POSIX shell has no
# openat()/renameat() binding, so a literal NtCreateFile-style handle
# cannot be produced from this script. The guarantee requirements.md
# describes for POSIX -- "an O_DIRECTORY fd held for the operation's
# duration" plus "resolves every relative path one segment at a time
# through that held handle" -- is realized here via the process's OWN
# current-working-directory binding: POSIX chdir(2) with a RELATIVE name
# resolves against the kernel's already-open reference to the CURRENT
# directory, never by re-walking the path string from "/". Walking one
# segment at a time via `cd "$segment"` (each preceded by an `-L` lstat
# check that denies a symlink BEFORE ever attempting to enter it) is
# therefore a genuine, kernel-mediated equivalent of handle-relative
# traversal, immune to an ATTACKER renaming/replacing an ALREADY-ENTERED
# ancestor directory out from under us -- exactly ADR-0011's "the
# filesystem namespace could still change between the final check and the
# path-based open" defect. Identity pinning / defense-in-depth is provided
# by an explicit (device, inode) re-check of the anchored destination
# parent (`stat_id .`) immediately before the atomic rename -- NOT by an
# `exec N<dir` file descriptor. Two such descriptors used to be opened
# here; quality-gate seq0361 established that neither was ever read from
# (so they added nothing the cwd binding does not already provide), while
# the `2>/dev/null` guarding one of them silently discarded this script's
# OWN stderr for the entire remainder of execution -- POSIX `exec` with
# redirections applies them to the CURRENT shell -- defeating die()'s
# documented intent. Both were removed. Documented residual (never
# silently implied as fully closed): the narrow window between a
# segment's own `-L` check and its
# `cd`, and between the final pre-rename re-check and the `mv` syscall
# itself, is not closed by a single held syscall the way a real
# openat()/renameat() chain would close it -- this is the strongest
# guarantee achievable in portable POSIX shell without an FFI-capable
# interpreter, which T-007's architecture constraint (no .py master, no
# hidden interpreter engine) deliberately excludes. See ADR-0025 for the
# full write-up.
#
# CLI:
#   apply-human-copy.sh --staging-dir <dir> --manifest <file>
#       [--simulate-crash-after <stage>]
#       [--simulate-crash-during-recovery-after <stage>]
#       [--simulate-substitution]
#   apply-human-copy.sh
#       [--simulate-crash-during-recovery-after <stage>]
#
# With no --staging-dir/--manifest, the tool performs ONLY the mandatory
# start-of-invocation crash-recovery scan (Human-copy publisher
# transactional bundle contract, design.md) and exits.
#
# --staging-dir/--manifest describe a BATCH: --manifest is a GNU
# sha256sum-format file (`<64-hex-lowercase>  <repo-relative-path>`, two
# spaces, one line per target, in COMMIT ORDER) whose staged candidate
# bytes live at <staging-dir>/<repo-relative-path>; targets are published
# relative to the CURRENT WORKING DIRECTORY, matching this epic's other
# scripts' "invoked from the project root" convention (no --repo-root
# flag). A single-target manifest is the ordinary case; a 2+ target
# manifest is applied as ONE journaled transaction (design.md "Human-copy
# publisher transactional bundle contract").
#
# --simulate-crash-after / --simulate-crash-during-recovery-after /
# --simulate-substitution are TEST-ONLY fault-injection hooks, mirroring
# generate-approval-sidecar.py's established `--simulate-mid-write-failure`
# convention. They send SIGKILL to this process's own PID at a precise,
# documented point (a real, unrecoverable-by-trap process death -- never a
# soft `exit`) so recovery tests exercise genuine crash semantics, not a
# clean-shutdown approximation.
set -u

# fd 6 is a saved duplicate of this process's REAL stdout, established
# before any code below ever does `some_function >"$tmpfile"` (e.g.
# parse_manifest's own caller). die()/emit_ok() write their one
# machine-readable JSON document through fd 6, never bare stdout --
# otherwise a die() call reached from inside a function whose OWN stdout
# the caller has redirected for data-capture purposes (parse_manifest's
# hash/path pairs) would have its diagnostic silently swallowed into that
# data file instead of ever reaching the real caller, while the process
# still exits with the right code -- a machine could recover from the
# exit code alone, but a human/log reading only stdout would see nothing.
exec 6>&1

EXIT_OK=0
EXIT_USAGE_ERROR=2
EXIT_PRE_EXISTING_SYMLINK_DENIED=10
EXIT_TRAVERSAL_DENIED=11
EXIT_STAGED_CANDIDATE_HASH_MISMATCH=12
EXIT_MANIFEST_INVALID=13
EXIT_JOURNAL_SHAPE_INVALID=14
EXIT_JOURNAL_WRITE_FAILED=15
EXIT_RENAME_FAILED=16
EXIT_RECOVERY_FAILED=17
EXIT_SOURCE_UNREADABLE=18
EXIT_DUPLICATE_BASENAME_IN_BATCH=19
EXIT_UNSUPPORTED_PATH_CHARACTER=20
EXIT_LIVE_PROBE_FAILED=21

# ---------------------------------------------------------------------------
# Small helpers.
# ---------------------------------------------------------------------------

json_escape() {
  # quality-gate seq0359 fixed TAB specifically; quality-gate seq0360's
  # extended hostile-path matrix proved every OTHER C0 control byte
  # (0x01-0x07, 0x0B, 0x0E-0x1F -- the evaluator's own repro used
  # vtab/soh/formfeed/esc as representative samples) was STILL emitted
  # RAW, producing invalid JSON (RFC 8259 requires every control
  # character 0x00-0x1F to be escaped) that a strict `python3 json.load`
  # rejects and this tool's OWN T-005-reader surrogate silently fails
  # open on. Fixed generically for the FULL C0 range (never another
  # single-character patch): named JSON escapes are used where JSON
  # defines one (`\b` 0x08, `\f` 0x0C, `\r` 0x0D, `\t` 0x09); every OTHER
  # C0 byte (1-31, excluding those four and 0x0A) gets the generic
  # `\u00XX` form. 0x0A (LF) is DELIBERATELY left to the existing
  # newline-to-space normalization below (this function's own long-
  # standing convention for multi-line diagnostic TEXT -- a literal
  # newline inside a manifest PATH is separately confirmed structurally
  # unrepresentable, quality-gate seq0359, so this never applies to a
  # path). NUL (0x00) cannot survive into a POSIX shell string at all (a
  # hard C-string/argv boundary, not specific to this tool) and so is not
  # separately handled. Verified round-trip-safe against `python3
  # json.load` for every one of these codes (quality-gate seq0360
  # remedy); UTF-8 multi-byte sequences pass through completely
  # untouched (every continuation/lead byte is >= 0x80, outside the C0
  # range these substitutions ever match).
  esc=$(printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | tr '\n' ' ')
  esc=$(printf '%s' "$esc" | sed "s/$(printf '\b')/\\\\b/g")
  esc=$(printf '%s' "$esc" | sed "s/$(printf '\f')/\\\\f/g")
  esc=$(printf '%s' "$esc" | sed "s/$(printf '\r')/\\\\r/g")
  n=1
  while [ "$n" -le 31 ]; do
    case "$n" in
      8|9|10|12|13) n=$((n + 1)); continue ;;
    esac
    ch=$(printf "\\$(printf '%03o' "$n")")
    hex=$(printf '%02x' "$n")
    esc=$(printf '%s' "$esc" | sed "s/$ch/\\\\u00$hex/g")
    n=$((n + 1))
  done
  printf '%s' "$esc" | sed "s/$(printf '\t')/\\\\t/g"
}

emit_ok() {
  # emit_ok <summary-json-fragment-already-escaped> -- ALWAYS through fd 6
  # (the real stdout), never bare stdout; see the fd-6 note above set -u.
  printf '{"status":"ok",%s}\n' "$1" >&6
}

die() {
  # die <exit_code> <category> <message> -- diagnostic to stderr, the ONE
  # machine-readable JSON document through fd 6 (never bare stdout; see
  # the fd-6 note above set -u -- this is what keeps a die() reached from
  # inside a stdout-redirected-for-data-capture function, e.g.
  # parse_manifest, from having its diagnostic silently swallowed).
  code=$1
  category=$2
  message=$3
  printf '{"status":"denied","category":"%s","message":"%s"}\n' \
    "$category" "$(json_escape "$message")" >&2
  printf '{"status":"denied","category":"%s","message":"%s"}\n' \
    "$category" "$(json_escape "$message")" >&6
  exit "$code"
}

crash_now() {
  # crash_now <label> -- a genuine, trap-immune process death (real
  # crash-injection, not a soft exit), used only when the matching
  # --simulate-crash-* flag names this exact point.
  printf 'SIMULATED_CRASH: %s\n' "$1" >&2
  kill -KILL "$$"
  # kill -KILL is not expected to return; if it somehow does not take
  # effect on some POSIX variant, fail loudly rather than continuing.
  exit 90
}

stat_id() {
  # stat_id <path> -> prints "<device>:<inode>" for identity comparison.
  # DELIBERATELY not a path-string comparison: `pwd -P`/`getcwd()` always
  # reflects a directory's CURRENT name (it walks `..` entries fresh each
  # call), so a legitimate rename-and-continue (substitution resistance)
  # would ALWAYS show a path-string mismatch even though we are still
  # anchored to the exact same directory -- verified empirically at
  # implementation time. Comparing (device, inode) instead correctly
  # reports "same identity" across a rename, and "different identity" if
  # the directory entry now resolves to a genuinely different inode
  # (a real substitution attack, as opposed to a mere rename of the
  # anchored one).
  if stat -f '%d:%i' "$1" >/dev/null 2>&1; then
    stat -f '%d:%i' "$1"
  else
    stat -c '%d:%i' "$1"
  fi
}

sha256_of() {
  # sha256_of <file> -> prints lowercase 64-hex on stdout, or nothing +
  # nonzero exit on failure. quality-gate seq0360: the PRIOR implementation
  # piped `sha256sum ... | awk ...` directly -- in POSIX sh a pipeline's
  # own exit status is the LAST command's (awk's), which succeeds (prints
  # nothing) even when sha256sum/shasum itself failed to OPEN the file
  # (e.g. permission-denied), so this function's doc comment ("or nothing
  # + nonzero exit on failure") was FALSE in practice: it always returned
  # 0. Fixed by capturing the hashing command's OWN exit status via
  # command substitution (`out=$(...) || return 1`) before ever handing
  # anything to awk, so a genuine read failure is never silently
  # indistinguishable from "hashed successfully, zero-length output".
  file=$1
  if command -v sha256sum >/dev/null 2>&1; then
    out=$(sha256sum -- "$file" 2>/dev/null) || return 1
  else
    out=$(shasum -a 256 -- "$file" 2>/dev/null) || return 1
  fi
  [ -n "$out" ] || return 1
  printf '%s' "$out" | awk '{print $1}'
}

# file_mode_of <path> -> prints the octal permission bits (e.g. "755",
# "644") on stdout, or nothing + nonzero exit on failure. Same BSD-then-
# GNU capability probe as stat_id above. The output is validated as pure
# octal digits so an unexpected stat variant can never hand chmod an
# empty or option-shaped argument (fail closed, never fail open).
file_mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    fm=$(stat -f '%Lp' "$1" 2>/dev/null) || return 1
  else
    fm=$(stat -c '%a' "$1" 2>/dev/null) || return 1
  fi
  case "$fm" in
    ''|*[!0-7]*) return 1 ;;
  esac
  printf '%s' "$fm"
}

sha256_of_or_absent() {
  # sha256_of_or_absent <file> -> prints the file's sha256 (exit 0), or the
  # literal sentinel "ABSENT" (exit 0) ONLY when NOTHING WHATSOEVER occupies
  # <file>. Returns nonzero, printing NOTHING, whenever the state cannot be
  # determined:
  #   1 = an entry is there and IS a regular file, but sha256_of could not
  #       read it (e.g. mode 000).
  #   2 = an entry IS there but is NOT a regular file -- a symlink (dangling
  #       or not), a directory, a fifo, a device. "Cannot hash what is
  #       here", never "confirmed absent".
  #
  # quality-gate seq0360 established this function's governing rule: a
  # genuine read failure propagates as its OWN nonzero exit and is NEVER
  # silently coerced to "ABSENT", because that misrepresents "cannot
  # determine" as "confirmed absent". External review of PR #229 (Codex)
  # found the rule had been applied to only ONE of the two ways this
  # function can fail to hash an entry that exists: the prior
  # `[ -e ] && [ ! -L ] && [ -f ]` guard sent a SYMLINK straight through to
  # `printf 'ABSENT'`. During crash recovery that is exactly the
  # misrepresentation seq0360 forbids -- a journal recording
  # pre_hash="ABSENT" plus a symlink squatting the live target made
  # recover_all()'s `[ "$ph" = ABSENT ] && [ "$cur" = ABSENT ]` comparison
  # read as "confirmed absent => the transaction never began committing",
  # so recovery deleted the journal AND the pre/ backups and left the
  # symlink standing on a protected path. Verified empirically against the
  # pre-fix script: publish a target, crash after rename-1, replace the
  # committed target with a symlink, re-run -> {"status":"ok","recovered":1},
  # journal and backups gone, symlink still in place.
  #
  # Fixed for EVERY non-regular entry rather than for symlinks alone -- the
  # same "repair the whole class, never another single-case patch"
  # discipline seq0360 itself applied to the full C0 range in json_escape().
  # A directory or a fifo at the target path is the identical "something is
  # here that I cannot hash" observation; coercing THAT to ABSENT would be
  # the same defect wearing a different inode type.
  #
  # `[ -L "$file" ]` is tested FIRST and SEPARATELY because `[ -e ]` is
  # FALSE for a DANGLING symlink -- testing existence first would let a
  # symlink pointing at a nonexistent path fall through to "ABSENT" again.
  file=$1
  if [ -L "$file" ]; then
    return 2
  fi
  if [ -e "$file" ]; then
    if [ -f "$file" ]; then
      sha256_of "$file" || return 1
      return 0
    fi
    return 2
  fi
  printf 'ABSENT'
}

gen_nonce() {
  if [ -r /dev/urandom ]; then
    od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'
  else
    # Extremely unlikely fallback path (no /dev/urandom): derive 64 hex
    # chars from high-resolution time + PID, hashed.
    printf '%s-%s-%s' "$$" "$(date +%s)" "$RANDOM" 2>/dev/null | sha256_stdin
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    # Fail closed (same contract as sha256_of): nothing on stdout + nonzero,
    # never a silent empty digest that passes empty == empty comparisons.
    return 1
  fi
}

is_hex64() {
  case $1 in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Handle-relative (cwd-anchored) traversal.
# ---------------------------------------------------------------------------

# walk_relative_dir <relpath> [create] -- MUST be called with the CURRENT
# process already anchored at the intended base (repo root, or a staging
# root). Walks one path segment at a time; denies a symlink or a
# `.`/`..` segment BEFORE ever descending into it. A segment that does
# not exist yet is a hard denial UNLESS the optional second argument is
# the literal string "create" -- in which case it is created (mkdir,
# immediately re-checked for a symlink-race before descending) rather
# than denied; this is used ONLY for the destination-parent chain during
# an actual publish (e.g. a first-ever `sdd/.approved-context/` publish),
# NEVER for the read-only source/pre-hash/backup walks, which must
# continue to treat "does not exist" as a plain absence, never a
# directory to fabricate. On success the caller's cwd is the resolved
# directory and this returns 0; on failure this returns nonzero and the
# caller's cwd is left at whichever segment failed (callers MUST run this
# inside a subshell so a failed walk never corrupts the parent shell's
# own cwd anchor).
#
# Return codes (quality-gate seq0360 Critical remedy: return 3 -- "this
# segment plainly does not exist" -- is now DISTINCT from return 5 --
# "this segment exists but is blocked by a non-directory entry" -- which
# were previously the SAME code, both produced by one `[ ! -d "$seg" ]`
# check. This distinction exists ONLY so a caller with narrow, explicit
# context (pre_hash_of_live_target's PREPARE-time-only tolerance, below)
# can safely treat "never existed" as a legitimate absence while STILL
# fail-closing on every other denial reason (symlink, access-denied,
# blocked-by-file) -- never the reverse. `walk_relative_dir` itself makes
# NO safety judgment; it only reports precisely what it found):
#   1 = malformed relpath (absolute, or a `.`/`..` segment)
#   2 = symlink/reparse-point encountered
#   3 = segment does not exist (clean `! -e`), non-create mode
#   4 = `cd` itself failed despite existing+directory+non-symlink (e.g.
#       access denied -- a directory whose OWN execute/search bit is
#       removed, as opposed to its parent's, which would already have
#       been caught earlier by the walk never reaching this segment)
#   5 = segment exists but is NOT a directory (blocked by a file)
#   6 = create_mode="create" requested but mkdir failed for a real reason
#       (not merely "already exists as a directory", which is tolerated)
walk_relative_dir() {
  # quality-gate seq0359 (Major): the PRIOR implementation split segments
  # via `IFS='/'; set -- $relpath` -- an UNQUOTED expansion, which in
  # POSIX shell undergoes BOTH word-splitting AND PATHNAME EXPANSION
  # (globbing). A segment containing a glob metacharacter (`*`, `?`,
  # `[...]`) that happened to match an EXISTING, differently-named
  # directory entry was silently substituted for the real (non-existent)
  # literal segment -- "validated one path, published a different one,"
  # while reporting success under the DECLARED (never-actually-used) name
  # (design.md's own anchored-publisher intent, directly violated).
  # Verified empirically at remedy time: `set -- $relpath` on
  # "a*b/f.txt" with an existing "axxb" directory yields segments
  # ["axxb","f.txt"], not the literal ["a*b","f.txt"].
  # Fix: split via PURE PARAMETER EXPANSION (`${var%%/*}` /
  # `${var#*/}`), which performs pattern-matching against the STRING
  # value only -- it never touches the filesystem and is therefore
  # immune to pathname expansion regardless of the shell's `-f`/noglob
  # state. Every extracted segment is used ONLY as a quoted variable
  # reference below (`"$seg"`), so no glob-sensitive context is ever
  # reached for it.
  relpath=$1
  create_mode=${2:-}
  [ -n "$relpath" ] || return 0
  case "$relpath" in
    /*) return 1 ;;
  esac
  rest=$relpath
  while [ -n "$rest" ]; do
    case "$rest" in
      */*) seg=${rest%%/*}; rest=${rest#*/} ;;
      *) seg=$rest; rest="" ;;
    esac
    [ -n "$seg" ] || continue
    case "$seg" in
      .|..) return 1 ;;
    esac
    if [ -L "$seg" ]; then
      return 2
    fi
    if [ ! -e "$seg" ] && [ "$create_mode" = "create" ]; then
      mkdir -- "$seg" 2>/dev/null || [ -d "$seg" ] || return 6
    fi
    if [ -L "$seg" ]; then
      return 2
    fi
    if [ ! -e "$seg" ]; then
      return 3
    fi
    if [ ! -d "$seg" ]; then
      return 5
    fi
    cd -- "$seg" || return 4
  done
  return 0
}

split_dir_base() {
  # split_dir_base <relpath> -- sets globals SPLIT_DIR / SPLIT_BASE.
  case $1 in
    */*) SPLIT_DIR=${1%/*}; SPLIT_BASE=${1##*/} ;;
    *) SPLIT_DIR=""; SPLIT_BASE=$1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Fixed-width "target record" encoding (quality-gate seq0358 Major): every
# INTERNAL work file this script writes and re-reads for a batch (the
# rehashed target list, the journal's own re-derived target list during
# recovery) previously stored "<hash> <hash> <path>"-shaped lines and
# re-parsed them with `read -r a b c`, which IFS-field-splits on
# whitespace -- silently corrupting any path containing an embedded
# space/tab (fields shift) and silently STRIPPING a path's own leading/
# trailing whitespace (a `read`-assigned field never retains it), both
# verified empirically at remedy time. Neither the MANIFEST file itself
# nor the live TRANSACTION.json journal (both parsed via fixed-column
# `cut`/JSON extraction) had this defect -- only these SPECIFIC internal
# work-file round-trips did. Fix: every hash field is normalized to an
# EXACT 64-character encoding (real hashes already are; "ABSENT" is
# mapped to a 64-'z' sentinel, since 'z' is never a valid lowercase-hex
# digit and so can never collide with a genuine SHA-256 digest), so a
# record is always "<64-char><64-char><SPACE><path-to-end-of-line>" and
# is ALWAYS split via `cut -c`, NEVER via `read` IFS-splitting -- `cut`
# operates on byte/character positions only and is therefore immune to
# embedded whitespace, runs of whitespace, tabs, or leading/trailing
# whitespace in the path. A literal newline inside a path cannot be
# expressed in this line-oriented format at all (a raw newline would
# simply terminate the record early) -- inherently unrepresentable, not
# separately guarded here.
# ---------------------------------------------------------------------------

ABSENT_SENTINEL=$(printf '%064d' 0 | tr '0' z)

norm_hash() {
  # norm_hash <hash-or-ABSENT> -- prints a fixed-64-char encoding.
  if [ "$1" = "ABSENT" ]; then
    printf '%s' "$ABSENT_SENTINEL"
  else
    printf '%s' "$1"
  fi
}

denorm_hash() {
  # denorm_hash <64-char-encoded> -- inverse of norm_hash.
  if [ "$1" = "$ABSENT_SENTINEL" ]; then
    printf 'ABSENT'
  else
    printf '%s' "$1"
  fi
}

write_target_record() {
  # write_target_record <pre_hash_or_ABSENT> <post_hash_or_ABSENT> <path>
  # -- prints one fixed-width-prefix record: cols 1-64 = pre (normalized),
  # cols 65-128 = post (normalized), col 129 = one literal space, cols
  # 130-end = path VERBATIM.
  printf '%s%s %s\n' "$(norm_hash "$1")" "$(norm_hash "$2")" "$3"
}

# parse_target_record <line> -- sets globals TR_PRE / TR_POST / TR_PATH.
parse_target_record() {
  line=$1
  TR_PRE=$(denorm_hash "$(printf '%s' "$line" | cut -c1-64)")
  TR_POST=$(denorm_hash "$(printf '%s' "$line" | cut -c65-128)")
  TR_PATH=$(printf '%s' "$line" | cut -c130-)
}

# ---------------------------------------------------------------------------
# Manifest parsing.
# ---------------------------------------------------------------------------

# parse_manifest <file> -- prints one "<hash> <path>" pair per line to
# stdout (order preserved = commit order), or dies MANIFEST_INVALID.
parse_manifest() {
  manifest=$1
  [ -f "$manifest" ] || die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
    "manifest file does not exist: $manifest"
  [ -s "$manifest" ] || die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
    "manifest file is empty: $manifest"
  # UNSUPPORTED_PATH_CHARACTER (quality-gate seq0360 Major #2): a literal
  # CR (0x0D) ANYWHERE in the manifest file is rejected, whole-file, in
  # BOTH runtimes -- symmetric with the backslash precedent (seq0359).
  # This manifest is documented as a GNU sha256sum-format file (this
  # tool's own CLI contract comment, above): LF-line-oriented, never
  # CRLF. A CR embedded WITHIN a target path is, by raw bytes alone,
  # genuinely INDISTINGUISHABLE from a legitimate CRLF line terminator --
  # the exact same "cannot tell apart without external context" class
  # this whole remedy round addresses at the recovery layer -- so BOTH
  # are refused uniformly here rather than attempting a raw-byte,
  # LF-only re-parse (which would risk silently corrupting a genuinely
  # CRLF-terminated manifest by leaving a spurious trailing CR attached
  # to every target path). The .ps1 twin's Get-Content ALSO independently
  # splits a bare CR as its own line boundary, making a CR mid-path
  # unparseable as a single manifest line there too without an
  # equivalent raw pre-check -- verified empirically, see Read-Manifest's
  # own comment for the evaluator's exact repro.
  if grep -q "$(printf '\r')" "$manifest" 2>/dev/null; then
    die "$EXIT_UNSUPPORTED_PATH_CHARACTER" UNSUPPORTED_PATH_CHARACTER \
      "manifest file contains a literal carriage return (CR), which cannot be safely distinguished from a CRLF line terminator by either runtime; rejected in both runtimes (sh and ps1) to avoid a silent capability divergence: $manifest"
  fi
  # Duplicate-path / duplicate-basename tracking (quality-gate seq0358):
  # NEWLINE-delimited accumulator FILES, checked via `grep -qxF` (exact
  # whole-line, fixed-string match) -- NEVER a space-joined string checked
  # via a `case "* $x *"` substring pattern (the PRIOR implementation),
  # which is UNSOUND once paths may contain embedded spaces: `seen=" a b"`
  # would false-positive-match a LATER, genuinely distinct target "b"
  # (" a b " contains " b " as a literal substring), verified empirically
  # at remedy time. A path can never contain a newline (this manifest
  # format is inherently line-oriented -- a literal newline would simply
  # terminate the line early, producing a malformed line the hash/
  # separator checks below already reject), so newline-delimited,
  # exact-line matching is unambiguous regardless of embedded spaces,
  # tabs, or runs of either.
  seen_paths_file=$(mktemp "${TMPDIR:-/tmp}/ahc-seen-paths.XXXXXX")
  seen_basenames_file=$(mktemp "${TMPDIR:-/tmp}/ahc-seen-basenames.XXXXXX")
  : >"$seen_paths_file"
  : >"$seen_basenames_file"
  line_no=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    [ -n "$line" ] || continue
    hash=$(printf '%s' "$line" | cut -c1-64)
    sep=$(printf '%s' "$line" | cut -c65-66)
    # Fixed-column extraction (never `read`-based IFS field-splitting):
    # `path` is EVERYTHING from column 67 to end of line, verbatim --
    # embedded spaces/tabs, runs of either, and leading/trailing
    # whitespace within the path are all preserved byte-exact
    # (quality-gate seq0358 Major: a `read`-split path corrupts on
    # embedded whitespace and a `read`-assigned path has its OWN
    # leading/trailing whitespace silently stripped by IFS semantics,
    # verified empirically at remedy time -- `cut -c` does neither).
    path=$(printf '%s' "$line" | cut -c67-)
    if ! is_hex64 "$hash" || [ "$sep" != "  " ] || [ -z "$path" ]; then
      die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest line $line_no is not '<64-hex-lowercase>  <path>': $manifest"
    fi
    case "$path" in
      /*|*..*) die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest line $line_no target is not a normalized repo-relative path: $path" ;;
    esac
    # UNSUPPORTED_PATH_CHARACTER (quality-gate seq0359 hostile-path
    # matrix): a literal backslash is rejected in BOTH runtimes, by
    # design, not merely by sh-side limitation. This publisher's .ps1
    # twin runs via cross-platform pwsh, and PowerShell/.NET's
    # FileSystemProvider was verified EMPIRICALLY to treat `\` as a
    # directory separator on every platform (macOS included) even when
    # `-LiteralPath` is used -- `Test-Path -LiteralPath 'back\slash.txt'`
    # resolves to a NESTED path ('back/slash.txt') and returns $false for
    # a real, literal file named 'back\slash.txt'; this is a genuine,
    # verified runtime limitation of PowerShell's own path-handling
    # layer, not a bug reachable by any technique available to this
    # tool's architecture (which relies on PowerShell's own Test-Path/
    # Get-FileHash/etc. cmdlets, all of which pass through the same
    # provider). Rejecting it in sh TOO (which has no such limitation on
    # its own) avoids a silent divergence where sh accepts a path .ps1
    # can never publish -- the SAME "genuinely unsupportable character"
    # treatment as an unrepresentable literal newline, above.
    case "$path" in
      *'\'*) die "$EXIT_UNSUPPORTED_PATH_CHARACTER" UNSUPPORTED_PATH_CHARACTER \
        "manifest line $line_no target contains a literal backslash, which the .ps1 twin's PowerShell/.NET FileSystemProvider cannot address literally on any platform (verified: -LiteralPath still treats \\ as a directory separator); rejected in both runtimes to avoid a silent sh/ps1 capability divergence: $path" ;;
    esac
    if grep -qxF -- "$path" "$seen_paths_file" 2>/dev/null; then
      rm -f "$seen_paths_file" "$seen_basenames_file"
      die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest lists target '$path' more than once"
    fi
    printf '%s\n' "$path" >>"$seen_paths_file"
    # DUPLICATE_BASENAME_IN_BATCH (quality-gate seq0357 Major #1): the
    # transactional bundle contract's own backup path
    # (design.md:1011, `sdd/.staging/<batch-nonce>/pre/<target-basename>`)
    # is basename-keyed, not path-keyed. Two targets sharing a basename
    # in different directories within the SAME batch would collide on a
    # single backup slot, permanently defeating recovery for one of them.
    # This never occurs in this epic's own real batches (every staged
    # basename across REQ-004's sidecar+anchor pair and REQ-007's own
    # guard-invariants/self-protection batches is globally unique), but
    # is a reachable input to this generic, content-agnostic publisher --
    # refused here, at manifest-parse time, before any live mutation,
    # rather than silently deviating from the design's literal backup
    # naming scheme (a design amendment to a path-derived backup name is
    # a review-process matter, not an implementer's unilateral choice).
    #
    # quality-gate seq0361 Major #2: this comparison is CASE-INSENSITIVE.
    # The prior `grep -qxF` was byte-exact, so on a case-insensitive
    # volume -- macOS APFS by default, and this tool's primary platform --
    # `d1/File.txt` and `d2/file.txt` passed the guard as "different
    # basenames" yet resolved to the SAME `pre/<basename>` slot: the
    # second backup silently overwrote the first, destroying one target's
    # only PRE bytes (evaluator's repro: one slot holding the WRONG
    # target's content, then RECOVERY_FAILED forever).
    #
    # The fold is applied UNCONDITIONALLY, on every platform, rather than
    # probing the volume's own case semantics: a batch is then accepted or
    # refused identically everywhere, both runtimes agree by construction,
    # and the verdict does not depend on where the repository happens to
    # be checked out. It is deliberately ASCII-ONLY (`LC_ALL=C` makes `tr`
    # operate bytewise, and every UTF-8 continuation/lead byte is >= 0x80,
    # outside the A-Z range) so the two runtimes fold byte-identically;
    # non-ASCII case folding is a per-volume Unicode property no static
    # fold can decide, and is caught instead by the backup-slot
    # exclusivity check at PREPARE time (below), which uses the real
    # filesystem's own answer.
    split_dir_base "$path"
    base=$SPLIT_BASE
    base_key=$(printf '%s' "$base" | LC_ALL=C tr 'A-Z' 'a-z')
    if grep -qxF -- "$base_key" "$seen_basenames_file" 2>/dev/null; then
      rm -f "$seen_paths_file" "$seen_basenames_file"
      die "$EXIT_DUPLICATE_BASENAME_IN_BATCH" DUPLICATE_BASENAME_IN_BATCH \
        "manifest target '$path' shares basename '$base' (compared case-insensitively) with an earlier target in the same batch; the pre-transaction backup path is basename-keyed (design.md:1011) and cannot safely hold two colliding targets in one transaction"
    fi
    printf '%s\n' "$base_key" >>"$seen_basenames_file"
    printf '%s %s\n' "$hash" "$path"
  done <"$manifest"
  rm -f "$seen_paths_file" "$seen_basenames_file"
}

# ---------------------------------------------------------------------------
# Anchored single-target publish primitive.
#
# publish_one_target <source_root> <staged_relpath> <expected_hash>
#                     <batch_dir_abs> <do_substitute>
# Anchors into <source_root>/<dirname staged_relpath> AND (separately, in
# the SAME subshell so the anchor is held for the operation's duration)
# the repo-relative destination parent, writes an exclusive temp file,
# rehashes, and commits via a same-directory atomic rename. Prints
# "<pre_hash_or_ABSENT>" on stdout on success. Returns nonzero (and prints
# nothing) on any denial.
#
# Mode-preservation contract (Human-copy publisher transactional bundle
# contract, design.md): the STAGED CANDIDATE's own Unix permission bits
# (read via file_mode_of, above) are `chmod`ed onto the temp file BEFORE
# the atomic rename, so they -- and never the live target's own
# pre-existing mode -- are what the rename commits. Return 13 = the
# staged candidate's mode could not be read; subshell exit 9 (surfaced by
# the caller as 109) = the temp file's mode could not be set to match.
# ---------------------------------------------------------------------------

publish_one_target() {
  source_root=$1
  staged_relpath=$2
  expected_hash=$3
  do_substitute=$4
  repo_root_abs=$5

  split_dir_base "$staged_relpath"
  src_dir=$SPLIT_DIR
  src_base=$SPLIT_BASE
  split_dir_base "$staged_relpath"
  dest_dir=$SPLIT_DIR
  dest_base=$SPLIT_BASE

  # --- Anchor into the SOURCE side and read+rehash staged bytes. -----------
  src_abs=$(
    cd -- "$source_root" 2>/dev/null || exit 1
    walk_relative_dir "$src_dir" || exit 2
    if [ -L "$src_base" ] || [ ! -f "$src_base" ]; then exit 3; fi
    pwd -P
  ) || return 10
  [ -n "$src_abs" ] || return 10
  staged_file="$src_abs/$src_base"
  actual_hash=$(sha256_of "$staged_file")
  [ -n "$actual_hash" ] || return 11
  if [ "$actual_hash" != "$expected_hash" ]; then
    return 12
  fi
  # Mode-preservation contract (Human-copy publisher transactional bundle
  # contract, design.md): the STAGED CANDIDATE's own permission bits are
  # what get applied to the live target below -- the live target's
  # pre-existing mode is deliberately NEVER consulted. Captured here,
  # before the destination-parent anchor, so a failure to read it denies
  # the whole publish (return 13) rather than silently falling through to
  # whatever mode the temp file's own `mktemp` default happens to be.
  staged_mode=$(file_mode_of "$staged_file") || return 13

  # --- Anchor into the DESTINATION-PARENT side (held for this target's
  #     entire write+rename window, inside one subshell). ------------------
  (
    cd -- "$repo_root_abs" || exit 1
    walk_relative_dir "$dest_dir" create || exit 2
    dest_parent_id=$(stat_id .)

    if [ "$do_substitute" = "1" ]; then
      # TEST-ONLY: simulate an attacker renaming the destination-parent
      # directory aside and creating a harmless empty replacement at the
      # ORIGINAL path, from a vantage OUTSIDE this already-anchored
      # subshell -- proving the anchor (this subshell's own cwd) still
      # resolves to, and writes into, the TRUE original directory.
      (
        cd -- "$repo_root_abs" || exit 0
        if [ -n "$dest_dir" ]; then
          mv -- "$dest_dir" "${dest_dir}.attacker-moved" 2>/dev/null &&
            mkdir -p -- "$dest_dir" 2>/dev/null
        fi
      )
    fi

    # Pre-existing symlink at the FINAL target name itself is always denied.
    if [ -L "$dest_base" ]; then
      exit 3
    fi

    tmp=$(mktemp ".apply-human-copy.XXXXXX" 2>/dev/null) || exit 4
    if ! cat -- "$staged_file" >"$tmp" 2>/dev/null; then
      rm -f -- "$tmp" 2>/dev/null
      exit 5
    fi
    tmp_hash=$(sha256_of "$tmp")
    if [ "$tmp_hash" != "$expected_hash" ]; then
      rm -f -- "$tmp" 2>/dev/null
      exit 6
    fi
    # The rename below carries the temp file's own permission bits, so
    # the STAGED candidate's mode is applied here -- the live target's
    # pre-existing mode is deliberately never consulted (it is exactly
    # the drift/tamper surface this publisher exists to overwrite).
    if ! chmod "$staged_mode" "$tmp" 2>/dev/null; then
      rm -f -- "$tmp" 2>/dev/null
      exit 9
    fi
    # Immediately-before-use identity re-check: the destination-parent we
    # anchored into at the top of this subshell must still be the SAME
    # underlying directory BY INODE (never by path string -- a legitimate
    # rename-and-continue, i.e. substitution RESISTANCE, must still pass
    # this check even though `pwd -P` would now report a different
    # string; defense-in-depth, closes the window as tightly as POSIX
    # shell allows -- see the header comment's documented residual).
    now_id=$(stat_id .)
    if [ "$now_id" != "$dest_parent_id" ]; then
      rm -f -- "$tmp" 2>/dev/null
      exit 7
    fi
    if ! mv -f -- "$tmp" "$dest_base" 2>/dev/null; then
      rm -f -- "$tmp" 2>/dev/null
      exit 8
    fi
  ) || return $((100 + $?))

  return 0
}

# pre_hash_of_live_target <repo_root_abs> <relpath> [tolerate-not-found]
# -- prints the CURRENT live sha256, or the literal "ABSENT" -- ONLY when
# that is a CONFIRMED fact, never a guess -- anchored the same cwd-chain
# way, WITHOUT mutating the caller's cwd (runs in a subshell). Returns
# nonzero with EMPTY stdout -- a PROBE FAILURE -- when the state cannot be
# safely determined; callers MUST check the exit status, never infer
# success from stdout alone.
#
# quality-gate seq0360 CRITICAL: the PRIOR implementation printed the bare
# string "ABSENT" whenever the inner subshell exited nonzero for ANY
# reason -- a missing destination-parent segment, a symlink REPLACING it,
# an access-denied `cd` (e.g. chmod 000), ALL produced the identical
# output as "the file genuinely does not exist". recover_all()'s own
# comparisons (`cur == pre_hash`) could then not tell "confirmed absent"
# from "could not check", so an attacker (or an unrelated fault) able to
# make a target's destination-parent chain momentarily unwalkable BETWEEN
# a successful commit and the next invocation's recovery scan could make
# a target that had already advanced to POST look identical to one that
# had never been touched (evaluator's own repro: parent replaced with a
# symlink / renamed aside / chmod 000, six runs, six false "already
# reverted" verdicts) -- recovery then deleted the journal AND the
# pre/ backup UNCONDITIONALLY, permanently destroying the only durable
# record of the pre-transaction state, leaving the live target standing
# at POST with no way back. Fixed: a probe failure is now ALWAYS reported
# as a probe failure (nonzero return, no stdout) -- NEVER silently
# reinterpreted as "absent" -- with exactly ONE narrow, explicit
# exception: the OPTIONAL third argument, the literal string
# "tolerate-not-found", makes THIS SPECIFIC probe accept walk_relative_dir
# return code 3 ("this exact segment plainly does not exist", never a
# symlink/access-denied/blocked-by-file) as a legitimate absence. This
# flag is passed by the very first, journal-free PREPARE-time probe
# (below, before ANY journal for this batch exists -- so there is nothing
# yet to protect, and "the destination directory has simply never been
# created yet" is the ordinary, ENTIRELY EXPECTED first-ever-publish
# case, not a threat) and, during recovery, ONLY through
# recovery_probe_live_target() below, which derives it from the JOURNAL's
# own recorded pre_hash rather than from the probe result. See that
# function's header for the design derivation.
#
# RETURN CODES (external review of PR #229, Codex): a probe failure is no
# longer a single undifferentiated `1`. The `tolerate-not-found` flag has
# ALWAYS been scoped to walk_relative_dir's rc 3 alone, so it never
# tolerated a non-regular LEAF -- but sha256_of_or_absent used to hide that
# case by returning "ABSENT" instead of failing, so the distinction never
# reached this layer at all. Now it does:
#   0 = state determined; the hash (or the literal "ABSENT") is on stdout.
#   1 = state could NOT be determined (bad anchor, or a destination-parent
#       segment that is a symlink / access-denied / blocked by a
#       non-directory / plainly missing without `tolerate-not-found`).
#   2 = the destination-parent chain walked cleanly, but a NON-REGULAR
#       entry (symlink, directory, fifo, ...) occupies the target LEAF, so
#       its bytes cannot be hashed. Callers classify this distinctly: at
#       PREPARE it is PRE_EXISTING_SYMLINK_DENIED (exit 10, the category
#       publish_one_target already uses for exactly this condition at the
#       final target name); during recovery it is RECOVERY_FAILED (exit 17,
#       fail-closed, journal and backups retained).
# Stdout is EMPTY for both nonzero codes; callers MUST check the status.
pre_hash_of_live_target() {
  repo_root_abs=$1
  relpath=$2
  tolerate_not_found=${3:-}
  split_dir_base "$relpath"
  result=$(
    cd -- "$repo_root_abs" 2>/dev/null || exit 1
    walk_relative_dir "$SPLIT_DIR"
    walk_rc=$?
    if [ "$walk_rc" != 0 ]; then
      if [ "$walk_rc" = 3 ] && [ "$tolerate_not_found" = "tolerate-not-found" ]; then
        printf 'ABSENT'
        exit 0
      fi
      exit 1
    fi
    # `exit $?` (never a flattened `exit 1`): sha256_of_or_absent's own
    # rc 2 -- "a non-regular entry occupies the leaf" -- must survive to
    # this function's caller so it can be classified under the script's
    # existing symlink-rejection category rather than merged into the
    # generic probe failure.
    sha256_of_or_absent "$SPLIT_BASE" || exit $?
  )
  rc=$?
  if [ "$rc" != 0 ]; then
    return "$rc"
  fi
  printf '%s' "$result"
  return 0
}

# recovery_probe_live_target <repo_root_abs> <relpath> <journal_pre_hash>
# -- the ONLY probe recover_all() is permitted to use. Prints the target's
# current live sha256 or the literal "ABSENT"; returns nonzero with EMPTY
# stdout when the state cannot be determined.
#
# DESIGN DERIVATION (quality-gate seq0361 Critical; seq0360's own remedy
# over-corrected here and bricked every first-ever publish, so the exact
# reasoning is recorded rather than left implicit):
#
#   design.md:1036-1037 requires recovery to "re-hash every listed
#   target's CURRENT live bytes (OR NOTE `ABSENT`)", and design.md:1042-
#   1046 makes "every target's current hash equals its journal-recorded
#   PRE value (OR BOTH ARE `ABSENT`) => SAFE abandonment" a REQUIRED
#   terminal verdict. Observing ABSENT is therefore a first-class,
#   mandatory outcome of the probe -- not a failure. A recovery that can
#   never reach it cannot satisfy design.md:1056-1058's "recovery ALWAYS
#   drives the system to exactly one of two terminal states".
#
#   What must never happen (seq0360's Critical) is COERCING an
#   undetermined state into "ABSENT". So the line is drawn between an
#   OBSERVATION and a FAILURE TO OBSERVE, and the journal itself supplies
#   the discriminator:
#
#   * walk rc 2/4/5 (symlink, access-denied, blocked by a non-directory)
#     -- the segment EXISTS but its true contents cannot be read. Nothing
#     was observed. ALWAYS fail closed, in both branches, for every
#     target, regardless of what the journal recorded.
#   * walk rc 3 (this segment plainly does not exist) AND the journal
#     recorded pre_hash="ABSENT" for this target -- a legitimate
#     OBSERVATION of exactly the state the journal says to expect. This
#     is the ordinary first-ever-publish shape: PREPARE tolerated the
#     same missing chain moments earlier (its own probe below) precisely
#     because the tool creates destination directories on demand.
#   * walk rc 3 AND the journal recorded a REAL pre_hash -- fail closed.
#     A non-ABSENT pre_hash PROVES that at journal-write time this target
#     existed as a regular file, which PROVES its entire destination-
#     parent chain existed and was walkable. A clean ENOENT now is
#     therefore evidence that something REMOVED a chain that provably
#     existed (seq0360's own "parent renamed aside" repro), never the
#     never-yet-created case -- and the pre/ backup that would be
#     destroyed by a wrong "already at PRE" verdict is exactly the
#     durable record that only exists in this branch.
recovery_probe_live_target() {
  rp_root=$1
  rp_path=$2
  rp_journal_pre=$3
  if [ "$rp_journal_pre" = "ABSENT" ]; then
    pre_hash_of_live_target "$rp_root" "$rp_path" "tolerate-not-found"
  else
    pre_hash_of_live_target "$rp_root" "$rp_path"
  fi
}

# backup_pre_bytes <repo_root_abs> <relpath> <dest_file> -- if the live
# target currently exists (and is not a symlink), copies its bytes
# byte-exact to <dest_file>, EVEN IF the target is legitimately a
# zero-byte file (quality-gate seq0357 Critical: the previous
# `[ ! -s "$dest_file" ] && rm -f` heuristic could not distinguish "no
# backup was produced" from "a genuine empty-file backup was produced",
# deleting a legitimate zero-byte backup and leaving `revert_one_target`
# permanently unable to restore it -- a standing mixed state and a
# permanently bricked publisher, exactly what AC-033/design.md:1056-1063
# forbid). The subshell below signals "found" (exit 0, possibly zero
# bytes of output) vs. "not found" (any nonzero exit) explicitly, so the
# decision to keep or remove <dest_file> is never inferred from its size.
# No-op (removes any placeholder) if absent.
backup_pre_bytes() {
  repo_root_abs=$1
  relpath=$2
  dest_file=$3
  split_dir_base "$relpath"
  (
    cd -- "$repo_root_abs" 2>/dev/null || exit 1
    walk_relative_dir "$SPLIT_DIR" || exit 1
    if [ -f "$SPLIT_BASE" ] && [ ! -L "$SPLIT_BASE" ]; then
      cat -- "$SPLIT_BASE"
      exit 0
    fi
    exit 9
  ) >"$dest_file" 2>/dev/null
  found_rc=$?
  if [ "$found_rc" != 0 ]; then
    rm -f -- "$dest_file" 2>/dev/null
  else
    # Capture the live target's PRE-transaction permission bits onto the
    # backup, so a MIX-state rollback restores mode as well as bytes
    # (fully-reverted must be faithful in both). Read through the same
    # anchored walk as the byte read above; on any failure the backup is
    # discarded (fail closed -- revert will then refuse on the missing
    # backup rather than restore with a fabricated mode).
    live_mode=$(
      cd -- "$repo_root_abs" 2>/dev/null || exit 1
      walk_relative_dir "$SPLIT_DIR" || exit 1
      file_mode_of "$SPLIT_BASE"
    )
    # NOTE: no `--` before $dest_file here (unlike this file's other
    # commands): verified empirically that BSD/macOS chmod, UNLIKE GNU
    # chmod (and unlike BSD's own rm/mv/cat, which all support `--`
    # correctly), does NOT treat `--` as an end-of-options marker -- it
    # is parsed as a literal (nonexistent) file OPERAND, so
    # `chmod MODE -- $dest_file` silently chmods $dest_file correctly
    # but still EXITS NONZERO (failing on the bogus `--` operand), which
    # would make this fail-closed check wrongly delete a backup it had
    # just correctly written. Safe to omit here because $dest_file is
    # always `$BATCH_DIR_ABS/pre/$base` -- always absolute (prefixed by
    # a `pwd -P`-derived batch directory) and therefore can never begin
    # with `-` regardless of $base's own leading character.
    if [ -z "$live_mode" ] || ! chmod "$live_mode" "$dest_file" 2>/dev/null; then
      rm -f -- "$dest_file" 2>/dev/null
    fi
  fi
}

# revert_one_target <repo_root_abs> <relpath> <pre_hash> <backup_file>
# Restores <relpath> to its PRE-transaction bytes AND mode: deletes it if
# pre_hash is ABSENT, else atomically renames <backup_file> onto it
# (same anchored-write discipline as publish_one_target), first chmod-ing
# the temp file to the backup's own captured PRE-transaction permission
# bits (backup_pre_bytes populated them onto the backup file itself).
revert_one_target() {
  repo_root_abs=$1
  relpath=$2
  pre_hash=$3
  backup_file=$4
  split_dir_base "$relpath"
  (
    cd -- "$repo_root_abs" || exit 1
    walk_relative_dir "$SPLIT_DIR" || exit 2
    if [ "$pre_hash" = "ABSENT" ]; then
      if [ -e "$SPLIT_BASE" ] && [ ! -L "$SPLIT_BASE" ]; then
        rm -f -- "$SPLIT_BASE" || exit 3
      fi
      exit 0
    fi
    [ -f "$backup_file" ] || exit 4
    tmp=$(mktemp ".apply-human-copy.revert.XXXXXX" 2>/dev/null) || exit 5
    cat -- "$backup_file" >"$tmp" || { rm -f -- "$tmp"; exit 6; }
    got=$(sha256_of "$tmp")
    if [ "$got" != "$pre_hash" ]; then rm -f -- "$tmp"; exit 7; fi
    # Restore the PRE-transaction permission bits captured on the backup
    # (backup_pre_bytes) along with the bytes.
    backup_mode=$(file_mode_of "$backup_file") || { rm -f -- "$tmp"; exit 9; }
    if ! chmod "$backup_mode" "$tmp" 2>/dev/null; then rm -f -- "$tmp"; exit 10; fi
    mv -f -- "$tmp" "$SPLIT_BASE" || exit 8
  )
}

# ---------------------------------------------------------------------------
# Journal (TRANSACTION.json) I/O.
#
# Shape (registered carry-forward obligation 1, T-005 relay):
#   {"schema":"sdd-human-copy-transaction/v1","nonce":"<hex>",
#    "status":"in-progress",
#    "targets":[{"live_path":"...","pre_hash":"...","post_hash":"..."}]}
# ---------------------------------------------------------------------------

write_journal() {
  # write_journal <batch_dir_abs> <nonce> <targets_file>
  # <targets_file> has one FIXED-WIDTH "target record" per line
  # (write_target_record's own format, above -- quality-gate seq0358:
  # NEVER read via IFS field-splitting, since a live_path may legitimately
  # contain whitespace). Writes TRANSACTION.json via temp+rehash+atomic-
  # rename (itself all-or-nothing, design.md).
  batch_dir_abs=$1
  nonce=$2
  targets_file=$3

  body="{\"schema\":\"sdd-human-copy-transaction/v1\",\"nonce\":\"$(json_escape "$nonce")\",\"status\":\"in-progress\",\"targets\":["
  first=1
  while IFS= read -r target_line || [ -n "$target_line" ]; do
    [ -n "$target_line" ] || continue
    parse_target_record "$target_line"
    lp=$TR_PATH; ph=$TR_PRE; qh=$TR_POST
    [ -n "$lp" ] || continue
    if [ "$first" = "1" ]; then first=0; else body="$body,"; fi
    body="$body{\"live_path\":\"$(json_escape "$lp")\",\"pre_hash\":\"$(json_escape "$ph")\",\"post_hash\":\"$(json_escape "$qh")\"}"
  done <"$targets_file"
  body="$body]}"

  (
    cd -- "$batch_dir_abs" || exit 1
    tmp=$(mktemp ".TRANSACTION.json.XXXXXX") || exit 2
    printf '%s\n' "$body" >"$tmp" || { rm -f "$tmp"; exit 3; }
    # quality-gate seq0359 Minor (authorized fix): round-trip-verify the
    # temp file's own bytes before the rename, matching design.md:1020-
    # 1022's "temp-then-rehash-then-atomic-rename" discipline the .ps1
    # twin already performs (Write-Journal's own round-trip read-back).
    written=$(sha256_of "$tmp")
    roundtrip=$(cat -- "$tmp")
    if [ -z "$written" ] || [ "$roundtrip" != "$body" ]; then
      rm -f -- "$tmp"
      exit 5
    fi
    mv -f -- "$tmp" TRANSACTION.json || exit 4
  )
}

# json_get_targets <journal_file> -- validates SHAPE strictly (fail
# closed on any deviation, carry-forward obligation 2: a journal that is
# valid JSON but lacks/mis-shapes `targets` is REJECTED, never silently
# treated as "no journal"). On success prints one write_target_record-
# shaped fixed-width record (above) per target to stdout, preserving
# live_path verbatim including any whitespace it may legitimately contain
# (quality-gate seq0358), and returns 0. On a shape violation, prints
# nothing and returns 1 (an UNREADABLE/unparsable file also returns 1 --
# caller treats both identically: fail closed, never proceed).
#
# quality-gate seq0359 (Critical x2): the PRIOR implementation used
# `sed -n 's/.*"live_path":"\([^"]*\)".*/\1/p'` and a naive "split on
# `},{`" character scan -- NEITHER understands JSON string escaping, so
# (C1) a live_path containing `"` or `\` (which json_escape, above,
# legitimately produces escaped forms of) was silently mis-decoded to the
# WRONG string, and (C2) a live_path containing a literal `}` broke the
# object-boundary scan, causing the tool to reject its OWN well-formed
# journal. This is a genuine, repeated failure CLASS (round 1: a
# byte-count heuristic; round 2: `read`-based IFS field-splitting; round
# 3: a non-JSON-aware hand-rolled parser) -- each prior fix solved one
# character/mechanism at a time rather than the underlying pattern
# ("home-grown parsing that does not understand the full expressiveness
# of the format it's reading"). This round replaces the reader with a
# real JSON-STRING-AWARE parser (implemented in awk, since sed cannot
# express the required backtracking/state): it walks the journal
# character-by-character, correctly treats `{`/`}`/`,`/`"` occurring
# INSIDE a properly-parsed string value as ordinary string content (never
# structural), and correctly reverses every escape json_escape's CLOSED
# emit set can produce (`\\` -> `\`, `\"` -> `"`) plus the standard JSON
# escapes generally (`\/`, `\n`, `\t`, `\r`, `\b`, `\f`, `\uXXXX` for the
# ASCII range) for defense-in-depth against a hand-edited or
# differently-produced journal. Any character genuinely outside JSON's
# own string grammar (an unterminated string, a missing key, a
# non-object array element, etc.) is a parse failure -- fail closed,
# exactly as before.
json_get_targets() {
  jf=$1
  [ -f "$jf" ] || return 1
  awk '
    function zsentinel(   i, s) {
      s = ""
      for (i = 0; i < 64; i++) s = s "z"
      return s
    }
    # hex2dec(h): portable 4-hex-digit -> decimal conversion for \uXXXX
    # decoding. quality-gate seq0360: the PRIOR implementation used
    # strtonum("0x" hex), a GAWK EXTENSION not part of POSIX awk -- macOS
    # own default /usr/bin/awk (the "one true awk"/BWK awk, NOT gawk) has
    # no such builtin, so this whole function silently hard-crashed
    # ("calling undefined function strtonum", awk exit 2) the FIRST time
    # any \uXXXX escape actually reached this code path at runtime. This
    # was LATENT since it was first written (quality-gate seq0359):
    # json_escape never itself emitted a \uXXXX sequence back then, so
    # nothing ever exercised this function end-to-end until the seq0360
    # json_escape fix started generically emitting \u00XX for C0 control
    # bytes. Implemented here using only POSIX-standard awk
    # builtins (length/substr/tolower/index), portable across the BWK
    # awk, gawk, and mawk this tool must run under.
    function hex2dec(h,   i, c, v, digits) {
      digits = "0123456789abcdef"
      v = 0
      for (i = 1; i <= length(h); i++) {
        c = tolower(substr(h, i, 1))
        v = v * 16 + (index(digits, c) - 1)
      }
      return v
    }
    # parse_json_string(s, start): s is the whole content; start is the
    # index of the OPENING quote. Sets RES_VAL (decoded value) and
    # RES_NEXT (index just past the closing quote) on success; sets
    # PARSE_ERR=1 on an unterminated string.
    function parse_json_string(s, start,    i, n, c, out, nc, hex, cp) {
      n = length(s)
      i = start + 1
      out = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\"") { RES_VAL = out; RES_NEXT = i + 1; return }
        if (c == "\\") {
          nc = substr(s, i + 1, 1)
          if (nc == "\"") { out = out "\""; i += 2 }
          else if (nc == "\\") { out = out "\\"; i += 2 }
          else if (nc == "/") { out = out "/"; i += 2 }
          else if (nc == "n") { out = out "\n"; i += 2 }
          else if (nc == "t") { out = out "\t"; i += 2 }
          else if (nc == "r") { out = out "\r"; i += 2 }
          else if (nc == "b") { out = out "\b"; i += 2 }
          else if (nc == "f") { out = out "\f"; i += 2 }
          else if (nc == "u") {
            # quality-gate seq0360 Major #1: this decoder previously
            # restricted \uXXXX to PRINTABLE ASCII (32-126), substituting
            # "?" for anything outside that range. The json_escape fix
            # now GENERICALLY emits \u00XX for every C0 control byte NOT
            # covered by a named escape (1-7, 11, 14-31) -- the prior
            # restriction silently corrupted every one of those bytes
            # back to "?" on decode, breaking the round-trip fidelity of
            # the journal for exactly the class this remedy exists to
            # fix. Decoded for the FULL single-byte range (0-255) that
            # this encoder can ever produce; sprintf with %c is
            # byte-exact in the C-locale awk invocation this function
            # always runs under.
            hex = substr(s, i + 2, 4)
            cp = hex2dec(hex)
            if (cp >= 0 && cp <= 255) { out = out sprintf("%c", cp) }
            else { out = out "?" }
            i += 6
          }
          else { out = out nc; i += 2 }
          continue
        }
        out = out c
        i += 1
      }
      PARSE_ERR = 1
    }
    # skip_seps(s, p, n): index of the first character at or after p that
    # is not a space, comma, or newline (past n when none remains) -- the
    # inter-value separator skip the array and object loops previously
    # each inlined.
    function skip_seps(s, p, n,   ch) {
      while (p <= n) {
        ch = substr(s, p, 1)
        if (ch == " " || ch == "," || ch == "\n") { p++; continue }
        break
      }
      return p
    }
    # parse_quoted(s, p, n): parse one JSON string whose OPENING quote
    # must sit at index p; RES_VAL/RES_NEXT via parse_json_string. Any
    # malformation (not a quote, unterminated) is a parse failure of the
    # whole journal -- exit 1, fail closed, exactly as the previous
    # inline checks did (exit inside a function called from END
    # terminates the program with that status, the same control flow).
    function parse_quoted(s, p, n) {
      if (substr(s, p, 1) != "\"") { exit 1 }
      PARSE_ERR = 0
      parse_json_string(s, p)
      if (PARSE_ERR) { exit 1 }
    }
    # parse_target_object(s, p, n): p is just past a target object
    # opening "{". Parses "key": "value" members until the closing "}",
    # following the established parse_json_string global-channel idiom:
    # sets OBJ_LIVE/OBJ_PRE/OBJ_POST with HAVE_LIVE/HAVE_PRE/HAVE_POST
    # presence flags, and RES_NEXT (just past the closing brace).
    # Malformed members exit 1 through parse_quoted / the shape checks.
    function parse_target_object(s, p, n,   ch, key) {
      OBJ_LIVE = ""; OBJ_PRE = ""; OBJ_POST = ""
      HAVE_LIVE = 0; HAVE_PRE = 0; HAVE_POST = 0
      for (;;) {
        p = skip_seps(s, p, n)
        if (p > n) { exit 1 }
        ch = substr(s, p, 1)
        if (ch == "}") { RES_NEXT = p + 1; return }
        parse_quoted(s, p, n)
        key = RES_VAL
        p = RES_NEXT
        while (p <= n && substr(s, p, 1) != ":") p++
        if (p > n) { exit 1 }
        p++
        while (p <= n && substr(s, p, 1) == " ") p++
        parse_quoted(s, p, n)
        p = RES_NEXT
        if (key == "live_path") { OBJ_LIVE = RES_VAL; HAVE_LIVE = 1 }
        else if (key == "pre_hash") { OBJ_PRE = RES_VAL; HAVE_PRE = 1 }
        else if (key == "post_hash") { OBJ_POST = RES_VAL; HAVE_POST = 1 }
      }
    }
    { content = content $0 "\n" }
    END {
      n = length(content)
      ZS = zsentinel()
      tidx = index(content, "\"targets\"")
      if (tidx == 0) { exit 1 }
      p = tidx + length("\"targets\"")
      while (p <= n && substr(content, p, 1) != ":") p++
      p++
      while (p <= n && substr(content, p, 1) == " ") p++
      if (substr(content, p, 1) != "[") { exit 1 }
      p++
      count = 0
      for (;;) {
        p = skip_seps(content, p, n)
        if (p > n) { exit 1 }
        ch = substr(content, p, 1)
        if (ch == "]") { p++; break }
        if (ch != "{") { exit 1 }
        parse_target_object(content, p + 1, n)
        p = RES_NEXT
        if (!HAVE_LIVE || !HAVE_PRE || !HAVE_POST || OBJ_LIVE == "" || OBJ_PRE == "" || OBJ_POST == "") { exit 1 }
        pre_enc = (OBJ_PRE == "ABSENT") ? ZS : OBJ_PRE
        post_enc = (OBJ_POST == "ABSENT") ? ZS : OBJ_POST
        printf "%s%s %s\n", pre_enc, post_enc, OBJ_LIVE
        count++
      }
      if (count == 0) { exit 1 }
      exit 0
    }
  ' "$jf" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Crash recovery (runs at the START of every invocation).
# ---------------------------------------------------------------------------

# target_at_pre <recorded-pre-hash> <current-probe-value> -> rc 0 when the
# current live state matches the journal's recorded pre-transaction state
# (including the both-ABSENT case), rc 1 otherwise. One definition for the
# match rule the classify and confirm passes previously each spelled out.
target_at_pre() {
  if [ "$1" = "ABSENT" ] && [ "$2" = "ABSENT" ]; then return 0; fi
  if [ "$1" != "ABSENT" ] && [ "$2" = "$1" ]; then return 0; fi
  return 1
}

# probe_or_die <repo_root_abs> <live_path> <recorded-pre-hash> <context>
#   Probes one live target and sets the global PROBE_CUR (never a
#   command-substitution return value -- die() below MUST terminate the
#   real top-level process, so callers MUST invoke this directly, never as
#   X=$(probe_or_die ...)). recovery_probe_live_target() decides what a
#   plainly-missing chain means from the JOURNAL's own recorded pre_hash
#   for THIS target -- never from the probe result alone (seq0360
#   Critical) and never by refusing every absence (seq0361 Critical). See
#   its header for the full design derivation. Any undeterminable state
#   (rc 2: a non-regular entry whose bytes cannot be hashed, external
#   review PR #229; other nonzero: an unwalkable destination-parent
#   chain) dies fail-closed with <context>'s exact message, after
#   removing the pass's temp file -- journal and backups are retained so
#   the NEXT invocation gets another chance. <context> is one of
#   classify | revert | confirm; reads the globals batch_dir_abs and
#   targets_tmp.
probe_or_die() {
  pod_root=$1
  pod_lp=$2
  pod_ph=$3
  pod_ctx=$4
  PROBE_CUR=$(recovery_probe_live_target "$pod_root" "$pod_lp" "$pod_ph")
  pod_rc=$?
  if [ "$pod_rc" = 2 ]; then
    rm -f "$targets_tmp"
    case "$pod_ctx" in
      classify)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "recovery found a NON-REGULAR entry (a symlink, directory, fifo, or other non-file) occupying target '$pod_lp' in batch $batch_dir_abs; its bytes cannot be hashed, so this target's state is UNDETERMINED and must never be read as 'confirmed absent' (external review PR #229); refusing to proceed, journal and backups retained (fail-closed)" ;;
      revert)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "recovery found a NON-REGULAR entry (a symlink, directory, fifo, or other non-file) occupying target '$pod_lp' in batch $batch_dir_abs before deciding whether to revert it; its bytes cannot be hashed, so this target's state is UNDETERMINED and must never be read as 'confirmed absent' (external review PR #229); refusing to proceed, journal and backups retained (fail-closed)" ;;
      confirm)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "post-revert confirmation found a NON-REGULAR entry (a symlink, directory, fifo, or other non-file) occupying target '$pod_lp' in batch $batch_dir_abs; its bytes cannot be hashed, so it can never be CONFIRMED back at PRE (external review PR #229); refusing to delete the journal (fail-closed, design.md:1055-1056)" ;;
    esac
  fi
  if [ "$pod_rc" != 0 ]; then
    rm -f "$targets_tmp"
    case "$pod_ctx" in
      classify)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "recovery could not determine the current live state of target '$pod_lp' in batch $batch_dir_abs (its destination-parent chain could not be safely walked -- possibly replaced, renamed, or made inaccessible since the crash); refusing to proceed, journal and backups retained (fail-closed, never coerced to ABSENT)" ;;
      revert)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "recovery could not determine the current live state of target '$pod_lp' in batch $batch_dir_abs before deciding whether to revert it; refusing to proceed, journal and backups retained (fail-closed, never coerced to ABSENT)" ;;
      confirm)
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "post-revert confirmation could not determine the current live state of target '$pod_lp' in batch $batch_dir_abs; refusing to delete the journal (fail-closed, design.md:1055-1056)" ;;
    esac
  fi
}

# classify_batch: pass 1 of a batch's recovery. Probes every journal
# target and sets the globals CLASSIFY_ALL_POST / CLASSIFY_ALL_PRE (never
# command-substitution return values -- probe_or_die dies through this
# frame). The batch is a 3-state machine: ALL-POST (the transaction
# completed; keep the post state), ALL-PRE (it never touched a target;
# nothing to undo), or MIXED (revert then confirm). Reads targets_tmp via
# input redirection -- `cmd | while` would put the loop in a subshell and
# strand both the globals and die()'s exit.
classify_batch() {
  CLASSIFY_ALL_POST=1
  CLASSIFY_ALL_PRE=1
  while IFS= read -r target_line || [ -n "$target_line" ]; do
    [ -n "$target_line" ] || continue
    parse_target_record "$target_line"
    lp=$TR_PATH; ph=$TR_PRE; qh=$TR_POST
    [ -n "$lp" ] || continue
    probe_or_die "$repo_root_abs" "$lp" "$ph" classify
    if [ "$PROBE_CUR" != "$qh" ]; then CLASSIFY_ALL_POST=0; fi
    if ! target_at_pre "$ph" "$PROBE_CUR"; then CLASSIFY_ALL_PRE=0; fi
  done <"$targets_tmp"
}

# revert_mixed_batch: pass 2, MIXED batches only -- revert every target
# currently at POST back to PRE. Re-probes each target rather than
# trusting pass 1's answers (the filesystem may have moved between
# passes; the .ps1 twin deliberately differs here and reuses its
# classify-pass probes). Honors the revert-<idx> crash-stage hook.
revert_mixed_batch() {
  idx=0
  while IFS= read -r target_line || [ -n "$target_line" ]; do
    [ -n "$target_line" ] || continue
    parse_target_record "$target_line"
    lp=$TR_PATH; ph=$TR_PRE; qh=$TR_POST
    [ -n "$lp" ] || continue
    idx=$((idx + 1))
    probe_or_die "$repo_root_abs" "$lp" "$ph" revert
    if [ "$PROBE_CUR" = "$qh" ] && [ "$PROBE_CUR" != "$ph" ]; then
      base=$(basename "$lp")
      backup="${batch_dir_abs}/pre/${base}"
      if ! revert_one_target "$repo_root_abs" "$lp" "$ph" "$backup"; then
        rm -f "$targets_tmp"
        die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
          "recovery could not revert target '$lp' to its pre-transaction state"
      fi
      if [ "$recovery_crash_stage" = "revert-$idx" ]; then
        rm -f "$targets_tmp"
        crash_now "recovery after reverting target $idx ($lp)"
      fi
    fi
  done <"$targets_tmp"
}

# confirm_all_at_pre: pass 3. design.md:1055-1056 MANDATORY final
# confirmation (quality-gate seq0360 Critical remedy, requirement 2):
# "for every target still at its POST hash, until every target is
# confirmed back at PRE. Only then is the journal deleted." This is a
# DISTINCT re-probe pass -- never inferred from revert_one_target's own
# return value alone. Any probe failure, or any target NOT confirmed at
# PRE here, is fail-closed: the journal and backups are retained rather
# than deleted, so the NEXT invocation gets another chance once whatever
# blocked the probe (or the revert) is resolved.
confirm_all_at_pre() {
  while IFS= read -r target_line || [ -n "$target_line" ]; do
    [ -n "$target_line" ] || continue
    parse_target_record "$target_line"
    lp=$TR_PATH; ph=$TR_PRE
    [ -n "$lp" ] || continue
    probe_or_die "$repo_root_abs" "$lp" "$ph" confirm
    if ! target_at_pre "$ph" "$PROBE_CUR"; then
      rm -f "$targets_tmp"
      die "$EXIT_RECOVERY_FAILED" RECOVERY_FAILED \
        "post-revert confirmation failed for target '$lp' in batch $batch_dir_abs: its current live state does not match the journal's recorded pre-transaction hash; refusing to delete the journal (fail-closed, design.md:1055-1056)"
    fi
  done <"$targets_tmp"
}

# finalize_recovered_batch <journal-path> <pre-backup-dir>: the one
# success exit for a batch -- delete the journal (the commit point:
# recovery never re-runs for this batch), drop the pre/ backups, count
# it, and release the pass temp file.
finalize_recovered_batch() {
  rm -f -- "$1"
  rm -rf -- "$2" 2>/dev/null
  recovered=$((recovered + 1))
  rm -f "$targets_tmp"
}

recover_all() {
  # Sets the global RECOVERED (never a command-substitution return value):
  # this function (via probe_or_die and the pass helpers above) calls
  # die()/crash_now() directly, which MUST terminate the real top-level
  # process on a fail-closed shape violation or a simulated crash --
  # running it inside `$( ... )` would only terminate a throwaway
  # subshell and let the caller silently continue, exactly the fail-open
  # class of bug carry-forward obligation 2 exists to prevent. Callers
  # MUST invoke this directly, never as `X=$(recover_all ...)`; the same
  # rule binds every helper above.
  repo_root_abs=$1
  recovery_crash_stage=${2:-}
  recovered=0
  RECOVERED=0
  if [ ! -d sdd/.staging ]; then
    RECOVERED=0
    return 0
  fi
  for batch_dir in sdd/.staging/*/; do
    [ -d "$batch_dir" ] || continue
    jf="${batch_dir}TRANSACTION.json"
    [ -f "$jf" ] || continue
    batch_dir_abs=$(cd -- "$batch_dir" && pwd -P)

    targets_tmp=$(mktemp "${TMPDIR:-/tmp}/ahc-recover-targets.XXXXXX")
    if ! json_get_targets "$jf" >"$targets_tmp"; then
      rm -f "$targets_tmp"
      die "$EXIT_JOURNAL_SHAPE_INVALID" JOURNAL_SHAPE_INVALID \
        "a human-copy transaction journal exists at '$jf' but is not valid JSON or does not conform to the required targets[]={live_path,pre_hash,post_hash} shape; refusing to proceed (fail-closed, never treated as absent)"
    fi

    classify_batch
    if [ "$CLASSIFY_ALL_POST" = 1 ] || [ "$CLASSIFY_ALL_PRE" = 1 ]; then
      finalize_recovered_batch "$jf" "${batch_dir}pre"
      continue
    fi

    revert_mixed_batch
    confirm_all_at_pre
    finalize_recovered_batch "$jf" "${batch_dir_abs}/pre"
  done
  RECOVERED=$recovered
  return 0
}

# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------

STAGING_DIR=""
MANIFEST=""
SIM_CRASH_AFTER=""
SIM_CRASH_RECOVERY_AFTER=""
SIM_SUBSTITUTE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --staging-dir) STAGING_DIR=$2; shift 2 ;;
    --manifest) MANIFEST=$2; shift 2 ;;
    --simulate-crash-after) SIM_CRASH_AFTER=$2; shift 2 ;;
    --simulate-crash-during-recovery-after) SIM_CRASH_RECOVERY_AFTER=$2; shift 2 ;;
    --simulate-substitution) SIM_SUBSTITUTE=1; shift ;;
    *)
      printf 'apply-human-copy: unrecognized argument: %s\n' "$1" >&2
      exit "$EXIT_USAGE_ERROR"
      ;;
  esac
done

REPO_ROOT_ABS=$(pwd -P)

RECOVERED=0
recover_all "$REPO_ROOT_ABS" "$SIM_CRASH_RECOVERY_AFTER"

if [ -z "$STAGING_DIR" ] || [ -z "$MANIFEST" ]; then
  emit_ok "\"recovered\":$RECOVERED,\"targets\":[]"
  exit "$EXIT_OK"
fi

[ -d "$STAGING_DIR" ] || die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
  "staging directory does not exist: $STAGING_DIR"
STAGING_DIR_ABS=$(cd -- "$STAGING_DIR" && pwd -P) || die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
  "staging directory could not be resolved: $STAGING_DIR"

MANIFEST_LINES=$(mktemp "${TMPDIR:-/tmp}/ahc-manifest.XXXXXX")
parse_manifest "$MANIFEST" >"$MANIFEST_LINES"

# ---- PREPARE: rehash every staged candidate together; record pre_hash;
#      back up existing live bytes; deny on ANY problem before any write.
BATCH_NONCE=$(gen_nonce)
BATCH_DIR="sdd/.staging/$BATCH_NONCE"
mkdir -p -- "$BATCH_DIR/pre"
BATCH_DIR_ABS=$(cd -- "$BATCH_DIR" && pwd -P)

TARGETS_FILE=$(mktemp "${TMPDIR:-/tmp}/ahc-targets.XXXXXX")
: >"$TARGETS_FILE"
LIVEPATHS_FILE=$(mktemp "${TMPDIR:-/tmp}/ahc-livepaths.XXXXXX")
: >"$LIVEPATHS_FILE"

while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
  [ -n "$manifest_line" ] || continue
  # Fixed-column extraction (never `read`-based IFS field-splitting; see
  # parse_manifest's own header comment, quality-gate seq0358): hash is
  # cols 1-64, one literal separator space at col 65, path is cols 66-end
  # verbatim -- matches parse_manifest's own emitted "<hash> <path>" line
  # shape exactly.
  hash=$(printf '%s' "$manifest_line" | cut -c1-64)
  relpath=$(printf '%s' "$manifest_line" | cut -c66-)
  [ -n "$relpath" ] || continue
  split_dir_base "$relpath"
  # Verify the staged candidate exists, is not a symlink, and hashes to
  # the manifest's own claim -- via the SAME anchored traversal used at
  # publish time (closes the "validated one path, published a different
  # one" class of bug).
  staged_hash=$(
    cd -- "$STAGING_DIR_ABS" 2>/dev/null || exit 1
    walk_relative_dir "$SPLIT_DIR" || exit 2
    if [ -L "$SPLIT_BASE" ] || [ ! -f "$SPLIT_BASE" ]; then exit 3; fi
    sha256_of "$SPLIT_BASE"
  )
  rc=$?
  if [ $rc -ne 0 ] || [ -z "$staged_hash" ]; then
    rm -rf -- "$BATCH_DIR"
    die "$EXIT_PRE_EXISTING_SYMLINK_DENIED" PRE_EXISTING_SYMLINK_DENIED \
      "staged candidate for '$relpath' is missing, is a symlink, or is unreadable under $STAGING_DIR_ABS"
  fi
  if [ "$staged_hash" != "$hash" ]; then
    rm -rf -- "$BATCH_DIR"
    die "$EXIT_STAGED_CANDIDATE_HASH_MISMATCH" STAGED_CANDIDATE_HASH_MISMATCH \
      "staged candidate for '$relpath' does not match the manifest's recorded sha256 (got $staged_hash, want $hash)"
  fi

  # quality-gate seq0360 CRITICAL: this is the ONLY call site anywhere in
  # this file that passes "tolerate-not-found" -- it is the FIRST,
  # journal-free probe for this batch (nothing has been recorded yet, so
  # "the destination directory has simply never been created" is the
  # ordinary first-ever-publish case, not a threat). Any OTHER probe
  # failure (symlink, access-denied, blocked-by-a-file) is still fail-
  # closed here too, denying the whole batch BEFORE any journal is ever
  # written -- never silently proceeding with a guessed "ABSENT" that
  # could misrepresent hidden live content as absent and skip backing it
  # up.
  pre_hash=$(pre_hash_of_live_target "$REPO_ROOT_ABS" "$relpath" "tolerate-not-found")
  probe_rc=$?
  # rc 2 -- a non-regular entry occupies the target LEAF itself (external
  # review PR #229). Reported under the script's OWN existing category for
  # exactly this condition (EXIT_PRE_EXISTING_SYMLINK_DENIED, the same one
  # publish_one_target's `[ -L "$dest_base" ]` guard raises at commit time),
  # not merged into LIVE_PROBE_FAILED, whose message is specifically about
  # the destination-PARENT CHAIN. Denying here, inside PREPARE, is strictly
  # earlier and safer than the pre-fix behaviour, which recorded a bogus
  # pre_hash="ABSENT", skipped the backup, wrote a journal, and only then
  # let the commit-time guard refuse.
  if [ "$probe_rc" = 2 ]; then
    rm -rf -- "$BATCH_DIR"
    die "$EXIT_PRE_EXISTING_SYMLINK_DENIED" PRE_EXISTING_SYMLINK_DENIED \
      "a NON-REGULAR entry (a symlink, directory, fifo, or other non-file) already occupies live target '$relpath'; its bytes cannot be hashed, so its pre-transaction state can never be recorded or restored, and recording it as 'ABSENT' would misrepresent an undetermined state as a confirmed one; refusing to stage batch $BATCH_NONCE (fail-closed)"
  fi
  if [ "$probe_rc" != 0 ]; then
    rm -rf -- "$BATCH_DIR"
    die "$EXIT_LIVE_PROBE_FAILED" LIVE_PROBE_FAILED \
      "could not determine the current live state of target '$relpath' before staging batch $BATCH_NONCE (its destination-parent chain exists but could not be safely walked -- a symlink, access-denied directory, or a non-directory entry blocking the path); refusing to proceed (fail-closed, never coerced to ABSENT)"
  fi
  if [ "$pre_hash" != "ABSENT" ]; then
    base=$(basename "$relpath")
    # Backup-slot EXCLUSIVITY (quality-gate seq0361 Major #2, second line
    # of defence): parse_manifest's ASCII case fold cannot decide whether
    # THIS volume folds non-ASCII case (APFS does) or normalizes Unicode,
    # so the slot itself is the authority -- if the path this target's
    # backup would occupy is already taken by an earlier target in the
    # SAME batch, the filesystem has just told us the two basenames
    # collide, whatever its rules are. Refused here, still inside PREPARE
    # (before the journal exists and before any rename), so no live target
    # has been touched; reported under the SAME documented category as the
    # parse-time guard, since it is the same condition detected with the
    # filesystem's own answer instead of a static fold.
    if [ -e "$BATCH_DIR_ABS/pre/$base" ]; then
      rm -rf -- "$BATCH_DIR"
      die "$EXIT_DUPLICATE_BASENAME_IN_BATCH" DUPLICATE_BASENAME_IN_BATCH \
        "manifest target '$relpath' would reuse the pre-transaction backup slot 'pre/$base' already occupied by an earlier target in this batch (this filesystem treats the two basenames as the same name); the backup path is basename-keyed (design.md:1011) and cannot safely hold two colliding targets in one transaction"
    fi
    backup_pre_bytes "$REPO_ROOT_ABS" "$relpath" "$BATCH_DIR_ABS/pre/$base"
  fi
  write_target_record "$pre_hash" "$hash" "$relpath" >>"$TARGETS_FILE"
  printf '%s\n' "$relpath" >>"$LIVEPATHS_FILE"
done <"$MANIFEST_LINES"

if [ "$SIM_CRASH_AFTER" = "prepare" ]; then
  crash_now "after prepare, before journal write"
fi

# ---- JOURNAL: durable, atomic, BEFORE any rename. --------------------------
if ! write_journal "$BATCH_DIR_ABS" "$BATCH_NONCE" "$TARGETS_FILE"; then
  rm -rf -- "$BATCH_DIR"
  die "$EXIT_JOURNAL_WRITE_FAILED" JOURNAL_WRITE_FAILED \
    "could not write the transaction journal for batch $BATCH_NONCE"
fi

if [ "$SIM_CRASH_AFTER" = "journal-write" ]; then
  crash_now "after journal write, before first rename"
fi

# ---- COMMIT: atomic rename per target, in journal (=manifest) order. ------
idx=0
first_target=1
while IFS= read -r target_line || [ -n "$target_line" ]; do
  [ -n "$target_line" ] || continue
  parse_target_record "$target_line"
  relpath=$TR_PATH; pre_hash=$TR_PRE; post_hash=$TR_POST
  [ -n "$relpath" ] || continue
  idx=$((idx + 1))
  do_sub=0
  if [ "$SIM_SUBSTITUTE" = "1" ] && [ "$first_target" = "1" ]; then
    do_sub=1
  fi
  first_target=0
  if ! publish_one_target "$STAGING_DIR_ABS" "$relpath" "$post_hash" "$do_sub" "$REPO_ROOT_ABS"; then
    die "$EXIT_RENAME_FAILED" RENAME_FAILED \
      "publish failed for target '$relpath' (batch $BATCH_NONCE); journal retained at $BATCH_DIR_ABS/TRANSACTION.json for the next invocation's recovery scan"
  fi
  if [ "$SIM_CRASH_AFTER" = "rename-$idx" ]; then
    crash_now "after committing rename #$idx ($relpath)"
  fi
done <"$TARGETS_FILE"

# ---- COMPLETE: delete the journal. -----------------------------------------
rm -f -- "$BATCH_DIR_ABS/TRANSACTION.json"
rm -rf -- "$BATCH_DIR_ABS/pre" 2>/dev/null
rmdir -- "$BATCH_DIR_ABS" 2>/dev/null || true

applied_json="["
first=1
while IFS= read -r relpath || [ -n "$relpath" ]; do
  [ -n "$relpath" ] || continue
  if [ "$first" = "1" ]; then first=0; else applied_json="$applied_json,"; fi
  applied_json="$applied_json\"$(json_escape "$relpath")\""
done <"$LIVEPATHS_FILE"
applied_json="$applied_json]"

rm -f "$MANIFEST_LINES" "$TARGETS_FILE" "$LIVEPATHS_FILE"

emit_ok "\"recovered\":$RECOVERED,\"targets\":$applied_json"
exit "$EXIT_OK"
