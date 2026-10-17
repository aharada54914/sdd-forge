#!/usr/bin/env python3
"""Collect real advisory consumers; never sign, activate, or authorize promotion."""
import argparse
import hashlib
import importlib.util
import json
import os
import stat
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
POLICY_PATHS = {'context': 'sdd/project-context.yaml',
                'approval': 'sdd/project-context.approval.json',
                'anchor': 'sdd/.approved-context/project-context.approved.yaml',
                'registry': 'contracts/capability-registry.json'}
ARTIFACTS = set(POLICY_PATHS) | {'resolver_evidence', 'facet_manifest', 'coverage',
                               'verification_contract', 'selected_plan'}
OPERATIONS = ['resolver', 'manifest', 'resolver-evidence', 'coverage', 'selected-plan']
WORKFLOWS = {state: {'spec_profile': 'full', 'artifact_layout': layout, 'capability_enforcement': state}
             for state, layout in (('advisory', 'legacy-seven-layer'), ('required', 'facet-hybrid'))}


def load(name):
    spec = importlib.util.spec_from_file_location('a9_' + name.replace('-', '_'), SCRIPTS / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


resolver = load('resolve-project-context')
facets = load('validate-facet-manifest')
evidence = load('validate-resolver-evidence')
plans = load('evaluate-selected-plan')
ownership = load('resolve-component-paths')
coverage_gate = load('check-component-coverage')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE)


def commit(value):
    if not isinstance(value, str) or not re.fullmatch('[0-9a-f]{40}', value):
        raise ValueError('full commit ID required')
    return value


def artifact(raw):
    return {'sha256': sha(raw), 'contents': raw.decode('utf-8')}


def artifact_bytes(item):
    if set(item) != {'sha256', 'contents'} or not isinstance(item['contents'], str):
        raise ValueError('invalid artifact envelope')
    raw = item['contents'].encode('utf-8')
    if sha(raw) != item['sha256']:
        raise ValueError('artifact digest mismatch')
    return raw


def document(item):
    raw = artifact_bytes(item)
    with tempfile.TemporaryDirectory(prefix='a9-artifact-') as tmp:
        path = Path(tmp) / 'input'
        path.write_bytes(raw)
        return resolver._canonicalize(str(path), 'json' if raw.lstrip().startswith(b'{') else 'yaml')[1]



def relative_path(value):
    if (not isinstance(value, str) or not value or "\\" in value or ":" in value
            or value.startswith("/") or any(p in ("", ".", "..") for p in value.split("/"))):
        raise ValueError("evidence must use a normalized repository-relative file")
    return value


def read_input(root, path):
    target = root / relative_path(path)
    for item in (target, *target.parents):
        if item == root:
            break
        metadata = item.lstat()
        if (stat.S_ISLNK(metadata.st_mode) or
                getattr(metadata, 'st_file_attributes', 0) & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0)):
            raise ValueError('input symlinks and reparse points are not supported')
    if not target.is_file():
        raise ValueError('input must be a regular file')
    return target.read_bytes()


def replay_plan(record, docs, root, head_sha, owned):
    """Re-evaluate the contract, not the claimed plan, without executing evidence."""
    artifacts = record['artifacts']
    expected_paths = {relative_path(c['evidence']) for c in docs['verification_contract']['checks']
                      if c.get('evidence')}
    if set(record['verification_evidence']) != expected_paths:
        raise ValueError('verification evidence file set mismatch')
    with tempfile.TemporaryDirectory(prefix='a9-plan-replay-') as tmp:
        replay = Path(tmp)
        inputs = {'registry': 'contracts/capability-registry.json',
                  'facet_manifest': 'specs/' + record['feature'] + '/facet-manifest.yaml',
                  'verification_contract': 'specs/' + record['feature'] + '/verification/' + record['task_id'] + '/contract.json',
                  'context': POLICY_PATHS['context']}
        payloads = {relative_path(path): artifact_bytes(artifacts[name]) for name, path in inputs.items()}
        for path, item in record['verification_evidence'].items():
            if path in payloads:
                raise ValueError('evidence cannot replace policy inputs')
            payloads[path] = artifact_bytes(item)
        selected = {g['id'] for g in docs['facet_manifest']['resolved_gates']}
        for gate in docs['registry']['gates']:
            if gate['id'] in selected and gate['stage'] == 'implementation':
                path = relative_path(gate['implementation_ref'])
                raw = git(root, 'show', head_sha + ':' + path)
                if path in payloads and payloads[path] != raw:
                    raise ValueError('evidence cannot replace a committed verifier')
                payloads[path] = raw
        for path, raw in payloads.items():
            target = replay / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        provider = 'sdd/provider-bindings.yaml'
        if git(root, 'ls-tree', '--name-only', head_sha, '--', provider).strip():
            (replay / provider).write_bytes(git(root, 'show', head_sha + ':' + provider))
        actual_coverage = coverage_gate.run(str(replay / inputs['context']),
            str(replay / inputs['facet_manifest']), str(replay / provider), owned['records'])
        if docs['coverage'] != actual_coverage:
            raise ValueError('coverage does not match committed inputs and affected paths')
        expected, errors = plans.evaluate(*(replay / inputs[k] for k in
            ('registry', 'facet_manifest', 'verification_contract')), replay)
        if errors or plans.validate_plan(docs['selected_plan'], expected) or expected['verdict'] != 'PASS':
            raise ValueError('selected plan does not match actual required observations')


def validate_observation(record, head_sha, base_sha, root, expected_state="advisory"):
    """Consistency of trusted exports and immutable Git inputs, not authentication."""
    try:
        commit(head_sha); commit(base_sha)
        if (not re.fullmatch('[a-z0-9][a-z0-9-]*', record['feature'])
                or not re.fullmatch('T-[0-9]{3,}', record['task_id'])):
            raise ValueError('invalid observation identity')
        if (expected_state not in WORKFLOWS
                or record['schema'] != 'a9-' + expected_state + '-observation/v1' or record['state'] != expected_state
                or record['result'] != 'PASS' or record['authorization_checked'] is not False
                or record['head_sha'] != head_sha or record['base_sha'] != base_sha):
            raise ValueError('observation is inactive, failed, or bound to another revision')
        if not re.fullmatch('sha256:[0-9a-f]{64}', record['trusted_tooling_sha256']):
            raise ValueError('trusted tooling content binding is missing')
        if record['operations'] != [{'name': name, 'exit_code': 0} for name in OPERATIONS]:
            raise ValueError('required consumer execution is missing or failed')
        if 'request' in record:
            binding = record['request']
            raw_request = git(root, 'show', head_sha + ':' + relative_path(binding['path']))
            request = document(artifact(raw_request))
            if (sha(raw_request) != binding['sha256'] or request['schema'] != 'a9-advisory-request/v1'
                    or request['feature'] != record['feature']
                    or request['verification_contract'] != binding['verification_contract']):
                raise ValueError('request is not bound to the final PR head')
        artifacts = record['artifacts']
        if 'request' in record and git(root, 'show', head_sha + ':' + relative_path(
                record['request']['verification_contract'])) != artifact_bytes(artifacts['verification_contract']):
            raise ValueError('request contract is not the final head blob')
        if set(artifacts) != ARTIFACTS:
            raise ValueError('incomplete advisory artifacts')
        docs = {name: document(item) for name, item in artifacts.items()}
        for name, path in POLICY_PATHS.items():
            if git(root, 'show', head_sha + ':' + path) != artifacts[name]['contents'].encode('utf-8'):
                raise ValueError('policy artifact is not the PR head blob: ' + name)
        merge_base = git(root, 'merge-base', base_sha, head_sha).decode().strip()
        context, approval, manifest = docs['context'], docs['approval'], docs['facet_manifest']
        observed, registry, plan = docs['resolver_evidence'], docs['registry'], docs['selected_plan']
        if context['workflow'] != WORKFLOWS[expected_state]:
            raise ValueError('live Context does not match the expected phase')
        if not resolver._project_context_valid(context, ROOT):
            raise ValueError('invalid Context')
        if (docs['anchor'] != context or approval['schema'] != 'sdd-project-context-approval/v1'
                or approval['context_sha256'] != ownership.canonical_digest(context)):
            raise ValueError('publication content binding mismatch')
        if (observed['state'] != expected_state or observed['feature'] != record['feature']
                or manifest['feature'] != record['feature'] or plan['feature'] != record['feature']
                or facets.validate_document(manifest)
                or evidence.validate_document(observed, registry, 'recorded registry', manifest, None)):
            raise ValueError('invalid Resolver/Manifest observation')
        if (observed['context_binding']['full_context_revision'] != ownership.canonical_digest(context)
                or manifest['context_binding'] != observed['context_binding']
                or record['context_binding'] != observed['context_binding']
                or record['resolver'] != observed['resolver'] or manifest['resolver'] != observed['resolver']):
            raise ValueError('Context/Registry/ownership/Resolver binding mismatch')
        changed = git(root, 'diff', '--name-only', '-z', merge_base, head_sha).decode().rstrip('\0').split('\0')
        owned = ownership.classify_paths(ownership.load_config_dict(context), [p for p in changed if p])
        revision = ownership.canonical_digest(context)
        projection = resolver._projection(context, revision)
        expected_binding = resolver._assemble_context_binding(revision, owned['affected_components'],
            ownership.canonical_digest(projection), evidence.whole_registry_digest(registry),
            owned['context_binding']['ownership_digest'])
        if (observed['context_binding'] != expected_binding or observed['resolver'] != resolver._resolver_block()
                or manifest['affected_components'] != owned['affected_components']):
            raise ValueError('observation does not match independently derived Git/Context inputs')
        evaluations, warnings = [], []
        warned = resolver._evaluate_capabilities(SCRIPTS, registry, owned['affected_components'],
            projection['components'], evaluations, warnings)
        evaluations.sort(key=lambda entry: entry['capability_id'])
        if warned or warnings or observed['capability_evaluations'] != evaluations or observed['diagnostics']:
            raise ValueError('capability evaluation differs from committed inputs')
        expected_manifest = resolver._assemble_facet_manifest(record['feature'], owned['affected_components'],
            registry, evaluations, expected_binding, resolver._resolver_block())
        if manifest != expected_manifest:
            raise ValueError('Manifest does not match the recorded capability evaluation')
        coverage, contract = docs['coverage'], docs['verification_contract']
        if (coverage['schema'] != 'check-component-coverage-verdict/v1'
                or coverage['state'] != expected_state or coverage['manifest_status'] != 'present'):
            raise ValueError('coverage did not evaluate advisory inputs')
        if (plan['verdict'] != 'PASS' or plans.validate_plan(plan, plan)
                or plan['task_id'] != record['task_id'] or contract['task_id'] != record['task_id']
                or any(c['blocking'] and c['result'] != 'passed' for c in plan['checks'])):
            raise ValueError('required quality observations did not pass')
        expected = {'registry_sha256': artifacts['registry']['sha256'],
                    'facet_manifest_sha256': artifacts['facet_manifest']['sha256'],
                    'verification_contract_sha256': artifacts['verification_contract']['sha256']}
        if plan['bindings'] != expected:
            raise ValueError('selected plan input binding mismatch')
        replay_plan(record, docs, root, head_sha, owned)
    except (KeyError, TypeError, ValueError, AttributeError, OSError, subprocess.CalledProcessError,
            resolver.CanonicalizerFailed, resolver.CanonicalizerOutputMalformed, resolver.RegistryValidationFailed,
            resolver.DependencySubprocessFailed, resolver.DependencyOutputMalformed,
            resolver.AffectedComponentAbsentFromContext, evidence.ValidatorError,
            facets.CanonicalizerError, coverage_gate.ConfigParseHardError) as exc:
        return ['advisory observation rejected: ' + type(exc).__name__]
    return []



def tooling_digest(scripts):
    tools_root = scripts.parents[2]
    paths = list((tools_root / 'plugins/sdd-quality-loop').rglob('*')) + list((tools_root / 'contracts').rglob('*'))
    inputs = {path.relative_to(tools_root).as_posix(): sha(path.read_bytes()) for path in paths
              if path.is_file() and '__pycache__' not in path.parts
              and path.relative_to(tools_root).as_posix() !=
                  'plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json'}
    inputs['scripts/observe-a9-advisory.py'] = sha(Path(__file__).read_bytes())
    return ownership.canonical_digest(inputs)


def collect(root, base_sha, head_sha, feature, contract_path, output=None):
    # Resolver publishes one output beside its own script. Stage trusted tooling,
    # never execute PR-controlled scripts or modify the trusted tool checkout.
    with tempfile.TemporaryDirectory(prefix='a9-consumers-') as tmp:
        tools_root = Path(tmp)
        for path in ('plugins', 'contracts'):
            shutil.copytree(ROOT / path, tools_root / path,
                            ignore=shutil.ignore_patterns('__pycache__'))
        git(tools_root, 'init', '-q')
        registry = root / POLICY_PATHS['registry']
        if registry.is_file():
            registry_raw = read_input(root.resolve(), POLICY_PATHS['registry'])
            (tools_root / POLICY_PATHS['registry']).write_bytes(registry_raw)
            # Packaged discovery has priority over the repository fallback.
            (tools_root / 'plugins/sdd-quality-loop/contracts/capability-registry.json').write_bytes(registry_raw)
        return collect_with_tools(root, base_sha, head_sha, feature, contract_path,
                                  tools_root / 'plugins/sdd-quality-loop/scripts')


def collect_with_tools(root, base_sha, head_sha, feature, contract_path, scripts):
    root = root.resolve()
    commit(base_sha); commit(head_sha)
    if git(root, 'rev-parse', 'HEAD').decode().strip() != head_sha:
        raise ValueError('checkout is not the requested PR head')
    if git(root, 'status', '--porcelain', '--untracked-files=no'):
        raise ValueError('tracked worktree changes would contaminate the PR observation')
    if not re.fullmatch('[a-z0-9][a-z0-9-]*', feature):
        raise ValueError('invalid feature')
    config = root / POLICY_PATHS['context']
    if not config.exists():
        return {'schema': 'a9-advisory-observation/v1', 'state': 'not_activated',
                'result': 'NOT_RUN', 'head_sha': head_sha, 'base_sha': base_sha,
                'authorization_checked': False}
    policy = {}
    for name, path in POLICY_PATHS.items():
        raw = read_input(root, path)
        if git(root, 'show', head_sha + ':' + path) != raw:
            raise ValueError('live publication must be committed at the observed head')
        policy[name] = artifact(raw)
    provider = root / 'sdd/provider-bindings.yaml'
    provider_raw = read_input(root, 'sdd/provider-bindings.yaml') if provider.exists() else None
    provider_tracked = bool(git(root, 'ls-tree', '--name-only', head_sha, '--', 'sdd/provider-bindings.yaml').strip())
    if provider_tracked != (provider_raw is not None) or (provider_tracked and
            git(root, 'show', head_sha + ':sdd/provider-bindings.yaml') != provider_raw):
        raise ValueError('provider bindings must match the observed committed head')
    context = document(policy['context'])
    state = context['workflow'].get('capability_enforcement')
    if state not in WORKFLOWS or context['workflow'] != WORKFLOWS[state]:
        raise ValueError('live Context is not an exact supported phase')
    contract_path = Path(os.path.abspath(contract_path))
    contract_relative = contract_path.relative_to(root).as_posix()
    contract_raw = read_input(root, contract_relative)
    contract = json.loads(contract_raw)
    task_id = contract['task_id']
    if not isinstance(task_id, str) or not re.fullmatch('T-[0-9]{3,}', task_id):
        raise ValueError('invalid task identity')
    proof_files = {relative_path(c['evidence']): artifact(read_input(root, relative_path(c['evidence'])))
                   for c in contract['checks'] if c.get('evidence')}
    trusted_tooling = tooling_digest(scripts)
    operations = []

    def run(name, filename, args):
        result = subprocess.run([sys.executable, str(scripts / filename), *map(str, args)],
                                cwd=root, capture_output=True)
        operations.append({'name': name, 'exit_code': result.returncode})
        if result.returncode:
            raise ValueError('consumer failed: ' + name)
        return result.stdout

    run('resolver', 'resolve-project-context.py', ['--config', config, '--source-rev', head_sha,
        '--target-rev', base_sha, '--feature', feature])
    manifest = root / 'specs' / feature / 'facet-manifest.yaml'
    observed = manifest.with_name('resolver-evidence.yaml')
    registry = root / POLICY_PATHS['registry']
    run('manifest', 'validate-facet-manifest.py', ['--manifest', manifest])
    run('resolver-evidence', 'validate-resolver-evidence.py', ['--evidence', observed,
        '--registry', registry, '--manifest', manifest])
    # Pin the Git diff explicitly: generated Resolver outputs are not PR changes.
    # Resolver publishes tracked outputs; use the immutable commits for coverage's input list.
    merge_base = git(root, 'merge-base', base_sha, head_sha).decode().strip()
    changed = git(root, 'diff', '--name-only', '-z', merge_base, head_sha).decode().split('\0')
    with tempfile.TemporaryDirectory(prefix='a9-diff-') as tmp:
        paths = Path(tmp) / 'paths.txt'
        if any('\n' in p or '\r' in p for p in changed):
            raise ValueError('coverage path list cannot represent multiline names')
        paths.write_text('\n'.join(p for p in changed if p) + '\n', encoding='utf-8')
        coverage = run('coverage', 'check-component-coverage.py', ['--config', config,
            '--facet-manifest', manifest, '--repo-root', root, '--changed-paths-file', paths])
    plan = root / 'specs' / feature / 'verification' / task_id / 'selected-plan.json'
    plan.parent.mkdir(parents=True, exist_ok=True)
    run('selected-plan', 'evaluate-selected-plan.py', ['--repo-root', root, '--registry', registry,
        '--facet-manifest', manifest, '--contract', contract_path, '--output', plan])
    if (read_input(root, contract_relative) != contract_raw
            or any(read_input(root, path) != artifact_bytes(item) for path, item in proof_files.items())
            or any(read_input(root, path) != artifact_bytes(policy[name]) for name, path in POLICY_PATHS.items())
            or (read_input(root, 'sdd/provider-bindings.yaml') if provider.exists() else None) != provider_raw
            or git(root, 'rev-parse', 'HEAD').decode().strip() != head_sha
            or tooling_digest(scripts) != trusted_tooling):
        raise ValueError('inputs changed during collection')
    artifacts = {**policy, 'resolver_evidence': artifact(observed.read_bytes()),
        'facet_manifest': artifact(manifest.read_bytes()), 'coverage': artifact(coverage),
        'verification_contract': artifact(contract_raw), 'selected_plan': artifact(plan.read_bytes())}
    doc = document(artifacts['resolver_evidence'])
    record = {'schema': 'a9-' + state + '-observation/v1', 'state': state, 'result': 'PASS',
        'authorization_checked': False, 'head_sha': head_sha, 'base_sha': base_sha, 'feature': feature,
        'task_id': task_id, 'context_binding': doc['context_binding'], 'resolver': doc['resolver'],
        'operations': operations, 'artifacts': artifacts, 'verification_evidence': proof_files,
        'trusted_tooling_sha256': trusted_tooling}
    errors = validate_observation(record, head_sha, base_sha, root, expected_state=state)
    if errors:
        raise ValueError('; '.join(errors))
    return record



class MissingInputs(ValueError):
    def __init__(self, names):
        self.names = sorted(set(names))
        super().__init__('required advisory inputs are missing')


def request_inputs(root, request_path, head_sha):
    root = root.resolve()
    request_path = relative_path(request_path)
    missing = [name for name, path in POLICY_PATHS.items() if not (root / path).exists()]
    if not (root / request_path).exists():
        missing.append('advisory_request')
    if missing:
        raise MissingInputs(missing)
    raw = read_input(root, request_path)
    if git(root, 'show', commit(head_sha) + ':' + request_path) != raw:
        raise ValueError('request must match the committed PR head')
    request = document(artifact(raw))
    if (set(request) != {'schema', 'feature', 'verification_contract'}
            or request['schema'] != 'a9-advisory-request/v1'
            or not isinstance(request['feature'], str)
            or not re.fullmatch('[a-z0-9][a-z0-9-]*', request['feature'])):
        raise ValueError('invalid advisory request')
    contract = relative_path(request['verification_contract'])
    if not contract.startswith('specs/' + request['feature'] + '/verification/'):
        raise ValueError('request contract must belong to the declared feature')
    if not (root / contract).exists():
        raise MissingInputs(['verification_contract'])
    contract_raw = read_input(root, contract)
    if git(root, 'show', commit(head_sha) + ':' + contract) != contract_raw:
        raise ValueError('requested contract must match the committed PR head')
    parsed = document(artifact(contract_raw))
    if (not isinstance(parsed, dict) or parsed.get('schema') != 'verification-contract/v2'
            or not isinstance(parsed.get('checks'), list)
            or any(not isinstance(check, dict) for check in parsed['checks'])):
        raise ValueError('invalid requested verification contract')
    missing = ['verification_evidence' for check in parsed.get('checks', [])
               if check.get('evidence') and not (root / relative_path(check['evidence'])).exists()]
    if missing:
        raise MissingInputs(missing)
    return request['feature'], root / contract, {'path': request_path, 'sha256': sha(raw),
                                               'verification_contract': contract}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('repo-root', 'output'):
        parser.add_argument('--' + name, required=True, type=Path)
    for name in ('base-sha', 'head-sha'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--expected-observation-sha256', help='authenticated original check digest for private content recovery')
    parser.add_argument('--feature')
    parser.add_argument('--contract', type=Path)
    parser.add_argument('--request', help='committed repository-relative advisory request')
    args = parser.parse_args()
    try:
        if (args.output.exists() or not args.output.parent.is_dir()
                or args.output.resolve().is_relative_to(args.repo_root.resolve())):
            raise ValueError('output must be a fresh file in an existing private evidence directory')
        request = None
        if args.request:
            if args.feature is not None or args.contract is not None:
                raise ValueError('request and manual inputs are mutually exclusive')
            args.feature, args.contract, request = request_inputs(args.repo_root, args.request, args.head_sha)
        elif args.feature is None or args.contract is None:
            raise MissingInputs(['feature', 'verification_contract'])
        record = collect(args.repo_root, args.base_sha, args.head_sha, args.feature, args.contract, args.output)
        if request is not None:
            record['request'] = request
            if validate_observation(record, args.head_sha, args.base_sha, args.repo_root, expected_state=record["state"]):
                raise ValueError('request binding failed')
        record_digest = ownership.canonical_digest(record)
        if args.expected_observation_sha256 is not None:
            if (not re.fullmatch('sha256:[0-9a-f]{64}', args.expected_observation_sha256)
                    or record['result'] != 'PASS' or record_digest != args.expected_observation_sha256):
                raise ValueError('private reconstruction does not match the original observation digest')
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            json.dump(record, stream, sort_keys=True, indent=2); stream.write('\n')
        summary = {key: record[key] for key in ('state', 'result', 'authorization_checked', 'head_sha', 'base_sha')}
        summary['observation_sha256'] = record_digest
        if args.expected_observation_sha256 is not None:
            summary['expected_digest_matched'] = True
            summary['original_ci_authenticated'] = False
        if record['state'] == 'advisory':
            summary['advisory_observation_sha256'] = summary['observation_sha256']
        print(json.dumps(summary, sort_keys=True))
        return 0 if record['result'] == 'PASS' else 3
    except MissingInputs as exc:
        print(json.dumps({'state': 'blocked', 'result': 'BLOCKED', 'authorization_checked': False,
                          'missing_inputs': exc.names}, sort_keys=True))
        return 1
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.CalledProcessError) as exc:
        print('A9 observation BLOCKED: ' + type(exc).__name__, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
