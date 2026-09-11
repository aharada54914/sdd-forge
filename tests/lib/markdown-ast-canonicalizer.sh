#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
  printf 'usage: %s <markdown-file>\n' "${0##*/}" >&2
  exit 2
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/markdown-ast.XXXXXX")"
trap 'rm -rf "$work"' EXIT

if ! awk -v frontmatter="$work/frontmatter.tsv" -v headings="$work/headings.tsv" '
  function normalized(value) {
    gsub(/[ \t]+/, " ", value)
    sub(/^ /, "", value)
    sub(/ $/, "", value)
    return value
  }
  function invalid(message) {
    print "markdown AST parse failure: " message > "/dev/stderr"
    failed=1
    exit 2
  }
  {
    line=$0
    sub(/\r$/, "", line)
    if (NR == 1 && line == "---") {
      in_frontmatter=1
      saw_frontmatter=1
      next
    }
    if (in_frontmatter) {
      if (line == "---") {
        in_frontmatter=0
        closed_frontmatter=1
        next
      }
      if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) next
      if (line !~ /^[A-Za-z0-9_.-]+[ \t]*:/) invalid("malformed frontmatter entry at line " NR)
      key=line
      sub(/[ \t]*:.*/, "", key)
      value=line
      sub(/^[^:]*:/, "", value)
      value=normalized(value)
      if (seen_key[key]++) invalid("duplicate frontmatter key " key)
      print key "\t" value >> frontmatter
      next
    }
    if (line ~ /^#/) {
      hashes=line
      sub(/[^#].*$/, "", hashes)
      level=length(hashes)
      if (level < 1 || level > 6 || substr(line, level + 1, 1) !~ /[ \t]/) {
        invalid("unrecognized heading grammar at line " NR)
      }
      text=substr(line, level + 2)
      text=normalized(text)
      if (text == "") invalid("empty heading at line " NR)
      print level "\t" text >> headings
      next
    }
    stripped=line
    gsub(/^[ \t]+|[ \t]+$/, "", stripped)
    if (stripped ~ /^===+$/ || stripped ~ /^---+$/) invalid("setext heading grammar is unsupported at line " NR)
  }
  END {
    if (!failed && saw_frontmatter && (!closed_frontmatter || in_frontmatter)) {
      print "markdown AST parse failure: unterminated frontmatter" > "/dev/stderr"
      exit 2
    }
  }
' "$1"; then
  exit 2
fi

touch "$work/frontmatter.tsv" "$work/headings.tsv"
LC_ALL=C sort -o "$work/frontmatter.tsv" "$work/frontmatter.tsv"

frontmatter_json="$(jq -Rn '[inputs | select(length > 0) | capture("^(?<key>[^\\t]+)\\t(?<value>.*)$")]' < "$work/frontmatter.tsv")"
headings_json="$(jq -Rn '[inputs | select(length > 0) | capture("^(?<level>[0-9]+)\\t(?<text>.*)$") | .level |= tonumber]' < "$work/headings.tsv")"
jq -cn --argjson frontmatter "$frontmatter_json" --argjson headings "$headings_json" '{frontmatter: $frontmatter, headings: $headings}'
