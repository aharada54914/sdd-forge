#!/usr/bin/env python3
"""canonicalize-sdd-yaml: parse a restricted YAML subset (or JSON) and emit
RFC 8785 (JCS) canonical JSON bytes, or its SHA-256 hash.

REQ-003 (specs/epic-189-a1-project-context/design.md, "Canonicalization
procedure" and "Design Decisions" (parser library, REVISED 2026-07-24, human
decision-3 = B, reports/notes/epic-189-a1-decision-3-yaml-parser.md)).

This is a HAND-WRITTEN, stdlib-only, RESTRICTED YAML-SUBSET parser -- no
third-party YAML library (PyYAML/ruamel.yaml are explicitly retired for this
tool). It accepts exactly the subset project-context.yaml,
provider-bindings.yaml, sdd/approver-registry.yaml, and the staged approval
JSON objects actually use, and rejects everything else fail-closed with a
named, category-specific diagnostic -- never a best-effort interpretation.
Every other script in this epic that needs canonical bytes or a canonical
hash calls into this one script; none reimplements canonicalization
independently, and this script itself has exactly ONE behavioral
implementation (the thin `.sh`/`.ps1`/`.js` wrappers beside it dispatch to
this file; they never reimplement any of this logic).

Accepted subset (normative; design.md Design Decisions):
  - UTF-8, single document, no leading BOM, no document markers (`---`/`...`);
  - block mappings (`key: value`; `key:` + indented child block) and block
    sequences (`- item`; `- key: value` inline-mapping start), nested
    arbitrarily; indentation is spaces-only;
  - mapping keys: plain or quoted string scalars (a plain key resolving to a
    non-string core-schema type is rejected);
  - scalars: plain, single-quoted (`''` escaping), double-quoted (JSON's
    escape set exactly, including `\\uXXXX` with surrogate-pair merging);
    plain scalars resolve per the YAML 1.2 core schema to null/bool/number/
    string, with the YAML-1.1-only tokens (yes/no/on/off) remaining strings;
  - the empty flow collections `[]` and `{}` as complete values only;
  - full-line and space-preceded trailing `#` comments; blank lines.

Everything else -- anchors, aliases, non-core tags, duplicate keys,
non-string keys, multi-document streams, non-empty flow style, block
scalars, directives, explicit-key/merge-key syntax, tab indentation, an
unquoted scalar beginning with a reserved sigil, and any other out-of-subset
construct -- is rejected fail-closed with its own named category and a
stable, documented exit code (see CATEGORY_EXIT_CODES below and --help).

Output/exit contract: default invocation writes the canonical UTF-8 bytes to
stdout byte-exact (no diagnostic text on stdout) and exits 0; `--hash-only`
writes `sha256:<hex>\\n` to stdout and exits 0; any rejection exits non-zero
with the diagnostic on stderr only and writes nothing to stdout.
"""
import argparse
import hashlib
import json
import math
import re
import sys
import unicodedata

EXIT_OK = 0
EXIT_USAGE_ERROR = 2
# Reserved: the .sh/.ps1/.js wrappers beside this script use exit 3 for
# CANONICALIZER_RUNTIME_UNAVAILABLE when neither python3 nor python is on
# PATH. This script never raises it itself (if it is running, a compatible
# interpreter was already found) -- documented here so the full exit-code
# table lives in one place.
EXIT_RUNTIME_UNAVAILABLE = 3

CATEGORY_EXIT_CODES = {
    "CANONICALIZER_RUNTIME_UNAVAILABLE": EXIT_RUNTIME_UNAVAILABLE,
    "INVALID_UTF8_REJECTED": 10,
    "INVALID_JSON_REJECTED": 11,
    "ANCHOR_REJECTED": 20,
    "ALIAS_REJECTED": 21,
    "CUSTOM_TAG_REJECTED": 22,
    "DUPLICATE_KEY_REJECTED": 23,
    "NON_STRING_KEY_REJECTED": 24,
    "MULTI_DOCUMENT_REJECTED": 25,
    "UNSUPPORTED_SYNTAX_REJECTED": 26,
    "POST_NFC_DUPLICATE_KEY_REJECTED": 27,
    "NUMBER_OUT_OF_RANGE_REJECTED": 28,
}


class CanonicalizeError(Exception):
    """A fail-closed rejection. `category` is one of CATEGORY_EXIT_CODES's
    keys; `line_no` is 1-based and omitted (None) when not applicable
    (e.g. JSON-mode and whole-document errors)."""

    def __init__(self, category, message, line_no=None):
        super().__init__(message)
        self.category = category
        self.message = message
        self.line_no = line_no


def _unsupported(message, line_no=None, hint=None):
    if hint:
        message = f"{message} (hint: {hint})"
    return CanonicalizeError("UNSUPPORTED_SYNTAX_REJECTED", message, line_no)


# ---------------------------------------------------------------------------
# Shared UTF-8 / BOM handling
# ---------------------------------------------------------------------------

def _decode_and_check_bom(data):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise CanonicalizeError("INVALID_UTF8_REJECTED", f"input is not valid UTF-8: {exc}")
    if text.startswith("\ufeff"):
        raise _unsupported("a leading UTF-8 BOM is not accepted", line_no=1)
    return text


def _normalize_and_split(text):
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    return normalized.split("\n")


# ---------------------------------------------------------------------------
# JSON input mode (used for the HMAC preimage path, T-003)
# ---------------------------------------------------------------------------

def _json_object_pairs_hook(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise CanonicalizeError("DUPLICATE_KEY_REJECTED", f"duplicate JSON object key {key!r}")
        obj[key] = value
    return obj


def _json_reject_constant(constant_text):
    raise CanonicalizeError(
        "NUMBER_OUT_OF_RANGE_REJECTED",
        f"non-finite JSON constant {constant_text!r} is not accepted",
    )


def parse_json_bytes(data):
    text = _decode_and_check_bom(data)
    try:
        return json.loads(
            text,
            object_pairs_hook=_json_object_pairs_hook,
            parse_constant=_json_reject_constant,
        )
    except json.JSONDecodeError as exc:
        raise CanonicalizeError("INVALID_JSON_REJECTED", str(exc))


# ---------------------------------------------------------------------------
# YAML-subset input mode: document-marker detection
# ---------------------------------------------------------------------------

_DOC_START_RE = re.compile(r"^---(?:[ \t].*)?$")
_DOC_END_RE = re.compile(r"^\.\.\.(?:[ \t].*)?$")


def _check_document_markers(raw_lines):
    # 0-based line indices, distinct from the 1-based `.line_no` used
    # elsewhere in diagnostics.
    start_idxs = [i for i, raw in enumerate(raw_lines) if _DOC_START_RE.match(raw)]
    end_idxs = [i for i, raw in enumerate(raw_lines) if _DOC_END_RE.match(raw)]
    if not start_idxs and not end_idxs:
        return

    # A '---' line ALWAYS opens a new document, whether or not it is the
    # very first thing in the file: content before the first marker (if
    # any) is document 1, and each marker opens the next one. Segment the
    # stream at each '---' (the marker line itself carries no document
    # content) and count segments that hold real content -- that count is
    # the true number of documents, independent of how many marker lines
    # were used to produce it.
    seg_starts = [0] + [i + 1 for i in start_idxs]
    seg_ends = start_idxs + [len(raw_lines)]
    nonempty = [
        j for j, (a, b) in enumerate(zip(seg_starts, seg_ends))
        if _has_real_content(raw_lines[a:b])
    ]
    if len(nonempty) >= 2:
        marker_line_no = start_idxs[nonempty[1] - 1] + 1
        raise CanonicalizeError(
            "MULTI_DOCUMENT_REJECTED",
            f"{len(nonempty)} non-empty YAML documents detected in one stream; only a single document is accepted",
            marker_line_no,
        )
    first_marker_line = min(start_idxs + end_idxs) + 1
    raise _unsupported(
        "YAML document markers ('---' / '...') are not accepted; this parser accepts exactly one implicit document with no markers",
        first_marker_line,
    )


def _has_real_content(raw_lines_slice):
    for raw in raw_lines_slice:
        ws_len = _leading_ws_len(raw)
        rest = raw[ws_len:]
        if rest == "" or rest.startswith("#"):
            continue
        if _DOC_START_RE.match(raw) or _DOC_END_RE.match(raw):
            continue
        return True
    return False


# ---------------------------------------------------------------------------
# YAML-subset input mode: tokenizer (indentation + comments -> logical lines)
# ---------------------------------------------------------------------------

class LogicalLine:
    __slots__ = ("indent", "content", "line_no")

    def __init__(self, indent, content, line_no):
        self.indent = indent
        self.content = content
        self.line_no = line_no


def _leading_ws_len(raw):
    n = 0
    while n < len(raw) and raw[n] in (" ", "\t"):
        n += 1
    return n


def _strip_trailing_comment(rest):
    in_single = False
    in_double = False
    i = 0
    n = len(rest)
    while i < n:
        c = rest[i]
        if in_single:
            if c == "'":
                if i + 1 < n and rest[i + 1] == "'":
                    i += 2
                    continue
                in_single = False
            i += 1
            continue
        if in_double:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_double = False
            i += 1
            continue
        if c == "'":
            in_single = True
        elif c == '"':
            in_double = True
        elif c == "#" and i > 0 and rest[i - 1] in (" ", "\t"):
            return rest[:i].rstrip(" \t")
        i += 1
    return rest.rstrip(" \t")


def tokenize(text):
    raw_lines = _normalize_and_split(text)
    _check_document_markers(raw_lines)
    logical = []
    for idx, raw in enumerate(raw_lines):
        line_no = idx + 1
        ws_len = _leading_ws_len(raw)
        if "\t" in raw[:ws_len]:
            raise _unsupported("tab indentation is not accepted (indentation is spaces-only)", line_no)
        rest = raw[ws_len:]
        if rest == "" or rest.startswith("#"):
            continue
        content = _strip_trailing_comment(rest)
        if content == "":
            continue
        logical.append(LogicalLine(ws_len, content, line_no))
    return logical


# ---------------------------------------------------------------------------
# YAML-subset input mode: quoted-scalar parsing
# ---------------------------------------------------------------------------

def parse_single_quoted(s, start, line_no):
    i = start + 1
    n = len(s)
    out = []
    while True:
        if i >= n:
            raise _unsupported("unterminated single-quoted scalar", line_no)
        c = s[i]
        if c == "'":
            if i + 1 < n and s[i + 1] == "'":
                out.append("'")
                i += 2
                continue
            i += 1
            break
        out.append(c)
        i += 1
    return "".join(out), i


_DOUBLE_ESCAPES = {
    '"': '"', "\\": "\\", "/": "/", "b": "\b", "f": "\f",
    "n": "\n", "r": "\r", "t": "\t",
}
_HEX_DIGITS = set("0123456789abcdefABCDEF")


def _read_uescape(s, i, line_no):
    hex_part = s[i:i + 4]
    if len(hex_part) != 4 or any(ch not in _HEX_DIGITS for ch in hex_part):
        raise _unsupported("invalid \\u escape in double-quoted scalar", line_no)
    return int(hex_part, 16), i + 4


def parse_double_quoted(s, start, line_no):
    i = start + 1
    n = len(s)
    out = []
    while True:
        if i >= n:
            raise _unsupported("unterminated double-quoted scalar", line_no)
        c = s[i]
        if c == '"':
            i += 1
            break
        if c == "\\":
            if i + 1 >= n:
                raise _unsupported("trailing backslash in double-quoted scalar", line_no)
            nc = s[i + 1]
            if nc in _DOUBLE_ESCAPES:
                out.append(_DOUBLE_ESCAPES[nc])
                i += 2
                continue
            if nc == "u":
                code, i = _read_uescape(s, i + 2, line_no)
                if 0xD800 <= code <= 0xDBFF and s[i:i + 2] == "\\u":
                    code2, j = _read_uescape(s, i + 2, line_no)
                    if 0xDC00 <= code2 <= 0xDFFF:
                        out.append(chr(0x10000 + (code - 0xD800) * 0x400 + (code2 - 0xDC00)))
                        i = j
                        continue
                out.append(chr(code))
                continue
            raise _unsupported(f"unknown escape sequence '\\{nc}' in double-quoted scalar", line_no)
        out.append(c)
        i += 1
    return "".join(out), i


# ---------------------------------------------------------------------------
# YAML-subset input mode: core-schema plain-scalar resolution
# ---------------------------------------------------------------------------

_NULL_RE = re.compile(r"^(?:null|Null|NULL|~)$")
_BOOL_RE = re.compile(r"^(?:true|True|TRUE|false|False|FALSE)$")
_INT_DEC_RE = re.compile(r"^[-+]?[0-9]+$")
_INT_OCT_RE = re.compile(r"^0o[0-7]+$")
_INT_HEX_RE = re.compile(r"^0x[0-9a-fA-F]+$")
_FLOAT_RE = re.compile(r"^[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?$")
_FLOAT_INF_RE = re.compile(r"^([-+]?)\.(?:inf|Inf|INF)$")
_FLOAT_NAN_RE = re.compile(r"^\.(?:nan|NaN|NAN)$")

_RESERVED_SIGIL_CATEGORY = {"&": "ANCHOR_REJECTED", "*": "ALIAS_REJECTED", "!": "CUSTOM_TAG_REJECTED"}
_RESERVED_SIGIL_NAME = {"&": "anchor", "*": "alias", "!": "tag"}
_RESERVED_SIGIL_GENERIC = set("?%@`|>")


def resolve_core_schema_scalar(text):
    """Resolve a PLAIN (unquoted) scalar per the YAML 1.2 core schema.
    Quoted scalars never call this -- they are always type 'string'. Returns
    (type_name, value) with type_name in {'null','bool','number','string'};
    numbers collapse int/float into a single Python float, since RFC 8785
    JCS formats every JSON number identically regardless of the YAML tag
    that produced it."""
    if _NULL_RE.match(text):
        return "null", None
    if _BOOL_RE.match(text):
        return "bool", text[0] in "tT"
    if _INT_DEC_RE.match(text):
        return "number", float(text)
    if _INT_OCT_RE.match(text) or _INT_HEX_RE.match(text):
        try:
            return "number", float(int(text, 0))
        except OverflowError:
            return "number", math.inf
    m = _FLOAT_INF_RE.match(text)
    if m:
        return "number", (-math.inf if m.group(1) == "-" else math.inf)
    if _FLOAT_NAN_RE.match(text):
        return "number", math.nan
    if _FLOAT_RE.match(text):
        return "number", float(text)
    return "string", text


def _check_reserved_sigil(token, line_no):
    if not token:
        return
    c0 = token[0]
    if c0 in _RESERVED_SIGIL_CATEGORY:
        name = _RESERVED_SIGIL_NAME[c0]
        raise CanonicalizeError(
            _RESERVED_SIGIL_CATEGORY[c0],
            f"unquoted scalar uses a YAML {name} indicator ({c0!r}), which this restricted parser does not accept",
            line_no,
        )
    if c0 in _RESERVED_SIGIL_GENERIC:
        raise _unsupported(
            f"unquoted scalar begins with the reserved indicator character {c0!r}",
            line_no,
            hint="quote the scalar",
        )


# ---------------------------------------------------------------------------
# YAML-subset input mode: recursive-descent block parser
# ---------------------------------------------------------------------------

def is_sequence_item(content):
    return content == "-" or content.startswith("- ")


def _looks_like_mapping_entry(content):
    """Non-raising probe used only to choose mapping-vs-scalar parsing: does
    `content` actually start a mapping entry? A quoted token only counts if
    a ':' immediately follows its closing quote -- otherwise a bare quoted
    scalar (e.g. a whole-document value) would be misrouted into mapping
    parsing. Malformed quoting here is not itself an error: the real parse
    (parse_key_part_and_rest / resolve_value_str) reports it properly."""
    c0 = content[0]
    if c0 == "'":
        try:
            _, end = parse_single_quoted(content, 0, None)
        except CanonicalizeError:
            return False
        return content[end:end + 1] == ":"
    if c0 == '"':
        try:
            _, end = parse_double_quoted(content, 0, None)
        except CanonicalizeError:
            return False
        return content[end:end + 1] == ":"
    return content.find(": ") != -1 or content.endswith(":")


def parse_key_part_and_rest(content, line_no):
    """Split `content` (one logical line, e.g. "key: value" or "key:") into
    (key_str, val_str_or_None). Raises on anything outside the accepted
    subset."""
    if content[0] == "'":
        key_str, rest_start = parse_single_quoted(content, 0, line_no)
    elif content[0] == '"':
        key_str, rest_start = parse_double_quoted(content, 0, line_no)
    else:
        idx = content.find(": ")
        if idx == -1:
            if content.endswith(":"):
                idx = len(content) - 1
            else:
                raise _unsupported(
                    "expected a mapping entry ('key: value' or 'key:'); no unquoted ': ' separator found",
                    line_no,
                    hint="quote the scalar if this is meant as plain text",
                )
        key_token = content[:idx].rstrip(" ")
        if key_token == "":
            raise _unsupported("empty mapping key", line_no)
        _check_reserved_sigil(key_token, line_no)
        key_type, key_value = resolve_core_schema_scalar(key_token)
        if key_type != "string":
            raise CanonicalizeError(
                "NON_STRING_KEY_REJECTED",
                f"mapping key {key_token!r} resolves to YAML core-schema type {key_type!r}, not string",
                line_no,
            )
        key_str, rest_start = key_value, idx

    if content[rest_start:rest_start + 1] != ":":
        raise _unsupported("expected ':' immediately after the quoted key", line_no)
    after_colon = rest_start + 1
    if after_colon >= len(content):
        return key_str, None
    if content[after_colon] != " ":
        raise _unsupported(
            "mapping ':' must be followed by a space or end of line",
            line_no,
            hint="quote the scalar if this is meant as plain text",
        )
    val_str = content[after_colon + 1:].lstrip(" ")
    return key_str, (val_str or None)


def resolve_value_str(val_str, line_no):
    c0 = val_str[0]
    if c0 == "'":
        s, end = parse_single_quoted(val_str, 0, line_no)
        if end != len(val_str):
            raise _unsupported("unexpected content after a single-quoted scalar value", line_no)
        return s
    if c0 == '"':
        s, end = parse_double_quoted(val_str, 0, line_no)
        if end != len(val_str):
            raise _unsupported("unexpected content after a double-quoted scalar value", line_no)
        return s
    if val_str == "[]":
        return []
    if val_str == "{}":
        return {}
    if c0 in "[{":
        raise _unsupported(
            "non-empty flow-style collections are not accepted; only the empty forms '[]'/'{}' are",
            line_no,
        )
    if c0 in "]},":
        raise _unsupported(f"unexpected flow indicator character {c0!r}", line_no, hint="quote the scalar")
    _check_reserved_sigil(val_str, line_no)
    _, value = resolve_core_schema_scalar(val_str)
    return value


def _add_key(mapping, key, value, line_no):
    if key in mapping:
        raise CanonicalizeError("DUPLICATE_KEY_REJECTED", f"duplicate mapping key {key!r}", line_no)
    mapping[key] = value


def _resolve_entry_value(lines, i, indent, val_str, line_no):
    """Shared tail of one mapping-entry line: given the already-split
    val_str (None means "value is a nested block, or null"), returns
    (value, next_i)."""
    n = len(lines)
    if val_str is None:
        if i < n and lines[i].indent > indent:
            return parse_block(lines, i, lines[i].indent)
        return None, i
    return resolve_value_str(val_str, line_no), i


def parse_block(lines, i, indent):
    if is_sequence_item(lines[i].content):
        return parse_sequence(lines, i, indent)
    return parse_mapping(lines, i, indent)


def parse_sequence(lines, i, indent):
    items = []
    n = len(lines)
    while i < n and lines[i].indent == indent and is_sequence_item(lines[i].content):
        line = lines[i]
        rest = line.content[1:]
        if rest == "":
            i += 1
            value, i = _resolve_entry_value(lines, i, indent, None, line.line_no)
        else:
            inline = rest[1:]
            if inline == "":
                raise _unsupported("sequence item marker '- ' must be followed by a value or nothing", line.line_no)
            if _looks_like_mapping_entry(inline):
                value, i = parse_inline_mapping_start(lines, i, indent, inline)
            else:
                value = resolve_value_str(inline, line.line_no)
                i += 1
        items.append(value)
    return items, i


def _parse_mapping_entries(lines, i, indent, mapping):
    n = len(lines)
    while i < n and lines[i].indent == indent:
        content = lines[i].content
        if is_sequence_item(content):
            raise _unsupported(
                "sequence item marker where a mapping key was expected (same-indent block "
                "sequences are not supported by this restricted parser; indent sequence "
                "items under their key)",
                lines[i].line_no,
            )
        line_no = lines[i].line_no
        key_str, val_str = parse_key_part_and_rest(content, line_no)
        i += 1
        value, i = _resolve_entry_value(lines, i, indent, val_str, line_no)
        _add_key(mapping, key_str, value, line_no)
    return i


def parse_mapping(lines, i, indent):
    mapping = {}
    i = _parse_mapping_entries(lines, i, indent, mapping)
    return mapping, i


def parse_inline_mapping_start(lines, i, seq_indent, first_inline_content):
    """Parse "- key: value" (and any following same-mapping sibling keys at
    seq_indent + 2, e.g. a `key1: v1` / `  key2: v2` pair under one item)."""
    mapping = {}
    child_indent = seq_indent + 2
    line_no = lines[i].line_no
    key_str, val_str = parse_key_part_and_rest(first_inline_content, line_no)
    i += 1
    value, i = _resolve_entry_value(lines, i, child_indent, val_str, line_no)
    _add_key(mapping, key_str, value, line_no)
    i = _parse_mapping_entries(lines, i, child_indent, mapping)
    return mapping, i


def parse_document(lines):
    if not lines:
        return None
    first = lines[0]
    if first.indent != 0:
        raise _unsupported("document root must start at column 0 (unexpected indentation)", first.line_no)
    if is_sequence_item(first.content):
        value, i = parse_sequence(lines, 0, 0)
    elif _looks_like_mapping_entry(first.content):
        value, i = parse_mapping(lines, 0, 0)
    else:
        if len(lines) != 1:
            raise _unsupported(
                "multiple top-level lines but the document root is not a mapping or sequence",
                lines[1].line_no,
            )
        value, i = resolve_value_str(first.content, first.line_no), 1
    if i != len(lines):
        raise _unsupported("unexpected content after the document's top-level value (bad indentation?)", lines[i].line_no)
    return value


def parse_yaml_bytes(data):
    text = _decode_and_check_bom(data)
    return parse_document(tokenize(text))


# ---------------------------------------------------------------------------
# Post-parse walk: NFC normalization, post-NFC duplicate-key detection,
# non-finite/out-of-range number rejection (procedure steps 3-4)
# ---------------------------------------------------------------------------

def normalize_and_validate(node):
    if isinstance(node, dict):
        result = {}
        seen = {}
        for k, v in node.items():
            nk = unicodedata.normalize("NFC", k)
            if nk in seen:
                raise CanonicalizeError(
                    "POST_NFC_DUPLICATE_KEY_REJECTED",
                    f"keys {seen[nk]!r} and {k!r} both normalize (NFC) to {nk!r}",
                )
            seen[nk] = k
            result[nk] = normalize_and_validate(v)
        return result
    if isinstance(node, list):
        return [normalize_and_validate(item) for item in node]
    if isinstance(node, str):
        return unicodedata.normalize("NFC", node)
    if isinstance(node, bool) or node is None:
        return node
    if isinstance(node, float):
        if math.isinf(node) or math.isnan(node):
            raise CanonicalizeError(
                "NUMBER_OUT_OF_RANGE_REJECTED",
                f"numeric value {node!r} is non-finite or exceeds the IEEE-754 double-precision representable range",
            )
        return node
    if isinstance(node, int):
        # JSON-input mode only: json.loads yields native Python ints for
        # integer literals. Convert to the double value RFC 8785 numbers are
        # formatted from, then apply the same finiteness/range check.
        try:
            d = float(node)
        except OverflowError:
            d = math.inf if node > 0 else -math.inf
        if math.isinf(d) or math.isnan(d):
            raise CanonicalizeError(
                "NUMBER_OUT_OF_RANGE_REJECTED",
                f"integer value {node} exceeds the IEEE-754 double-precision representable range",
            )
        return d
    raise AssertionError(f"unexpected parsed node type: {type(node)!r}")


# ---------------------------------------------------------------------------
# RFC 8785 (JCS) canonical serialization
# ---------------------------------------------------------------------------

def _shortest_digits_and_exponent(abs_v):
    """Extract (digits, n) from Python's own shortest-round-trip repr() such
    that abs_v == 0.<digits> * 10**n, with `digits` having no leading or
    trailing zeros (Python's float repr has been shortest-round-trip since
    3.1, so this reuses it rather than re-deriving Grisu/Ryu from scratch)."""
    text = repr(abs_v)
    if "e" in text or "E" in text:
        mantissa, exp_text = re.split("[eE]", text)
        exp = int(exp_text)
    else:
        mantissa, exp = text, 0
    int_part, _, frac_part = mantissa.partition(".")
    all_digits = int_part + frac_part
    point_pos = len(int_part)
    stripped = all_digits.lstrip("0")
    point_pos -= len(all_digits) - len(stripped)
    all_digits = (stripped or "0").rstrip("0") or "0"
    return all_digits, point_pos + exp


def _format_jcs_number(v):
    """Format a finite double per RFC 8785 section 3.2.2.3: the same
    algorithm as ECMAScript's Number::toString (shortest round-trip decimal;
    fixed notation for -6 < n <= 21 in spec terms, else exponential with no
    leading zero in the exponent)."""
    if v == 0.0:
        return "0"
    sign = ""
    if v < 0:
        sign, v = "-", -v
    digits, n = _shortest_digits_and_exponent(v)
    k = len(digits)
    if k <= n <= 21:
        return sign + digits + ("0" * (n - k))
    if 0 < n <= 21:
        return sign + digits[:n] + "." + digits[n:]
    if -6 < n <= 0:
        return sign + "0." + ("0" * (-n)) + digits
    e = n - 1
    mantissa = digits if k == 1 else digits[0] + "." + digits[1:]
    return sign + mantissa + "e" + ("+" if e >= 0 else "-") + str(abs(e))


_JCS_ESCAPES = {
    '"': b'\\"', "\\": b"\\\\", "\b": b"\\b", "\f": b"\\f",
    "\n": b"\\n", "\r": b"\\r", "\t": b"\\t",
}


def _jcs_escape_string(s):
    out = [b'"']
    for ch in s:
        if ch in _JCS_ESCAPES:
            out.append(_JCS_ESCAPES[ch])
        elif ord(ch) < 0x20:
            out.append(("\\u%04x" % ord(ch)).encode("ascii"))
        else:
            out.append(ch.encode("utf-8"))
    out.append(b'"')
    return b"".join(out)


def jcs_serialize(value):
    if value is None:
        return b"null"
    if isinstance(value, bool):
        return b"true" if value else b"false"
    if isinstance(value, float):
        return _format_jcs_number(value).encode("ascii")
    if isinstance(value, str):
        return _jcs_escape_string(value)
    if isinstance(value, list):
        return b"[" + b",".join(jcs_serialize(v) for v in value) + b"]"
    if isinstance(value, dict):
        items = sorted(value.items(), key=lambda kv: kv[0].encode("utf-16-be"))
        parts = [_jcs_escape_string(k) + b":" + jcs_serialize(v) for k, v in items]
        return b"{" + b",".join(parts) + b"}"
    raise AssertionError(f"unexpected canonical node type: {type(value)!r}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

_EXIT_CODE_HELP = "\n".join(
    f"  {code:>3}  {name}" for name, code in sorted(CATEGORY_EXIT_CODES.items(), key=lambda kv: kv[1])
)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="canonicalize-sdd-yaml.py",
        description=(
            "Parse a restricted YAML subset (or JSON, with --input-format json) "
            "and emit RFC 8785 (JCS) canonical JSON bytes on stdout, or its "
            "SHA-256 hash with --hash-only."
        ),
        epilog="Exit codes (stable, one per rejection category):\n"
        f"    0  success\n"
        f"  {EXIT_USAGE_ERROR:>3}  usage error (bad arguments, unreadable file)\n"
        f"{_EXIT_CODE_HELP}\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("file", help="path to the YAML or JSON file to canonicalize")
    parser.add_argument(
        "--hash-only",
        action="store_true",
        help="write 'sha256:<hex>\\n' instead of the canonical bytes",
    )
    parser.add_argument(
        "--input-format",
        choices=("yaml", "json"),
        default=None,
        help="input format; default: 'json' when <file> ends in .json (case-insensitive), else 'yaml'",
    )
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        with open(args.file, "rb") as f:
            data = f.read()
    except OSError as exc:
        print(f"canonicalize-sdd-yaml: usage error: cannot read file {args.file!r}: {exc}", file=sys.stderr)
        return EXIT_USAGE_ERROR

    input_format = args.input_format or ("json" if args.file.lower().endswith(".json") else "yaml")

    try:
        value = parse_json_bytes(data) if input_format == "json" else parse_yaml_bytes(data)
        value = normalize_and_validate(value)
        canonical_bytes = jcs_serialize(value)
    except CanonicalizeError as exc:
        location = f" (line {exc.line_no})" if exc.line_no else ""
        print(f"canonicalize-sdd-yaml: {exc.category}{location}: {exc.message}", file=sys.stderr)
        return CATEGORY_EXIT_CODES[exc.category]

    if args.hash_only:
        digest = hashlib.sha256(canonical_bytes).hexdigest()
        sys.stdout.buffer.write(f"sha256:{digest}\n".encode("ascii"))
    else:
        sys.stdout.buffer.write(canonical_bytes)
    sys.stdout.buffer.flush()
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
