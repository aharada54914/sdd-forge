# T-004 (epic-189-a1-project-context, REQ-006): acceptance checks for
# contracts/approver-registry.schema.json.
#
# PowerShell parity port of tests/approver-registry-schema.tests.sh. See
# that file's header for the TEST-044/045/046 <-> AC-044/045/046 mapping.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("approver-registry-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$script:PassCount = 0
$script:FailCount = 0

function Test-Pass([string]$Label) {
  $script:PassCount++
  Write-Output "PASS: $Label"
}

function Test-Fail([string]$Label, [string]$Detail = '') {
  $script:FailCount++
  Write-Output "FAIL: ${Label}: $Detail"
}

try {
  $Py = $null
  foreach ($candidate in @('python3', 'python')) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
      $Py = $candidate
      break
    }
  }
  if (-not $Py) {
    Write-Output 'FAIL: no python3/python interpreter available'
    exit 1
  }

  $Schema = Join-Path $Root 'contracts/approver-registry.schema.json'
  $Validator = Join-Path $Work 'ar_validator.py'

  $ValidatorSource = @'
#!/usr/bin/env python3
"""Minimal draft-07 JSON Schema subset validator, purpose-built for
contracts/approver-registry.schema.json (T-004,
epic-189-a1-project-context). Byte-identical logic to the validator
embedded in tests/project-context-schema.tests.sh (T-001) -- see that
file's module docstring for the supported keyword subset and rationale.
"""
import copy
import json
import sys


def validate(schema, instance, path="/"):
    errors = []
    if "const" in schema and instance != schema["const"]:
        errors.append("%s: expected const %r, got %r" % (path, schema["const"], instance))
    if "enum" in schema and instance not in schema["enum"]:
        errors.append("%s: %r not in enum %r" % (path, instance, schema["enum"]))
    t = schema.get("type")
    if t == "object" and not isinstance(instance, dict):
        errors.append("%s: expected object" % path)
    elif t == "array" and not isinstance(instance, list):
        errors.append("%s: expected array" % path)
    elif t == "string" and not isinstance(instance, str):
        errors.append("%s: expected string" % path)
    elif t == "boolean" and not isinstance(instance, bool):
        errors.append("%s: expected boolean" % path)

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                errors.append("%s: missing required field %r" % (path, req))
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for k in instance:
                if k not in props:
                    errors.append("%s: additional property %r not allowed" % (path, k))
        for k, v in instance.items():
            if k in props:
                errors.extend(validate(props[k], v, path.rstrip("/") + "/" + k))
    elif isinstance(instance, list) and "items" in schema:
        for idx, item in enumerate(instance):
            errors.extend(validate(schema["items"], item, path.rstrip("/") + "/%d" % idx))
    elif isinstance(instance, str) and "minLength" in schema and len(instance) < schema["minLength"]:
        errors.append("%s: shorter than minLength %d" % (path, schema["minLength"]))

    return errors


def delete_pointer(instance, pointer):
    inst = copy.deepcopy(instance)
    parts = [p for p in pointer.split("/") if p != ""]
    node = inst
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        if part == "*":
            if last:
                del node[0]
            else:
                node = node[0]
        else:
            if last:
                del node[part]
            else:
                node = node[part]
    return inst


def duplicate_id_check(instance, array_path, code):
    arr = instance.get(array_path, [])
    seen = set()
    for item in arr:
        iid = item.get("id")
        if iid in seen:
            return code
        seen.add(iid)
    return None


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main(argv):
    if len(argv) < 2:
        print("usage: ar_validator.py <command> [args...]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "check":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        errors = validate(schema, instance)
        if errors:
            for e in errors:
                print(e, file=sys.stderr)
            return 1
        print("VALID")
        return 0
    if cmd == "check-expect-invalid":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        errors = validate(schema, instance)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID", file=sys.stderr)
        return 1
    if cmd == "delete-check":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        pointer = argv[4]
        mutated = delete_pointer(instance, pointer)
        errors = validate(schema, mutated)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID after deleting %s" % pointer, file=sys.stderr)
        return 1
    if cmd == "dup-check":
        instance = load_json(argv[2])
        array_path = argv[3]
        expected_code = argv[4]
        code = duplicate_id_check(instance, array_path, expected_code)
        if code == expected_code:
            print("DETECTED: %s" % code)
            return 0
        print("NOT DETECTED (got %r, expected %r)" % (code, expected_code), file=sys.stderr)
        return 1
    print("unknown command: %s" % cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
'@
  Set-Content -LiteralPath $Validator -Value $ValidatorSource -NoNewline -Encoding utf8

  function Invoke-Validator {
    param([string[]]$ValidatorArgs)
    $out = & $Py $Validator @ValidatorArgs 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out -join "`n") }
  }

  $ArPositive = Join-Path $Work 'ar_positive.json'
  Set-Content -LiteralPath $ArPositive -Encoding utf8 -Value @'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": [
    {"id": "alice-01", "name": "Alice Example", "registered_at": "2026-01-01T00:00:00Z"},
    {"id": "bob-02", "name": "Bob Example", "registered_at": "2026-01-02T00:00:00Z"}
  ]
}
'@

  $ArEmpty = Join-Path $Work 'ar_empty.json'
  Set-Content -LiteralPath $ArEmpty -Encoding utf8 -Value @'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": []
}
'@

  $ArMalformed = Join-Path $Work 'ar_malformed_shape.json'
  Set-Content -LiteralPath $ArMalformed -Encoding utf8 -Value @'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": "not-an-array"
}
'@

  $ArDup = Join-Path $Work 'ar_dup_id.json'
  Set-Content -LiteralPath $ArDup -Encoding utf8 -Value @'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": [
    {"id": "dup-approver", "name": "First"},
    {"id": "dup-approver", "name": "Second"}
  ]
}
'@

  # ---------------------------------------------------------------------
  # TEST-044
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $Schema, $ArPositive)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-044 positive fixture (id+name+registered_at) validates' }
  else { Test-Fail 'TEST-044 positive fixture (id+name+registered_at) validates' $r.Output }

  foreach ($ptr in @('/approvers/*/id', '/approvers/*/name')) {
    $r = Invoke-Validator @('delete-check', $Schema, $ArPositive, $ptr)
    if ($r.ExitCode -eq 0) { Test-Pass "TEST-044 deleting required field $ptr is rejected" }
    else { Test-Fail "TEST-044 deleting required field $ptr is rejected" $r.Output }
  }

  $r = Invoke-Validator @('check-expect-invalid', $Schema, $ArMalformed)
  if ($r.ExitCode -eq 0) { Test-Pass "TEST-044 non-array 'approvers' value is rejected" }
  else { Test-Fail "TEST-044 non-array 'approvers' value is rejected" $r.Output }

  $r = Invoke-Validator @('check', $Schema, $ArEmpty)
  if ($r.ExitCode -eq 0) { Test-Pass "TEST-044 zero-entry 'approvers: []' fixture validates" }
  else { Test-Fail "TEST-044 zero-entry 'approvers: []' fixture validates" $r.Output }

  # ---------------------------------------------------------------------
  # TEST-045
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $Schema, $ArDup)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-045 duplicate-id fixture still passes plain JSON Schema (M18-equivalent)' }
  else { Test-Fail 'TEST-045 duplicate-id fixture still passes plain JSON Schema (M18-equivalent)' $r.Output }

  $r = Invoke-Validator @('dup-check', $ArDup, 'approvers', 'DUPLICATE_APPROVER_REGISTRY_ID')
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-045 semantic-validator layer rejects duplicate approvers[].id (DUPLICATE_APPROVER_REGISTRY_ID)' }
  else { Test-Fail 'TEST-045 semantic-validator layer rejects duplicate approvers[].id (DUPLICATE_APPROVER_REGISTRY_ID)' $r.Output }

  # ---------------------------------------------------------------------
  # TEST-046 (schema-conformance half only)
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $Schema, $ArEmpty)
  if ($r.ExitCode -eq 0) { Test-Pass "TEST-046 zero-identity 'approvers: []' fixture validates against the schema" }
  else { Test-Fail "TEST-046 zero-identity 'approvers: []' fixture validates against the schema" $r.Output }

  Write-Output "PASS: $script:PassCount"
  Write-Output "FAIL: $script:FailCount"
  if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
