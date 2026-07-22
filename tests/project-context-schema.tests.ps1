# T-001 (epic-189-a1-project-context, REQ-001/REQ-002): acceptance checks
# for contracts/project-context.schema.json, contracts/provider-bindings.schema.json,
# and contracts/project-context.template.yaml.
#
# PowerShell parity port of tests/project-context-schema.tests.sh. See that
# file's header for the TEST-001..TEST-042/AC-001..AC-042 mapping. The
# embedded Python validator source below is byte-identical to the one
# embedded in the .sh script (single logical source, duplicated only as a
# heredoc, per this repo's existing python3/python-resolution dispatcher
# convention — design.md Components, canonicalize-sdd-yaml.{sh,ps1,js}).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("pc-schema-test-" + [Guid]::NewGuid().ToString('N'))
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

  $PcSchema = Join-Path $Root 'contracts/project-context.schema.json'
  $PbSchema = Join-Path $Root 'contracts/provider-bindings.schema.json'
  $PcTemplate = Join-Path $Root 'contracts/project-context.template.yaml'
  $Validator = Join-Path $Work 'pc_validator.py'

  $ValidatorSource = @'
#!/usr/bin/env python3
"""Minimal draft-07 JSON Schema subset validator + restricted YAML-subset
loader, purpose-built for contracts/project-context.schema.json and
contracts/provider-bindings.schema.json (T-001, epic-189-a1-project-context).

Not a general-purpose JSON Schema or YAML implementation. Supports exactly
the keywords/shapes these two schemas and the template use: type, required,
additionalProperties (bool), properties, items, enum, const, minLength,
oneOf. The YAML loader supports block-style mappings and lists-of-mappings
with 2-space indentation only (no anchors, tags, flow style, or multiline
scalars) -- sufficient for contracts/project-context.template.yaml.
"""
import copy
import json
import sys


def parse_scalar(val):
    val = val.strip()
    if len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        return val[1:-1]
    if len(val) >= 2 and val[0] == "'" and val[-1] == "'":
        return val[1:-1]
    if val == "true":
        return True
    if val == "false":
        return False
    if val == "[]":
        return []
    if val == "{}":
        return {}
    return val


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def parse_yaml_block(lines):
    if not lines:
        return {}
    first_content = lines[0].lstrip(" ")
    if first_content.startswith("- "):
        result = []
        idx = 0
        while idx < len(lines):
            line = lines[idx]
            marker_indent = indent_of(line)
            content = line.lstrip(" ")[2:]
            entry = {}
            k, _, v = content.partition(":")
            entry[k.strip()] = parse_scalar(v.strip()) if v.strip() else None
            idx += 1
            cont_indent = marker_indent + 2
            while idx < len(lines) and indent_of(lines[idx]) == cont_indent and not lines[idx].lstrip(" ").startswith("- "):
                k2, _, v2 = lines[idx].strip().partition(":")
                entry[k2.strip()] = parse_scalar(v2.strip())
                idx += 1
            result.append(entry)
        return result
    else:
        result = {}
        base_indent = indent_of(lines[0])
        idx = 0
        while idx < len(lines):
            line = lines[idx]
            k, _, v = line.strip().partition(":")
            k = k.strip()
            v = v.strip()
            idx += 1
            if v == "":
                sub_indent = base_indent + 2
                sub_lines = []
                while idx < len(lines) and indent_of(lines[idx]) >= sub_indent:
                    sub_lines.append(lines[idx])
                    idx += 1
                result[k] = parse_yaml_block(sub_lines)
            else:
                result[k] = parse_scalar(v)
        return result


def load_yaml_subset(text):
    lines = []
    for raw in text.split("\n"):
        line = raw.rstrip("\n").rstrip("\r")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        lines.append(line)
    return parse_yaml_block(lines)


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

    # required / properties / additionalProperties apply to any object
    # instance regardless of whether "type": "object" is explicitly
    # declared on this schema node (draft-07 keywords are inert against
    # non-applicable instance types, not against absent "type").
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

    if "oneOf" in schema:
        matches = 0
        for sub in schema["oneOf"]:
            if not validate(sub, instance, path):
                matches += 1
        if matches != 1:
            errors.append("%s: oneOf matched %d branches (need exactly 1)" % (path, matches))

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


def load_json_or_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if path.endswith(".yaml") or path.endswith(".yml"):
        return load_yaml_subset(text)
    return json.loads(text)


def main(argv):
    if len(argv) < 2:
        print("usage: pc_validator.py <command> [args...]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "check":
        schema = load_json_or_yaml(argv[2])
        instance = load_json_or_yaml(argv[3])
        errors = validate(schema, instance)
        if errors:
            for e in errors:
                print(e, file=sys.stderr)
            return 1
        print("VALID")
        return 0
    if cmd == "delete-check":
        # Expects deletion at pointer to be REJECTED (errors non-empty).
        schema = load_json_or_yaml(argv[2])
        instance = load_json_or_yaml(argv[3])
        pointer = argv[4]
        mutated = delete_pointer(instance, pointer)
        errors = validate(schema, mutated)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID after deleting %s" % pointer, file=sys.stderr)
        return 1
    if cmd == "yaml-to-json":
        data = load_json_or_yaml(argv[2])
        print(json.dumps(data))
        return 0
    if cmd == "dup-check":
        instance = load_json_or_yaml(argv[2])
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

  # ---------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------

  $PcPositive = Join-Path $Work 'pc_positive.json'
  Set-Content -LiteralPath $PcPositive -Encoding utf8 -Value @'
{
  "schema": "sdd-project-context/v1",
  "workflow": {
    "spec_profile": "full",
    "artifact_layout": "legacy-seven-layer",
    "capability_enforcement": "advisory"
  },
  "components": [
    {
      "id": "example-cli",
      "artifact_kinds": ["cli"],
      "runtime_classes": ["node"],
      "platform_targets": [
        {"os": "linux", "architecture": "x86_64"}
      ],
      "characteristics": {
        "pii": false,
        "ui": false,
        "auto_update": true,
        "local_persistence": true,
        "long_running": false,
        "replayable": true,
        "human_in_the_loop": false
      },
      "distribution_channels": ["npm"],
      "data_classification": ["internal"],
      "provider_binding_ids": ["example-provider"],
      "paths": {
        "include": ["src/**"],
        "exclude": ["src/**/*.test.ts"]
      }
    }
  ],
  "shared_paths": [
    {"pattern": "specs/**", "classification": "cross-cutting"}
  ]
}
'@

  $PcDupComponent = Join-Path $Work 'pc_dup_component.json'
  Set-Content -LiteralPath $PcDupComponent -Encoding utf8 -Value @'
{
  "schema": "sdd-project-context/v1",
  "workflow": {"spec_profile": "full", "artifact_layout": "legacy-seven-layer", "capability_enforcement": "advisory"},
  "components": [
    {"id": "dup-id"},
    {"id": "dup-id"}
  ]
}
'@

  $PbPositive = Join-Path $Work 'pb_positive.json'
  Set-Content -LiteralPath $PbPositive -Encoding utf8 -Value @'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {
      "id": "example-provider",
      "provider": "totally-invented-provider-xyz",
      "product": "widget-cloud",
      "purpose": "state storage",
      "state_authority": {"region": "us-east-1", "nested": {"a": 1}},
      "credentials": {"secret_ref": "vault://example"},
      "adapter_paths": ["adapters/**/*.ts"]
    }
  ]
}
'@

  $PbNoAdapterPaths = Join-Path $Work 'pb_no_adapter_paths.json'
  Set-Content -LiteralPath $PbNoAdapterPaths -Encoding utf8 -Value @'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {
      "id": "example-provider-2",
      "provider": "another-invented-provider",
      "product": "widget-cloud",
      "purpose": "state storage"
    }
  ]
}
'@

  $PbDupBinding = Join-Path $Work 'pb_dup_binding.json'
  Set-Content -LiteralPath $PbDupBinding -Encoding utf8 -Value @'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {"id": "dup-id", "provider": "p1", "product": "prod1", "purpose": "x"},
    {"id": "dup-id", "provider": "p2", "product": "prod2", "purpose": "y"}
  ]
}
'@

  # ---------------------------------------------------------------------
  # TEST-001
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $PcSchema, $PcPositive)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-001 positive fixture (full field coverage) validates' }
  else { Test-Fail 'TEST-001 positive fixture (full field coverage) validates' $r.Output }

  $requiredPointers = @(
    '/schema', '/workflow', '/workflow/spec_profile', '/workflow/artifact_layout',
    '/workflow/capability_enforcement', '/components/*/id',
    '/components/*/platform_targets/*/os', '/components/*/platform_targets/*/architecture'
  )
  foreach ($ptr in $requiredPointers) {
    $r = Invoke-Validator @('delete-check', $PcSchema, $PcPositive, $ptr)
    if ($r.ExitCode -eq 0) { Test-Pass "TEST-001 deleting required pointer $ptr is rejected" }
    else { Test-Fail "TEST-001 deleting required pointer $ptr is rejected" $r.Output }
  }

  # ---------------------------------------------------------------------
  # TEST-002
  # ---------------------------------------------------------------------

  $schemaJson = Get-Content -Raw -LiteralPath $PcSchema | ConvertFrom-Json
  $allowlist = @(
    @{ Label = 'artifact_kinds'; Present = $null -ne $schemaJson.properties.components.items.properties.artifact_kinds },
    @{ Label = 'runtime_classes'; Present = $null -ne $schemaJson.properties.components.items.properties.runtime_classes },
    @{ Label = 'characteristics.pii'; Present = $null -ne $schemaJson.properties.components.items.properties.characteristics.properties.pii },
    @{ Label = 'characteristics.ui'; Present = $null -ne $schemaJson.properties.components.items.properties.characteristics.properties.ui },
    @{ Label = 'characteristics.auto_update'; Present = $null -ne $schemaJson.properties.components.items.properties.characteristics.properties.auto_update },
    @{ Label = 'characteristics.local_persistence'; Present = $null -ne $schemaJson.properties.components.items.properties.characteristics.properties.local_persistence },
    @{ Label = 'distribution_channels'; Present = $null -ne $schemaJson.properties.components.items.properties.distribution_channels },
    @{ Label = 'data_classification'; Present = $null -ne $schemaJson.properties.components.items.properties.data_classification }
  )
  foreach ($entry in $allowlist) {
    if ($entry.Present) { Test-Pass "TEST-002 allowlist path $($entry.Label) resolves to a schema field" }
    else { Test-Fail "TEST-002 allowlist path $($entry.Label) resolves to a schema field" 'field absent' }
  }

  # ---------------------------------------------------------------------
  # TEST-003
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $PbSchema, $PbPositive)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-003 positive fixture with state_authority/credentials passthrough validates' }
  else { Test-Fail 'TEST-003 positive fixture with state_authority/credentials passthrough validates' $r.Output }

  $pbRequiredPointers = @('/schema', '/bindings', '/bindings/*/id', '/bindings/*/provider', '/bindings/*/product', '/bindings/*/purpose')
  foreach ($ptr in $pbRequiredPointers) {
    $r = Invoke-Validator @('delete-check', $PbSchema, $PbPositive, $ptr)
    if ($r.ExitCode -eq 0) { Test-Pass "TEST-003 deleting required pointer $ptr is rejected" }
    else { Test-Fail "TEST-003 deleting required pointer $ptr is rejected" $r.Output }
  }

  # ---------------------------------------------------------------------
  # TEST-004
  # ---------------------------------------------------------------------

  $pbSchemaJson = Get-Content -Raw -LiteralPath $PbSchema | ConvertFrom-Json
  if ($null -eq $pbSchemaJson.properties.bindings.items.properties.provider.enum) {
    Test-Pass 'TEST-004 no fixed Provider enum exists in the schema'
  } else {
    Test-Fail 'TEST-004 no fixed Provider enum exists in the schema' 'enum present'
  }

  $r = Invoke-Validator @('check', $PbSchema, $PbPositive)
  if ($r.ExitCode -eq 0) { Test-Pass "TEST-004 invented provider string 'totally-invented-provider-xyz' validates" }
  else { Test-Fail "TEST-004 invented provider string 'totally-invented-provider-xyz' validates" $r.Output }

  # ---------------------------------------------------------------------
  # TEST-040
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $PcSchema, $PcDupComponent)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-040 duplicate-id components[] fixture still passes plain JSON Schema (M18)' }
  else { Test-Fail 'TEST-040 duplicate-id components[] fixture still passes plain JSON Schema (M18)' $r.Output }

  $r = Invoke-Validator @('dup-check', $PcDupComponent, 'components', 'DUPLICATE_COMPONENT_ID')
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-040 semantic-validator layer rejects duplicate components[].id (DUPLICATE_COMPONENT_ID)' }
  else { Test-Fail 'TEST-040 semantic-validator layer rejects duplicate components[].id (DUPLICATE_COMPONENT_ID)' $r.Output }

  $r = Invoke-Validator @('check', $PbSchema, $PbDupBinding)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-040 duplicate-id bindings[] fixture still passes plain JSON Schema (M18)' }
  else { Test-Fail 'TEST-040 duplicate-id bindings[] fixture still passes plain JSON Schema (M18)' $r.Output }

  $r = Invoke-Validator @('dup-check', $PbDupBinding, 'bindings', 'DUPLICATE_BINDING_ID')
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-040 semantic-validator layer rejects duplicate bindings[].id (DUPLICATE_BINDING_ID)' }
  else { Test-Fail 'TEST-040 semantic-validator layer rejects duplicate bindings[].id (DUPLICATE_BINDING_ID)' $r.Output }

  # ---------------------------------------------------------------------
  # TEST-041
  # ---------------------------------------------------------------------

  $r = Invoke-Validator @('check', $PbSchema, $PbPositive)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-041 bindings[] entry declaring adapter_paths validates' }
  else { Test-Fail 'TEST-041 bindings[] entry declaring adapter_paths validates' $r.Output }

  $r = Invoke-Validator @('check', $PbSchema, $PbNoAdapterPaths)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-041 bindings[] entry with no adapter_paths also validates' }
  else { Test-Fail 'TEST-041 bindings[] entry with no adapter_paths also validates' $r.Output }

  # ---------------------------------------------------------------------
  # TEST-042
  # ---------------------------------------------------------------------

  $TemplateJsonPath = Join-Path $Work 'template.json'
  $r = & $Py $Validator 'yaml-to-json' $PcTemplate
  $exitCode = $LASTEXITCODE
  if ($exitCode -eq 0) {
    Test-Pass 'TEST-042 project-context.template.yaml parses'
    Set-Content -LiteralPath $TemplateJsonPath -Value ($r -join "`n") -NoNewline -Encoding utf8
  } else {
    Test-Fail 'TEST-042 project-context.template.yaml parses' ($r -join "`n")
  }

  $r = Invoke-Validator @('check', $PcSchema, $TemplateJsonPath)
  if ($r.ExitCode -eq 0) { Test-Pass 'TEST-042 project-context.template.yaml validates against the schema' }
  else { Test-Fail 'TEST-042 project-context.template.yaml validates against the schema' $r.Output }

  $templateJson = Get-Content -Raw -LiteralPath $TemplateJsonPath | ConvertFrom-Json
  $seedPatterns = @('specs/**', 'reports/**', 'docs/**', '.github/**', 'tests/fixtures/**', 'CHANGELOG.md')
  foreach ($seedPattern in $seedPatterns) {
    $matchCount = @($templateJson.shared_paths | Where-Object { $_.pattern -eq $seedPattern -and $_.classification -eq 'cross-cutting' }).Count
    if ($matchCount -eq 1) { Test-Pass "TEST-042 shared_paths contains cross-cutting seed pattern '$seedPattern'" }
    else { Test-Fail "TEST-042 shared_paths contains cross-cutting seed pattern '$seedPattern'" "match count $matchCount" }
  }

  if (@($templateJson.shared_paths).Count -eq 6) {
    Test-Pass 'TEST-042 shared_paths contains exactly the six canonical seed patterns'
  } else {
    Test-Fail 'TEST-042 shared_paths contains exactly the six canonical seed patterns' "count $(@($templateJson.shared_paths).Count)"
  }

  Write-Output "PASS: $script:PassCount"
  Write-Output "FAIL: $script:FailCount"
  if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
