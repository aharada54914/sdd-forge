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
import re
import sys

# The oversized-input ceiling (requirements.md Edge Cases: a contract file
# exceeding 10MB is abnormal input the validator rejects fail-closed, without
# a best-effort parse). Checked BEFORE the file is read, so an oversized input
# is never parsed at all. Keep identical to $MaxContractBytes in the .ps1 twin.
MAX_CONTRACT_BYTES = 10 * 1024 * 1024

EXPECTED_SCHEMA = "domain-contract/v2"

# Longest interpolated fragment allowed in one violation message.
MESSAGE_VALUE_LIMIT = 120

# The three patterns requirements.md `## Field Definitions` declares (T-003,
# REQ-002). Each is kept in two forms: the declared source text, which is what
# a violation message quotes back to the author, and the compiled form used to
# test a value. The compiled form is anchored with \A ... \Z rather than
# ^ ... $ because a Python `$` also matches immediately before a trailing
# newline, which would accept "Order\n" as a valid concept name. Keep both
# forms identical to the $Concept*/$Context* pair in the .ps1 twin.
CONCEPT_ID_PATTERN_TEXT = "^CONCEPT-[A-Z][A-Z0-9-]*$"
CONCEPT_ID_RE = re.compile(r"\ACONCEPT-[A-Z][A-Z0-9-]*\Z")
CONCEPT_NAME_PATTERN_TEXT = "^[A-Z][A-Za-z0-9]*$"
CONCEPT_NAME_RE = re.compile(r"\A[A-Z][A-Za-z0-9]*\Z")
CONTEXT_PATTERN_TEXT = "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
CONTEXT_RE = re.compile(r"\A[a-z][a-z0-9]*(-[a-z0-9]+)*\Z")

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


def type_matches(value, expected):
    """Does `value`'s JSON type equal the type Field Definitions declares?

    `bool` is deliberately not accepted as a number: json_type_name reports it
    as "boolean", and no declared field has a boolean type.
    """
    if expected == "string":
        return isinstance(value, str)
    if expected == "array":
        return isinstance(value, list)
    if expected == "object":
        return isinstance(value, dict)
    return False


def check_member(container, key, expected, path, add_violation,
                 required=True, at_root=False):
    """The single type-then-presence gate every declared member passes through.

    This function is where REQ-004(c)'s precedence rule lives: it returns the
    value ONLY when the member is present and its JSON type conforms. Every
    caller treats a `None` return as "stop -- do not run pattern, minLength or
    minItems on this value", which is what keeps a mistyped field away from a
    regex or a len() and out of a raw interpreter exception.
    """
    if key not in container:
        if required:
            if at_root:
                add_violation(
                    "V2-MISSING-KEY",
                    "%s: required key is absent at the contract root" % path,
                )
            else:
                add_violation("V2-MISSING-KEY", "%s: required key is absent" % path)
        return None
    value = container[key]
    if not type_matches(value, expected):
        add_violation(
            "V2-TYPE-MISMATCH",
            "%s: expected %s, found %s" % (path, expected, json_type_name(value)),
        )
        return None
    return value


def check_pattern(value, compiled, pattern_text, path, add_violation):
    if compiled.match(value) is None:
        add_violation(
            "V2-PATTERN",
            "%s: value %s does not match %s" % (path, safe(value), pattern_text),
        )


def check_non_empty_string(value, path, add_violation):
    if len(value) == 0:
        add_violation(
            "V2-EMPTY-STRING",
            "%s: value is an empty string; at least one character is required" % path,
        )


def check_string_array(values, path, add_violation, min_items_one):
    """minItems, then per-element type, then per-element minLength."""
    if min_items_one and len(values) == 0:
        add_violation(
            "V2-EMPTY-ARRAY",
            "%s: array is empty; at least one entry is required" % path,
        )
        return
    for index, item in enumerate(values):
        item_path = "%s[%d]" % (path, index)
        if not isinstance(item, str):
            add_violation(
                "V2-TYPE-MISMATCH",
                "%s: expected string, found %s" % (item_path, json_type_name(item)),
            )
            continue
        check_non_empty_string(item, item_path, add_violation)


def check_object_array(values, path, add_violation, member_check):
    """Walks an array of objects, reporting any element that is not an object
    and handing the ones that are to `member_check`. An element that fails the
    type check is never handed on, so its required-key checks never run on a
    non-object (REQ-004(c) precedence, one level down)."""
    for index, entry in enumerate(values):
        entry_path = "%s[%d]" % (path, index)
        if not isinstance(entry, dict):
            add_violation(
                "V2-TYPE-MISMATCH",
                "%s: expected object, found %s" % (entry_path, json_type_name(entry)),
            )
            continue
        member_check(entry, entry_path)


def check_concept(concept, path, add_violation):
    """One concepts[] element against requirements.md `## Field Definitions`."""
    value = check_member(concept, "id", "string", path + ".id", add_violation)
    if value is not None:
        check_pattern(value, CONCEPT_ID_RE, CONCEPT_ID_PATTERN_TEXT,
                      path + ".id", add_violation)

    value = check_member(concept, "name", "string", path + ".name", add_violation)
    if value is not None:
        check_pattern(value, CONCEPT_NAME_RE, CONCEPT_NAME_PATTERN_TEXT,
                      path + ".name", add_violation)

    value = check_member(concept, "context", "string", path + ".context", add_violation)
    if value is not None:
        check_pattern(value, CONTEXT_RE, CONTEXT_PATTERN_TEXT,
                      path + ".context", add_violation)

    for key in ("definition", "essence"):
        member_path = "%s.%s" % (path, key)
        value = check_member(concept, key, "string", member_path, add_violation)
        if value is not None:
            check_non_empty_string(value, member_path, add_violation)

    for key in ("responsibilities", "evidence"):
        member_path = "%s.%s" % (path, key)
        value = check_member(concept, key, "array", member_path, add_violation)
        if value is not None:
            check_string_array(value, member_path, add_violation, True)

    # must_not_own is optional and declares no minItems: an absent key and an
    # empty array are both valid (requirements.md Edge Cases).
    member_path = path + ".must_not_own"
    value = check_member(concept, "must_not_own", "array", member_path,
                         add_violation, required=False)
    if value is not None:
        check_string_array(value, member_path, add_violation, False)

    member_path = path + ".stakeholder_perspectives"
    value = check_member(concept, "stakeholder_perspectives", "array", member_path,
                         add_violation, required=False)
    if value is not None:
        def check_perspective(entry, entry_path):
            for key in ("actor", "concern"):
                field_path = "%s.%s" % (entry_path, key)
                text = check_member(entry, key, "string", field_path, add_violation)
                if text is not None:
                    check_non_empty_string(text, field_path, add_violation)

        check_object_array(value, member_path, add_violation, check_perspective)

    member_path = path + ".distinguished_from"
    value = check_member(concept, "distinguished_from", "array", member_path,
                         add_violation, required=False)
    if value is not None:
        def check_distinction(entry, entry_path):
            # This pass fixes only the declared JSON type of concept_id. Its
            # pattern is AC-022 and its dangling-reference check is AC-008,
            # both allocated to T-004 (tasks.md Negative Fixture Allocation).
            check_member(entry, "concept_id", "string",
                         entry_path + ".concept_id", add_violation)
            reasons_path = entry_path + ".reasons"
            reasons = check_member(entry, "reasons", "array", reasons_path,
                                   add_violation)
            if reasons is not None:
                check_string_array(reasons, reasons_path, add_violation, True)

        check_object_array(value, member_path, add_violation, check_distinction)


def check_contexts(contexts, add_violation):
    """The one member requirements.md `## Field Definitions` declares inside
    the contexts subtree is `contexts[].terms[].concept_id` -- the v2 addition
    (REQ-003). The v1-inherited boundedContext / term shape around it is
    declared by the schema file but is outside this pass's authority table and
    outside the Negative-path coverage matrix, so a non-conforming intermediate
    is walked past here rather than reported."""
    for index, entry in enumerate(contexts):
        if not isinstance(entry, dict):
            continue
        terms = entry.get("terms")
        if not isinstance(terms, list):
            continue
        for term_index, term in enumerate(terms):
            if not isinstance(term, dict):
                continue
            if "concept_id" not in term:
                continue
            check_member(
                term,
                "concept_id",
                "string",
                "contexts[%d].terms[%d].concept_id" % (index, term_index),
                add_violation,
                required=False,
            )


def check_structure(document, add_violation):
    """REQ-004(c) -- JSON type conformance, then required-key presence, then
    pattern, minLength and minItems; a value whose type does not conform is
    recorded and then excluded from the later checks.

    Owned by T-003. Appends through `add_violation` only: it does not write to
    stderr and does not exit. Runs only after the document has been admitted as
    domain-contract/v2 by the dispatch below. Rule ids: V2-TYPE-MISMATCH /
    V2-MISSING-KEY / V2-PATTERN / V2-EMPTY-ARRAY / V2-EMPTY-STRING (design.md
    Error Handling).
    """
    # `schema` is deliberately absent from this pass: admission has already
    # established that it is present, a string, and equal to domain-contract/v2,
    # so re-checking it here would emit that violation twice.
    meta = check_member(document, "meta", "object", "meta", add_violation,
                        at_root=True)
    if meta is not None:
        check_member(meta, "version", "string", "meta.version", add_violation)
        check_member(meta, "status", "string", "meta.status", add_violation)
        check_member(meta, "generated_from", "array", "meta.generated_from",
                     add_violation)

    contexts = check_member(document, "contexts", "array", "contexts",
                            add_violation, at_root=True)
    if contexts is not None:
        check_contexts(contexts, add_violation)

    concepts = check_member(document, "concepts", "array", "concepts",
                            add_violation, at_root=True)
    if concepts is not None:
        if len(concepts) == 0:
            # minItems 1 -- distinct from the absent-key path above, which is
            # why the rule id differs (AC-016 versus AC-021(4)).
            add_violation(
                "V2-EMPTY-ARRAY",
                "concepts: array is empty; at least one entry is required",
            )
        else:
            check_object_array(
                concepts,
                "concepts",
                add_violation,
                lambda entry, entry_path: check_concept(entry, entry_path,
                                                        add_violation),
            )


def reference_well_formed(value, path, add_violation):
    """Is this reference value a well-formed concept id?

    A reference whose value does not match the concept-id pattern is a
    MALFORMED reference, which is a different defect from a well-formed
    reference that resolves to nothing (AC-022 versus AC-008 / AC-009). It is
    reported here as V2-PATTERN, in the wording check_pattern already uses,
    and is then excluded from resolution. That is REQ-004(c)'s precedence idea
    one level further down: type before pattern, pattern before reference
    resolution. A reader can therefore always tell which of the two defects
    fired, and neither value is ever reported twice.
    """
    if CONCEPT_ID_RE.match(value) is not None:
        return True
    check_pattern(value, CONCEPT_ID_RE, CONCEPT_ID_PATTERN_TEXT, path, add_violation)
    return False


def declared_string_values(entries, key):
    """The set of `key` values across an array of objects.

    Only entries that are objects whose `key` is present and a string are
    indexed. A value that is not a string was already reported by the
    structural pass and can never be equal to a well-formed reference, so
    leaving it out changes no verdict. Membership is raw string equality, so
    the index is case-significant.
    """
    found = set()
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        value = entry.get(key)
        if isinstance(value, str):
            found.add(value)
    return found


def check_cross_references(document, add_violation):
    """REQ-004(d)-(i) -- duplicate concept ids, dangling concept.context,
    dangling distinguished_from.concept_id, dangling term.concept_id,
    responsibilities/must_not_own self-contradiction, duplicate concept name
    within one context. Also the pattern check for the two reference fields
    that share the concept-id pattern (AC-022), which T-003 left here so that
    the malformed and unresolvable cases could be told apart in one place.

    Owned by T-004. Same rules as check_structure: append through
    `add_violation` only; it does not write to stderr and does not exit. Rule
    ids: V2-DUP-CONCEPT-ID / V2-DANGLING-CONTEXT / V2-DANGLING-DISTINCTION /
    V2-DANGLING-TERM / V2-SELF-CONTRADICTION / V2-DUP-NAME-IN-CONTEXT, plus
    V2-PATTERN for a malformed reference (design.md Error Handling).

    These six checks are why this validator exists rather than a JSON Schema
    run: draft-07 cannot express referential integrity (DD-1, INV-003).
    """
    concepts = document.get("concepts")
    contexts = document.get("contexts")
    concepts_declared = isinstance(concepts, list)
    contexts_declared = isinstance(contexts, list)

    # The two referent indexes, each built only when the array it comes from
    # really is an array. When `concepts` or `contexts` is absent or mistyped
    # the structural pass has already reported that root cause; resolving
    # references against an index that could not be built would add a cascade
    # of derived failures naming fields the author did not get wrong.
    declared_concept_ids = None
    if concepts_declared:
        declared_concept_ids = declared_string_values(concepts, "id")
    declared_context_names = None
    if contexts_declared:
        declared_context_names = declared_string_values(contexts, "name")

    if concepts_declared:
        # --- (d) duplicate concept id -------------------------------------
        # Raw string equality, case-significant: CONCEPT-ORDER and
        # concept-order are different ids (and the second is separately a
        # pattern violation). The message names the duplicated id (AC-006).
        seen_ids = set()
        for index, concept in enumerate(concepts):
            if not isinstance(concept, dict):
                continue
            identifier = concept.get("id")
            if not isinstance(identifier, str):
                continue
            if identifier in seen_ids:
                add_violation(
                    "V2-DUP-CONCEPT-ID",
                    "concepts[%d].id: id %s is already declared by an earlier concept; concept ids must be unique"
                    % (index, safe(identifier)),
                )
            else:
                seen_ids.add(identifier)

        # --- (e) dangling concept.context ---------------------------------
        if declared_context_names is not None:
            for index, concept in enumerate(concepts):
                if not isinstance(concept, dict):
                    continue
                context_name = concept.get("context")
                if not isinstance(context_name, str):
                    continue
                if CONTEXT_RE.match(context_name) is None:
                    # Malformed, not unresolvable. The structural pass already
                    # reported this value as V2-PATTERN; reporting it again as
                    # a dangling reference would blur the two defects.
                    continue
                if context_name not in declared_context_names:
                    add_violation(
                        "V2-DANGLING-CONTEXT",
                        "concepts[%d].context: context %s is not declared in contexts"
                        % (index, safe(context_name)),
                    )

        # --- (f) dangling distinguished_from.concept_id -------------------
        # Pattern first (AC-022), then the self-reference case, then
        # resolution. requirements.md Edge Cases makes a concept pointing at
        # its own id invalid as part of this same check.
        for index, concept in enumerate(concepts):
            if not isinstance(concept, dict):
                continue
            own_id = concept.get("id")
            distinctions = concept.get("distinguished_from")
            if not isinstance(distinctions, list):
                continue
            for entry_index, distinction in enumerate(distinctions):
                if not isinstance(distinction, dict):
                    continue
                reference = distinction.get("concept_id")
                if not isinstance(reference, str):
                    continue
                path = "concepts[%d].distinguished_from[%d].concept_id" % (index, entry_index)
                if not reference_well_formed(reference, path, add_violation):
                    continue
                if isinstance(own_id, str) and reference == own_id:
                    add_violation(
                        "V2-DANGLING-DISTINCTION",
                        "%s: %s is the concept's own id; a concept cannot be distinguished from itself"
                        % (path, safe(reference)),
                    )
                    continue
                if declared_concept_ids is not None and reference not in declared_concept_ids:
                    add_violation(
                        "V2-DANGLING-DISTINCTION",
                        "%s: %s does not resolve to any declared concept id"
                        % (path, safe(reference)),
                    )

    # --- (g) dangling contexts[].terms[].concept_id ------------------------
    if contexts_declared and declared_concept_ids is not None:
        for index, entry in enumerate(contexts):
            if not isinstance(entry, dict):
                continue
            terms = entry.get("terms")
            if not isinstance(terms, list):
                continue
            for term_index, term in enumerate(terms):
                if not isinstance(term, dict):
                    continue
                if "concept_id" not in term:
                    continue
                reference = term["concept_id"]
                if not isinstance(reference, str):
                    continue
                path = "contexts[%d].terms[%d].concept_id" % (index, term_index)
                if not reference_well_formed(reference, path, add_violation):
                    continue
                if reference not in declared_concept_ids:
                    add_violation(
                        "V2-DANGLING-TERM",
                        "%s: %s does not resolve to any declared concept id"
                        % (path, safe(reference)),
                    )

    if concepts_declared:
        # --- (h) responsibilities / must_not_own self-contradiction --------
        # REQ-004(h) says the same STRING, so the comparison is exact: not
        # case-folded, not trimmed, not otherwise normalized. Each distinct
        # colliding string is reported once even if must_not_own repeats it.
        for index, concept in enumerate(concepts):
            if not isinstance(concept, dict):
                continue
            responsibilities = concept.get("responsibilities")
            forbidden = concept.get("must_not_own")
            if not isinstance(responsibilities, list):
                continue
            if not isinstance(forbidden, list):
                continue
            owned = set(item for item in responsibilities if isinstance(item, str))
            reported = set()
            for item in forbidden:
                if not isinstance(item, str):
                    continue
                if item not in owned or item in reported:
                    continue
                reported.add(item)
                add_violation(
                    "V2-SELF-CONTRADICTION",
                    "concepts[%d]: %s appears in both responsibilities and must_not_own"
                    % (index, safe(item)),
                )

        # --- (i) duplicate concept name inside ONE context -----------------
        # The key is the (context, name) pair. That pairing is exactly what
        # makes the same name in two DIFFERENT contexts legal (requirements.md
        # Edge Cases, INV-012) while a repeat inside one context is not.
        seen_names = set()
        for index, concept in enumerate(concepts):
            if not isinstance(concept, dict):
                continue
            name = concept.get("name")
            context_name = concept.get("context")
            if not isinstance(name, str) or not isinstance(context_name, str):
                continue
            key = (context_name, name)
            if key in seen_names:
                add_violation(
                    "V2-DUP-NAME-IN-CONTEXT",
                    "concepts[%d].name: name %s is already declared by another concept in context %s; names must be unique within a context"
                    % (index, safe(name), safe(context_name)),
                )
            else:
                seen_names.add(key)


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
