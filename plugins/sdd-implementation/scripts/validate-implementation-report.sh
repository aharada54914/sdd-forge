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
v2_indicators = (
    "## Output Paths And Hashes",
    "## Test Evidence",
    "## Iteration And Escalation",
    "## Isolation Evidence",
    "**Task Attempt Count**",
    "**Handoff Reload Evidence Hash**",
)
if not schema_lines and not any(indicator in text for indicator in v2_indicators):
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
    "Output Paths And Hashes",
    "Test Evidence",
    "Iteration And Escalation",
    "Isolation Evidence",
    "Unresolved Items",
    "Session Handoff",
)

heading_matches = list(re.finditer(r"(?m)^## ([^\n]+)\s*$", text))
sections = {}
for index, match in enumerate(heading_matches):
    name = match.group(1)
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
        or any(component in ("", ".", "..") for component in components)
    ):
        fail(f"invalid {field_name}")
    return value

output_body = sections["Output Paths And Hashes"][0]
output_pattern = re.compile(
    r"(?m)^- \*\*Path\*\*: `([^`\n]+)`; "
    r"\*\*SHA-256\*\*: `([0-9a-f]{64})`\s*$"
)
outputs = output_pattern.findall(output_body)
if not outputs:
    fail("missing Output Paths And Hashes entry")
if len(outputs) != len(re.findall(r"(?m)^- \*\*Path\*\*:", output_body)):
    fail("malformed Output Paths And Hashes entry")
seen_paths = set()
for output_path, _output_hash in outputs:
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
