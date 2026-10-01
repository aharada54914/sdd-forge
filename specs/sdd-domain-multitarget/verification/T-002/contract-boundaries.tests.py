"""T-002 ownership fixtures; reuses existing schema/provider validators.

MCP scanning checks literal registrations and fetch calls, not arbitrary TS;
existing ci-mcp runtime tests separately exercise the real request boundary.
Host/UI ownership declarations are not native activation proof.
"""
import copy
import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = None
_MODULE_CACHE = {}

def _load_module(rel_path):
    if rel_path not in _MODULE_CACHE:
        full_path = REPO_ROOT / rel_path
        name = full_path.stem.replace("-", "_")
        spec = importlib.util.spec_from_file_location(name, full_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _MODULE_CACHE[rel_path] = module
    return _MODULE_CACHE[rel_path]

def _sidecar_mod():
    return _load_module("plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py")

def _registry_mod():
    return _load_module("plugins/sdd-quality-loop/scripts/validate-capability-registry.py")

def _load_json(rel_path):
    with open(REPO_ROOT / rel_path, "r", encoding="utf-8") as f:
        return json.load(f)

def _read_text(rel_path):
    return (REPO_ROOT / rel_path).read_text(encoding="utf-8")

def _collect_property_names(node, names):
    if isinstance(node, dict):
        props = node.get("properties")
        if isinstance(props, dict):
            names.update(props.keys())
        for v in node.values():
            _collect_property_names(v, names)
    elif isinstance(node, list):
        for item in node:
            _collect_property_names(item, names)

PROJECT_CONTEXT_SCHEMA_PATH = "contracts/project-context.schema.json"
PROVIDER_BINDINGS_SCHEMA_PATH = "contracts/provider-bindings.schema.json"
CAPABILITY_REGISTRY_SCHEMA_PATH = "contracts/capability-registry.schema.json"
CAPABILITY_REGISTRY_PATH = "contracts/capability-registry.json"
CONTEXT_PROJECTION_SCHEMA_PATH = "contracts/context-projection.schema.json"
DESIGN_MD_PATH = "specs/sdd-domain-multitarget/design.md"

CORE_CONTRACT_PATHS = (
    PROJECT_CONTEXT_SCHEMA_PATH,
    CAPABILITY_REGISTRY_SCHEMA_PATH,
    CAPABILITY_REGISTRY_PATH,
    CONTEXT_PROJECTION_SCHEMA_PATH,
)

class OwnershipBoundaryTests(unittest.TestCase):
    def test_row1_core_owns_lifecycle_not_provider_identity(self):
        sidecar_mod = _sidecar_mod()
        keys = sidecar_mod.SIDECAR_REQUIRED_KEYS
        self.assertTrue(
            {"primary_approval", "effective_at", "approval_epoch", "weakening_verdict"} <= keys
        )
        self.assertFalse(keys & {"provider", "credentials", "state_authority", "product"})

    def test_row2_capability_registry_owns_obligations_not_provider_identity(self):
        schema = _load_json(CAPABILITY_REGISTRY_SCHEMA_PATH)
        names = set()
        _collect_property_names(schema, names)
        self.assertTrue({"required_facets", "conditional_facets", "review_check_ids", "gate_ids"} <= names)
        self.assertFalse(names & {"provider", "credentials", "state_authority", "product"})

    def test_row3_provider_binding_owns_identity_not_core_policy(self):
        schema = _load_json(PROVIDER_BINDINGS_SCHEMA_PATH)
        names = set()
        _collect_property_names(schema, names)
        self.assertTrue({"provider", "product", "credentials", "state_authority"} <= names)
        self.assertFalse(names & {"gate_ids", "risk", "approval", "status", "capabilities"})

    def _ownership_row_cells(self, row_label):
        design_text = _read_text(DESIGN_MD_PATH)
        pattern = re.compile(r"^\| " + re.escape(row_label) + r" \| (.+) \| (.+) \|$", re.MULTILINE)
        match = pattern.search(design_text)
        self.assertIsNotNone(match, f"design.md ownership row for {row_label!r} not found")
        return match.group(1), match.group(2)

    def test_row4_host_adapter_boundary_is_recorded(self):
        owns, does_not_own = self._ownership_row_cells("Host Adapter")
        self.assertIn("manifest and invocation differences", owns)
        self.assertIn("approval semantics", does_not_own)

    def test_row5_ui_provider_boundary_is_recorded(self):
        owns, does_not_own = self._ownership_row_cells("Optional UI design provider")
        self.assertIn("egress/consent handling", owns)
        self.assertIn("canonical project decisions", does_not_own)

class ProjectContextBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.schema = _load_json(PROJECT_CONTEXT_SCHEMA_PATH)
        self.sidecar_mod = _sidecar_mod()

    def _validate(self, instance):
        errors = self.sidecar_mod._schema_validate(self.schema, instance)
        for path, function in (
            ("resolve-component-paths.py", "_schema_validate"),
            ("resolve-project-context.py", "_schema_errors"),
        ):
            module = _load_module("plugins/sdd-quality-loop/scripts/" + path)
            validator = getattr(module, function)
            observed = (validator(self.schema, instance) if function == "_schema_validate"
                        else validator(instance, self.schema))
            self.assertEqual(bool(observed), bool(errors), (path, observed, errors))
        return errors

    def _base_instance(self):
        return {
            "schema": "sdd-project-context/v1",
            "workflow": {
                "spec_profile": "full",
                "artifact_layout": "facet-hybrid",
                "capability_enforcement": "required",
            },
            "components": [
                {
                    "id": "invoice-workflow",
                    "artifact_kinds": ["durable_workflow"],
                    "runtime_classes": ["cloud-function"],
                    "platform_targets": [{"os": "linux", "architecture": "arm64"}],
                    "characteristics": {
                        "pii": True,
                        "ui": False,
                        "long_running": True,
                        "replayable": True,
                        "human_in_the_loop": True,
                    },
                    "distribution_channels": ["internal"],
                    "data_classification": ["confidential"],
                    "provider_binding_ids": ["invoice-workflow-prod"],
                    "paths": {"include": ["src/**"], "exclude": ["src/generated/**"]},
                }
            ],
            "shared_paths": [
                {"pattern": "shared/**", "classification": "cross-cutting"},
                {"pattern": "contracts/**", "components": ["invoice-workflow"]},
            ],
        }

    def test_positive_ordinary_fields_and_binding_ids_accepted(self):
        errors = self._validate(self._base_instance())
        self.assertEqual(errors, [])

    def test_negative_provider_field_at_root_rejected(self):
        for field in ("provider", "product", "credentials", "state_authority"):
            with self.subTest(field=field):
                instance = self._base_instance()
                instance[field] = "azure"
                errors = self._validate(instance)
                self.assertTrue(any(field in e for e in errors), errors)

    def test_negative_provider_fields_at_component_rejected(self):
        for field in ("provider", "product", "credentials", "state_authority"):
            with self.subTest(field=field):
                instance = self._base_instance()
                instance["components"][0][field] = "azure"
                errors = self._validate(instance)
                self.assertTrue(any(field in e for e in errors), errors)

    def test_negative_provider_field_at_characteristics_rejected(self):
        for field in ("provider", "product", "credentials", "state_authority"):
            with self.subTest(field=field):
                instance = self._base_instance()
                instance["components"][0]["characteristics"][field] = "azure"
                errors = self._validate(instance)
                self.assertTrue(any(field in e for e in errors), errors)

    def test_negative_provider_fields_at_remaining_object_boundaries(self):
        for boundary in ("workflow", "platform_target", "paths", "shared_cross_cutting", "shared_bounded"):
            for field in ("provider", "product", "credentials", "state_authority"):
                with self.subTest(boundary=boundary, field=field):
                    instance = self._base_instance()
                    component = instance["components"][0]
                    target = {
                        "workflow": instance["workflow"],
                        "platform_target": component["platform_targets"][0],
                        "paths": component["paths"],
                        "shared_cross_cutting": instance["shared_paths"][0],
                        "shared_bounded": instance["shared_paths"][1],
                    }[boundary]
                    target[field] = "azure"
                    errors = self._validate(instance)
                    self.assertTrue(any(field in e for e in errors), errors)

    def test_provider_binding_schema_accepts_provider_product_credentials_state(self):
        binding_schema = _load_json(PROVIDER_BINDINGS_SCHEMA_PATH)
        instance = {
            "schema": "sdd-provider-bindings/v1",
            "bindings": [
                {
                    "id": "invoice-workflow-prod",
                    "provider": "azure",
                    "product": "durable-functions",
                    "purpose": "runtime",
                    "state_authority": {"type": "azure-runtime", "resource_ref": "invoice-workflow-prod"},
                    "credentials": {"source": "environment", "reference": "AZURE_FEDERATED_IDENTITY"},
                }
            ],
        }
        errors = self.sidecar_mod._schema_validate(binding_schema, instance)
        self.assertEqual(errors, [])

    def test_shared_path_shape_stays_exclusive_and_typed(self):
        for entry in (
            {"pattern": "shared/**"},
            {"pattern": "shared/**", "components": ["invoice-workflow"], "classification": "cross-cutting"},
            {"classification": "cross-cutting"},
            {"pattern": 1, "classification": "cross-cutting"},
            {"pattern": "shared/**", "components": "invoice-workflow"},
            {"pattern": "shared/**", "classification": "unknown"},
        ):
            with self.subTest(entry=entry):
                instance = self._base_instance()
                instance["shared_paths"] = [entry]
                self.assertTrue(self._validate(instance))

    def test_runtime_resolver_and_contract_reader_keep_legal_shapes(self):
        resolver = _load_module("plugins/sdd-quality-loop/scripts/resolve-project-context.py")
        paths = _load_module("plugins/sdd-quality-loop/scripts/resolve-component-paths.py")
        self.assertTrue(paths._check_schema_contract_shape(str(REPO_ROOT / PROJECT_CONTEXT_SCHEMA_PATH))[0])
        self.assertTrue(resolver._project_context_valid(self._base_instance(), REPO_ROOT))
        for index in (0, 1):
            for field in ("provider", "product", "credentials", "state_authority"):
                with self.subTest(index=index, field=field):
                    instance = self._base_instance()
                    instance["shared_paths"][index][field] = "azure"
                    self.assertFalse(resolver._project_context_valid(instance, REPO_ROOT))

    def test_context_projection_keeps_legal_shapes_and_binding_ids(self):
        resolver = _load_module("plugins/sdd-quality-loop/scripts/resolve-project-context.py")
        validator = _load_module("plugins/sdd-quality-loop/scripts/validate-context-projection.py")
        projection = resolver._projection(self._base_instance(), "sha256:" + "a" * 64)
        schema = _load_json(CONTEXT_PROJECTION_SCHEMA_PATH)
        self.assertEqual(validator.validate_document(projection, schema), [])

    def test_context_projection_rejects_provider_fields(self):
        resolver = _load_module("plugins/sdd-quality-loop/scripts/resolve-project-context.py")
        validator = _load_module("plugins/sdd-quality-loop/scripts/validate-context-projection.py")
        schema = _load_json(CONTEXT_PROJECTION_SCHEMA_PATH)
        for boundary in ("root", "workflow", "component", "characteristics", "platform_target", "paths", "shared_cross_cutting", "shared_bounded"):
            for field in ("provider", "product", "credentials", "state_authority"):
                with self.subTest(boundary=boundary, field=field):
                    projection = resolver._projection(self._base_instance(), "sha256:" + "a" * 64)
                    component = projection["components"]["invoice-workflow"]
                    target = {
                        "root": projection,
                        "workflow": projection["workflow"],
                        "component": component,
                        "characteristics": component["characteristics"],
                        "platform_target": component["platform_targets"][0],
                        "paths": component["paths"],
                        "shared_cross_cutting": projection["shared_paths"][0],
                        "shared_bounded": projection["shared_paths"][1],
                    }[boundary]
                    target[field] = "azure"
                    errors = validator.validate_document(projection, schema)
                    self.assertTrue(any(field in error.pointer for error in errors), errors)

class CapabilityRegistryProviderNeutralityTests(unittest.TestCase):
    def setUp(self):
        self.registry_mod = _registry_mod()
        self.registry = _load_json(
            "specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/"
            "fixture/capability-registry.fixture.json")
        self.assertEqual(_sidecar_mod()._schema_validate(
            _load_json(CAPABILITY_REGISTRY_SCHEMA_PATH), self.registry), [])
        self.provider_terms = self.registry_mod._load_provider_terms(REPO_ROOT)

    def test_actual_registry_has_no_provider_terms(self):
        diagnostics = []
        ok = self.registry_mod.check_g_provider_name_contamination(
            _load_json(CAPABILITY_REGISTRY_PATH), self.provider_terms, diagnostics
        )
        self.assertTrue(ok, diagnostics)

    def _predicate_registry(self, value, boundary):
        mutated = copy.deepcopy(self.registry)
        predicate = {"all": [{"not": {"any": [{
            "scope": "affected_component", "field": "characteristics.ui",
            "operator": "equals", "value": value,
        }]}}]}
        capability = mutated["capabilities"][0]
        if boundary == "trigger":
            capability["trigger"] = predicate
        else:
            capability["conditional_facets"][0]["when"] = predicate
        self.assertEqual(_sidecar_mod()._schema_validate(
            _load_json(CAPABILITY_REGISTRY_SCHEMA_PATH), mutated), [])
        return mutated

    def test_nested_predicate_credentials_and_state_keys_are_rejected(self):
        for boundary in ("trigger", "conditional"):
            for field in ("credentials", "state_authority"):
                for value in ({field: {}}, {"metadata": {field: None}},
                              {"items": [{"metadata": {field: False}}]}):
                    with self.subTest(boundary=boundary, field=field, value=value):
                        diagnostics = []
                        ok = self.registry_mod.check_g_provider_name_contamination(
                            self._predicate_registry(value, boundary),
                            self.provider_terms, diagnostics)
                        self.assertFalse(ok, diagnostics)
                        self.assertTrue(any("provider-name-detected" in d and
                                            f".{field}" in d for d in diagnostics), diagnostics)

    def test_provider_neutral_nested_predicate_values_are_accepted(self):
        value = {"metadata": {"name": "durable_workflow", "items": [
            {"replayable": True}, {"credentials_hint": False},
            {"state_authority_hint": None}], "labels": ["credentials", "state_authority"]}}
        for boundary in ("trigger", "conditional"):
            with self.subTest(boundary=boundary):
                diagnostics = []
                self.assertTrue(self.registry_mod.check_g_provider_name_contamination(
                    self._predicate_registry(value, boundary), self.provider_terms,
                    diagnostics), diagnostics)
                self.assertEqual(diagnostics, [])

    def test_mutated_registry_with_provider_name_is_detected(self):
        mutated = copy.deepcopy(self.registry)
        mutated["capabilities"][0]["delivery_strategy"]["kind"] = "azure-durable-workflow"
        diagnostics = []
        ok = self.registry_mod.check_g_provider_name_contamination(
            mutated, self.provider_terms, diagnostics
        )
        self.assertFalse(ok)
        self.assertTrue(any("provider-name-detected" in d for d in diagnostics), diagnostics)

    def test_capability_registry_schema_rejects_provider_extra_field(self):
        sidecar_mod = _sidecar_mod()
        schema = _load_json(CAPABILITY_REGISTRY_SCHEMA_PATH)
        for boundary in ("root", "gate", "capability"):
            for field in ("provider", "product", "credentials", "state_authority"):
                with self.subTest(boundary=boundary, field=field):
                    mutated = copy.deepcopy(self.registry)
                    target = mutated if boundary == "root" else mutated[
                        "gates" if boundary == "gate" else "capabilities"][0]
                    target[field] = "azure"
                    errors = sidecar_mod._schema_validate(schema, mutated)
                    self.assertTrue(any(field in e for e in errors), errors)

CI_MCP_SERVER_PATH = "mcp/ci-mcp/src/server.ts"
CI_MCP_CLIENT_PATH = "mcp/ci-mcp/src/github-client.ts"

EXPECTED_TOOL_NAMES = frozenset(
    {"list_workflow_runs", "get_workflow_run", "list_run_jobs", "list_run_artifacts", "get_job_log"}
)
_ALLOWED_IMPORT_PREFIXES = ("./", "../")
_ALLOWED_BARE_IMPORTS = frozenset({"@modelcontextprotocol/sdk/server/mcp.js"})

_TOOL_NAME_RE = re.compile(r"^\s*server\.registerTool\(\s*[\"']([A-Za-z0-9_]+)[\"']", re.MULTILINE)
_METHOD_RE = re.compile(r"await\s+fetchImpl\(\s*url,\s*\{\s*method:\s*[\"']([A-Za-z]+)[\"']")
_IMPORT_RE = re.compile(
    r"(?:import\s+(?:type\s+)?(?:\{[^}]*\}|[^\s{][^\s]*)\s+from\s+[\"']([^\"']+)[\"']"
    r"|require\(\s*[\"']([^\"']+)[\"']\s*\))"
)

def _scan_ci_mcp_read_only(server_text, client_text):
    """Literal source check; runtime behavior is covered by ci-mcp tests."""
    violations = []
    registrations = _TOOL_NAME_RE.findall(server_text)
    tool_names = set(registrations)
    if len(registrations) != len(EXPECTED_TOOL_NAMES):
        violations.append("tool-count-mismatch")
    for extra in sorted(tool_names - EXPECTED_TOOL_NAMES):
        violations.append(f"unexpected-tool:{extra}")
    for missing in sorted(EXPECTED_TOOL_NAMES - tool_names):
        violations.append(f"missing-tool:{missing}")
    methods = _METHOD_RE.findall(client_text)
    if len(methods) != 2:
        violations.append("fetch-call-count-mismatch")
    for method in methods:
        if method != "GET":
            violations.append(f"non-get-method:{method}")
    combined = server_text + "\n" + client_text
    for match in _IMPORT_RE.finditer(combined):
        spec = match.group(1) or match.group(2)
        if spec is None:
            continue
        if spec.startswith(_ALLOWED_IMPORT_PREFIXES) or spec in _ALLOWED_BARE_IMPORTS:
            continue
        violations.append(f"unexpected-dependency:{spec}")
    return violations

def _core_api_dependencies(document):
    # Root schema identifiers locate contracts; they are not API dependencies.
    semantic = {key: value for key, value in document.items()
                if key not in ("$id", "$schema")}
    text = json.dumps(semantic).lower()
    return [term for term in ("github", "octokit") if term in text]


class CiMcpReadOnlyBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.server_text = _read_text(CI_MCP_SERVER_PATH)
        self.client_text = _read_text(CI_MCP_CLIENT_PATH)

    def test_actual_tools_are_exactly_the_five_read_only_tools(self):
        violations = _scan_ci_mcp_read_only(self.server_text, self.client_text)
        self.assertEqual(violations, [])

    def test_mutated_write_tool_is_rejected(self):
        mutated_server = self.server_text.replace(
            "return server;",
            'server.registerTool("create_issue", {}, async () => {});\n  return server;',
        )
        self.assertNotEqual(mutated_server, self.server_text)
        violations = _scan_ci_mcp_read_only(mutated_server, self.client_text)
        self.assertIn("unexpected-tool:create_issue", violations)

    def test_mutated_non_get_method_is_rejected(self):
        mutated_client = self.client_text.replace(
            'await fetchImpl(url, { method: "GET"',
            'await fetchImpl(url, { method: "POST"', 1)
        self.assertNotEqual(mutated_client, self.client_text)
        violations = _scan_ci_mcp_read_only(self.server_text, mutated_client)
        self.assertIn("non-get-method:POST", violations)

    def test_mutated_api_dependency_is_rejected(self):
        mutated_client = 'import { Octokit } from "octokit";\n' + self.client_text
        violations = _scan_ci_mcp_read_only(self.server_text, mutated_client)
        self.assertIn("unexpected-dependency:octokit", violations)

    def test_core_contracts_have_no_api_dependency(self):
        for rel_path in CORE_CONTRACT_PATHS:
            self.assertEqual(_core_api_dependencies(_load_json(rel_path)), [], rel_path)

    def test_core_api_dependency_mutations_are_rejected(self):
        for rel_path in CORE_CONTRACT_PATHS:
            for value in ("https://api.github.com", "@octokit/rest"):
                with self.subTest(path=rel_path, value=value):
                    mutated = _load_json(rel_path)
                    mutated["api_dependency"] = value
                    self.assertTrue(_core_api_dependencies(mutated))

    def test_removed_fetch_calls_are_rejected(self):
        mutated = self.client_text.replace("await fetchImpl(", "await anotherClient(")
        self.assertIn("fetch-call-count-mismatch",
                      _scan_ci_mcp_read_only(self.server_text, mutated))

    def test_duplicate_tool_is_rejected(self):
        mutated = self.server_text + '\nserver.registerTool("get_job_log", {}, () => {});\n'
        self.assertIn("tool-count-mismatch",
                      _scan_ci_mcp_read_only(mutated, self.client_text))

def main(argv=None):
    global REPO_ROOT
    argv = list(sys.argv[1:] if argv is None else argv)
    repo_root_value = "."
    remaining = []
    i = 0
    while i < len(argv):
        if argv[i] == "--repo-root":
            repo_root_value = argv[i + 1]
            i += 2
            continue
        remaining.append(argv[i])
        i += 1
    REPO_ROOT = Path(repo_root_value).resolve()
    unittest.main(argv=[sys.argv[0]] + remaining)

if __name__ == "__main__":
    main()
