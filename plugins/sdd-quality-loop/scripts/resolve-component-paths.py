#!/usr/bin/env python3
"""Component path ownership resolver — Python master (INV-008 convention).

epic-191-a3-path-ownership T-001: implements REQ-001 (glob semantics,
normalization, schema conformance) and REQ-002 (exclusive/shared
classification, overlap/unowned detection, excluded-match evidence).

Usage (classification mode — T-001's own interim input surface; T-002 wraps
this with the real `git`-diff basis collector behind `--source-rev`/
`--target-rev`, which will supersede `--changed-paths-file` as the normal
entry point without removing it):

    resolve-component-paths.py --config <project-context.yaml> \\
        [--changed-paths-file <file, one raw path per line>] [--json]

    (omitting --changed-paths-file reads newline-separated raw paths from
    stdin)

Usage (schema-conformance mode, AC-011 — FAIL-closed on absence, never a
skip; this task's own Done state is gated on this fixture, see tasks.md):

    resolve-component-paths.py --check-schema-conformance \\
        [--schema <path, default contracts/project-context.template.yaml>]

Exit code 0 on a clean resolve (even with UNOWNED/OVERLAP results present in
the JSON output — classification results are data, not failure by
themselves; only check-component-coverage, T-004, turns a classification
into a Gate Fail). Non-zero exit on a config-shape error, an
unsupported-metacharacter pattern, or an NFC-collision (REQ-001); non-zero
in schema-conformance mode whenever the artifact is absent or divergent
(AC-011).

This module must NOT import from outside the standard library so it runs in
any Python 3.6+ environment without additional packages — this repository's
CI installs no Python packages for its gate scripts (check-contract.py sets
the same precedent), so a YAML library such as PyYAML is unavailable. The
restricted YAML-subset parser below is a deliberate, bounded implementation
choice (mirroring this repository's existing restricted-DSL philosophy,
ADR-0020 / ADR-0025), not a general YAML 1.2 implementation — it will be
re-validated against Epic A1's own canonical schema once that artifact
lands (the schema-conformance fixture above).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
from typing import Dict, List, Optional, Tuple

SCHEMA_ARTIFACT_PATH = "contracts/project-context.template.yaml"
MATCHER_SEMANTICS_VERSION = "1.0.0"

# Characters the restricted glob DSL never supports (REQ-001: "?" and
# "[...]" and every other glob metacharacter, and regex, and dynamic code
# are explicitly unsupported). "*" and "/" are handled specially and
# excluded from this rejection set; everything else that is a plausible
# glob/regex metacharacter is rejected fail-closed at load time (AC-006).
_UNSUPPORTED_METACHARS = set("?[]{}()!+@^$|~")


class ConfigError(ValueError):
    """A fail-closed configuration-shape error (REQ-001/REQ-002 fail-closed
    clauses). Always propagates to a non-zero exit with a diagnostic —
    never caught and silently downgraded."""


class CollisionError(ValueError):
    """Two distinct raw paths NFC-normalize to the same comparison key
    (AC-010). Fail-closed: never silently merged, dropped, or arbitrarily
    picked."""


# --------------------------------------------------------------------------
# Minimal restricted YAML-subset parser
# --------------------------------------------------------------------------
#
# Supports exactly what this feature's config shape needs:
#   - block mappings ("key: value" / "key:" + nested indented block)
#   - block sequences ("- item" / "- key: value" inline-mapping-start)
#   - scalar strings, optionally single- or double-quoted
#   - "#" starts a line comment when not inside a quoted scalar
#
# Deliberately NOT supported (and never silently guessed at): flow style
# ([a, b] / {a: b}), anchors/aliases, multi-document streams, block scalars
# (| / >), tags. Any of these appearing in a config is a fail-closed
# ConfigError, not a best-effort interpretation.


def _strip_comment(line: str) -> str:
    in_single = False
    in_double = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            if i == 0 or line[i - 1] in (" ", "\t"):
                return line[:i]
    return line


def _parse_scalar(raw: str) -> str:
    s = raw.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
        return s[1:-1]
    for forbidden in ("[", "]", "{", "}", "&", "*", "!", "|", ">", "%", "@", "`"):
        # A bare leading sigil is real YAML's flow/anchor/alias/tag syntax.
        # This restricted parser rejects it fail-closed rather than
        # mis-interpreting it (glob patterns that legitimately start with
        # "*" must be quoted, e.g. "*.ts").
        if s.startswith(forbidden):
            raise ConfigError(
                f"unsupported YAML construct at start of scalar: {raw!r} "
                f"(quote glob patterns beginning with '{forbidden}')"
            )
    return s


def _indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


class _Lines:
    def __init__(self, text: str):
        raw_lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        self.lines: List[Tuple[int, str]] = []
        for raw in raw_lines:
            stripped = _strip_comment(raw).rstrip()
            if stripped.strip() == "":
                continue
            if "\t" in raw[: _indent_of(raw)]:
                raise ConfigError("YAML indentation must use spaces, not tabs")
            self.lines.append((_indent_of(stripped), stripped.strip()))
        self.pos = 0

    def peek(self) -> Optional[Tuple[int, str]]:
        if self.pos >= len(self.lines):
            return None
        return self.lines[self.pos]

    def advance(self) -> Tuple[int, str]:
        item = self.lines[self.pos]
        self.pos += 1
        return item


def _parse_block(lines: "_Lines", indent: int):
    """Parse a block (mapping or sequence) whose entries sit at exactly
    `indent`. Returns a dict or list."""
    peeked = lines.peek()
    if peeked is None:
        return {}
    first_indent, first_content = peeked
    if first_indent != indent:
        raise ConfigError(f"unexpected indentation at: {first_content!r}")
    if first_content.startswith("- "):
        return _parse_sequence(lines, indent)
    return _parse_mapping(lines, indent)


def _parse_sequence(lines: "_Lines", indent: int) -> list:
    items: list = []
    while True:
        peeked = lines.peek()
        if peeked is None or peeked[0] != indent or not peeked[1].startswith("-"):
            break
        _, content = lines.advance()
        rest = content[1:].lstrip() if content != "-" else ""
        if rest == "":
            nxt = lines.peek()
            if nxt is None or nxt[0] <= indent:
                items.append(None)
                continue
            items.append(_parse_block(lines, nxt[0]))
            continue
        if _looks_like_mapping_entry(rest):
            # "- key: value" starts an inline mapping; subsequent
            # more-indented "key: value" lines (at the column right after
            # "- ") continue the same mapping entry.
            after_dash_col = indent + (content.index(rest[0]) if rest else 2)
            entry = _parse_inline_mapping_entry(lines, rest, after_dash_col)
            items.append(entry)
            continue
        items.append(_parse_scalar(rest))
    return items


def _looks_like_mapping_entry(s: str) -> bool:
    # A colon followed by a space or end-of-string marks a mapping key,
    # distinct from a colon inside an unquoted scalar (paths never contain
    # ": " in this feature's fixtures).
    idx = s.find(":")
    if idx == -1:
        return False
    return idx == len(s) - 1 or s[idx + 1] == " "


def _parse_inline_mapping_entry(lines: "_Lines", first_rest: str, key_col: int) -> dict:
    result: Dict[str, object] = {}
    key, _, value = first_rest.partition(":")
    key = key.strip()
    value = value.strip()
    if value == "":
        nxt = lines.peek()
        if nxt is not None and nxt[0] > key_col:
            result[key] = _parse_block(lines, nxt[0])
        else:
            result[key] = None
    else:
        result[key] = _parse_scalar(value)
    while True:
        nxt = lines.peek()
        if nxt is None or nxt[0] != key_col:
            break
        _, content = lines.advance()
        if not _looks_like_mapping_entry(content):
            raise ConfigError(f"expected 'key: value' inside list item, got: {content!r}")
        k, _, v = content.partition(":")
        k = k.strip()
        v = v.strip()
        if v == "":
            nxt2 = lines.peek()
            if nxt2 is not None and nxt2[0] > key_col:
                result[k] = _parse_block(lines, nxt2[0])
            else:
                result[k] = None
        else:
            result[k] = _parse_scalar(v)
    return result


def _parse_mapping(lines: "_Lines", indent: int) -> dict:
    result: Dict[str, object] = {}
    while True:
        peeked = lines.peek()
        if peeked is None or peeked[0] != indent:
            break
        if peeked[1].startswith("- "):
            break
        _, content = lines.advance()
        if not _looks_like_mapping_entry(content):
            raise ConfigError(f"expected 'key: value' mapping entry, got: {content!r}")
        key, _, value = content.partition(":")
        key = key.strip()
        value = value.strip()
        if value == "":
            nxt = lines.peek()
            if nxt is not None and nxt[0] > indent:
                result[key] = _parse_block(lines, nxt[0])
            else:
                result[key] = None
        else:
            result[key] = _parse_scalar(value)
    return result


def parse_minimal_yaml(text: str) -> dict:
    lines = _Lines(text)
    if lines.peek() is None:
        return {}
    top_indent = lines.peek()[0]
    value = _parse_block(lines, top_indent)
    if lines.peek() is not None:
        raise ConfigError(f"unexpected trailing content at: {lines.peek()[1]!r}")
    if not isinstance(value, dict):
        raise ConfigError("top-level YAML document must be a mapping")
    return value


# --------------------------------------------------------------------------
# Glob compiler and matcher (REQ-001)
# --------------------------------------------------------------------------


def normalize_nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s)


def validate_and_normalize_pattern(pattern: str) -> str:
    if not isinstance(pattern, str) or pattern == "":
        raise ConfigError("pattern must be a non-empty string")
    normalized = pattern.replace("\\", "/")
    for ch in normalized:
        if ch in _UNSUPPORTED_METACHARS:
            raise ConfigError(
                f"unsupported glob metacharacter {ch!r} in pattern {pattern!r} "
                "(only '**', '*', '/', and literal path characters are supported)"
            )
    return normalize_nfc(normalized)


def _segment_regex(segment: str) -> "re.Pattern":
    parts = []
    for ch in segment:
        if ch == "*":
            parts.append("[^/]*")
        else:
            parts.append(re.escape(ch))
    return re.compile("^" + "".join(parts) + "$")


def _segments_match(pat_segs: Tuple[str, ...], path_segs: Tuple[str, ...]) -> bool:
    # Small recursive matcher with the classic glob semantics:
    #  - "**" matches zero or more WHOLE segments (crosses "/", zero-segment
    #    case included, AC-007).
    #  - any other segment matches exactly one path segment via
    #    _segment_regex (bare "*" is confined to that one segment, AC-002).
    memo: Dict[Tuple[int, int], bool] = {}

    def rec(pi: int, si: int) -> bool:
        key = (pi, si)
        if key in memo:
            return memo[key]
        if pi == len(pat_segs):
            result = si == len(path_segs)
            memo[key] = result
            return result
        seg = pat_segs[pi]
        if seg == "**":
            result = False
            for k in range(si, len(path_segs) + 1):
                if rec(pi + 1, k):
                    result = True
                    break
            memo[key] = result
            return result
        if si == len(path_segs):
            memo[key] = False
            return False
        if not _segment_regex(seg).match(path_segs[si]):
            memo[key] = False
            return False
        result = rec(pi + 1, si + 1)
        memo[key] = result
        return result

    return rec(0, 0)


def pattern_matches(pattern_normalized: str, path_nfc: str) -> bool:
    pat_segs = tuple(pattern_normalized.split("/"))
    path_segs = tuple(path_nfc.split("/"))
    return _segments_match(pat_segs, path_segs)


# --------------------------------------------------------------------------
# Config loading and validation (REQ-001 config-shape, REQ-002 shared_paths
# shape)
# --------------------------------------------------------------------------


class Component:
    __slots__ = ("name", "include", "exclude", "include_raw", "exclude_raw")

    def __init__(self, name: str, include_raw: List[str], exclude_raw: List[str]):
        self.name = name
        self.include_raw = include_raw
        self.exclude_raw = exclude_raw
        self.include = [validate_and_normalize_pattern(p) for p in include_raw]
        self.exclude = [validate_and_normalize_pattern(p) for p in exclude_raw]


class SharedPathEntry:
    __slots__ = ("pattern_raw", "pattern", "components", "classification")

    def __init__(self, pattern_raw: str, components: Optional[List[str]], classification: Optional[str]):
        self.pattern_raw = pattern_raw
        self.pattern = validate_and_normalize_pattern(pattern_raw)
        self.components = components
        self.classification = classification


class Config:
    def __init__(self, components: List[Component], shared_paths: List[SharedPathEntry], raw: dict):
        self.components = components
        self.shared_paths = shared_paths
        self.raw = raw


def _as_str_list(value, field: str) -> List[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ConfigError(f"{field} must be a list")
    out = []
    for item in value:
        if not isinstance(item, str):
            raise ConfigError(f"{field} entries must be strings")
        out.append(item)
    return out


def load_config_dict(data: dict) -> Config:
    if not isinstance(data, dict):
        raise ConfigError("config must be a mapping")
    components_raw = data.get("components")
    if not isinstance(components_raw, list) or len(components_raw) == 0:
        raise ConfigError("config.components must be a non-empty list")
    components: List[Component] = []
    seen_names = set()
    for entry in components_raw:
        if not isinstance(entry, dict):
            raise ConfigError("each components[] entry must be a mapping")
        name = entry.get("name")
        if not isinstance(name, str) or name == "":
            raise ConfigError("each component requires a non-empty 'name'")
        if name in seen_names:
            raise ConfigError(f"duplicate component name: {name}")
        seen_names.add(name)
        paths = entry.get("paths")
        if not isinstance(paths, dict):
            raise ConfigError(f"component {name!r} requires a 'paths' mapping")
        include_raw = _as_str_list(paths.get("include"), f"component {name!r} paths.include")
        exclude_raw = _as_str_list(paths.get("exclude"), f"component {name!r} paths.exclude")
        # AC-008: a component with an empty include list is a config-load-time
        # error, never conflated with a runtime UNOWNED result.
        if len(include_raw) == 0:
            raise ConfigError(f"component {name!r} has an empty paths.include list")
        components.append(Component(name, include_raw, exclude_raw))

    shared_paths: List[SharedPathEntry] = []
    shared_raw = data.get("shared_paths")
    if shared_raw is not None:
        if not isinstance(shared_raw, list):
            raise ConfigError("config.shared_paths must be a list")
        for entry in shared_raw:
            if not isinstance(entry, dict):
                raise ConfigError("each shared_paths[] entry must be a mapping")
            pattern = entry.get("pattern")
            if not isinstance(pattern, str) or pattern == "":
                raise ConfigError("each shared_paths[] entry requires a non-empty 'pattern'")
            has_components = "components" in entry and entry.get("components") is not None
            classification = entry.get("classification")
            has_classification = classification is not None
            # AC-018: both-or-neither is a fail-closed configuration error,
            # distinct from the six Gate Fail conditions.
            if has_components == has_classification:
                raise ConfigError(
                    f"shared_paths entry {pattern!r} must carry exactly one of "
                    "'components' (bounded) or 'classification: cross-cutting' "
                    "(unbounded), never both or neither"
                )
            if has_classification:
                if classification != "cross-cutting":
                    raise ConfigError(
                        f"shared_paths entry {pattern!r} has unsupported classification "
                        f"{classification!r} (only 'cross-cutting' is defined)"
                    )
                shared_paths.append(SharedPathEntry(pattern, None, "cross-cutting"))
            else:
                comp_list = _as_str_list(entry.get("components"), f"shared_paths {pattern!r} components")
                if len(comp_list) == 0:
                    raise ConfigError(
                        f"shared_paths entry {pattern!r} has an empty 'components' list "
                        "(bounded form requires an explicit non-empty list)"
                    )
                shared_paths.append(SharedPathEntry(pattern, comp_list, None))

    return Config(components, shared_paths, data)


def load_config_text(text: str) -> Config:
    data = parse_minimal_yaml(text)
    return load_config_dict(data)


def load_config_file(path: str) -> Config:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    return load_config_text(text)


# --------------------------------------------------------------------------
# Classification (REQ-002)
# --------------------------------------------------------------------------

EXCLUSIVE = "EXCLUSIVE"
SHARED_BOUNDED = "SHARED_BOUNDED"
SHARED_CROSS_CUTTING = "SHARED_CROSS_CUTTING"
OVERLAP = "OVERLAP"
UNOWNED = "UNOWNED"


def classify_paths(config: Config, raw_paths: List[str]) -> dict:
    # AC-010: NFC-collision detection across the whole input set, fail-closed.
    nfc_to_raw: Dict[str, str] = {}
    for raw in raw_paths:
        nfc = normalize_nfc(raw)
        if nfc in nfc_to_raw and nfc_to_raw[nfc] != raw:
            raise CollisionError(
                f"NFC-normalization collision: {nfc_to_raw[nfc]!r} and {raw!r} "
                f"both normalize to {nfc!r}"
            )
        nfc_to_raw[nfc] = raw

    records = []
    exclusive_owners: set = set()
    bounded_shared_touched: set = set()

    for raw in raw_paths:
        nfc = normalize_nfc(raw)
        shared_hit: Optional[SharedPathEntry] = None
        for entry in config.shared_paths:
            if pattern_matches(entry.pattern, nfc):
                shared_hit = entry
                break

        if shared_hit is not None:
            if shared_hit.components is not None:
                classification = SHARED_BOUNDED
                owning = list(shared_hit.components)
                for c in owning:
                    bounded_shared_touched.add(c)
            else:
                classification = SHARED_CROSS_CUTTING
                owning = []
            records.append(
                {
                    "raw_path": raw,
                    "normalized_path": nfc,
                    "classification": classification,
                    "owning_components": owning,
                    "evidence": {"excluded_match": None},
                }
            )
            continue

        residual_owners = []
        excluded_match_evidence = []
        any_include_matched = False
        for comp in config.components:
            included = any(pattern_matches(p, nfc) for p in comp.include)
            if not included:
                continue
            any_include_matched = True
            matched_excludes = [p for p in comp.exclude if pattern_matches(p, nfc)]
            if matched_excludes:
                # AC-013 (Fail-5 invariant): a path inside component C's own
                # exclude is NEVER attributed to C, even though one of C's
                # include patterns also matched.
                excluded_match_evidence.append({"component": comp.name, "patterns": matched_excludes})
                continue
            residual_owners.append(comp.name)

        if len(residual_owners) == 1:
            classification = EXCLUSIVE
            exclusive_owners.add(residual_owners[0])
            evidence = {"excluded_match": None}
        elif len(residual_owners) == 0:
            classification = UNOWNED
            if any_include_matched and excluded_match_evidence:
                # AC-014: EXCLUDED_MATCH only when the reason this path is
                # UNOWNED is that every component whose include would
                # otherwise have matched it excluded it — distinguishable
                # from an ordinary UNOWNED record where no include pattern
                # ever matched at all.
                evidence = {"excluded_match": excluded_match_evidence}
            else:
                evidence = {"excluded_match": None}
        else:
            classification = OVERLAP
            evidence = {"excluded_match": excluded_match_evidence or None}

        records.append(
            {
                "raw_path": raw,
                "normalized_path": nfc,
                "classification": classification,
                "owning_components": residual_owners,
                "evidence": evidence,
            }
        )

    records.sort(key=lambda r: r["raw_path"].encode("utf-8", "surrogatepass"))

    affected_components = sorted(exclusive_owners | bounded_shared_touched)

    ownership_input = {
        "components": [
            {
                "name": c.name,
                "paths": {"include": list(c.include_raw), "exclude": list(c.exclude_raw)},
            }
            for c in config.components
        ],
        "shared_paths": [
            {"pattern": e.pattern_raw, "components": e.components, "classification": e.classification}
            for e in config.shared_paths
        ],
        "matcher_semantics_version": MATCHER_SEMANTICS_VERSION,
    }

    return {
        "records": records,
        "affected_components": affected_components,
        "ownership_input": ownership_input,
    }


# --------------------------------------------------------------------------
# Schema conformance (AC-011) — FAIL-closed on absence, never a skip.
# --------------------------------------------------------------------------


def check_schema_conformance(schema_path: str) -> Tuple[bool, str]:
    """Returns (conformant, diagnostic). `conformant` is False whenever the
    artifact is absent (fail-closed, never a skip) or present-but-divergent
    from decision-document v2 section 12's shape this feature's parser
    builds against."""
    if not os.path.isfile(schema_path):
        return False, f"schema artifact absent: {schema_path} (Epic A1 has not landed it yet)"
    try:
        with open(schema_path, "r", encoding="utf-8") as fh:
            text = fh.read()
        data = parse_minimal_yaml(text)
    except (ConfigError, OSError) as exc:
        return False, f"schema artifact at {schema_path} could not be parsed: {exc}"
    shared_raw = data.get("shared_paths")
    if shared_raw is None:
        return False, f"schema artifact at {schema_path} has no top-level 'shared_paths' key"
    if not isinstance(shared_raw, list):
        return False, f"schema artifact at {schema_path} 'shared_paths' is not a list"
    for entry in shared_raw:
        if not isinstance(entry, dict) or "pattern" not in entry:
            return False, f"schema artifact at {schema_path} has a shared_paths entry missing 'pattern'"
        has_components = "components" in entry and entry.get("components") is not None
        has_classification = entry.get("classification") is not None
        if has_components == has_classification:
            return (
                False,
                f"schema artifact at {schema_path} shared_paths entry {entry.get('pattern')!r} "
                "violates the bounded-xor-cross-cutting shape",
            )
    components_raw = data.get("components")
    if components_raw is not None:
        # The template may legitimately omit `components` (it documents
        # `shared_paths` conventions primarily); when present, it must
        # conform to the same components[].paths.{include,exclude} shape.
        try:
            load_config_dict({"components": components_raw, "shared_paths": shared_raw})
        except ConfigError as exc:
            return False, f"schema artifact at {schema_path} components[] shape diverges: {exc}"
    return True, f"schema artifact at {schema_path} conforms to this parser's expected shape"


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def _read_paths_file(path: Optional[str]) -> List[str]:
    if path is None:
        text = sys.stdin.read()
    else:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return [line for line in lines if line != ""]


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="resolve-component-paths.py")
    parser.add_argument("--config", help="path to project-context.yaml")
    parser.add_argument(
        "--changed-paths-file",
        help="path to a newline-separated file of raw changed paths "
        "(T-001 interim input surface; T-002 supersedes this with the "
        "real git-diff basis collector). Omit to read from stdin.",
    )
    parser.add_argument(
        "--check-schema-conformance",
        action="store_true",
        help="run the AC-011 schema-conformance check instead of classifying paths",
    )
    parser.add_argument(
        "--schema",
        default=SCHEMA_ARTIFACT_PATH,
        help=f"schema artifact path for --check-schema-conformance (default: {SCHEMA_ARTIFACT_PATH})",
    )
    args = parser.parse_args(argv)

    if args.check_schema_conformance:
        conformant, diagnostic = check_schema_conformance(args.schema)
        print(json.dumps({"conformant": conformant, "diagnostic": diagnostic}, indent=2))
        return 0 if conformant else 1

    if not args.config:
        print("resolve-component-paths: --config is required", file=sys.stderr)
        return 1

    try:
        config = load_config_file(args.config)
    except ConfigError as exc:
        print(f"resolve-component-paths: config error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"resolve-component-paths: cannot read config: {exc}", file=sys.stderr)
        return 1

    try:
        raw_paths = _read_paths_file(args.changed_paths_file)
    except OSError as exc:
        print(f"resolve-component-paths: cannot read changed-paths-file: {exc}", file=sys.stderr)
        return 1

    try:
        result = classify_paths(config, raw_paths)
    except (ConfigError, CollisionError) as exc:
        print(f"resolve-component-paths: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
