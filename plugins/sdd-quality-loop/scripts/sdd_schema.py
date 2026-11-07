"""Shared, offline Draft 7 validation with stable CLI diagnostics.

The bundled library owns validation. This adapter owns reference policy,
ECMA end anchors and the existing RFC 6901 diagnostic presentation.
"""
import json
import hashlib
import importlib.util
import sys
import re
from functools import lru_cache
from pathlib import Path

_directory = Path(__file__).resolve().parent
_vendor_name = '_sdd_schema_vendor_' + hashlib.sha256(str(_directory).encode()).hexdigest()
if _vendor_name not in sys.modules:
    _spec = importlib.util.spec_from_file_location(_vendor_name, _directory / '_schema_vendor/__init__.py')
    _vendor = importlib.util.module_from_spec(_spec)
    sys.modules[_vendor_name] = _vendor
    try:
        _spec.loader.exec_module(_vendor)
    except BaseException:
        del sys.modules[_vendor_name]
        raise
fastjsonschema = __import__(_vendor_name + '.fastjsonschema', fromlist=['fastjsonschema'])


def runtime_files():
    return tuple(_directory / name for name in (
        'sdd_schema.py', '_schema_vendor/__init__.py', '_schema_vendor/draft-07.json',
        '_schema_vendor/fastjsonschema.whl'))


def _escape_pointer_token(token):
    return str(token).replace('~', '~0').replace('/', '~1')


def _reject_remote(uri):
    raise ValueError(f'external schema reference is forbidden: {uri}')


def _schema_nodes(schema):
    if isinstance(schema, bool):
        return
    if not isinstance(schema, dict):
        raise ValueError('schema must be an object or boolean')
    yield schema
    for key in ('properties', 'patternProperties', 'definitions', '$defs', 'dependencies'):
        children = schema.get(key, {})
        if not isinstance(children, dict):
            raise ValueError(f'{key} must be an object')
        for child in children.values():
            if key != "dependencies" or not isinstance(child, list):
                yield from _schema_nodes(child)
    for key in ('allOf', 'anyOf', 'oneOf'):
        for child in schema.get(key, []):
            yield from _schema_nodes(child)
    for key in ('not', 'if', 'then', 'else', 'items', 'additionalItems',
                'additionalProperties', 'propertyNames', 'contains'):
        if key in schema:
            children = schema[key] if isinstance(schema[key], list) else [schema[key]]
            for child in children:
                yield from _schema_nodes(child)


class _DiagnosticDraft7(fastjsonschema.CodeGeneratorDraft07):
    def _expand_refs(self, definition):
        # Diagnostics must preserve literal $ref keys in const/enum/default data.
        # The compiler already resolves actual schema references before validation.
        return definition


def _compile(schema):
    resolver = fastjsonschema.RefResolver.from_schema(schema, store={}, handlers={
        'http': _reject_remote, 'https': _reject_remote, 'file': _reject_remote,
    })
    generator = _DiagnosticDraft7(schema, resolver=resolver, use_default=False,
                                  use_formats=False, fast_fail=False)
    namespace = generator.global_state
    exec(generator.func_code, namespace)
    return namespace[resolver.get_scope_name()]


@lru_cache(maxsize=1)
def _metavalidator():
    schema = json.loads(Path(__file__).with_name('_schema_vendor').joinpath('draft-07.json').read_text())
    return _compile(schema)


@lru_cache(maxsize=32)
def _validator(serialized):
    schema = json.loads(serialized)
    _metavalidator()(schema)
    dialect = schema.get('$schema') if isinstance(schema, dict) else None
    compatible_2020 = dialect == 'https://json-schema.org/draft/2020-12/schema'
    if compatible_2020:
        # These consumers use the common vocabulary plus $defs. Preserve $ref
        # siblings with allOf; reject newer-only keywords rather than ignore them.
        for node in list(_schema_nodes(schema)):
            if '$schema' in node:
                if node['$schema'] != dialect:
                    raise ValueError('mixed schema dialects are unsupported')
                node['$schema'] = 'http://json-schema.org/draft-07/schema#'
            if '$ref' in node and len(node) > 1:
                ref = node.pop('$ref')
                node.setdefault('allOf', []).append({'$ref': ref})
    _metavalidator()(schema)
    originals = {}
    known = set(json.loads(Path(__file__).with_name('_schema_vendor').joinpath('draft-07.json').read_text())['properties'])
    for node in _schema_nodes(schema):
        _metavalidator()(node)
        unknown = set(node) - known - ({"$defs"} if compatible_2020 else set())
        if unknown:
            raise ValueError(f'unsupported schema keywords: {sorted(unknown)!r}')
        ref = node.get('$ref', '#')
        if not isinstance(ref, str) or not (ref == '#' or ref.startswith('#/')):
            raise ValueError(f'only same-document schema references are allowed: {ref!r}')
        if '$schema' in node and node['$schema'] not in (
                'http://json-schema.org/draft-07/schema#', 'http://json-schema.org/draft-07/schema'):
            raise ValueError('only JSON Schema Draft 7 is supported')
        if 'pattern' in node:
            original = node['pattern']
            adapted = _ecma_anchor(original)
            originals[adapted] = original
            node['pattern'] = adapted
    return _compile(schema), originals


def _paths(document):
    """Map library display paths using actual keys, never splitting dotted keys."""
    result = {}
    def visit(value, name, pointer):
        result.setdefault(name, []).append(pointer)
        if isinstance(value, dict):
            for key, child in value.items():
                visit(child, name + '.' + key, pointer + '/' + _escape_pointer_token(key))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, name + '[' + str(index) + ']', pointer + '/' + str(index))
    visit(document, 'data', '')
    return result


def _diagnostics(error, paths, originals):
    locations = paths.get(error.name, [''])
    # A display-path collision cannot be resolved safely to an individual field.
    pointer = locations[0] if len(locations) == 1 else ''
    rule, value, constraint = error.rule, error.value, error.rule_definition
    if rule == 'required':
        for key in constraint:
            if key not in value:
                yield pointer + '/' + _escape_pointer_token(key), f'missing required property {key!r}'
        return
    if rule == 'additionalProperties':
        for key in value:
            if key not in error.definition.get('properties', {}) and not any(
                    re.search(_ecma_anchor(pattern), key)
                    for pattern in error.definition.get('patternProperties', {})):
                yield pointer + '/' + _escape_pointer_token(key), 'additional property not allowed'
        return
    if rule == 'propertyNames':
        for key in value:
            child = []
            _validate(key, constraint, constraint, pointer + '/' + _escape_pointer_token(key), child)
            yield from child
        return
    if rule == 'not':
        message = "value matched a schema under 'not'"
    elif rule == 'oneOf':
        count = re.search(r'\((\d+) matches found\)', error.message)
        message = f"expected exactly one 'oneOf' branch to match, {count[1]} matched" if count else error.message
    elif rule == 'const':
        message = f'expected const {constraint!r}, got {value!r}'
    elif rule == 'enum':
        message = f'expected one of {constraint!r}, got {value!r}'
    elif rule == 'type':
        message = f'expected type {constraint!r}, got {type(value).__name__}'
    elif rule == 'pattern':
        message = f'does not match pattern {originals.get(constraint, constraint)!r}'
    elif rule == 'minLength':
        message = f'length {len(value)} < minLength {constraint}'
    elif rule == 'minItems':
        message = f'array length {len(value)} < minItems {constraint}'
    elif rule == 'uniqueItems':
        # Ask the same engine for equality, keeping bool and number semantics aligned.
        for index, item in enumerate(value):
            equal = _compile({'const': item})
            for prior in value[:index]:
                try:
                    equal(prior)
                except fastjsonschema.JsonSchemaException:
                    continue
                yield pointer + '/' + str(index), 'duplicate item (uniqueItems violated)'
                break
        return
    else:
        message = error.message
    yield pointer, message


def _validate(instance, schema, root_schema, pointer, diags):
    if schema is not root_schema:
        schema = dict(schema, definitions=root_schema.get('definitions', {}))
    validator, originals = _validator(json.dumps(schema, sort_keys=True, ensure_ascii=False))
    try:
        validator(instance)
    except fastjsonschema.JsonSchemaValuesException as exc:
        paths = _paths(instance)
        for error in exc.errors:
            diags.extend((pointer + path, message) for path, message in _diagnostics(error, paths, originals))
    except fastjsonschema.JsonSchemaValueException as exc:
        diags.extend((pointer + path, message) for path, message in _diagnostics(exc, _paths(instance), originals))
def _ecma_anchor(pattern):
    """Rewrite unescaped, non-character-class `$` to `\\Z` (see module note
    above). Walks the pattern tracking backslash-escapes (an escape
    consumes exactly the following character, whatever it is) and `[...]`
    character-class state, including the ECMA-262/POSIX convention that a
    `]` in the first position of a class (optionally right after a leading
    `^`) is a literal member, not the closing bracket."""
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
        else:
            if ch == "]":
                in_class = False
            out.append(r"\$" if ch == "$" else ch)
            i += 1
    return "".join(out)
