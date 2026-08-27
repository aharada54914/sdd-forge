#!/usr/bin/env python3
"""REQ-004: Resolver Evidence schema + exact-set + provenance-binding validator.

Usage:
    validate-resolver-evidence.py --evidence <path>
                                  [--registry <capability-registry.json path>]
                                  [--affected-components <comma-separated ids>]
                                  [--context <context-projection path>]
                                  [--manifest <facet-manifest.yaml path>]

Exit 0 (conformant) or non-zero with `resolver-evidence: <check-id>: <detail>`
lines, one per failed check -- matching Epic A4's own three-validator
diagnostic-line convention exactly, but drawing `<check-id>` from THIS
script's own closed, twelve-value enum, independent of REQ-002's own Block
taxonomy (design.md `validate-resolver-evidence` contract; Minor "diagnostic
namespace").

`<path>` ending in .yaml/.yml is loaded through the YAML parse contract: a
`canonicalize-sdd-yaml` subprocess invocation (canonical-JSON stdout) is the
sole path from YAML bytes to a Python structure -- never a hand-rolled YAML
parser and never a silent fallback. `<path>` ending in .json is loaded
directly via stdlib `json.load`. This mirrors `validate-facet-manifest.py`'s
own already-shipped loading contract rather than inventing a second one.

This module implements a hand-rolled, stdlib-only subset of JSON Schema
draft-07 (investigation.md INV-011: no third-party `jsonschema` dependency),
carried here as this validator's own copy exactly as each of Epic A4's own
three validators carries its own -- the precedent design.md names ("the
identical hand-rolled, stdlib-only draft-07 subset Epic A4's own
validate-facet-manifest.py already implements").

No environment variable of any kind is consulted, on any path.

--------------------------------------------------------------------------
Provenance binding (design.md, "Provenance binding (B6, revised)")
--------------------------------------------------------------------------
`--registry` and `--affected-components`/`--context` are OPTIONAL OVERRIDES,
never the sole source of exact-set ground truth:

- **Registry.** Default: self-resolved via ADR-0025's own discovery contract
  (`registry_discovery.discover_artifact`), the identical procedure
  `resolve-project-context` itself uses -- never a caller-supplied path
  trusted blindly. Whether self-resolved or supplied as an explicit
  `--registry` override, this validator computes the whole-Registry digest and
  requires it to equal the Evidence's own `context_binding.registry_digest`
  verbatim BEFORE running any exact-set check against that Registry's own
  `capabilities[]`.
- **Affected components.** Default: derived from the Evidence instance's own
  `context_binding.dependency_pointers[]` (B9's `/components/<id>` RFC-6901
  encoding). A co-located Facet Manifest (`--manifest`, or the sibling
  `facet-manifest.yaml` beside `--evidence`) must be set-identical; any
  explicit override must ITSELF be set-identical to that derivation -- an
  override can substitute for the derivation, never contradict it.

**Digest single-sourcing.** `generate-registry-digest.py` performs its own
ADR-0025 discovery and exposes no path argument, so it cannot be *pointed at*
a `--registry` override as a subprocess. Rather than reimplement its
serialization (a second, silently-divergable digest rule), this validator
imports that script's own module and calls its own `canonical_digest()` -- the
exact function its `--whole` branch itself calls -- and applies it identically
to the self-resolved Registry and to an override. There is therefore exactly
ONE digest code path here, and no default-vs-override divergence for an
attacker to steer. `tests/validate-resolver-evidence-check.py` binds every
clean fixture's `registry_digest` to the value the REAL
`generate-registry-digest --whole` subprocess emits, so each `exit 0` case is
itself an assertion that this in-process computation agrees with that CLI.

--------------------------------------------------------------------------
Check ordering (fail-closed ladder)
--------------------------------------------------------------------------
0. Reader-side generation-consistency check -- a live
   `RESOLVER_PUBLICATION_IN_PROGRESS` journal naming a path this invocation is
   about to read fails closed BEFORE `--evidence`/`--manifest` is read at all
   (design.md "Reader-side generation-consistency check", AC-054).
1. Load; an unreadable/unparseable input fails closed.
2. `schema-invalid` -- the remaining checks are defined over a
   schema-conformant document, so a schema failure short-circuits.
3. `registry-digest-unbound` -- fired FIRST and ALONE among the content
   checks: an exact-set check against a Registry that is not provably the one
   this Evidence instance claims to be about is meaningless (design.md).
4. `affected-component-provenance-mismatch` -- likewise fired alone: when two
   independently-populated sibling claims (or an override) disagree, there is
   no single affected-component ground truth for the set checks below to be
   evaluated against, so this validator refuses rather than picking one.
5. Every remaining structural/set-membership check, run together, all
   diagnostics collected and emitted in canonical sorted order.

This validator never re-runs any predicate evaluation: every check is
structural, set-membership, or provenance-binding against already-recorded
evidence (design.md; tasks.md Out of Scope). It never edits
`contracts/resolver-evidence.schema.json`.
"""
import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from collections import namedtuple
from pathlib import Path

Diagnostic = namedtuple("Diagnostic", ["check_id", "pointer", "message"])

SCHEMA_FILENAME = "resolver-evidence.schema.json"
REGISTRY_FILENAME = "capability-registry.json"
EXPECTED_SCHEMA_ID = (
    "https://github.com/aharada54914/sdd-forge/contracts/resolver-evidence.schema.json"
)

PREFIX = "resolver-evidence"

# Transaction-journal vocabulary, mirroring T-007's own already-implemented
# journal in `resolve-project-context.py` (same schema token, same
# `live_path`/`pre_hash`/`post_hash` field names) rather than a parallel one.
TRANSACTION_SCHEMA = "sdd-resolver-transaction/v1"
STAGING_DIRNAME = ".resolver-staging"
JOURNAL_FILENAME = "TRANSACTION.json"
SIBLING_MANIFEST_FILENAME = "facet-manifest.yaml"

COMPONENT_POINTER_PREFIX = "/components/"


class ValidatorError(Exception):
    """An operational fail-closed condition -- carries its own diagnostic id,
    drawn from OUTSIDE the closed twelve-value check-id enum, exactly as Epic
    A4's own `canonicalizer-invocation-failed`/`manifest-unreadable` lines are
    (those three validators emit them outside their own check-id enums too)."""

    def __init__(self, diagnostic_id, detail):
        super().__init__(detail)
        self.diagnostic_id = diagnostic_id
        self.detail = detail


# --------------------------------------------------------------------------
# Discovery contract (design.md "Discovery contract", ADR-0025) -- identical
# three-step procedure for every contracts/* artifact this feature locates.
# --------------------------------------------------------------------------

def _script_dir():
    return Path(os.path.realpath(os.path.abspath(__file__))).parent


def _find_git_root(start_dir):
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=str(start_dir), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        if result.returncode == 0:
            candidate = result.stdout.decode("utf-8").strip()
            if candidate:
                return Path(candidate)
    except OSError:
        pass
    current = Path(start_dir)
    for _ in range(64):
        if (current / ".git").exists():
            return current
        if current.parent == current:
            break
        current = current.parent
    return None


def discover_schema_path():
    """(1) packaged copy at `../contracts/<filename>`; (2) git-root
    `contracts/<filename>`; (3) fail closed naming both attempted paths."""
    script_dir = _script_dir()
    packaged = (script_dir.parent / "contracts" / SCHEMA_FILENAME).resolve()
    if packaged.is_file():
        return packaged
    git_root = _find_git_root(script_dir)
    git_path = (git_root / "contracts" / SCHEMA_FILENAME) if git_root is not None else None
    if git_path is not None and git_path.is_file():
        return git_path
    attempted = [str(packaged), str(git_path) if git_path else "<git root unresolved>/contracts/" + SCHEMA_FILENAME]
    raise ValidatorError("schema-discovery-failed", "tried " + ", ".join(attempted))


def load_schema():
    path = discover_schema_path()
    try:
        with open(path, "r", encoding="utf-8") as handle:
            schema = json.load(handle)
    except (OSError, ValueError) as exc:
        raise ValidatorError("schema-discovery-failed", f"cannot read/parse {SCHEMA_FILENAME}: {exc}")
    # Per-artifact version check (design.md Discovery contract): `$schema`
    # present AND `$id` matching -- a genuine identity check, never merely
    # "an $id key exists".
    if "$schema" not in schema or schema.get("$id") != EXPECTED_SCHEMA_ID:
        raise ValidatorError(
            "schema-discovery-failed",
            f"{SCHEMA_FILENAME} failed its version check ($schema present + matching $id)",
        )
    return schema


def _import_sibling(module_name, filename):
    """Import a co-located sibling script as a module. `script_dir` goes onto
    `sys.path` first because `generate-registry-digest.py` itself does a plain
    `import registry_discovery`."""
    script_dir = _script_dir()
    if str(script_dir) not in sys.path:
        sys.path.insert(0, str(script_dir))
    path = script_dir / filename
    if not path.is_file():
        raise ValidatorError("dependency-unavailable", f"{filename} is not present beside this script")
    try:
        spec = importlib.util.spec_from_file_location(module_name, str(path))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except (OSError, ImportError, SyntaxError, ValueError) as exc:
        raise ValidatorError("dependency-unavailable", f"{filename} is not importable: {type(exc).__name__}")
    return module


# --------------------------------------------------------------------------
# YAML parse contract -- the sole YAML-bytes-to-structure path.
# --------------------------------------------------------------------------

def _canonicalizer_argv(path, input_format):
    script_dir = _script_dir()
    canonicalizer = script_dir / "canonicalize-sdd-yaml.py"
    base = ([sys.executable, str(canonicalizer)] if canonicalizer.is_file()
            else ["canonicalize-sdd-yaml"])
    return base + ["--input-format", input_format, str(path)]


def _load_via_canonicalizer(path):
    """The sole bytes-to-structure path for a `.yaml`/`.yml` target: a
    `canonicalize-sdd-yaml` subprocess followed by `json.loads` -- never a
    hand-rolled parser and never a lenient fallback parser (security-spec.md
    B1).

    Both of that canonicalizer's own declared input formats are attempted, in
    a fixed order, because a `.yaml` EXTENSION does not by itself determine
    the byte form here: this feature's own Resolver publishes every artifact
    -- `resolver-evidence.yaml` included -- as canonical, key-sorted JSON
    (`resolve-project-context.py` `_canonical_payload`), while a hand-authored
    sibling may be block YAML. The two forms are mutually exclusive under this
    canonicalizer, so the selection is deterministic rather than a guess:
    canonical JSON is rejected outright by the `yaml` reader (non-empty
    flow-style collections are not in its accepted subset) and block YAML is
    rejected outright by the `json` reader. `json` is attempted first because
    this validator's own subject is this feature's own published artifacts.
    If BOTH formats reject the bytes, this fails closed and names both
    attempts -- never a silent success on a partially-understood document."""
    attempts = []
    for input_format in ("json", "yaml"):
        try:
            result = subprocess.run(_canonicalizer_argv(path, input_format),
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except OSError as exc:
            raise ValidatorError("canonicalizer-invocation-failed", str(exc))
        if result.returncode != 0:
            attempts.append(f"--input-format {input_format}: "
                            f"{result.stderr.decode('utf-8', errors='replace').strip() or f'exit {result.returncode}'}")
            continue
        try:
            return json.loads(result.stdout.decode("utf-8"))
        except ValueError as exc:
            raise ValidatorError("canonicalizer-invocation-failed",
                                 f"non-JSON canonicalizer stdout: {exc}")
    raise ValidatorError("canonicalizer-invocation-failed",
                         "the canonicalizer rejected this target under every declared input "
                         "format (" + "; ".join(attempts) + ")")


def load_document(path, diagnostic_id):
    text = str(path)
    if text.endswith(".yaml") or text.endswith(".yml"):
        return _load_via_canonicalizer(path)
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    # ValueError covers json.JSONDecodeError AND UnicodeDecodeError (both
    # ValueError subclasses) -- a non-UTF-8 input must surface this
    # diagnostic, never an unhandled Python traceback.
    except (OSError, ValueError) as exc:
        raise ValidatorError(diagnostic_id, str(exc))


# --------------------------------------------------------------------------
# Reader-side generation-consistency check (design.md "Reader-side
# generation-consistency check"; AC-054). Runs BEFORE any target is read.
# --------------------------------------------------------------------------

def _normalize(path):
    return Path(os.path.abspath(str(path))).resolve()


def _journal_target_path(journal_path, live_path):
    """Journals record repo-relative paths whenever the target lives inside
    the repository (T-007's own `_repo_relative` rule), so the repository root
    is recovered from the journal's own fixed depth:
    `<repo>/specs/<feature>/.resolver-staging/<nonce>/TRANSACTION.json`."""
    candidate = Path(live_path)
    if candidate.is_absolute():
        return candidate
    parents = journal_path.parents
    if len(parents) <= 4:
        return candidate
    return parents[4] / candidate


def check_no_publication_in_progress(paths_being_read):
    """Fail closed when a live journal names a path this invocation is about
    to read -- never a silent read of possibly-torn cross-file state. A
    journal that exists but cannot be read or does not conform to T-007's own
    transaction shape is ALSO fail-closed: silently treating it as "no journal
    at all" is precisely how an unrecovered partial publish would be read as
    settled state."""
    targets = {_normalize(path) for path in paths_being_read}
    staging_roots = []
    for path in paths_being_read:
        root = Path(path).parent / STAGING_DIRNAME
        if root not in staging_roots:
            staging_roots.append(root)

    for staging_root in staging_roots:
        if not staging_root.is_dir():
            continue
        for journal_path in sorted(staging_root.glob(f"*/{JOURNAL_FILENAME}")):
            try:
                journal = json.loads(journal_path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                raise ValidatorError(
                    "resolver-publication-in-progress",
                    f"a publication transaction journal exists at "
                    f"{journal_path.name!r} but could not be read or parsed ({type(exc).__name__}); "
                    f"treated as a possibly-torn in-progress publication rather than proceeding "
                    f"on unverifiable state (RESOLVER_PUBLICATION_IN_PROGRESS)",
                )
            if not isinstance(journal, dict) or journal.get("schema") != TRANSACTION_SCHEMA:
                raise ValidatorError(
                    "resolver-publication-in-progress",
                    f"a file at the transaction-journal location {journal_path.name!r} does not "
                    f"conform to this feature's own {TRANSACTION_SCHEMA} journal shape; treated as "
                    f"a possibly-torn in-progress publication (RESOLVER_PUBLICATION_IN_PROGRESS)",
                )
            if journal.get("status") != "in-progress":
                continue
            for target in journal.get("targets", []):
                if not isinstance(target, dict):
                    continue
                live_path = target.get("live_path")
                if not isinstance(live_path, str):
                    continue
                if _normalize(_journal_target_path(journal_path, live_path)) in targets:
                    raise ValidatorError(
                        "resolver-publication-in-progress",
                        f"a live publication transaction journal names {live_path!r}, which this "
                        f"invocation is about to read; refusing to proceed on possibly-torn "
                        f"cross-file state (RESOLVER_PUBLICATION_IN_PROGRESS)",
                    )


# --------------------------------------------------------------------------
# Hand-rolled draft-07 subset schema engine (this validator's own copy, per
# the Epic A4 three-validator precedent design.md names).
# --------------------------------------------------------------------------

def _escape_pointer_token(token):
    return str(token).replace("~", "~0").replace("/", "~1")


def _unescape_pointer_token(token):
    return str(token).replace("~1", "/").replace("~0", "~")


# Draft-07 `pattern` values follow ECMA-262 regex semantics, where a bare,
# non-multiline `$` asserts end-of-string only. Python's `$` also matches
# immediately before a single trailing "\n", which would wrongly admit a
# "sha256:<64hex>\n" value the schema author intended to reject. `\Z` is
# Python's strict absolute-end anchor, so every unescaped `$` outside a
# `[...]` class is rewritten before compiling. Diagnostic text still reports
# the original, untranslated pattern string.
_PATTERN_CACHE = {}


def _ecma_anchor(pattern):
    out = []
    i = 0
    length = len(pattern)
    in_class = False
    while i < length:
        ch = pattern[i]
        if ch == "\\" and i + 1 < length:
            out.append(ch)
            out.append(pattern[i + 1])
            i += 2
            continue
        if not in_class:
            if ch == "[":
                in_class = True
                out.append(ch)
                i += 1
                if i < length and pattern[i] == "^":
                    out.append(pattern[i])
                    i += 1
                if i < length and pattern[i] == "]":
                    out.append(pattern[i])
                    i += 1
                continue
            if ch == "$":
                out.append(r"\Z")
                i += 1
                continue
            out.append(ch)
            i += 1
            continue
        if ch == "]":
            in_class = False
        out.append(ch)
        i += 1
    return "".join(out)


def _compile_pattern(pattern):
    compiled = _PATTERN_CACHE.get(pattern)
    if compiled is None:
        compiled = re.compile(_ecma_anchor(pattern))
        _PATTERN_CACHE[pattern] = compiled
    return compiled


def _type_matches(value, type_spec):
    if isinstance(type_spec, list):
        return any(_type_matches(value, item) for item in type_spec)
    if type_spec == "object":
        return isinstance(value, dict)
    if type_spec == "array":
        return isinstance(value, list)
    if type_spec == "string":
        return isinstance(value, str)
    if type_spec == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_spec == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_spec == "boolean":
        return isinstance(value, bool)
    if type_spec == "null":
        return value is None
    return False


def _resolve_ref(ref, root_schema):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref (not a same-document fragment): {ref}")
    node = root_schema
    for part in ref[2:].split("/"):
        node = node[_unescape_pointer_token(part)]
    return node


def _schema_matches(instance, schema, root_schema):
    probe = []
    _validate(instance, schema, root_schema, "", probe)
    return not probe


def _validate(instance, schema, root_schema, pointer, diags):
    if schema is True:
        return
    if schema is False:
        diags.append((pointer, "value not allowed (schema: false)"))
        return
    if not isinstance(schema, dict):
        raise ValueError(f"malformed schema node at {pointer!r}: {schema!r}")

    if "$ref" in schema:
        _validate(instance, _resolve_ref(schema["$ref"], root_schema), root_schema, pointer, diags)
        return

    if "const" in schema and instance != schema["const"]:
        diags.append((pointer, f"expected const {schema['const']!r}, got {instance!r}"))
        return

    if "enum" in schema and instance not in schema["enum"]:
        diags.append((pointer, f"expected one of {schema['enum']!r}, got {instance!r}"))
        return

    if "type" in schema and not _type_matches(instance, schema["type"]):
        diags.append((pointer, f"expected type {schema['type']!r}, got {type(instance).__name__}"))
        return

    if "not" in schema and _schema_matches(instance, schema["not"], root_schema):
        diags.append((pointer, "value matched a schema under 'not'"))

    if "oneOf" in schema:
        matches = sum(1 for sub in schema["oneOf"] if _schema_matches(instance, sub, root_schema))
        if matches != 1:
            diags.append((pointer, f"expected exactly one 'oneOf' branch to match, {matches} matched"))

    if "if" in schema:
        if _schema_matches(instance, schema["if"], root_schema):
            if "then" in schema:
                _validate(instance, schema["then"], root_schema, pointer, diags)
        elif "else" in schema:
            _validate(instance, schema["else"], root_schema, pointer, diags)

    if isinstance(instance, str):
        if "pattern" in schema and not _compile_pattern(schema["pattern"]).search(instance):
            diags.append((pointer, f"does not match pattern {schema['pattern']!r}"))
        if "minLength" in schema and len(instance) < schema["minLength"]:
            diags.append((pointer, f"length {len(instance)} < minLength {schema['minLength']}"))

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                diags.append((f"{pointer}/{_escape_pointer_token(req)}",
                              f"missing required property {req!r}"))
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                _validate(value, properties[key], root_schema,
                          f"{pointer}/{_escape_pointer_token(key)}", diags)
        if "propertyNames" in schema:
            for key in instance:
                _validate(key, schema["propertyNames"], root_schema,
                          f"{pointer}/{_escape_pointer_token(key)}", diags)
        additional = schema.get("additionalProperties", True)
        if additional is not True:
            extra_keys = [k for k in instance if k not in properties]
            if additional is False:
                for key in extra_keys:
                    diags.append((f"{pointer}/{_escape_pointer_token(key)}",
                                  "additional property not allowed"))
            else:
                for key in extra_keys:
                    _validate(instance[key], additional, root_schema,
                              f"{pointer}/{_escape_pointer_token(key)}", diags)

    if isinstance(instance, list):
        if "items" in schema:
            for index, element in enumerate(instance):
                _validate(element, schema["items"], root_schema, f"{pointer}/{index}", diags)
        if schema.get("uniqueItems"):
            seen = []
            for index, element in enumerate(instance):
                canonical = json.dumps(element, sort_keys=True)
                if canonical in seen:
                    diags.append((f"{pointer}/{index}", "duplicate item (uniqueItems violated)"))
                else:
                    seen.append(canonical)
        if "minItems" in schema and len(instance) < schema["minItems"]:
            diags.append((pointer, f"array length {len(instance)} < minItems {schema['minItems']}"))


def check_schema_invalid(document, schema):
    raw = []
    _validate(document, schema, schema, "", raw)
    return [Diagnostic("schema-invalid", pointer, message) for pointer, message in raw]


# --------------------------------------------------------------------------
# Provenance binding (B6).
# --------------------------------------------------------------------------

def affected_components_from_pointers(pointers):
    """B9's canonical `/components/<id>` RFC-6901 encoding, one pointer per
    affected component. `/workflow` and `/shared_paths` are not components and
    are ignored here (design.md Data Plan, "dependency_pointers[] -- canonical
    derivation rule")."""
    result = set()
    for pointer in pointers or []:
        if isinstance(pointer, str) and pointer.startswith(COMPONENT_POINTER_PREFIX):
            result.add(_unescape_pointer_token(pointer[len(COMPONENT_POINTER_PREFIX):]))
    return result


def resolve_registry(override_path):
    """Returns (registry_document, source_label). Default: ADR-0025
    self-discovery, the identical procedure `resolve-project-context` uses."""
    if override_path:
        path = Path(override_path)
        document = load_document(path, "registry-unreadable")
        label = "the --registry override"
    else:
        registry_discovery = _import_sibling("_sdd_registry_discovery", "registry_discovery.py")
        try:
            path = registry_discovery.discover_artifact(REGISTRY_FILENAME)
        except registry_discovery.DiscoveryError as exc:
            raise ValidatorError("registry-discovery-failed", str(exc))
        document = load_document(path, "registry-unreadable")
        label = "the ADR-0025-discovered Registry"
    if not isinstance(document, dict):
        raise ValidatorError("registry-unreadable", f"{label}'s top level is not an object")
    return document, label


def whole_registry_digest(registry_document):
    """`sha256:<64-hex>` over the whole Registry, computed by
    `generate-registry-digest.py`'s OWN `canonical_digest` -- the exact
    function its `--whole` branch calls (see module docstring, "Digest
    single-sourcing")."""
    module = _import_sibling("_sdd_generate_registry_digest", "generate-registry-digest.py")
    try:
        return "sha256:" + module.canonical_digest(registry_document)
    except module.DigestError as exc:
        raise ValidatorError("registry-digest-computation-failed", str(exc))


def check_registry_digest_unbound(document, registry_document, source_label):
    recorded = (document.get("context_binding") or {}).get("registry_digest")
    computed = whole_registry_digest(registry_document)
    if recorded == computed:
        return []
    return [Diagnostic(
        "registry-digest-unbound", "/context_binding/registry_digest",
        f"the whole-Registry digest of {source_label} ({computed}) does not equal this Evidence "
        f"instance's own recorded registry_digest ({recorded!r}); no exact-set check can be "
        f"meaningfully run against a Registry this instance is not provably about",
    )]


def check_affected_component_provenance(document, manifest_document, override_components):
    """The Evidence instance's own `dependency_pointers[]` derivation, the
    co-located Manifest's own, and any CLI override must all be set-identical
    (design.md; AC-051)."""
    evidence_set = affected_components_from_pointers(
        (document.get("context_binding") or {}).get("dependency_pointers")
    )
    claims = [("this Evidence instance's own dependency_pointers[]", evidence_set)]
    if manifest_document is not None:
        manifest_set = affected_components_from_pointers(
            (manifest_document.get("context_binding") or {}).get("dependency_pointers")
        )
        claims.append(("the co-located Facet Manifest's own dependency_pointers[]", manifest_set))
    if override_components is not None:
        claims.append(("the --affected-components/--context override", set(override_components)))

    diags = []
    for label, candidate in claims[1:]:
        if candidate != evidence_set:
            diags.append(Diagnostic(
                "affected-component-provenance-mismatch", "/context_binding/dependency_pointers",
                f"{label} names {sorted(candidate)!r}, which is not set-identical to this Evidence "
                f"instance's own dependency_pointers[]-derived affected-component set "
                f"{sorted(evidence_set)!r}",
            ))
    return diags, evidence_set


# --------------------------------------------------------------------------
# Structural / exact-set / bidirectional checks (B6/B7).
# --------------------------------------------------------------------------

def _capability_evaluations(document):
    value = document.get("capability_evaluations")
    return value if isinstance(value, list) else []


def _conditional_facet_evaluations(entry):
    value = entry.get("conditional_facet_evaluations")
    return value if isinstance(value, list) else []


def check_capability_set_mismatch(document, registry_document):
    registry_ids = {c.get("id") for c in registry_document.get("capabilities", []) if isinstance(c, dict)}
    evidence_ids = {e.get("capability_id") for e in _capability_evaluations(document)}
    missing = sorted(i for i in registry_ids - evidence_ids if i is not None)
    extra = sorted(i for i in evidence_ids - registry_ids if i is not None)
    if not missing and not extra:
        return []
    return [Diagnostic(
        "capability-set-mismatch", "/capability_evaluations",
        f"capability_evaluations[].capability_id is not exactly the provenance-bound Registry's "
        f"own capabilities[].id set (missing: {missing!r}; unexpected: {extra!r})",
    )]


def check_capability_evaluation_id_duplicate(document):
    diags = []
    seen = {}
    for index, entry in enumerate(_capability_evaluations(document)):
        capability_id = entry.get("capability_id")
        if capability_id in seen:
            diags.append(Diagnostic(
                "capability-evaluation-id-duplicate",
                f"/capability_evaluations/{index}/capability_id",
                f"duplicate capability_id {capability_id!r} (first seen at "
                f"/capability_evaluations/{seen[capability_id]}/capability_id)",
            ))
        else:
            seen[capability_id] = index
    return diags


def check_trigger_evaluation_set_mismatch(document, affected):
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        observed = {e.get("component_id") for e in entry.get("trigger_evaluations", [])}
        if observed != affected:
            diags.append(Diagnostic(
                "trigger-evaluation-set-mismatch",
                f"/capability_evaluations/{index}/trigger_evaluations",
                f"trigger_evaluations[].component_id is {sorted(str(c) for c in observed)!r}, not "
                f"exactly the provenance-bound affected-component set {sorted(affected)!r} "
                f"(capability_id {entry.get('capability_id')!r})",
            ))
    return diags


def _duplicate_component_ids(evaluations):
    seen = {}
    duplicates = []
    for index, evaluation in enumerate(evaluations):
        component_id = evaluation.get("component_id")
        if component_id in seen:
            duplicates.append((index, component_id, seen[component_id]))
        else:
            seen[component_id] = index
    return duplicates


def check_component_evaluation_id_duplicate(document):
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        base = f"/capability_evaluations/{index}/trigger_evaluations"
        for position, component_id, first in _duplicate_component_ids(entry.get("trigger_evaluations", [])):
            diags.append(Diagnostic(
                "component-evaluation-id-duplicate", f"{base}/{position}/component_id",
                f"duplicate component_id {component_id!r} in one trigger_evaluations[] array "
                f"(first seen at {base}/{first}/component_id)",
            ))
        for facet_index, facet_entry in enumerate(_conditional_facet_evaluations(entry)):
            facet_base = (f"/capability_evaluations/{index}/conditional_facet_evaluations/"
                          f"{facet_index}/evaluations")
            for position, component_id, first in _duplicate_component_ids(facet_entry.get("evaluations", [])):
                diags.append(Diagnostic(
                    "component-evaluation-id-duplicate", f"{facet_base}/{position}/component_id",
                    f"duplicate component_id {component_id!r} in one "
                    f"conditional_facet_evaluations[].evaluations[] array "
                    f"(first seen at {facet_base}/{first}/component_id)",
                ))
    return diags


def check_matched_result_contradiction(document):
    """Bidirectional (B6): an earlier revision of this validator, under the
    retired name `matched-without-evidence`, checked only the first
    direction."""
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        matched = entry.get("matched")
        results = [e.get("result") for e in entry.get("trigger_evaluations", [])]
        any_true = any(result is True for result in results)
        if matched is True and not any_true:
            diags.append(Diagnostic(
                "matched-result-contradiction", f"/capability_evaluations/{index}/matched",
                f"matched is true but no trigger_evaluations[].result is true "
                f"(capability_id {entry.get('capability_id')!r})",
            ))
        elif matched is False and any_true:
            diags.append(Diagnostic(
                "matched-result-contradiction", f"/capability_evaluations/{index}/matched",
                f"matched is false but at least one trigger_evaluations[].result is true "
                f"(capability_id {entry.get('capability_id')!r})",
            ))
    return diags


def check_conditional_facet_set_mismatch(document, registry_document):
    """B7 predicate-instance keying: positional (`declaration_index`, 0-based)
    identity against that Capability's own `conditional_facets[]` array --
    NEVER a comparison of the set of distinct `facet` NAMES, which cannot
    distinguish "declared F twice" from "declared F once" (Epic A2's own
    Registry schema permits the former within one Capability)."""
    declarations = {
        c.get("id"): c.get("conditional_facets", [])
        for c in registry_document.get("capabilities", []) if isinstance(c, dict)
    }
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        if entry.get("matched") is not True:
            continue
        capability_id = entry.get("capability_id")
        if capability_id not in declarations:
            continue  # capability-set-mismatch already covers an unknown id
        declared = declarations[capability_id] or []
        recorded = _conditional_facet_evaluations(entry)
        pointer = f"/capability_evaluations/{index}/conditional_facet_evaluations"

        by_index = {}
        for position, facet_entry in enumerate(recorded):
            declaration_index = facet_entry.get("declaration_index")
            if declaration_index in by_index:
                diags.append(Diagnostic(
                    "conditional-facet-set-mismatch", f"{pointer}/{position}/declaration_index",
                    f"declaration_index {declaration_index!r} appears more than once for "
                    f"capability_id {capability_id!r}; this array is positionally keyed and each "
                    f"index identifies exactly one Registry declaration",
                ))
            else:
                by_index[declaration_index] = facet_entry

        if len(recorded) != len(declared):
            diags.append(Diagnostic(
                "conditional-facet-set-mismatch", pointer,
                f"conditional_facet_evaluations[] has {len(recorded)} entries but the "
                f"provenance-bound Registry declares {len(declared)} conditional_facets[] entries "
                f"for capability_id {capability_id!r}; cardinality is bound to that array's own "
                f"LENGTH, not to its distinct-facet-name count",
            ))

        for declaration_index, declaration in enumerate(declared):
            facet_entry = by_index.get(declaration_index)
            if facet_entry is None:
                diags.append(Diagnostic(
                    "conditional-facet-set-mismatch", f"{pointer}/{declaration_index}",
                    f"no entry carries declaration_index {declaration_index}, which the "
                    f"provenance-bound Registry declares for capability_id {capability_id!r} "
                    f"(facet {declaration.get('facet')!r})",
                ))
            elif facet_entry.get("facet") != declaration.get("facet"):
                diags.append(Diagnostic(
                    "conditional-facet-set-mismatch",
                    f"{pointer}/{declaration_index}/facet",
                    f"declaration_index {declaration_index} carries facet "
                    f"{facet_entry.get('facet')!r} but the provenance-bound Registry declares "
                    f"{declaration.get('facet')!r} at that same index for capability_id "
                    f"{capability_id!r}",
                ))
        for declaration_index in sorted(k for k in by_index if isinstance(k, int) and k >= len(declared)):
            diags.append(Diagnostic(
                "conditional-facet-set-mismatch", f"{pointer}/{declaration_index}",
                f"declaration_index {declaration_index} has no counterpart in the "
                f"provenance-bound Registry's own conditional_facets[] array for capability_id "
                f"{capability_id!r} (length {len(declared)})",
            ))
    return diags


def check_conditional_facet_evaluation_set_mismatch(document, affected):
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        for facet_index, facet_entry in enumerate(_conditional_facet_evaluations(entry)):
            observed = {e.get("component_id") for e in facet_entry.get("evaluations", [])}
            if observed != affected:
                diags.append(Diagnostic(
                    "conditional-facet-evaluation-set-mismatch",
                    f"/capability_evaluations/{index}/conditional_facet_evaluations/"
                    f"{facet_index}/evaluations",
                    f"evaluations[].component_id is {sorted(str(c) for c in observed)!r}, not "
                    f"exactly the provenance-bound affected-component set {sorted(affected)!r} "
                    f"(capability_id {entry.get('capability_id')!r}, declaration_index "
                    f"{facet_entry.get('declaration_index')!r})",
                ))
    return diags


def check_applied_result_contradiction(document):
    """Bidirectional, the facet-level equivalent of
    `matched-result-contradiction`."""
    diags = []
    for index, entry in enumerate(_capability_evaluations(document)):
        for facet_index, facet_entry in enumerate(_conditional_facet_evaluations(entry)):
            applied = facet_entry.get("applied")
            any_true = any(e.get("result") is True for e in facet_entry.get("evaluations", []))
            pointer = (f"/capability_evaluations/{index}/conditional_facet_evaluations/"
                       f"{facet_index}/applied")
            context = (f"(capability_id {entry.get('capability_id')!r}, declaration_index "
                       f"{facet_entry.get('declaration_index')!r})")
            if applied is True and not any_true:
                diags.append(Diagnostic(
                    "applied-result-contradiction", pointer,
                    f"applied is true but no evaluations[].result is true {context}",
                ))
            elif applied is False and any_true:
                diags.append(Diagnostic(
                    "applied-result-contradiction", pointer,
                    f"applied is false but at least one evaluations[].result is true {context}",
                ))
    return diags


def check_array_not_stable_sorted(document):
    diags = []
    capability_ids = [e.get("capability_id") for e in _capability_evaluations(document)]
    if all(isinstance(i, str) for i in capability_ids) and capability_ids != sorted(capability_ids):
        diags.append(Diagnostic(
            "array-not-stable-sorted", "/capability_evaluations",
            "capability_evaluations is not sorted lexicographically ascending by capability_id",
        ))
    diagnostics = document.get("diagnostics")
    if isinstance(diagnostics, list):
        keys = [(d.get("id"), d.get("detail")) for d in diagnostics if isinstance(d, dict)]
        if (len(keys) == len(diagnostics)
                and all(isinstance(i, str) and isinstance(d, str) for i, d in keys)
                and keys != sorted(keys)):
            diags.append(Diagnostic(
                "array-not-stable-sorted", "/diagnostics",
                "diagnostics is not sorted lexicographically ascending by (id, detail)",
            ))
    return diags


# --------------------------------------------------------------------------
# Orchestration.
# --------------------------------------------------------------------------

def validate_document(document, registry_document, registry_source_label,
                      manifest_document, override_components):
    """The fail-closed ladder (module docstring, "Check ordering"). Pure over
    already-parsed structures apart from the schema/digest dependencies."""
    schema_diags = check_schema_invalid(document, load_schema())
    if schema_diags:
        return schema_diags

    binding_diags = check_registry_digest_unbound(document, registry_document, registry_source_label)
    if binding_diags:
        return binding_diags

    provenance_diags, affected = check_affected_component_provenance(
        document, manifest_document, override_components
    )
    if provenance_diags:
        return provenance_diags

    diags = []
    diags.extend(check_capability_set_mismatch(document, registry_document))
    diags.extend(check_capability_evaluation_id_duplicate(document))
    diags.extend(check_trigger_evaluation_set_mismatch(document, affected))
    diags.extend(check_component_evaluation_id_duplicate(document))
    diags.extend(check_matched_result_contradiction(document))
    diags.extend(check_conditional_facet_set_mismatch(document, registry_document))
    diags.extend(check_conditional_facet_evaluation_set_mismatch(document, affected))
    diags.extend(check_applied_result_contradiction(document))
    diags.extend(check_array_not_stable_sorted(document))
    return diags


def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer, d.message))
    return [f"{PREFIX}: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def _override_components(args):
    """`--affected-components <csv>` or its `--context`-derived equivalent
    (design.md CLI contract). Returns None when neither is supplied."""
    if args.affected_components is not None and args.context is not None:
        raise ValidatorError(
            "argument-conflict",
            "--affected-components and --context are two spellings of one override; supply at most one",
        )
    if args.affected_components is not None:
        return {item.strip() for item in args.affected_components.split(",") if item.strip()}
    if args.context is not None:
        projection = load_document(Path(args.context), "context-unreadable")
        components = projection.get("components") if isinstance(projection, dict) else None
        if not isinstance(components, dict):
            raise ValidatorError("context-unreadable",
                                 "--context target has no components object to derive a set from")
        return set(components.keys())
    return None


def _manifest_path(args, evidence_path):
    """`--manifest`, or the sibling `facet-manifest.yaml` beside `--evidence`
    on a Full-track Evidence instance. Existence is probed here; the file is
    not read until after the reader-side journal check has passed."""
    if args.manifest:
        return Path(args.manifest)
    sibling = evidence_path.parent / SIBLING_MANIFEST_FILENAME
    return sibling if sibling.is_file() else None


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass

    parser = argparse.ArgumentParser(prog="validate-resolver-evidence")
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--registry")
    parser.add_argument("--affected-components")
    parser.add_argument("--context")
    parser.add_argument("--manifest")
    args = parser.parse_args(argv)

    out = sys.stdout
    try:
        evidence_path = Path(args.evidence)
        manifest_path = _manifest_path(args, evidence_path)

        # Step 0: reader-side generation-consistency check, BEFORE any target
        # is read (design.md; AC-054).
        paths_being_read = [evidence_path] + ([manifest_path] if manifest_path else [])
        check_no_publication_in_progress(paths_being_read)

        document = load_document(evidence_path, "evidence-unreadable")
        manifest_document = None
        if manifest_path is not None:
            manifest_document = load_document(manifest_path, "manifest-unreadable")
            if not isinstance(manifest_document, dict):
                raise ValidatorError("manifest-unreadable", "manifest top level is not an object")
        override_components = _override_components(args)
        registry_document, registry_source_label = resolve_registry(args.registry)

        diags = validate_document(document, registry_document, registry_source_label,
                                  manifest_document, override_components)
    except ValidatorError as exc:
        out.write(f"{PREFIX}: {exc.diagnostic_id}: {exc.detail}\n")
        return 1

    if not diags:
        return 0
    for line in format_diagnostics(diags):
        out.write(line + "\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
