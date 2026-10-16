#!/usr/bin/env python3
"""Evaluate implementation observations without weakening the legacy contract.

Consumes the current, approved Resolver manifest after its context/staleness
checks. Does not execute verifiers or establish provider deployment success.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


legacy = load('selected_plan_legacy', 'check-contract.py')
facets = load('selected_plan_facets', 'validate-facet-manifest.py')
registry_checks = load('selected_plan_registry', 'validate-capability-registry.py')
digest = load('selected_plan_digest', 'generate-registry-digest.py')


def schema(name):
    packaged = SCRIPTS.parent / 'contracts' / name
    if packaged.is_file():
        return json.loads(packaged.read_text(encoding='utf-8'))
    git_root = facets._find_git_root(str(SCRIPTS))
    if git_root:
        return json.loads((Path(git_root) / 'contracts' / name).read_text(encoding='utf-8'))
    raise FileNotFoundError('schema-discovery-failed: ' + name)


def validate_plan(plan, expected):
    """Validate persisted bytes against the schema and recomputed input result."""
    contract = schema('selected-verification-plan.schema.json')
    errors = list(facets.validate_against_schema(plan, contract))
    # The Foundation validator supports if/then, but not the allOf keyword.
    if isinstance(plan, dict) and isinstance(plan.get('checks'), list):
        for check in plan['checks']:
            for rule in contract['definitions']['check']['allOf']:
                errors.extend(facets.validate_against_schema(check, rule))
    if plan != expected:
        errors.append('selected-plan-input-mismatch')
    return errors


def evaluate(registry_path, manifest_path, contract_path, root):
    paths = {'registry_sha256': registry_path, 'facet_manifest_sha256': manifest_path,
             'verification_contract_sha256': contract_path}
    raw = {key: path.read_bytes() for key, path in paths.items()}
    registry = json.loads(raw['registry_sha256'])
    manifest = facets.load_manifest(str(manifest_path))
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('repo-root', 'registry', 'facet-manifest', 'contract', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        inputs = (args.registry, args.facet_manifest, args.contract)
        if args.output.resolve() in {path.resolve() for path in inputs}:
            raise ValueError('output must not overwrite a policy input')
        plan, errors = evaluate(*inputs, args.repo_root)
        args.output.write_text(json.dumps(plan, indent=2) + '\n', encoding='utf-8')
        if validate_plan(json.loads(args.output.read_text(encoding='utf-8')), plan):
            raise ValueError('selected-plan-readback-mismatch')
        for error in errors:
            print(error, file=sys.stderr)
        print('selected-verification-plan: ' + plan['verdict'])
        return 0 if plan['verdict'] == 'PASS' else 1
    except (OSError, ValueError, TypeError, KeyError) as error:
        print('selected-verification-plan: BLOCKED: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
