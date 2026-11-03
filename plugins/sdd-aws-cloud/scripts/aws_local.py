"""Credential-free local CDK preparation. This process is NOT an isolation sandbox.

Only trusted applications may run directly. Untrusted code requires an externally
isolated, ephemeral planning job without OIDC, secrets or credential mounts.
"""
from __future__ import annotations

import copy
import os
from pathlib import Path
import re
import subprocess
import tempfile

from cloud import c, decode, digest, encode, publish_bytes, safe_publication, read_bytes

PLUGIN = Path(__file__).resolve().parents[1]
VERSION = '2.1145.0'
PARAMS = ('account', 'region', 'stackName', 'vpcId', 'subnetId', 'instanceProfile',
          'imageId', 'instanceType', 'backupPlanId', 'backupRoleArn')
TYPES = ('AWS::EC2::Instance', 'AWS::EC2::SecurityGroup', 'AWS::CloudWatch::Alarm',
         'AWS::Backup::BackupSelection')


def observation_configuration(value: dict) -> None:
    from aws_observation import configuration as validate_observation
    validate_observation(value)


def configuration(cfg: dict, *, discovery: bool = False) -> None:
    fields = {'schema': lambda v: c._enum(v, ('aws-local-config/v1',)),
              'import_resources': lambda v: c._require(v is False)}
    if not (discovery and set(cfg) == set(fields)):
        fields.update(entrypoint=c._path, parameters=c._path, upstream_root=c._path,
                      output_directory=c._path, private_management=lambda v: c._require(v is True),
                      cost=lambda v: c._record(v, {'estimated_minor_units': lambda n: c._integer(n, 1),
                          'currency': lambda x: c._match(x, r'[A-Z]{3}'), 'duration_hours': lambda n: c._integer(n, 1)}),
                      evidence=lambda v: c._record(v, {'residency': c._id, 'retention_days': lambda n: c._integer(n, 1),
                          'access': lambda x: c._enum(x, ('restricted',))}))
    c._record(cfg, fields, {"observation": observation_configuration})


def local_policy(root: Path, request: dict) -> tuple[dict, dict, dict, dict]:
    try:
        ctx = request['local_context']
        cfg = decode(c.read_verified(root, ctx['provider_config']))
        configuration(cfg)
        c._require(request['operation'] == 'apply')
        c._require(c._within(cfg['output_directory'], ctx['artifact_root']))
        c._require(not any(c._within(cfg['output_directory'], u) or c._within(u, cfg['output_directory'])
                           for u in ctx['unit_roots']))
        refs = {a['path']: a for a in request['input_artifacts']}
        c._require(refs[cfg['entrypoint']]['kind'] == 'source' and cfg['entrypoint'].endswith('.js'))
        c._require(refs[cfg['parameters']]['kind'] == 'parameters')
        p = decode(c.read_verified(root, c._file_ref(refs[cfg['parameters']])))
        c._record(p, {name: c._text for name in PARAMS})
        c._require(p['account'] == request['scope']['account_id'] and p['region'] == request['scope']['region']
                   and p['stackName'] == request['scope']['deployment_scope'])
        patterns = dict(account=r'[0-9]{12}', region=r'[a-z]{2}-[a-z]+-[1-9]', stackName=r'[A-Za-z][A-Za-z0-9-]{0,127}',
                        vpcId=r'vpc-[a-f0-9]{8,17}', subnetId=r'subnet-[a-f0-9]{8,17}',
                        instanceProfile=r'[A-Za-z0-9_-]{1,128}', imageId=r'ami-[a-f0-9]{17}',
                        instanceType=r'[a-z][a-z0-9]*\.[a-z0-9]+', backupPlanId=r'[A-Za-z0-9-]{1,128}',
                        backupRoleArn='arn:aws:iam::' + p['account'] + r':role/[A-Za-z0-9_/-]+')
        for k, pattern in patterns.items():
            c._match(p[k], pattern)
        policy = c.read_artifact(root, request['policy'], 'cloud-deployment-policy/v1')
        owner = c.read_artifact(root, ctx['ownership'], 'cloud-ownership/v1')
        c._require(set(TYPES) <= set(policy['allowed_resource_types']))
        c._require(cfg['cost']['currency'] == policy['budget']['currency'] and
                   cfg['cost']['estimated_minor_units'] <= policy['budget']['ceiling_minor_units'])
        c._require(cfg['evidence'] == policy['evidence'])
        required = [(p['vpcId'], TYPES[1]), (p['subnetId'], TYPES[0]), (p['instanceProfile'], TYPES[0]),
                    (p['backupPlanId'], TYPES[3]), (p['backupRoleArn'], TYPES[3])]
        c._require({r['resource_id'] for r in owner['existing_resources']} == {rid for rid, _ in required})
        for rid, typ in required:
            resource = next(r for r in owner['existing_resources'] if r['resource_id'] == rid)
            c._require(len(resource['attachments']) == 1 and resource['attachments'][0]['resource_type'] == typ)
        return cfg, p, policy, owner
    except (c.ContractError, KeyError, TypeError, ValueError, StopIteration):
        raise c.ContractError('LOCAL_POLICY_DENIED') from None


def credential_preflight() -> None:
    """Detect common ambient sources; NOT a proof arbitrary code cannot find secrets."""
    blocked = ('AWS_', 'AZURE_', 'ARM_', 'GOOGLE_', 'CLOUDSDK_', 'ACTIONS_ID_TOKEN_',
               'ACTIONS_RUNTIME_TOKEN', 'GITHUB_TOKEN', 'GH_TOKEN')
    c._require(not any(value and key.startswith(blocked) for key, value in os.environ.items()), 'AMBIENT_CREDENTIALS')
    homes = {Path.home()}
    # HOME overrides do not hide the real account's credential directories.
    import pwd
    homes.add(Path(pwd.getpwuid(os.getuid()).pw_dir))
    for home in homes:
        for name in ('.aws', '.azure', '.config/gcloud', '.boto'):
            c._require(not (home / name).exists() and not (home / name).is_symlink(), 'AMBIENT_CREDENTIALS')
    for path in ('/var/run/secrets',):
        c._require(not Path(path).exists(), 'AMBIENT_CREDENTIALS')


def source_snapshot(root: Path, request: dict, files: list[str], cfg: dict) -> dict[str, bytes]:
    refs = [a for a in request['input_artifacts'] if a['kind'] not in ('compiled', 'asset')]
    c._require(set(files) == {a['path'] for a in refs}, 'UNLOCKED_SOURCE')
    snapshot = {a['path']: c.read_verified(root, c._file_ref(a)) for a in refs}
    base = str(Path(cfg['entrypoint']).parent)
    c._require(cfg['parameters'] == base + '/parameters.json', 'UNSUPPORTED_CDK_CONFIG')
    c._require(decode(snapshot[base + '/cdk.json']) == {'app': 'node ' + Path(cfg['entrypoint']).name}, 'UNSUPPORTED_CDK_CONFIG')
    c._require(snapshot[base + '/package-lock.json'] == (PLUGIN / 'examples/private-ec2/package-lock.json').read_bytes(), 'PACKAGE_LOCK_DRIFT')
    c._require(snapshot[base + '/package.json'] == (PLUGIN / 'examples/private-ec2/package.json').read_bytes(), 'PACKAGE_LOCK_DRIFT')
    # No npm lifecycle, context lookups, executable assets or alternate app launchers.
    for path in snapshot:
        c._require(Path(path).suffix in ('.json', '.js', '.txt') and 'node_modules' not in Path(path).parts,
                   'UNSUPPORTED_SOURCE')
    return snapshot


def toolchain() -> tuple[Path, Path, dict]:
    pin = decode((PLUGIN / 'references/toolchain-lock.json').read_bytes())
    root = Path(os.environ.get('CLOUD_CDK_ROOT', ''))
    c._require(root.is_absolute() and root.resolve() == root and root.is_dir(), 'CDK_UNAVAILABLE')
    c._require(digest((root / 'package-lock.json').read_bytes()) == pin['lock_sha256'] and
               digest((root / 'package.json').read_bytes()) == pin['package_sha256'], 'CDK_LOCK_DRIFT')
    rows = []
    for f in sorted((root / 'node_modules').rglob('*')):
        if f.is_symlink():
            c._require('.bin' in f.parts and f.resolve().is_relative_to(root / 'node_modules'), 'CDK_RUNTIME_DRIFT')
            continue
        if f.is_file():
            rows.append((str(f.relative_to(root)), digest(f.read_bytes())))
    tree = digest(''.join(n + '\0' + h + '\n' for n, h in rows).encode())
    c._require(tree == pin['installed_tree_sha256'] and len(rows) == pin['installed_file_count'], 'CDK_RUNTIME_DRIFT')
    for package in pin['packages']:
        data = (root / package['path'] / 'package.json').read_bytes()
        c._require(digest(data) == package['package_sha256'] and decode(data)['version'] == package['version'], 'CDK_RUNTIME_DRIFT')
    node = Path(os.environ.get('CLOUD_NODE_BIN', ''))
    c._require(node.is_absolute() and node.resolve() == node and node.is_file(), 'NODE_UNAVAILABLE')
    c._require(node.resolve() == node and digest(node.read_bytes()) == pin['tools'][-1]['sha256'], 'NODE_RUNTIME_DRIFT')
    env = {'PATH': os.defpath}
    actual_node = subprocess.run([str(node), '--version'], env=env, capture_output=True, timeout=15)
    c._require(actual_node.returncode == 0 and actual_node.stdout.decode().strip() == 'v' + pin['tools'][-1]['version'], 'NODE_VERSION_DRIFT')
    version = subprocess.run([str(node), str(root / 'node_modules/aws-cdk/bin/cdk'), '--version'],
                             env=env, capture_output=True, timeout=15)
    c._require(version.returncode == 0 and version.stdout.decode().strip() == pin['cli_version_output'], 'CDK_VERSION_DRIFT')
    return root, node, pin


def upstream(root: Path, request: dict, cfg: dict) -> dict:
    pin = decode((PLUGIN / 'references/upstream-lock.json').read_bytes())
    tools = decode((PLUGIN / 'references/toolchain-lock.json').read_bytes())
    lock = c.read_artifact(root, request['dependency_lock'], 'cloud-dependency-lock/v1')
    base = cfg['upstream_root']
    expected = dict(repository=pin['repository'], commit=pin['commit'], root=base,
                    files=[dict(path=base + '/' + f['path'], sha256=f['sha256'],
                                references=[base + '/' + p for p in f['references']]) for f in pin['files']])
    c._require(lock['upstream'] == [expected], 'UPSTREAM_PIN_MISMATCH')
    c.verify_lock(root, lock, consumed_paths=[f['path'] for f in expected['files']],
                  tools=tools['tools'], adapter_version='1.0.0', tool_schemas={})
    return tools


def assembly_policy(blobs: dict[str, bytes], parameters: dict, policy: dict, owner: dict) -> dict:
    """Accept one stack and staged plain file assets; no executable/remote assets."""
    c._require(all(name.endswith('.json') or name == 'cdk.out' for name in blobs), 'ASSET_TYPE_UNSUPPORTED')
    for data in blobs.values():
        decode(data)
    manifest = decode(blobs['manifest.json'])
    c._require(manifest.get('version') == '54.0.0', 'ASSEMBLY_SCHEMA_DRIFT')
    c._require(not manifest.get('missing'), 'LIVE_LOOKUP_UNSUPPORTED')
    artifacts = manifest.get('artifacts', {})
    c._require(type(artifacts) is dict, 'ASSEMBLY_INVALID')
    stacks = [a for a in artifacts.values() if a.get('type') == 'aws:cloudformation:stack']
    c._require(len(stacks) == 1, 'ASSEMBLY_STACK_MISMATCH')
    stack = stacks[0]
    c._require(stack['environment'] == 'aws://' + parameters['account'] + '/' + parameters['region'] and
               stack['properties']['stackName'] == parameters['stackName'], 'ASSEMBLY_SCOPE_MISMATCH')
    template = stack['properties']['templateFile']
    c._path(template)
    from aws_graph import validate_graph
    validate_graph(decode(blobs[template]), parameters, policy, owner)
    assets = []
    for artifact in artifacts.values():
        typ = artifact['type']
        c._require(typ in ('aws:cloudformation:stack', 'cdk:asset-manifest', 'cdk:tree', 'cdk:feature-flag-report'), 'ASSEMBLY_ARTIFACT_UNSUPPORTED')
        if typ == 'cdk:asset-manifest':
            path = artifact['properties']['file']
            c._path(path)
            doc = decode(blobs[path])
            c._require(doc.get('version') == '54.0.0', 'ASSET_SCHEMA_DRIFT')
            c._require(not doc.get('dockerImages') and set(doc) <= {'version', 'files', 'dockerImages'}, 'ASSET_TYPE_UNSUPPORTED')
            for asset in doc.get('files', {}).values():
                source = asset['source']
                c._require(set(source) == {'path', 'packaging'} and source['packaging'] == 'file', 'ASSET_TYPE_UNSUPPORTED')
                name = source['path']
                c._path(name)
                c._require(name == template, 'ASSET_TYPE_UNSUPPORTED')
                c._require(name in blobs, 'ASSET_FILE_MISSING')
                for destination in asset['destinations'].values():
                    c._require(destination.get('region') == parameters['region'] and
                               destination.get('bucketName') == 'cdk-hnb659fds-assets-' + parameters['account'] + '-' + parameters['region'],
                               'ASSET_SCOPE_MISMATCH')
                assets.append(name)
    return dict(template=template, assets=sorted(set(assets)), schema_version=manifest['version'])


def synthesize(snapshot: dict[str, bytes], cfg: dict, toolroot: Path, node: Path) -> tuple[dict[str, bytes], dict]:
    with tempfile.TemporaryDirectory(prefix='aws-local-cdk-') as tmp:
        scratch = Path(tmp).resolve()
        for path, data in snapshot.items():
            dest = scratch / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        base = scratch / Path(cfg['entrypoint']).parent
        # The shell command contains only trusted/pathed tokens, never cdk.json app text.
        env = dict(PATH=str(node.parent) + ':' + os.defpath, HOME=str(scratch),
                   NODE_PATH=str(toolroot / 'node_modules'), AWS_EC2_METADATA_DISABLED='true',
                   CDK_DISABLE_VERSION_CHECK='1', CDK_DISABLE_CLI_TELEMETRY='1')
        app = str(node) + ' ' + str(scratch / cfg['entrypoint'])
        c._require(re.fullmatch(r'[A-Za-z0-9_./ :\-]+', app) is not None, 'UNSAFE_APP_PATH')
        proc = subprocess.run([str(node), str(toolroot / 'node_modules/aws-cdk/bin/cdk'), 'synth',
                               '--app', app, '--output', str(scratch / 'assembly'), '--no-lookups',
                               '--strict', '--path-metadata', 'false', '--version-reporting', 'false', '--notices', 'false'],
                              cwd=base, env=env, capture_output=True, timeout=90)
        c._require(proc.returncode == 0, 'CDK_SYNTH_FAILED')
        files = c._scan_unit(scratch, 'assembly')
        blobs = {p[len('assembly/'):]: read_bytes(scratch, p) for p in files}
        c._require(all(safe_publication(data) for data in blobs.values()), 'SECRET_SCAN_FAILED')
    return blobs, dict(name='aws-cdk', version=VERSION, exit_code=proc.returncode,
                       stdout_sha256=digest(proc.stdout), diagnostics_sha256=digest(proc.stderr))


def publish_assembly(root: Path, directory: str, blobs: dict[str, bytes]) -> list[dict]:
    # New directory exclusively reserved with dir-fd; a failed partial plan is never reused.
    with c._parent(root, directory) as (fd, name):
        os.mkdir(name, mode=0o700, dir_fd=fd)
    refs = []
    for name, data in sorted(blobs.items()):
        path = directory + '/' + name
        c._path(path)
        parts = path.split('/')
        for i in range(len(directory.split('/')) + 1, len(parts)):
            with c._parent(root, '/'.join(parts[:i])) as (fd, component):
                try:
                    os.mkdir(component, mode=0o700, dir_fd=fd)
                except FileExistsError:
                    pass
        # All currently supported assembly files and template assets are JSON.
        # Other file assets are explicit unsupported, not silently dropped.
        c._require(name.endswith('.json') or name == 'cdk.out', 'ASSET_TYPE_UNSUPPORTED')
        refs.append(dict(kind='compiled', **publish_bytes(root, path, data)))
    return refs


def prepare_local(root: Path, request: dict, files: list[str], phase: str, request_ref: dict) -> dict:
    cfg, parameters, policy, owner = local_policy(root, request)
    snapshot = source_snapshot(root, request, files, cfg)
    pin = upstream(root, request, cfg)
    compiled = [a for a in request['input_artifacts'] if a['kind'] in ('compiled', 'asset')]
    if phase == 'plan':
        c._require(not compiled, 'PLAN_ALREADY_LOCKED')
        credential_preflight()
        toolroot, node, actual = toolchain()
        blobs, compiler = synthesize(snapshot, cfg, toolroot, node)
        details = assembly_policy(blobs, parameters, policy, owner)
        # Require installed runtime and original inputs unchanged after executing the app.
        c._require(toolchain()[2] == actual, 'CDK_RUNTIME_DRIFT')
        c._require(c.verify_local_context(root, request) == files and source_snapshot(root, request, files, cfg) == snapshot, 'INPUT_DRIFT')
        directory = cfg['output_directory'] + '/' + request_ref['sha256']
        with c._parent(root, directory) as (fd, name):
            c._require(not os.path.lexists(root / directory), 'PLAN_EXISTS')
        compiled = publish_assembly(root, directory, blobs)
        locked = copy.deepcopy(request)
        locked['input_artifacts'] += compiled
        locked_ref = c.publish_artifact(root, directory + '.request.json', encode(locked), scan=safe_publication)
    else:
        c._require(bool(compiled), 'COMPILED_ARTIFACT_REQUIRED')
        directories = {str(Path(a['path']).parent) for a in compiled}
        c._require(len(directories) == 1, 'ASSEMBLY_PATH_MISMATCH')
        directory = directories.pop()
        c._require(str(Path(directory).parent) == cfg['output_directory'], 'ASSEMBLY_PATH_MISMATCH')
        c._require(set(c._scan_unit(root, directory)) == {a['path'] for a in compiled}, 'ASSEMBLY_FILE_MISMATCH')
        blobs = {Path(a['path']).name: c.read_verified(root, c._file_ref(a)) for a in compiled}
        details = assembly_policy(blobs, parameters, policy, owner)
        locked_ref = request_ref
        compiler = None  # No synthesis occurred during validate. Never invent an exit code.
    return dict(locked_request=locked_ref, assembly=[c._file_ref(a) for a in compiled],
                assembly_details=details, compiler=compiler, toolchain=pin,
                local_policy='PASS', source_closure=[dict(path=p, sha256=digest(b)) for p, b in sorted(snapshot.items())])
