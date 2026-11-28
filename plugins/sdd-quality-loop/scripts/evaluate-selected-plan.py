#!/usr/bin/env python3
"""Evaluate implementation observations without weakening the legacy contract.

Consumes the current, approved Resolver manifest after its context/staleness
checks. Does not execute verifiers or establish provider deployment success.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import stat
import subprocess
from pathlib import Path
import sys
import tempfile
from types import ModuleType, SimpleNamespace
from typing import Any

sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))


def load(name: str, filename: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    if spec is None or spec.loader is None:
        raise ImportError('module-discovery-failed: ' + filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _build_legacy_bridge() -> SimpleNamespace:
    baseline_ids = {'lint', 'typecheck', 'unit-tests', 'build', 'placeholder-scan', 'task-state-check'}
    risk_tiers = {
        'low': {'lint', 'typecheck', 'build', 'placeholder-scan', 'task-state-check'},
        'medium': {'lint', 'typecheck', 'build', 'placeholder-scan', 'task-state-check', 'unit-tests', 'acceptance-tests', 'regression'},
        'high': {'lint', 'typecheck', 'build', 'placeholder-scan', 'task-state-check', 'unit-tests', 'acceptance-tests', 'regression', 'requirement-traceability', 'check-component-coverage'},
        'critical': {'lint', 'typecheck', 'build', 'placeholder-scan', 'task-state-check', 'unit-tests', 'acceptance-tests', 'regression', 'requirement-traceability', 'check-component-coverage'},
    }

    def _str_field(check: dict[str, Any], key: str) -> str:
        val = check.get(key)
        return val.strip() if isinstance(val, str) else ''

    def _capability_enforcement_declared(root: str) -> bool:
        return os.path.isfile(os.path.join(root, 'sdd', 'project-context.yaml'))

    def _discover_project_root(contract_path: str, fallback_root: str) -> str:
        try:
            contract_abs = os.path.abspath(contract_path)
        except Exception:
            return fallback_root
        current = os.path.dirname(contract_abs)
        while True:
            try:
                rel = os.path.relpath(contract_abs, current)
            except ValueError:
                return fallback_root
            segments = rel.split(os.sep)
            if len(segments) > 1 and segments[0] == 'specs':
                return current
            parent = os.path.dirname(current)
            if parent == current:
                return fallback_root
            current = parent

    def validate_evidence_path(label: str, raw_path: Any, root: str, failures: list[str]) -> bool:
        before = len(failures)
        if raw_path is not None and not isinstance(raw_path, str):
            failures.append(f'{label} must be a string')
            return False
        trimmed = raw_path.strip() if isinstance(raw_path, str) else ''
        if not trimmed:
            failures.append(f'{label} is missing or empty')
            return False
        if trimmed.startswith('/') or (len(trimmed) >= 2 and trimmed[1] == ':') or trimmed.startswith('\\\\'):
            failures.append(f'{label} is an absolute path: {raw_path}')
            return False
        try:
            abs_root = os.path.realpath(os.path.abspath(root))
            resolved = os.path.realpath(os.path.join(abs_root, trimmed))
        except Exception:
            failures.append(f'{label} path could not be resolved: {raw_path}')
            return False
        if not resolved.startswith(abs_root + os.sep) and resolved != abs_root:
            failures.append(f'{label} path escapes repo root: {raw_path}')
            return False
        if not os.path.exists(resolved):
            failures.append(f'{label} file missing: {raw_path}')
        elif not os.path.isfile(resolved):
            failures.append(f'{label} is not a regular file: {raw_path}')
        elif os.path.getsize(resolved) == 0:
            failures.append(f'{label} file is empty: {raw_path}')
        return len(failures) == before

    def run_contract(contract_path: str, root: str) -> tuple[str, list[str]]:
        task_id = '?'
        try:
            doc = json.loads(Path(contract_path).read_text(encoding='utf-8'))
            if isinstance(doc, dict) and isinstance(doc.get('task_id'), str):
                task_id = doc['task_id']
        except Exception:
            pass
        proc = subprocess.run(
            ['node', str(SCRIPTS / 'check-contract.ts'), str(contract_path), str(root)],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode == 0:
            return task_id, []
        lines = [ln.strip().removeprefix('- ').strip() for ln in (proc.stdout + '\n' + proc.stderr).splitlines() if ln.strip().startswith('- ')]
        return task_id, lines or [(proc.stdout + proc.stderr).strip() or 'check-contract failed']

    return SimpleNamespace(
        BASELINE_IDS=baseline_ids,
        RISK_TIERS=risk_tiers,
        COMPILE_CHECKS={'lint', 'typecheck', 'build'},
        NONCODE_STACKS={'shell', 'docs', 'spec'},
        CAPABILITY_STATE_GATED_IDS={'check-component-coverage'},
        _capability_enforcement_declared=_capability_enforcement_declared,
        _discover_project_root=_discover_project_root,
        _str_field=_str_field,
        validate_evidence_path=validate_evidence_path,
        run=run_contract,
    )


legacy = _build_legacy_bridge()
facets = load('selected_plan_facets', 'validate-facet-manifest.py')
resolver_evidence = load('selected_plan_resolver_evidence', 'validate-resolver-evidence.py')
registry_checks = load('selected_plan_registry', 'validate-capability-registry.py')
digest = load('selected_plan_digest', 'generate-registry-digest.py')


def schema(name: str) -> dict[str, Any]:
    packaged = SCRIPTS.parent / 'contracts' / name
    if packaged.is_file():
        source = packaged
    else:
        git_root = facets._find_git_root(str(SCRIPTS))
        if not git_root:
            raise FileNotFoundError('schema-discovery-failed: ' + name)
        source = Path(git_root) / 'contracts' / name
    document = json.loads(source.read_text(encoding='utf-8'))
    if (not isinstance(document, dict) or '$schema' not in document or
            document.get('$id') != 'https://github.com/aharada54914/sdd-forge/contracts/' + name):
        raise ValueError('schema-identity-invalid: ' + name)
    return document


def validate_plan(plan: Any, expected: Any) -> list[str]:
    """Validate persisted bytes against the schema and recomputed input result."""
    contract = schema('selected-verification-plan-v2.schema.json' if isinstance(plan, dict) and plan.get('schema') == 'selected-verification-plan/v2' else 'selected-verification-plan.schema.json')
    errors = list(facets.validate_against_schema(plan, contract))
    # The Foundation validator supports if/then, but not the allOf keyword.
    if isinstance(plan, dict) and plan.get('schema') != 'selected-verification-plan/v2' and isinstance(plan.get('checks'), list):
        for check in plan['checks']:
            for rule in contract['definitions']['check']['allOf']:
                errors.extend(facets.validate_against_schema(check, rule))
    if plan != expected:
        errors.append('selected-plan-input-mismatch')
    return errors


def evaluate(registry_path: Path, manifest_path: Path, contract_path: Path,
             root: Path) -> tuple[dict[str, Any], list[str]]:
    paths = {'registry_sha256': registry_path, 'facet_manifest_sha256': manifest_path,
             'verification_contract_sha256': contract_path}
    raw = {key: path.read_bytes() for key, path in paths.items()}
    registry = json.loads(raw['registry_sha256'])
    manifest = resolver_evidence.load_document(manifest_path, 'manifest-unreadable')
    contract = json.loads(raw['verification_contract_sha256'])
    errors = list(facets.validate_against_schema(registry, schema('capability-registry.schema.json')))
    errors.extend(facets.validate_document(manifest))
    if errors:
        raise ValueError('invalid Registry or Facet Manifest: ' + str(errors))
    for check in (registry_checks.check_a_gate_id_uniqueness,
                  registry_checks.check_i_capability_id_uniqueness,
                  registry_checks.check_f_referential_integrity):
        check(registry, errors)
    if errors:
        raise ValueError('; '.join(errors))
    if manifest['context_binding']['registry_digest'] != 'sha256:' + digest.canonical_digest(registry):
        raise ValueError('registry-digest-mismatch')
    gates = {g['id']: g for g in registry['gates']}
    capabilities = {c['id']: c for c in registry['capabilities']}
    if not set(manifest['capabilities']) <= set(capabilities):
        raise ValueError('unknown-resolved-capability')
    selected_ids = {gid for cid in manifest['capabilities'] for gid in capabilities[cid]['gate_ids']}
    expected_gates = [{key: gates[gid][key] for key in ('id', 'stage', 'blocking')}
                      for gid in sorted(selected_ids)]
    if manifest['resolved_gates'] != expected_gates:
        raise ValueError('registry-projection-mismatch')
    if isinstance(contract, dict) and contract.get('schema') == 'verification-contract/v3':
        from cloud_verification import saved_profile_plan
        plan = saved_profile_plan(raw['verification_contract_sha256'], root)
        if plan['feature'] != manifest['feature']:
            raise ValueError('cloud-feature-mismatch')
        if any(path.read_bytes() != raw[key] for key, path in paths.items()):
            raise ValueError('input-changed-during-evaluation')
        if validate_plan(plan, plan):
            raise ValueError('invalid selected verification plan')
        return plan, ['cloud profile requires fresh authenticated collection; saved evidence is not provenance']
    if not isinstance(contract, dict) or not isinstance(contract.get('checks'), list):
        raise ValueError('invalid verification contract')
    observations = contract['checks']
    if any(not isinstance(c, dict) or not isinstance(c.get('id'), str) for c in observations):
        raise ValueError('invalid check identity')
    if len({c['id'] for c in observations}) != len(observations):
        raise ValueError('duplicate check identity')
    task_id, legacy_errors = legacy.run(str(contract_path), str(root))
    observations = {c['id']: c for c in observations}
    if any(cid in gates and gates[cid]['stage'] != 'implementation' for cid in observations):
        raise ValueError('nonimplementation-observation')
    required_ids = set(legacy.RISK_TIERS.get(contract.get('risk'), legacy.BASELINE_IDS))
    if not legacy._capability_enforcement_declared(str(root)):
        required_ids -= legacy.CAPABILITY_STATE_GATED_IDS
    # Preserve the existing explicit non-code compile waiver, never omission.
    required_ids -= {cid for cid, observation in observations.items()
                     if contract.get('stack') in legacy.NONCODE_STACKS
                     and cid in legacy.COMPILE_CHECKS and observation.get('required') is False}
    selected = {gid: gates[gid] for gid in selected_ids if gates[gid]['stage'] == 'implementation'}
    checks = []
    evidence_root = legacy._discover_project_root(str(contract_path), str(root))
    for cid in sorted(set(observations) | set(selected) | required_ids):
        observation = observations.get(cid, {})
        gate = selected.get(cid)
        legacy_required = observation.get('required') is True or cid in required_ids
        required = legacy_required or bool(gate and gate['blocking'])
        item = {'id': cid, 'sources': (['legacy-contract'] if cid in observations or cid in required_ids else []) +
                (['registry'] if gate else []), 'stage': 'implementation',
                'obligation': 'required' if required else 'optional', 'blocking': required,
                'applicability': 'applicable', 'result': 'not-run'}
        if cid in required_ids and observation.get('required') is not True:
            item.update(result='unknown', reason='migration-pending-required')
        elif not required and not gate and observation.get('required') is False:
            item.update(applicability='not-applicable', result='not-applicable',
                        reason='legacy-optional-not-selected')
        elif gate and not legacy.validate_evidence_path('verifier', gate['implementation_ref'], root, []):
            item.update(result='unavailable', reason='verifier-missing')
        elif not all(legacy._str_field(observation, key) for key in ('command', 'started_at', 'finished_at')):
            item['reason'] = 'not-executed'
        else:
            exit_code = observation.get('exit_code')
            passed = observation.get('passes')
            if type(exit_code) is not int or type(passed) is not bool or passed != (exit_code == 0):
                item.update(result='unknown', reason='execution-status-unknown')
            else:
                evidence = legacy._str_field(observation, 'evidence')
                if legacy.validate_evidence_path('observation', evidence, evidence_root, []):
                    item.update(result='passed' if passed else 'failed', evidence_path=evidence)
                    if not passed:
                        item['reason'] = 'observed-failure'
                else:
                    item.update(result='unknown', reason='execution-status-unknown')
        if legacy_required and item['result'] in ('unavailable', 'not-run', 'unknown'):
            item['reason'] = 'migration-pending-required'
        checks.append(item)
    failed_ids = {c['id'] for c in checks if c['result'] == 'failed'}
    # A measured failure is NEEDS_WORK; invalid/missing evidence is BLOCKED.
    blocking_errors = [e for e in legacy_errors if not any(
        e == "required check '{}' has passes=false".format(cid) for cid in failed_ids)]
    blocked = bool(blocking_errors) or any(c['blocking'] and c['result'] in
        ('unavailable', 'not-run', 'unknown') for c in checks)
    verdict = 'BLOCKED' if blocked else ('NEEDS_WORK' if any(
        c['blocking'] and c['result'] == 'failed' for c in checks) else 'PASS')
    plan = {'schema': 'selected-verification-plan/v1', 'feature': manifest['feature'],
            'task_id': task_id, 'bindings': {key: hashlib.sha256(value).hexdigest() for key, value in raw.items()},
            'checks': checks, 'verdict': verdict}
    # Do not persist a binding to bytes different from those evaluated.
    if any(path.read_bytes() != raw[key] for key, path in paths.items()):
        raise ValueError('input-changed-during-evaluation')
    if validate_plan(plan, plan):
        raise ValueError('invalid selected verification plan')
    return plan, legacy_errors


def validate_output(output: Path, root: Path, plan: dict[str, Any]) -> Path:
    """Only publish to the task's canonical, symlink-free verification directory."""
    if '..' in output.parts:
        raise ValueError('output-path-traversal')
    destination = Path(os.path.abspath(output))
    expected = (Path(os.path.abspath(root)) / 'specs' / plan['feature'] /
                'verification' / plan['task_id'] / 'selected-plan.json')
    if destination != expected:
        raise ValueError('output-outside-task-verification-directory')
    for path in (destination, *destination.parents):
        try:
            metadata = path.lstat()
        except FileNotFoundError:
            continue
        if (stat.S_ISLNK(metadata.st_mode) or
                getattr(metadata, 'st_file_attributes', 0) & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0)):
            raise ValueError('output-path-symlink-or-reparse-point')
    if not destination.parent.is_dir():
        raise ValueError('task-verification-directory-missing')
    return destination


def write_plan(output: Path, root: Path, plan: dict[str, Any]) -> None:
    destination = validate_output(output, root, plan)
    fd, temporary = tempfile.mkstemp(prefix='.selected-plan-', dir=destination.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(plan, indent=2) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        # Recheck before publishing. Replacing the entry also avoids following
        # hardlinks at an existing output into another repository file.
        validate_output(output, root, plan)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('repo-root', 'registry', 'facet-manifest', 'contract', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        inputs = (args.registry, args.facet_manifest, args.contract)
        plan, errors = evaluate(*inputs, args.repo_root)
        destination = validate_output(args.output, args.repo_root, plan)
        if destination in {path.resolve() for path in inputs}:
            raise ValueError('output must not overwrite a policy input')
        write_plan(destination, args.repo_root, plan)
        if validate_plan(json.loads(args.output.read_text(encoding='utf-8')), plan):
            raise ValueError('selected-plan-readback-mismatch')
        for error in errors:
            print(error, file=sys.stderr)
        print('selected-verification-plan: ' + plan['verdict'])
        return 0 if plan['verdict'] == 'PASS' else 1
    except (OSError, ValueError, TypeError, KeyError, resolver_evidence.ValidatorError) as error:
        print('selected-verification-plan: BLOCKED: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
