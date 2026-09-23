#!/usr/bin/env bash
set -euo pipefail

report="${1:-}"
if [[ -z "$report" || ! -f "$report" || -L "$report" ]]; then
  printf 'IMPLEMENTATION_REPORT_PATH: report must be a regular file\n' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'BLOCKED deterministic-runtime-unavailable\n' >&2
  exit 1
fi

python3 - "$report" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    text = handle.read()

schema_lines = re.findall(r"(?m)^Report Schema[^\n]*$", text)
valid_schema_lines = re.findall(
    r"(?m)^Report Schema: implementation-report/v2$", text
)
# These promote a schema-less document into the STRICT branch. They were tested
# with a bare `in text` substring scan, which has no anchoring, so a document
# that merely QUOTES one -- a review report citing a validator diagnostic inside
# backticks, mid-sentence -- was promoted and then failed as a malformed v2
# report. That is the mention-versus-declaration confusion WFI-049 records for
# section headings, one layer up: a citation is not a declaration. Each
# indicator is now anchored to the start of its own line.
v2_indicators = (
    r"^## Output Paths And Hashes[ \t]*$",
    r"^## Test Evidence[ \t]*$",
    r"^## Iteration And Escalation[ \t]*$",
    r"^## Isolation Evidence[ \t]*$",
    r"^- \*\*Task Attempt Count\*\*",
    r"^- \*\*Handoff Reload Evidence Hash\*\*",
)
# The indicators are a heuristic for LEGACY implementation reports, which carry
# no schema line. They must never promote a document that is not an
# implementation report at all: an independent review report filed beside one
# shares its section names ("## Test Evidence") without being one, and was
# failing as a malformed v2 report. A document's own title is its declaration of
# kind, and it is a sound discriminator here -- measured across all 228 shipped
# reports, every one of the 145 carrying a schema line also claims the kind in
# its title, and there is no counterexample.
declares_implementation_report = bool(re.match(r"^# Implementation Report", text))
if not schema_lines and not (
    declares_implementation_report
    and any(re.search(indicator, text, re.M) for indicator in v2_indicators)
):
    print("IMPLEMENTATION_REPORT_LEGACY_OK")
    raise SystemExit(0)
if not schema_lines:
    print("IMPLEMENTATION_REPORT_SCHEMA: missing schema", file=sys.stderr)
    raise SystemExit(1)
if len(schema_lines) != 1:
    print("IMPLEMENTATION_REPORT_SCHEMA: duplicate schema", file=sys.stderr)
    raise SystemExit(1)
if len(valid_schema_lines) != 1:
    print("IMPLEMENTATION_REPORT_SCHEMA: malformed or unsupported schema", file=sys.stderr)
    raise SystemExit(1)

required_headings = (
    "Test Evidence",
    "Iteration And Escalation",
    "Isolation Evidence",
    "Unresolved Items",
    "Session Handoff",
)

# The capture is NON-GREEDY so trailing whitespace is excluded from the
# section name. With a greedy `[^\n]+` the `\s*` absorbed nothing, so
# `## Outputs ` keyed as "Outputs " -- a section this validator then never
# found, never row-checked and never path-checked, while
# validate-review-context-set.sh's evaluator_output_is_declared DID accept
# it as an Outputs section. One invisible trailing byte therefore smuggled
# arbitrary paths (including `../../etc/passwd`) into an evaluator's
# authorized input set, past the very duplicate-section guard this file
# delivers. Found at gate seq 851.
# The first two fixes each banned the characters that cycle's evaluator had
# demonstrated -- space and tab, then the C0 controls -- and each time the next
# evaluator found more. str.strip() removes only characters where str.isspace()
# is true, so U+200B, U+2060, U+FEFF, U+00AD, the bidi controls and 25 other
# invisible forms all still keyed `## Outputs<pad>` to a section distinct from
# `## Outputs` (gate seq 856). Ban the CLASS instead of enumerating members:
#   * NFC-normalize, so decomposed and precomposed spellings key alike;
#   * reject control, format, private-use, surrogate, unassigned and
#     standalone-combining characters outright -- every one is invisible or
#     near-invisible, and none belongs in a heading;
#   * strip every Unicode separator, not only the ASCII subset.
# Measured against all 228 shipped implementation reports before landing: zero
# headings carry a banned character, so this rejects nothing already in the
# corpus. The authorization boundary screens the same class at the byte level,
# because awk silently DROPS a NUL and cannot be trusted to see it.
import unicodedata

HEADING_BANNED_CATEGORIES = {"Cc", "Cf", "Co", "Cs", "Cn", "Mn", "Me", "Zl", "Zp"}


def canonical_heading_name(raw):
    # Check the class on the RAW form AND on the normalized form. NFC COMBINES
    # a trailing U+0301 into the preceding letter, erasing the standalone Mn, so
    # a normalize-then-check order let `## Outputs` + combining acute key a
    # section of its own -- the only pad form of 23 that survived the first
    # draft of this rule.
    normalized = unicodedata.normalize("NFC", raw)
    for character in raw + normalized:
        if unicodedata.category(character) in HEADING_BANNED_CATEGORIES:
            print("IMPLEMENTATION_REPORT_FIELD: control or format character in "
                  "section heading", file=sys.stderr)
            raise SystemExit(1)
    stripped = "".join(
        character for character in normalized
        if unicodedata.category(character) != "Zs" or character == " "
    )
    return stripped.strip()


heading_matches = list(re.finditer(r"(?m)^## ([^\n]+)$", text))
sections = {}
for index, match in enumerate(heading_matches):
    name = canonical_heading_name(match.group(1))
    end = heading_matches[index + 1].start() if index + 1 < len(heading_matches) else len(text)
    sections.setdefault(name, []).append(text[match.end():end])

for heading in required_headings:
    count = len(sections.get(heading, []))
    if count != 1:
        qualifier = "missing" if count == 0 else "duplicate"
        print(f"IMPLEMENTATION_REPORT_FIELD: {qualifier} ## {heading}", file=sys.stderr)
        raise SystemExit(1)

def fail(detail):
    print(f"IMPLEMENTATION_REPORT_FIELD: {detail}", file=sys.stderr)
    raise SystemExit(1)

def is_unfilled(value):
    stripped = value.strip()
    return not stripped or "{{" in stripped or "}}" in stripped

# Present-and-format-only checks for the top-level "- Model:"/"- Effort:"
# lines (epic-159-pillar-c REQ-004/AC-026): exactly one occurrence each,
# non-empty, no unfilled template placeholder. No value-correctness check
# (e.g. no enumerated-effort-vocabulary check) -- matching this validator's
# existing scope for every other field.
for top_level_label in ("Model", "Effort"):
    matches = re.findall(rf"(?m)^- {top_level_label}: ([^\n]+)$", text)
    if len(matches) != 1 or is_unfilled(matches[0]):
        fail(f"missing or invalid {top_level_label}")

def label(section_name, label_name):
    body = sections[section_name][0]
    matches = re.findall(
        rf"(?m)^- \*\*{re.escape(label_name)}\*\*: ([^\n]+)$",
        body,
    )
    if len(matches) != 1 or is_unfilled(matches[0]):
        fail(f"missing {label_name}")
    return matches[0].strip()

def canonical_repository_path(value, field_name):
    if value.startswith("`") or value.endswith("`"):
        if len(value) < 2 or not (value.startswith("`") and value.endswith("`")):
            fail(f"invalid {field_name}")
        value = value[1:-1]
    components = value.split("/")
    if (
        not value
        or value.startswith("/")
        or re.match(r"^[A-Za-z]:", value)
        or "\\" in value
        or any(component in ("", ".", "..", "~") for component in components)
        or value.startswith("~")
    ):
        fail(f"invalid {field_name}")
    return value

# WFI-017: the v2 outputs contract accepts EITHER (or both) of two forms --
# the current template's "## Outputs" two-column table, and the legacy
# "## Output Paths And Hashes" bullet list retained solely so previously
# committed bullet-only and dual-form v2 reports remain valid. At least one
# of the two sections must be present; when both are present both are
# validated, and duplicate-path rejection spans both sections via one shared
# `seen_paths` set.
outputs_sections = sections.get("Outputs", [])
legacy_sections = sections.get("Output Paths And Hashes", [])
if len(outputs_sections) > 1:
    fail("duplicate ## Outputs")
if len(legacy_sections) > 1:
    fail("duplicate ## Output Paths And Hashes")
if not outputs_sections and not legacy_sections:
    fail("missing ## Outputs")

seen_paths = set()

# Outputs-table row parser. Mirrors the semantics of the Outputs-table row
# consumed by validate-review-context-set.sh's evaluator_output_is_declared
# (an exact `| \`path\` | \`sha256\` |` row match on a "## Outputs" section)
# but additionally enforces the malformed-entry guard the legacy bullet
# rules apply today: every line inside the section that starts with `|` and
# is neither the header row nor the separator row must parse as a data row,
# or the report is rejected.
outputs_header_pattern = re.compile(r"^\|\s*Path\s*\|\s*SHA-256\s*\|\s*$")
outputs_separator_pattern = re.compile(r"^\|\s*:?-+:?\s*\|\s*:?-+:?\s*\|\s*$")
outputs_row_pattern = re.compile(
    r"^\|\s*`([^`\n]+)`\s*\|\s*`([0-9a-f]{64})`\s*\|\s*$"
)

if outputs_sections:
    outputs_body = outputs_sections[0]
    table_rows = []
    for line in outputs_body.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        if outputs_header_pattern.match(stripped) or outputs_separator_pattern.match(stripped):
            continue
        row_match = outputs_row_pattern.match(stripped)
        if row_match is None:
            fail("malformed Outputs entry")
        table_rows.append(row_match.groups())
    if not table_rows:
        fail("missing Outputs entry")
    for output_path, _output_hash in table_rows:
        canonical_repository_path(output_path, "output path")
        if output_path in seen_paths:
            fail("duplicate output path")
        seen_paths.add(output_path)

if legacy_sections:
    legacy_body = legacy_sections[0]
    output_pattern = re.compile(
        r"(?m)^- \*\*Path\*\*: `([^`\n]+)`; "
        r"\*\*SHA-256\*\*: `([0-9a-f]{64})`\s*$"
    )
    legacy_outputs = output_pattern.findall(legacy_body)
    if not legacy_outputs:
        fail("missing Output Paths And Hashes entry")
    if len(legacy_outputs) != len(re.findall(r"(?m)^- \*\*Path\*\*:", legacy_body)):
        fail("malformed Output Paths And Hashes entry")
    for output_path, _output_hash in legacy_outputs:
        canonical_repository_path(output_path, "output path")
        if output_path in seen_paths:
            fail("duplicate output path")
        seen_paths.add(output_path)

label("Test Evidence", "Test Command")
test_result = label("Test Evidence", "Test Result")
if test_result not in {"PASS", "FAIL", "BLOCKED", "NOT RUN"}:
    fail("invalid Test Result")
canonical_repository_path(
    label("Test Evidence", "Test Evidence Path"),
    "Test Evidence Path",
)

attempt_count = label("Iteration And Escalation", "Task Attempt Count")
if re.fullmatch(r"[1-9][0-9]*", attempt_count) is None:
    fail("invalid Task Attempt Count")

escalation_names = (
    "Escalation Prior Tier",
    "Escalation Next Tier",
    "Escalation Failure Class",
    "Escalation Attempt Number",
    "Escalation Reason",
)
escalation = {
    name: label("Iteration And Escalation", name)
    for name in escalation_names
}
none_fields = [name for name, value in escalation.items() if value == "None"]
if none_fields and len(none_fields) != len(escalation):
    fail("partial escalation record")
if not none_fields:
    tiers = ("lightweight", "standard", "strong")
    prior = escalation["Escalation Prior Tier"]
    next_tier = escalation["Escalation Next Tier"]
    if prior not in tiers or next_tier not in tiers:
        fail("invalid escalation tier")
    if tiers.index(next_tier) != tiers.index(prior) + 1:
        fail("invalid escalation transition")
    failure_classes = {
        "test",
        "lint",
        "typecheck",
        "build",
        "review-major",
        "review-critical",
    }
    if escalation["Escalation Failure Class"] not in failure_classes:
        fail("invalid Escalation Failure Class")
    escalation_attempt = escalation["Escalation Attempt Number"]
    if re.fullmatch(r"[1-9][0-9]*", escalation_attempt) is None:
        fail("invalid Escalation Attempt Number")
    if int(escalation_attempt) > int(attempt_count):
        fail("Escalation Attempt Number exceeds Task Attempt Count")

for identity_label in ("Run ID", "Session ID", "Agent Instance ID"):
    label("Isolation Evidence", identity_label)
isolation_mode = label("Isolation Evidence", "Isolation Mode")
fallback_reason = label("Isolation Evidence", "Fallback Reason")
reload_hash = label("Isolation Evidence", "Handoff Reload Evidence Hash")
if isolation_mode == "fresh-agent":
    if fallback_reason != "None" or reload_hash != "None":
        fail("fresh-agent must record no fallback")
elif isolation_mode == "same-session-file-reload":
    if fallback_reason != "host-does-not-support-implementation-subagents":
        fail("same-session fallback requires host-capability Fallback Reason")
    if re.fullmatch(r"[0-9a-f]{64}", reload_hash) is None:
        fail("same-session fallback requires Handoff Reload Evidence Hash")
else:
    fail("invalid Isolation Mode")

# WFI-044: a quota interruption ends the recording agent's turn, so the
# RESUMING orchestrator -- a different actor -- is the one that knows the run
# fell back to same-session-file-reload, and nothing obliged it to say so.
# Presence-only checking therefore let agci T-007 ship `fresh-agent` over a
# narrative describing exactly that fallback (RT-20260821-016).
#
# The rule fires only on a `fresh-agent` declaration, and only when ONE
# sentence carries both an interruption term and a resumption term -- the
# conjunction is what distinguishes "this run was interrupted and resumed"
# from the framework's ordinary talk of handoffs and reloads. Fail-closed: a
# false positive is corrected by making the declaration truthful, never by
# deleting the narrative.
if isolation_mode == "fresh-agent":
    _interruption = re.compile(
        r"\b(quota|rate[- ]limit\w*|interrupt\w*|"
        r"ran out of context|context (?:limit|window) (?:hit|exhausted))\b",
        re.IGNORECASE,
    )
    _resumption = re.compile(
        r"\b(resum\w+|took over|picked (?:it |the work )?up|"
        r"orchestrator (?:completed|finished|continued))\b",
        re.IGNORECASE,
    )
    for _sentence in re.split(r"(?<=[.!?])\s+", text):
        if _interruption.search(_sentence) and _resumption.search(_sentence):
            fail("isolation narrative contradicts declared mode")

unresolved_body = sections["Unresolved Items"][0].strip()
if is_unfilled(unresolved_body):
    fail("missing Unresolved Items section value")

for handoff_label in ("Current Status", "Next Action", "Unresolved Items"):
    label("Session Handoff", handoff_label)

current_status = label("Session Handoff", "Current Status")
if current_status not in {"In Progress", "Implementation Complete", "Blocked"}:
    fail("invalid Current Status")

print("IMPLEMENTATION_REPORT_OK")
PY
