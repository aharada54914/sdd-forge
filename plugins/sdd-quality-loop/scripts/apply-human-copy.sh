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
# path-based open" defect. An explicit `exec N<dir` file descriptor is
# ADDITIONALLY held on the repo root and on each target's destination
# parent for the duration of that target's operation, for identity
# pinning / defense-in-depth (its /dev/fd or /proc/self/fd projection is
# used, where available, to re-verify identity immediately before the
# atomic rename). Documented residual (never silently implied as fully
# closed): the narrow window between a segment's own `-L` check and its
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

# ---------------------------------------------------------------------------
# Small helpers.
# ---------------------------------------------------------------------------

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '
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
  # nonzero exit on failure.
  file=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" 2>/dev/null | awk '{print $1}'
  else
    shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}'
  fi
}

sha256_of_or_absent() {
  # sha256_of_or_absent <file> -> the file's sha256, or the literal
  # sentinel "ABSENT" if it does not exist (or is not a regular file).
  file=$1
  if [ -e "$file" ] && [ ! -L "$file" ] && [ -f "$file" ]; then
    sha256_of "$file"
  else
    printf 'ABSENT'
  fi
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
  else
    shasum -a 256 | awk '{print $1}'
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
walk_relative_dir() {
  relpath=$1
  create_mode=${2:-}
  [ -n "$relpath" ] || return 0
  case "$relpath" in
    /*) return 1 ;;
  esac
  oldifs=$IFS
  IFS='/'
  set -- $relpath
  IFS=$oldifs
  for seg in "$@"; do
    [ -n "$seg" ] || continue
    case "$seg" in
      .|..) return 1 ;;
    esac
    if [ -L "$seg" ]; then
      return 2
    fi
    if [ ! -e "$seg" ] && [ "$create_mode" = "create" ]; then
      mkdir -- "$seg" 2>/dev/null || [ -d "$seg" ] || return 3
    fi
    if [ -L "$seg" ]; then
      return 2
    fi
    if [ ! -d "$seg" ]; then
      return 3
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
  seen_paths=""
  seen_basenames=""
  line_no=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    [ -n "$line" ] || continue
    hash=$(printf '%s' "$line" | cut -c1-64)
    sep=$(printf '%s' "$line" | cut -c65-66)
    path=$(printf '%s' "$line" | cut -c67-)
    if ! is_hex64 "$hash" || [ "$sep" != "  " ] || [ -z "$path" ]; then
      die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest line $line_no is not '<64-hex-lowercase>  <path>': $manifest"
    fi
    case "$path" in
      /*|*..*) die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest line $line_no target is not a normalized repo-relative path: $path" ;;
    esac
    case " $seen_paths " in
      *" $path "*) die "$EXIT_MANIFEST_INVALID" MANIFEST_INVALID \
        "manifest lists target '$path' more than once" ;;
    esac
    seen_paths="$seen_paths $path"
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
    split_dir_base "$path"
    base=$SPLIT_BASE
    case " $seen_basenames " in
      *" $base "*) die "$EXIT_DUPLICATE_BASENAME_IN_BATCH" DUPLICATE_BASENAME_IN_BATCH \
        "manifest target '$path' shares basename '$base' with an earlier target in the same batch; the pre-transaction backup path is basename-keyed (design.md:1011) and cannot safely hold two colliding targets in one transaction" ;;
    esac
    seen_basenames="$seen_basenames $base"
    printf '%s %s\n' "$hash" "$path"
  done <"$manifest"
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

  # --- Anchor into the DESTINATION-PARENT side (held for this target's
  #     entire write+rename window, inside one subshell). ------------------
  (
    cd -- "$repo_root_abs" || exit 1
    walk_relative_dir "$dest_dir" create || exit 2
    dest_parent_id=$(stat_id .)
    exec 9<. 2>/dev/null || true

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

# pre_hash_of_live_target <repo_root_abs> <relpath> -- prints the CURRENT
# live sha256 (or ABSENT), anchored the same cwd-chain way, WITHOUT
# mutating the caller's cwd (runs in a subshell).
pre_hash_of_live_target() {
  repo_root_abs=$1
  relpath=$2
  split_dir_base "$relpath"
  result=$(
    cd -- "$repo_root_abs" 2>/dev/null || exit 1
    walk_relative_dir "$SPLIT_DIR" || exit 1
    sha256_of_or_absent "$SPLIT_BASE"
  )
  if [ -z "$result" ]; then
    printf 'ABSENT'
  else
    printf '%s' "$result"
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
  fi
}

# revert_one_target <repo_root_abs> <relpath> <pre_hash> <backup_file>
# Restores <relpath> to its PRE-transaction bytes: deletes it if
# pre_hash is ABSENT, else atomically renames <backup_file> onto it
# (same anchored-write discipline as publish_one_target).
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
  # <targets_file> has one "<live_path> <pre_hash> <post_hash>" line per
  # target (space-separated; live_path/hash never contain spaces by
  # construction -- repo-relative paths, hex or ABSENT). Writes
  # TRANSACTION.json via temp+rehash+atomic-rename (itself all-or-nothing,
  # design.md).
  batch_dir_abs=$1
  nonce=$2
  targets_file=$3

  body="{\"schema\":\"sdd-human-copy-transaction/v1\",\"nonce\":\"$(json_escape "$nonce")\",\"status\":\"in-progress\",\"targets\":["
  first=1
  while read -r lp ph qh; do
    [ -n "$lp" ] || continue
    if [ "$first" = "1" ]; then first=0; else body="$body,"; fi
    body="$body{\"live_path\":\"$(json_escape "$lp")\",\"pre_hash\":\"$(json_escape "$ph")\",\"post_hash\":\"$(json_escape "$qh")\"}"
  done <"$targets_file"
  body="$body]}"

  (
    cd -- "$batch_dir_abs" || exit 1
    tmp=$(mktemp ".TRANSACTION.json.XXXXXX") || exit 2
    printf '%s\n' "$body" >"$tmp" || { rm -f "$tmp"; exit 3; }
    mv -f -- "$tmp" TRANSACTION.json || exit 4
  )
}

# json_get_targets <journal_file> -- validates SHAPE strictly (fail
# closed on any deviation, carry-forward obligation 2: a journal that is
# valid JSON but lacks/mis-shapes `targets` is REJECTED, never silently
# treated as "no journal"). On success prints one
# "<live_path> <pre_hash> <post_hash>" line per target to stdout and
# returns 0. On a shape violation, prints nothing and returns 1 (an
# UNREADABLE/unparsable file also returns 1 -- caller treats both
# identically: fail closed, never proceed).
json_get_targets() {
  jf=$1
  [ -f "$jf" ] || return 1
  content=$(cat -- "$jf" 2>/dev/null) || return 1
  [ -n "$content" ] || return 1
  case "$content" in
    *'"targets"'*'['*']'*) : ;;
    *) return 1 ;;
  esac
  # Minimal, dependency-free structural extraction: one target object per
  # {...} group inside the targets array. Each MUST contain all three
  # required keys with string values -- anything else is a shape
  # violation (fail closed).
  arr=$(printf '%s' "$content" | sed -n 's/.*"targets":\[\(.*\)\].*/\1/p')
  [ -n "$arr" ] || return 1
  count=0
  ok=1
  # Split on "},{" boundaries (each target is a flat, single-level
  # object -- true for every journal THIS tool ever writes).
  rest=$arr
  while [ -n "$rest" ]; do
    case "$rest" in
      '{'*'}'*)
        obj=${rest#\{}
        obj=${obj%%\}*}
        lp=$(printf '%s' "$obj" | sed -n 's/.*"live_path":"\([^"]*\)".*/\1/p')
        ph=$(printf '%s' "$obj" | sed -n 's/.*"pre_hash":"\([^"]*\)".*/\1/p')
        qh=$(printf '%s' "$obj" | sed -n 's/.*"post_hash":"\([^"]*\)".*/\1/p')
        if [ -z "$lp" ] || [ -z "$ph" ] || [ -z "$qh" ]; then
          ok=0
          break
        fi
        printf '%s %s %s\n' "$lp" "$ph" "$qh"
        count=$((count + 1))
        after=${rest#*\}}
        case "$after" in
          ,*) rest=${after#,} ;;
          *) rest="" ;;
        esac
        ;;
      *) ok=0; break ;;
    esac
  done
  [ "$ok" = "1" ] && [ "$count" -gt 0 ]
}

# ---------------------------------------------------------------------------
# Crash recovery (runs at the START of every invocation).
# ---------------------------------------------------------------------------

recover_all() {
  # Sets the global RECOVERED (never a command-substitution return value):
  # this function calls die()/crash_now() directly, which MUST terminate
  # the real top-level process on a fail-closed shape violation or a
  # simulated crash -- running it inside `$( ... )` would only terminate
  # a throwaway subshell and let the caller silently continue, exactly
  # the fail-open class of bug carry-forward obligation 2 exists to
  # prevent. Callers MUST invoke this directly, never as `X=$(recover_all ...)`.
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

    all_post=1
    all_pre=1
    while read -r lp ph qh; do
      [ -n "$lp" ] || continue
      cur=$(pre_hash_of_live_target "$repo_root_abs" "$lp")
      if [ "$cur" != "$qh" ]; then all_post=0; fi
      pre_match=0
      if [ "$ph" = "ABSENT" ] && [ "$cur" = "ABSENT" ]; then pre_match=1; fi
      if [ "$ph" != "ABSENT" ] && [ "$cur" = "$ph" ]; then pre_match=1; fi
      if [ "$pre_match" = "0" ]; then all_pre=0; fi
    done <"$targets_tmp"

    if [ "$all_post" = "1" ]; then
      rm -f -- "$jf"
      rm -rf -- "${batch_dir}pre" 2>/dev/null
      recovered=$((recovered + 1))
      rm -f "$targets_tmp"
      continue
    fi
    if [ "$all_pre" = "1" ]; then
      rm -f -- "$jf"
      rm -rf -- "${batch_dir}pre" 2>/dev/null
      recovered=$((recovered + 1))
      rm -f "$targets_tmp"
      continue
    fi

    # MIXED: revert every target currently at POST back to PRE.
    idx=0
    while read -r lp ph qh; do
      [ -n "$lp" ] || continue
      idx=$((idx + 1))
      cur=$(pre_hash_of_live_target "$repo_root_abs" "$lp")
      if [ "$cur" = "$qh" ] && [ "$cur" != "$ph" ]; then
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
    rm -f -- "$jf"
    rm -rf -- "${batch_dir_abs}/pre" 2>/dev/null
    recovered=$((recovered + 1))
    rm -f "$targets_tmp"
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
exec 8<. 2>/dev/null || true

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

while read -r hash relpath; do
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

  pre_hash=$(pre_hash_of_live_target "$REPO_ROOT_ABS" "$relpath")
  if [ "$pre_hash" != "ABSENT" ]; then
    base=$(basename "$relpath")
    backup_pre_bytes "$REPO_ROOT_ABS" "$relpath" "$BATCH_DIR_ABS/pre/$base"
  fi
  printf '%s %s %s\n' "$relpath" "$pre_hash" "$hash" >>"$TARGETS_FILE"
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
while read -r relpath pre_hash post_hash; do
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
while read -r relpath; do
  [ -n "$relpath" ] || continue
  if [ "$first" = "1" ]; then first=0; else applied_json="$applied_json,"; fi
  applied_json="$applied_json\"$(json_escape "$relpath")\""
done <"$LIVEPATHS_FILE"
applied_json="$applied_json]"

rm -f "$MANIFEST_LINES" "$TARGETS_FILE" "$LIVEPATHS_FILE"

emit_ok "\"recovered\":$RECOVERED,\"targets\":$applied_json"
exit "$EXIT_OK"
