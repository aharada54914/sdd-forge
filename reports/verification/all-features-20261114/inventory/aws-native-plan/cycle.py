#!/usr/bin/env python3
"""Run only on the authenticated CloudShell; no billable workload resource types."""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

p = argparse.ArgumentParser()
p.add_argument('--expected-account', default=os.environ.get('SDD_EXPECTED_AWS_ACCOUNT'))
p.add_argument('--region', default='ap-northeast-1', choices=['ap-northeast-1'])
a = p.parse_args()
if not a.expected_account or not a.expected_account.isdigit() or len(a.expected_account) != 12:
    p.error('provide the selected 12-digit account through SDD_EXPECTED_AWS_ACCOUNT or --expected-account')
run = uuid.uuid4().hex
name = 'sdd-forge-verify-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S') + '-' + run[:12]
folder = Path('/tmp') / name
folder.mkdir(mode=0o700)
state = {'name': name, 'region': a.region, 'run': run, 'checks': [], 'cleanup': False, 'scope': 'provider-native CloudFormation only; not governed plugin acceptance'}
stack_id = None
create_attempted = False
base = {'AWSTemplateFormatVersion': '2010-09-09', 'Description': 'Disposable provider-native rollback verification; no workload resources', 'Resources': {'BaselineHandle': {'Type': 'AWS::CloudFormation::WaitConditionHandle'}}}
failure = copy.deepcopy(base)
failure['Resources'].update({'NewFailureHandle': {'Type': 'AWS::CloudFormation::WaitConditionHandle'}, 'ExpectedTimeout': {'Type': 'AWS::CloudFormation::WaitCondition', 'Properties': {'Handle': {'Ref': 'NewFailureHandle'}, 'Timeout': '1', 'Count': 1}}})
for label, template in [('base', base), ('failure', failure)]:
    encoded = json.dumps(template, sort_keys=True, separators=(',', ':')).encode()
    (folder / (label + '.json')).write_bytes(encoded)
    state.setdefault('template_sha256', {})[label] = hashlib.sha256(encoded).hexdigest()

def call(service, operation, *args):
    cmd = ['aws', '--region', a.region, '--no-cli-pager', '--output', 'json', '--cli-connect-timeout', '10', '--cli-read-timeout', '30', service, operation, *args]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=45, env={**os.environ, 'AWS_MAX_ATTEMPTS': '2'})
    if result.returncode:
        # Do not print provider responses that could contain a presigned handle.
        (folder / 'last-error.txt').write_text(result.stderr)
        raise RuntimeError(operation + ' failed; private diagnostic retained at ' + str(folder / 'last-error.txt'))
    return json.loads(result.stdout or '{}')

def describe():
    return call('cloudformation', 'describe-stacks', '--stack-name', stack_id or name)['Stacks'][0]

def owned():
    d = describe()
    tags = {v['Key']: v['Value'] for v in d.get('Tags', [])}
    if d['StackName'] != name or tags.get('sdd-verification-run') != run or (stack_id and d['StackId'] != stack_id):
        raise RuntimeError('refuse mutation: stack ownership does not match this run')
    return d

def wait(expected, seconds=360, prior=None, prior_grace=30):
    started = time.monotonic()
    deadline = started + seconds
    last = None
    progress_seen = False
    while time.monotonic() < deadline:
        status = describe()['StackStatus']
        if status != last:
            print('STATUS ' + status, flush=True)
            last = status
        if status == expected:
            return
        if status.endswith('_IN_PROGRESS'):
            progress_seen = True
        elif not (status == prior and not progress_seen and time.monotonic() - started < prior_grace):
            raise RuntimeError('unexpected terminal stack status: ' + status)
        time.sleep(min(3, max(0, deadline - time.monotonic())))
    raise RuntimeError('bounded wait expired; retain name/ARN for read-only reconciliation')

try:
    identity = call('sts', 'get-caller-identity')
    if identity['Account'] != a.expected_account:
        raise RuntimeError('AWS account differs from explicitly selected account')
    state['identity_account_matched'] = True
    identity_resource = identity.get('Arn', '').split(':', 5)[-1]
    state['identity_kind'] = identity_resource.split('/', 1)[0] if identity_resource else 'unknown'
    version = subprocess.run(['aws', '--version'], capture_output=True, text=True, timeout=10, check=True)
    state['aws_cli_version'] = (version.stdout or version.stderr).strip()
    state['script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    # Hooks may add billable handler operations; do not execute an unknown hook.
    hooks = call('cloudformation', 'list-types', '--type', 'HOOK', '--visibility', 'PRIVATE')
    if hooks.get('TypeSummaries'):
        raise RuntimeError('registered CloudFormation hooks exist; stop before resource mutation')
    state['checks'].append('no registered private CloudFormation hooks')
    for label in ('base', 'failure'):
        call('cloudformation', 'validate-template', '--template-body', 'file://' + str(folder / (label + '.json')))
    create_attempted = True
    response = call('cloudformation', 'create-stack', '--stack-name', name, '--template-body', 'file://' + str(folder / 'base.json'), '--on-failure', 'DELETE', '--tags', 'Key=sdd-verification-run,Value=' + run, '--client-request-token', run + '-create')
    stack_id = response['StackId']
    # ARN is private operational state; no physical handle URL is collected.
    (folder / 'private-stack-id.txt').write_text(stack_id)
    wait('CREATE_COMPLETE')
    state['checks'].append('actual CREATE_COMPLETE')
    owned()
    call('cloudformation', 'update-stack', '--stack-name', stack_id, '--template-body', 'file://' + str(folder / 'failure.json'), '--client-request-token', run + '-expected-failure')
    wait('UPDATE_ROLLBACK_COMPLETE', prior='CREATE_COMPLETE')
    state['checks'].append('actual UPDATE_ROLLBACK_COMPLETE')
    template = call('cloudformation', 'get-template', '--stack-name', stack_id)['TemplateBody']
    if isinstance(template, str):
        template = json.loads(template)
    if template != base:
        raise RuntimeError('rollback did not restore exact initial template')
    state['checks'].append('initial template restored exactly')
    events = call('cloudformation', 'describe-stack-events', '--stack-name', stack_id)['StackEvents']
    state['events'] = [{k: e.get(k) for k in ('LogicalResourceId', 'ResourceType', 'ResourceStatus', 'Timestamp')} for e in events]
    if not any(e.get('LogicalResourceId') == 'ExpectedTimeout' and e.get('ResourceStatus') == 'CREATE_FAILED'
               and any(word in e.get('ResourceStatusReason', '').lower() for word in ('timed out', 'timeout')) for e in events):
        raise RuntimeError('expected injected wait failure missing from provider events')
    state['checks'].append('provider event confirms injected wait failure')
    resources = call('cloudformation', 'list-stack-resources', '--stack-name', stack_id)['StackResourceSummaries']
    live = {r['LogicalResourceId'] for r in resources if r['ResourceStatus'] != 'DELETE_COMPLETE'}
    if live != {'BaselineHandle'}:
        raise RuntimeError('unexpected resource remains after rollback')
    state['checks'].append('only baseline resource remains after rollback')
except Exception as exc:
    state['error'] = str(exc)
finally:
    try:
        if create_attempted and not stack_id:
            # Reconcile an uncertain create response only by exact random name + tag.
            d = owned()
            stack_id = d['StackId']
            (folder / 'private-stack-id.txt').write_text(stack_id)
        if stack_id:
            d = owned()
            if d['StackStatus'].endswith('_IN_PROGRESS'):
                raise RuntimeError('stack still in progress; do not cancel or alter unrelated resources')
            call('cloudformation', 'delete-stack', '--stack-name', stack_id, '--client-request-token', run + '-cleanup')
            wait('DELETE_COMPLETE', prior=d['StackStatus'])
            remaining = call('cloudformation', 'list-stack-resources', '--stack-name', stack_id)['StackResourceSummaries']
            if any(r['ResourceStatus'] != 'DELETE_COMPLETE' for r in remaining):
                raise RuntimeError('owned stack deleted but resource deletion not fully confirmed')
            state['cleanup'] = True
            state['checks'].append('DELETE_COMPLETE and every owned resource DELETE_COMPLETE')
    except Exception as exc:
        state['cleanup_error'] = str(exc)
    state['result'] = 'PASS' if not state.get('error') and state['cleanup'] else 'FAIL'
    (folder / 'result.json').write_text(json.dumps(state, indent=2) + '\n')
    print(json.dumps(state), flush=True)
    print('PRIVATE_EVIDENCE_DIRECTORY ' + str(folder), flush=True)
raise SystemExit(0 if state['result'] == 'PASS' else 1)
