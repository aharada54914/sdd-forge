#!/usr/bin/env bash
# Deterministic validator for a domain-contract/v2 contract file.
#
# Usage: validate-domain-contract.sh <contract.json>
#
# Issue #290, sdd-domain-concept-contract Phase 0. This file is the bash half
# of the sh/ps1 twin pair; validate-domain-contract.ps1 is the other half and
# must stay verdict-identical to it (REQ-006 twin parity, checked by T-005).
#
# T-002 implements REQ-004 steps (a) fail-closed JSON parse and (b) `schema`
# value dispatch, plus the shared skeleton the later steps extend:
#   - one `RULE-ID: message` line per violation on stderr, nothing on stdout,
#     exit 0 or 1 only, never a partial verdict (design.md DD-7);
#   - a single violation accumulator that T-003 (structural checks, REQ-004(c))
#     and T-004 (cross-reference checks, REQ-004(d)-(i)) append to through the
#     `check_structure` / `check_cross_references` extension points below.
#     Later steps must not introduce a second output path.
#
# No external dependency: a single python3 invocation using only the stdlib
# `json` module. No external JSON-Schema engine of any kind, no network, and
# no writes (design.md DD-4, INV-005, security-spec.md).
#
# Contract content is data, never instruction: no value read from the contract
# is ever used to build a command, resolve a path, or reach `eval`
# (security-spec.md content-as-data rule).
set -euo pipefail

emit() { printf '%s: %s\n' "$1" "$2" >&2; }

if [ "$#" -ne 1 ]; then
  emit 'V2-USAGE' 'exactly one argument is required: validate-domain-contract.sh <contract.json>'
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  emit 'V2-RUNTIME' 'python3 is required by this validator and was not found on PATH'
  exit 1
fi

python3 - "$1" <<'PY'
import json
import os
import sys

# The oversized-input ceiling (requirements.md Edge Cases: a contract file
# exceeding 10MB is abnormal input the validator rejects fail-closed, without
# a best-effort parse). Checked BEFORE the file is read, so an oversized input
# is never parsed at all. Keep identical to $MaxContractBytes in the .ps1 twin.
MAX_CONTRACT_BYTES = 10 * 1024 * 1024

EXPECTED_SCHEMA = "domain-contract/v2"

# Longest interpolated fragment allowed in one violation message.
MESSAGE_VALUE_LIMIT = 120

# The single violation accumulator. Every check appends `RULE-ID: message`
# strings here; nothing writes to stderr directly. Exit status is 1 when this
# list is non-empty and 0 when it is empty -- there is no third outcome.
violations = []


def add(rule_id, message):
    violations.append("%s: %s" % (rule_id, message))


def safe(value):
    """Render an untrusted value for a one-line stderr message.

    Control characters would break the one-violation-per-line contract, so
    they are folded to spaces; the result is truncated so a large value cannot
    flood stderr. Purely a rendering step -- the value is never interpreted.
    """
    text = value if isinstance(value, str) else str(value)
    cleaned = []
    for character in text:
        code = ord(character)
        cleaned.append(" " if code < 32 or code == 127 else character)
    rendered = "".join(cleaned)
    if len(rendered) > MESSAGE_VALUE_LIMIT:
        rendered = rendered[:MESSAGE_VALUE_LIMIT] + "..."
    return rendered


def json_type_name(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, str):
        return "string"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return "unknown"


def finish():
    for line in violations:
        sys.stderr.write(line + "\n")
    sys.stderr.flush()
    sys.exit(1 if violations else 0)


def check_structure(document, add_violation):
    """REQ-004(c) -- required keys, JSON type conformance, pattern, minLength,
    minItems, in that order (type conformance precedes the rest).

    EXTENSION POINT owned by T-003. Append violations through `add_violation`;
    do not write to stderr and do not exit from here. Runs only after the
    document has been admitted as domain-contract/v2 by the dispatch above.
    Rule ids: V2-TYPE-MISMATCH / V2-MISSING-KEY / V2-PATTERN /
    V2-EMPTY-ARRAY / V2-EMPTY-STRING (design.md Error Handling).
    """
    return


def check_cross_references(document, add_violation):
    """REQ-004(d)-(i) -- duplicate concept ids, dangling concept.context,
    dangling distinguished_from.concept_id, dangling term.concept_id,
    responsibilities/must_not_own self-contradiction, duplicate concept name
    within one context.

    EXTENSION POINT owned by T-004. Same rules as check_structure: append
    through `add_violation` only. Rule ids: V2-DUP-CONCEPT-ID /
    V2-DANGLING-CONTEXT / V2-DANGLING-DISTINCTION / V2-DANGLING-TERM /
    V2-SELF-CONTRADICTION / V2-DUP-NAME-IN-CONTEXT.
    """
    return


def run(path):
    # --- Step (a): fail-closed acquisition and parse of the input ----------
    if not os.path.exists(path):
        add("V2-INPUT-NOT-FOUND", "input path does not exist: %s" % safe(path))
        finish()
    if not os.path.isfile(path):
        add("V2-INPUT-NOT-FILE", "input path is not a regular file: %s" % safe(path))
        finish()
    try:
        size = os.path.getsize(path)
    except OSError:
        add("V2-INPUT-UNREADABLE", "input path could not be read: %s" % safe(path))
        finish()
    if size > MAX_CONTRACT_BYTES:
        add(
            "V2-INPUT-TOO-LARGE",
            "input is %d bytes, above the %d byte ceiling; the file is rejected without being parsed"
            % (size, MAX_CONTRACT_BYTES),
        )
        finish()
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except OSError:
        add("V2-INPUT-UNREADABLE", "input path could not be read: %s" % safe(path))
        finish()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        add("V2-PARSE", "input is not valid UTF-8 text and cannot be parsed as JSON")
        finish()
    # Strip a leading UTF-8 BOM if present, so both twins see the same text.
    if text[:1] == "\ufeff":
        text = text[1:]
    try:
        document = json.loads(text)
    except ValueError:
        add("V2-PARSE", "input is not well-formed JSON and was not parsed further")
        finish()

    # --- Step (b): dispatch on the declared `schema` value (DD-6) ----------
    # A document that does not identify itself as domain-contract/v2 is not
    # measured against v2's structure; it is rejected here with one named
    # line. The three non-v2-value branches use the structural rule ids
    # design.md Error Handling assigns, so T-003's structural pass inherits
    # them unchanged rather than having to restate them.
    if not isinstance(document, dict):
        add(
            "V2-TYPE-MISMATCH",
            "root: expected object, found %s" % json_type_name(document),
        )
        finish()
    if "schema" not in document:
        add("V2-MISSING-KEY", "schema: required key is absent at the contract root")
        finish()
    schema_value = document["schema"]
    if not isinstance(schema_value, str):
        add(
            "V2-TYPE-MISMATCH",
            "schema: expected string, found %s" % json_type_name(schema_value),
        )
        finish()
    if schema_value != EXPECTED_SCHEMA:
        add(
            "V2-WRONG-SCHEMA",
            "schema is %s; this validator checks %s only"
            % (safe(schema_value), EXPECTED_SCHEMA),
        )
        finish()

    # --- Steps (c) and (d)-(i): appended by T-003 and T-004 ---------------
    check_structure(document, add)
    check_cross_references(document, add)
    finish()


try:
    run(sys.argv[1])
except SystemExit:
    raise
except BaseException:
    # Fail closed with a single line. No traceback and no interpreter
    # exception text ever reaches stderr (requirements.md Edge Cases,
    # security-spec.md fail-closed parsing).
    sys.stderr.write("V2-INTERNAL: the validator stopped on an unexpected internal error\n")
    sys.exit(1)
PY
