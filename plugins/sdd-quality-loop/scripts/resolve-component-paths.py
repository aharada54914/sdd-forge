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
ADR-0020 / ADR-0030), not a general YAML 1.2 implementation. The
schema-conformance fixture below validates this projection against Epic A1's
landed canonical schema and template.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from typing import Dict, List, Optional, Tuple

SCHEMA_ARTIFACT_PATH = "contracts/project-context.template.yaml"
SCHEMA_CONTRACT_PATH = "contracts/project-context.schema.json"
PROJECT_CONTEXT_SCHEMA_VERSION = "sdd-project-context/v1"
MATCHER_SEMANTICS_VERSION = "1.0.0"
RESOLVER_VERSION = "1.1.0"

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


def canonical_digest(value: dict) -> str:
    """Hash a JSON-compatible value through the shipped A1 canonicalizer.

    Canonicalization remains single-sourced in canonicalize-sdd-yaml.py.
    The resolver supplies ordinary JSON bytes and validates the subprocess
    contract fail-closed before placing the digest in emitted evidence.
    """
    canonicalizer = os.path.join(os.path.dirname(os.path.abspath(__file__)), "canonicalize-sdd-yaml.py")
    fd, temp_path = tempfile.mkstemp(prefix="resolve-component-paths-", suffix=".json")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
        try:
            process = subprocess.run(
                [sys.executable, canonicalizer, temp_path, "--input-format", "json", "--hash-only"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as exc:
            raise ConfigError("ownership digest canonicalizer could not be invoked: {}".format(exc))
    finally:
        try:
            os.unlink(temp_path)
        except OSError:
            pass

    if process.returncode != 0:
        diagnostic = process.stderr.decode("utf-8", "replace").strip()
        raise ConfigError(
            "ownership digest canonicalization failed (exit {}): {}".format(process.returncode, diagnostic)
        )
    digest = process.stdout.decode("ascii", "strict").strip()
    if re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is None:
        raise ConfigError("ownership digest canonicalizer returned a malformed digest")
    return digest


# --------------------------------------------------------------------------
# Minimal restricted YAML-subset parser
# --------------------------------------------------------------------------
#
# Supports exactly what this feature's config shape needs:
#   - block mappings ("key: value" / "key:" + nested indented block)
#   - block sequences ("- item" / "- key: value" inline-mapping-start)
#   - scalar strings, optionally single- or double-quoted
#   - the exact empty sequence `[]` used by the canonical starter template
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


def _parse_scalar(raw: str):
    s = raw.strip()
    # The canonical A1 starter intentionally declares `components: []`.
    # Accept this one bounded flow-style value without widening the parser
    # into a general flow-style YAML implementation.
    if s == "[]":
        return []
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


def _leading_whitespace(line: str) -> str:
    # Deliberately strips BOTH " " and "\t" here (unlike _indent_of, which
    # only strips " " to measure a space-only indent depth) so the tab
    # guard below sees the true leading-whitespace run. A bare leading tab
    # has zero leading SPACES, so `raw[: _indent_of(raw)]` -- slicing only
    # as many characters as _indent_of counted -- is always the empty
    # string for such a line and can never contain a tab; the same holds
    # for spaces-then-tab indentation, since _indent_of stops counting at
    # the first non-space character. That made the guard this replaces
    # permanently unable to fire for any tab-indented line, not just a
    # bare leading tab.
    return line[: len(line) - len(line.lstrip(" \t"))]


class _Lines:
    def __init__(self, text: str):
        raw_lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        self.lines: List[Tuple[int, str]] = []
        for raw in raw_lines:
            stripped = _strip_comment(raw).rstrip()
            if stripped.strip() == "":
                continue
            if "\t" in _leading_whitespace(raw):
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
    if not isinstance(components_raw, list):
        raise ConfigError("config.components must be a list")
    components: List[Component] = []
    seen_names = set()
    for entry in components_raw:
        if not isinstance(entry, dict):
            raise ConfigError("each components[] entry must be a mapping")
        # Epic A1's canonical schema requires `id` and forbids additional
        # properties. Do not retain the pre-A1 `name` alias on the ordinary
        # resolve path: AC-011 field-name conformance applies here too.
        if "name" in entry:
            raise ConfigError("legacy 'name' is not supported; use canonical component field 'id'")
        name = entry.get("id")
        if not isinstance(name, str) or name == "":
            raise ConfigError("each component requires a non-empty 'id'")
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
                excluded_match_evidence.extend(
                    {"component": comp.name, "pattern": pattern}
                    for pattern in matched_excludes
                )
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
                "id": c.name,
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
    ownership_digest = canonical_digest(ownership_input)
    rule_set_revision = canonical_digest(
        {"matcher_semantics_version": MATCHER_SEMANTICS_VERSION}
    )

    return {
        "records": records,
        "affected_components": affected_components,
        "ownership_input": ownership_input,
        "context_binding": {"ownership_digest": ownership_digest},
        "resolver": {
            "version": RESOLVER_VERSION,
            "rule_set_revision": rule_set_revision,
        },
    }


# --------------------------------------------------------------------------
# Schema conformance (AC-011) — FAIL-closed on absence, never a skip.
# --------------------------------------------------------------------------


def _json_schema_type_is(node, expected: str) -> bool:
    return isinstance(node, dict) and node.get("type") == expected


# JSON Schema draft-07 SUBSET validator.
#
# Deliberately a subset, mirroring the same bounded-validator precedent this
# repository already set in validate-approval-sidecar.py's `_schema_validate`
# (CI installs no third-party packages for gate scripts, so `jsonschema` is
# unavailable). Supported: $ref into #/definitions, const, enum, type,
# required, additionalProperties:false, properties, items, oneOf, minLength.
#
# KNOWN LIMIT, stated rather than hidden: the instance handed to this
# validator comes from this file's restricted YAML-subset parser, which
# yields every scalar as a `str`. A `"type": "boolean"`/`"integer"` keyword
# therefore cannot be checked faithfully against a YAML-sourced instance and
# is skipped for string scalars (see `_schema_type_ok`). Epic A1's
# project-context schema declares booleans only under
# `components[].characteristics`, which the canonical starter template does
# not populate, so every field this resolver actually consumes is validated
# for real. A JSON-sourced instance has no such limit.
_YAML_UNTYPED_SCALAR = object()


def _schema_type_ok(expected, instance) -> bool:
    if isinstance(expected, list):
        return any(_schema_type_ok(t, instance) for t in expected)
    if expected == "object":
        return isinstance(instance, dict)
    if expected == "array":
        return isinstance(instance, list)
    if expected == "string":
        return isinstance(instance, str)
    if expected in ("boolean", "integer", "number"):
        # See KNOWN LIMIT above: a restricted-YAML scalar is always `str`,
        # so a string instance is accepted rather than falsely rejected.
        if isinstance(instance, str):
            return True
        if expected == "boolean":
            return isinstance(instance, bool)
        return isinstance(instance, (int, float)) and not isinstance(instance, bool)
    if expected == "null":
        return instance is None
    return True


def _schema_validate(schema, instance, path="/", root=None) -> List[str]:
    if root is None:
        root = schema
    if not isinstance(schema, dict):
        return []
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/definitions/"):
            return [f"{path}: unsupported $ref {ref!r}"]
        target = (root.get("definitions") or {}).get(ref[len("#/definitions/"):])
        if not isinstance(target, dict):
            return [f"{path}: unresolvable $ref {ref!r}"]
        return _schema_validate(target, instance, path, root)

    errors: List[str] = []
    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: expected const {schema['const']!r}, got {instance!r}")
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: {instance!r} not in enum {schema['enum']!r}")
    if "type" in schema and not _schema_type_ok(schema["type"], instance):
        errors.append(f"{path}: expected {schema['type']}")

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                errors.append(f"{path}: missing required field {req!r}")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in instance:
                if key not in props:
                    errors.append(f"{path}: additional property {key!r} not allowed")
        for key, value in instance.items():
            if key in props:
                errors.extend(
                    _schema_validate(props[key], value, path.rstrip("/") + "/" + key, root)
                )
    elif isinstance(instance, list) and "items" in schema:
        for idx, item in enumerate(instance):
            errors.extend(
                _schema_validate(schema["items"], item, path.rstrip("/") + f"/{idx}", root)
            )
    elif isinstance(instance, str) and "minLength" in schema:
        if len(instance) < schema["minLength"]:
            errors.append(f"{path}: shorter than minLength {schema['minLength']}")

    if "oneOf" in schema:
        matches = sum(
            1 for sub in schema["oneOf"] if not _schema_validate(sub, instance, path, root)
        )
        if matches != 1:
            errors.append(f"{path}: oneOf matched {matches} branches (need exactly 1)")
    return errors


def _check_schema_contract_shape(schema_contract_path: str) -> Tuple[bool, str]:
    """Validate only the A3-consumed projection of Epic A1's JSON Schema."""
    if not os.path.isfile(schema_contract_path):
        return False, f"schema contract absent: {schema_contract_path}"
    try:
        with open(schema_contract_path, "r", encoding="utf-8") as fh:
            contract = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        return False, f"schema contract at {schema_contract_path} could not be parsed: {exc}"

    properties = contract.get("properties") if isinstance(contract, dict) else None
    if not isinstance(properties, dict):
        return False, f"schema contract at {schema_contract_path} has no properties mapping"
    schema_node = properties.get("schema")
    if not isinstance(schema_node, dict) or schema_node.get("const") != PROJECT_CONTEXT_SCHEMA_VERSION:
        return False, f"schema contract at {schema_contract_path} has a divergent schema version"

    components_node = properties.get("components")
    if not _json_schema_type_is(components_node, "array"):
        return False, f"schema contract at {schema_contract_path} components is not an array"
    component_item = components_node.get("items", {})
    if not _json_schema_type_is(component_item, "object"):
        return False, f"schema contract at {schema_contract_path} components[] is not an object"
    if "id" not in component_item.get("required", []):
        return False, f"schema contract at {schema_contract_path} components[].id is not required"
    component_props = component_item.get("properties", {})
    if not _json_schema_type_is(component_props.get("id"), "string"):
        return False, f"schema contract at {schema_contract_path} components[].id is not a string"
    paths_node = component_props.get("paths")
    if not _json_schema_type_is(paths_node, "object"):
        return False, f"schema contract at {schema_contract_path} components[].paths is not an object"
    path_props = paths_node.get("properties", {})
    for field in ("include", "exclude"):
        field_node = path_props.get(field)
        if not _json_schema_type_is(field_node, "array") or not _json_schema_type_is(
            field_node.get("items") if isinstance(field_node, dict) else None, "string"
        ):
            return (
                False,
                f"schema contract at {schema_contract_path} "
                f"components[].paths.{field} is not a string array",
            )

    shared_node = properties.get("shared_paths")
    if not _json_schema_type_is(shared_node, "array"):
        return False, f"schema contract at {schema_contract_path} shared_paths is not an array"
    shared_items = shared_node.get("items", {})
    if not _json_schema_type_is(shared_items, "object"):
        return False, f"schema contract at {schema_contract_path} shared_paths[] is not an object"
    if "pattern" not in shared_items.get("required", []):
        return False, f"schema contract at {schema_contract_path} shared_paths[].pattern is not required"
    bounded_ok = False
    cross_cutting_ok = False
    for branch in shared_items.get("oneOf", []):
        if not isinstance(branch, dict):
            continue
        branch_props = branch.get("properties", {})
        components = branch_props.get("components")
        if (
            "components" in branch.get("required", [])
            and _json_schema_type_is(components, "array")
            and _json_schema_type_is(components.get("items"), "string")
        ):
            bounded_ok = True
        classification = branch_props.get("classification")
        if (
            "classification" in branch.get("required", [])
            and isinstance(classification, dict)
            and classification.get("const") == "cross-cutting"
        ):
            cross_cutting_ok = True
    if not (bounded_ok and cross_cutting_ok):
        return False, f"schema contract at {schema_contract_path} shared_paths XOR shape diverges"
    return True, "schema contract field names, types, and version conform"


def check_schema_conformance(
    schema_path: str, schema_contract_path: str = SCHEMA_CONTRACT_PATH
) -> Tuple[bool, str]:
    """Fail closed unless both the JSON Schema and starter template align."""
    contract_ok, contract_diagnostic = _check_schema_contract_shape(schema_contract_path)
    if not contract_ok:
        return False, contract_diagnostic
    if not os.path.isfile(schema_path):
        return False, f"schema artifact absent: {schema_path}"
    try:
        with open(schema_path, "r", encoding="utf-8") as fh:
            text = fh.read()
        data = parse_minimal_yaml(text)
    except (ConfigError, OSError) as exc:
        return False, f"schema artifact at {schema_path} could not be parsed: {exc}"
    if data.get("schema") != PROJECT_CONTEXT_SCHEMA_VERSION:
        return False, f"schema artifact at {schema_path} has a divergent or missing schema version"
    shared_raw = data.get("shared_paths")
    if not isinstance(shared_raw, list):
        return False, f"schema artifact at {schema_path} 'shared_paths' is not a list"
    for entry in shared_raw:
        if not isinstance(entry, dict) or not isinstance(entry.get("pattern"), str):
            return False, f"schema artifact at {schema_path} has an invalid shared_paths pattern"
        has_components = "components" in entry and entry.get("components") is not None
        has_classification = entry.get("classification") is not None
        if has_components == has_classification:
            return (
                False,
                f"schema artifact at {schema_path} shared_paths entry {entry.get('pattern')!r} "
                "violates the bounded-xor-cross-cutting shape",
            )
    # AC-011's substantive step: validate the parsed artifact as an INSTANCE
    # against Epic A1's real JSON Schema. The shape checks above only assert
    # that A1's schema still says what this resolver was built against;
    # without this call nothing ever checks a document against the schema,
    # which is what AC-011 is framed as doing.
    try:
        with open(schema_contract_path, "r", encoding="utf-8") as fh:
            contract = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        return False, f"schema contract at {schema_contract_path} could not be parsed: {exc}"
    instance_errors = _schema_validate(contract, data)
    if instance_errors:
        return (
            False,
            f"schema artifact at {schema_path} does not validate against "
            f"{schema_contract_path}: " + "; ".join(instance_errors[:5]),
        )

    components_raw = data.get("components")
    if not isinstance(components_raw, list):
        return False, f"schema artifact at {schema_path} 'components' is not a list"
    try:
        load_config_dict({"components": components_raw, "shared_paths": shared_raw})
    except ConfigError as exc:
        return False, f"schema artifact at {schema_path} components[] shape diverges: {exc}"

    return (
        True,
        f"schema artifact {schema_path} validates against {schema_contract_path} "
        "and conforms to the resolver projection",
    )


# --------------------------------------------------------------------------
# Git-diff basis collector (REQ-003, T-002)
# --------------------------------------------------------------------------
#
# Wraps the pure classifier above with a deterministic git-diff change-set
# collector: resolves --source-rev/--target-rev to commit OIDs, computes
# their merge-base, collects the baseline..worktree change set (staged +
# unstaged + untracked, each counted once, NUL-framed raw-byte parsing),
# follows renames under a pinned threshold/limit, evaluates submodule/
# symlink entries reference-only, and enforces a single-writer/TOCTOU
# snapshot check with a retry-once-then-fail-closed rule. Every axis is
# normatively fail-closed (ADR-0030).

RENAME_SIMILARITY_THRESHOLD = 50  # percent, pinned (git's own default -M50%)
RENAME_LIMIT = 1000  # pinned diff.renameLimit


class GitDiffError(ValueError):
    """A fail-closed git-diff-collection error (REQ-003). Always propagates
    to a non-zero exit with a diagnostic — never a silent empty change set
    or a silent fallback."""


def _run_git(repo_root: str, args: List[str]) -> Tuple[int, bytes, bytes]:
    import subprocess

    try:
        proc = subprocess.run(
            ["git", "-C", repo_root] + args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise GitDiffError(f"git executable not found: {exc}") from exc
    return proc.returncode, proc.stdout, proc.stderr


def _decode_path_strict(raw: bytes) -> str:
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise GitDiffError(f"invalid UTF-8 in a git-reported path: {raw!r} ({exc})") from exc


def resolve_commit_oid(repo_root: str, rev: str) -> str:
    code, out, err = _run_git(repo_root, ["rev-parse", "--verify", f"{rev}^{{commit}}"])
    if code != 0:
        raise GitDiffError(f"unresolvable rev {rev!r}: {err.decode('utf-8', 'replace').strip()}")
    return out.decode("ascii").strip()


def compute_merge_base(repo_root: str, source_oid: str, target_oid: str) -> str:
    code, out, err = _run_git(repo_root, ["merge-base", source_oid, target_oid])
    if code != 0:
        raise GitDiffError(
            f"no merge-base between {source_oid} and {target_oid} "
            f"(unrelated histories?): {err.decode('utf-8', 'replace').strip()}"
        )
    return out.decode("ascii").strip()


def _capture_fingerprint(repo_root: str) -> Tuple[str, str]:
    # Single-writer/snapshot contract: HEAD OID + a hash of the full
    # staged/unstaged/untracked porcelain status, captured before and after
    # this collector's own multi-command sequence.
    code, out, _err = _run_git(repo_root, ["rev-parse", "HEAD"])
    head = out.decode("ascii").strip() if code == 0 else "(unborn)"
    _code2, status_out, _err2 = _run_git(
        repo_root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"]
    )
    import hashlib

    status_hash = hashlib.sha256(status_out).hexdigest()
    return head, status_hash


def _split_nul(raw: bytes) -> List[bytes]:
    parts = raw.split(b"\x00")
    if parts and parts[-1] == b"":
        parts = parts[:-1]
    return parts


def collect_tracked_diff(repo_root: str, baseline_oid: str) -> Tuple[List[str], List[dict]]:
    code, out, err = _run_git(
        repo_root,
        [
            "-c",
            f"diff.renameLimit={RENAME_LIMIT}",
            "diff",
            "--no-ext-diff",
            f"-M{RENAME_SIMILARITY_THRESHOLD}%",
            "--ignore-submodules=dirty",
            "--name-status",
            "-z",
            baseline_oid,
        ],
    )
    err_text = err.decode("utf-8", "replace")
    if "too many files" in err_text or "rename detection was skipped" in err_text:
        raise GitDiffError(
            f"rename-detection limit exceeded (pinned diff.renameLimit={RENAME_LIMIT}); "
            "failing closed rather than silently falling back to an unrelated add+delete pair"
        )
    if code != 0:
        raise GitDiffError(f"git diff against baseline {baseline_oid} failed: {err_text.strip()}")

    tokens = _split_nul(out)
    entries: List[str] = []
    renames: List[dict] = []
    i = 0
    while i < len(tokens):
        status = tokens[i].decode("ascii", "replace")
        if status.startswith("R") or status.startswith("C"):
            if i + 2 >= len(tokens):
                raise GitDiffError("malformed rename/copy entry in git diff --name-status -z output")
            old_path = _decode_path_strict(tokens[i + 1])
            new_path = _decode_path_strict(tokens[i + 2])
            entries.append(old_path)
            entries.append(new_path)
            renames.append({"old_path": old_path, "new_path": new_path, "status": status})
            i += 3
        else:
            if i + 1 >= len(tokens):
                raise GitDiffError("malformed status entry in git diff --name-status -z output")
            path = _decode_path_strict(tokens[i + 1])
            entries.append(path)
            i += 2
    return entries, renames


def collect_untracked(repo_root: str) -> List[str]:
    code, out, err = _run_git(repo_root, ["ls-files", "--others", "--exclude-standard", "-z"])
    if code != 0:
        raise GitDiffError(f"git ls-files --others failed: {err.decode('utf-8', 'replace').strip()}")
    return [_decode_path_strict(tok) for tok in _split_nul(out)]


def collect_changed_paths(
    repo_root: str, source_rev: str, target_rev: str, include_untracked: bool = True
) -> dict:
    attempt = 0
    while True:
        attempt += 1
        fp_before = _capture_fingerprint(repo_root)

        source_oid = resolve_commit_oid(repo_root, source_rev)
        target_oid = resolve_commit_oid(repo_root, target_rev)
        baseline_oid = compute_merge_base(repo_root, source_oid, target_oid)
        tracked_entries, renames = collect_tracked_diff(repo_root, baseline_oid)
        untracked_entries = collect_untracked(repo_root) if include_untracked else []

        fp_after = _capture_fingerprint(repo_root)
        if fp_before == fp_after:
            break
        if attempt >= 2:
            raise GitDiffError(
                "single-writer/TOCTOU snapshot mismatch persisted after one retry; "
                "failing closed rather than returning a mixed-snapshot result"
            )
        # else: retry the whole sequence once (attempt == 1 -> loop to attempt 2)

    # Staged + unstaged + untracked, each counted exactly once: tracked_entries
    # come only from `git diff` (staged+unstaged against the baseline,
    # porcelain-only, never touching the filesystem directly); untracked_entries
    # come only from `git ls-files --others`, a disjoint set by construction
    # (a tracked path can never also be untracked). Deduplicate defensively
    # (order-preserving) in case the same path appears twice across rename
    # old/new legs and untracked (should not happen, but never double-count).
    seen: Dict[str, None] = {}
    changed_paths: List[str] = []
    for p in tracked_entries + untracked_entries:
        if p not in seen:
            seen[p] = None
            changed_paths.append(p)

    return {
        "source_oid": source_oid,
        "target_oid": target_oid,
        "baseline_oid": baseline_oid,
        "changed_paths": changed_paths,
        "renames": renames,
    }


# --------------------------------------------------------------------------
# --diagnose (T-004, resolver-only diagnostics — never Gate-invoked)
# --------------------------------------------------------------------------
#
# Fail-1/3/5/6(conditional)-only findings for early feedback, any time,
# regardless of capability state. This subcommand's exit code carries no
# Implementation Gate meaning and `quality-gate`'s `## Process` never
# invokes it (REQ-004). Fail-2/Fail-4 are never evaluated here since they
# require Facet Manifest data this subcommand deliberately never accepts.


def diagnose(classify_result: dict, provider_bindings_path: Optional[str]) -> dict:
    records = classify_result["records"]
    findings = []

    unowned = [r["raw_path"] for r in records if r["classification"] == "UNOWNED"]
    findings.append({"id": "Fail-1", "triggered": len(unowned) > 0, "detail": {"unowned_paths": unowned}})

    overlap = [r["raw_path"] for r in records if r["classification"] == "OVERLAP"]
    findings.append({"id": "Fail-3", "triggered": len(overlap) > 0, "detail": {"overlap_paths": overlap}})

    excluded_match = [
        r["raw_path"] for r in records if r["classification"] == "UNOWNED" and r.get("evidence", {}).get("excluded_match")
    ]
    findings.append(
        {"id": "Fail-5", "triggered": len(excluded_match) > 0, "detail": {"excluded_match_paths": excluded_match}}
    )

    warnings: List[str] = []
    if provider_bindings_path and os.path.isfile(provider_bindings_path):
        try:
            with open(provider_bindings_path, "r", encoding="utf-8") as fh:
                text = fh.read()
            data = json.loads(text)
        except (OSError, json.JSONDecodeError):
            try:
                data = parse_minimal_yaml(text)
            except ConfigError:
                data = {}
        bindings = data.get("bindings") if isinstance(data, dict) else None
        exclusive_by_component: Dict[str, List[str]] = {}
        for r in records:
            if r["classification"] == "EXCLUSIVE":
                for comp in r["owning_components"]:
                    exclusive_by_component.setdefault(comp, []).append(r["raw_path"])
        matches = []
        if isinstance(bindings, list):
            for binding in bindings:
                if not isinstance(binding, dict):
                    continue
                adapter_paths = binding.get("adapter_paths")
                joined = binding.get("provider_binding_ids") or []
                if adapter_paths is None:
                    warnings.append("Fail-6: a provider binding declares no adapter_paths; evaluation not possible for it")
                    continue
                for comp in joined:
                    for path in exclusive_by_component.get(comp, []):
                        nfc_path = normalize_nfc(path)
                        for pattern in adapter_paths:
                            try:
                                normalized = validate_and_normalize_pattern(pattern)
                            except ConfigError:
                                continue
                            if pattern_matches(normalized, nfc_path):
                                matches.append({"component": comp, "path": path, "pattern": pattern})
        findings.append({"id": "Fail-6", "triggered": len(matches) > 0, "detail": {"matches": matches}})
    else:
        findings.append(
            {"id": "Fail-6", "triggered": False, "detail": {"status": "not-applicable (provider-bindings absent)"}}
        )
        warnings.append("Fail-6: provider-bindings file absent; recorded N/A")

    return {"schema": "resolve-component-paths-diagnose/v1", "findings": findings, "warnings": warnings}


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
        "(T-001 interim input surface, still available when --target-rev "
        "is omitted). Omit to read from stdin.",
    )
    parser.add_argument(
        "--source-rev",
        default="HEAD",
        help="source revision for the git-diff basis (default: HEAD, T-002)",
    )
    parser.add_argument(
        "--target-rev",
        help="target revision (complete ref/OID) for the git-diff basis; "
        "supplying this switches to the real git-diff collector (T-002) "
        "instead of --changed-paths-file/stdin",
    )
    parser.add_argument(
        "--include-untracked",
        action="store_true",
        default=True,
        help="include untracked files in the git-diff basis (default: true)",
    )
    parser.add_argument(
        "--no-include-untracked",
        dest="include_untracked",
        action="store_false",
        help="exclude untracked files from the git-diff basis",
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="repository root the git-diff basis operates against (default: .)",
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
    parser.add_argument(
        "--schema-contract",
        default=SCHEMA_CONTRACT_PATH,
        help=f"JSON Schema path for --check-schema-conformance (default: {SCHEMA_CONTRACT_PATH})",
    )
    parser.add_argument(
        "--diagnose",
        action="store_true",
        help="T-004: resolver-only diagnostics (Fail-1/3/5/6-conditional), never Gate-invoked, "
        "no --facet-manifest input, exit code carries no Implementation Gate meaning",
    )
    parser.add_argument(
        "--provider-bindings",
        default="sdd/provider-bindings.yaml",
        help="path to the Provider Bindings file for --diagnose's Fail-6 (default: sdd/provider-bindings.yaml)",
    )
    args = parser.parse_args(argv)

    if args.check_schema_conformance:
        conformant, diagnostic = check_schema_conformance(args.schema, args.schema_contract)
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

    diff_basis: Optional[dict] = None
    if args.target_rev:
        try:
            diff_basis = collect_changed_paths(
                args.repo_root, args.source_rev, args.target_rev, args.include_untracked
            )
        except GitDiffError as exc:
            print(f"resolve-component-paths: {exc}", file=sys.stderr)
            return 1
        raw_paths = diff_basis["changed_paths"]
    else:
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

    if args.diagnose:
        diag = diagnose(result, args.provider_bindings)
        print(json.dumps(diag, indent=2, ensure_ascii=False, sort_keys=True))
        return 0

    if diff_basis is not None:
        classification_by_path = {r["raw_path"]: r for r in result["records"]}
        renames_with_evidence = []
        for rename in diff_basis["renames"]:
            old_rec = classification_by_path.get(rename["old_path"])
            new_rec = classification_by_path.get(rename["new_path"])
            old_owners = set(old_rec["owning_components"]) if old_rec else set()
            new_owners = set(new_rec["owning_components"]) if new_rec else set()
            renames_with_evidence.append(
                {
                    **rename,
                    "cross_component": old_owners != new_owners,
                }
            )
        result["diff_basis"] = {
            "source_oid": diff_basis["source_oid"],
            "target_oid": diff_basis["target_oid"],
            "baseline_oid": diff_basis["baseline_oid"],
            "renames": renames_with_evidence,
        }

    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
