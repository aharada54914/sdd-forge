#!/usr/bin/env python3
"""Validate reserved domain reviews and publish immutable, approval-pending evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

CHECKS = {
    'a': {
        'CONTEXT-BOUNDARY-CLARITY': 'Major', 'RELATION-PATTERN-VALID': 'Major',
        'EVENT-COVERAGE': 'Major', 'TERM-UNIQUENESS': 'Major',
        'AGGREGATE-CONTEXT-OWNERSHIP': 'Critical', 'CONCEPT-DISTINCTION-JUSTIFIED': 'Major',
        'MULTI-ROLE-CONCEPT': 'Major', 'STAKEHOLDER-PERSPECTIVE-COVERAGE': 'Minor',
        'NAME-SEMANTIC-FIT': 'Minor', 'DOMAIN-MODEL-STATUS-PRESENT': 'Critical',
    },
    'b': {
        'INVARIANT-VERIFIABLE': 'Critical', 'TRANSACTION-BOUNDARY-REALISTIC': 'Major',
        'NO-GOD-AGGREGATE': 'Major', 'NO-ANEMIC-MODEL': 'Major',
        'LIFECYCLE-DEFINED': 'Major', 'AGGREGATE-SIZE-PROPORTIONATE': 'Minor',
    },
}
CANONICAL = [
    'domain/domain-story.md', 'domain/event-storming.md', 'domain/concept-model.md',
    'domain/ubiquitous-language.md', 'domain/context-map.md', 'domain/message-flow.md',
    'domain/domain-contract.json',
]
CALIBRATION = 'plugins/sdd-domain/references/domain-review-calibration.md'
MAX_BYTES = 10 * 1024 * 1024


class Invalid(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Invalid(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON key')
        result[key] = value
    return result


def reject_constant(_):
    raise Invalid('non-finite JSON number')


def is_link(path):
    if not path.exists() and not path.is_symlink():
        return False
    info = path.lstat()
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, 'st_file_attributes', 0) & 0x400)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


class Review:
    def __init__(self, root, attempt, round_number, runtime):
        requested = Path(root).absolute()
        for component in (requested, *requested.parents):
            require(not is_link(component), 'root must not traverse a link or reparse point')
        self.root = requested.resolve(strict=True)
        require(self.root.is_dir(), 'root must be a directory')
        self.attempt, self.round, self.runtime = attempt, round_number, runtime
        self.relative = f'reports/domain-review/attempt-{attempt}/round-{round_number}'
        self.round_dir = self.path(self.relative, directory=True)
        self.observed = {}

    def path(self, relative, directory=False, missing=False):
        require(isinstance(relative, str) and relative and '\\' not in relative,
                'noncanonical evidence path')
        parts = relative.split('/')
        require(all(part not in ('', '.', '..') and ':' not in part and not any(ord(c) < 32 for c in part) for part in parts), 'noncanonical evidence path')
        current = self.root
        for index, part in enumerate(parts):
            current /= part
            require(not is_link(current), 'evidence path traverses a link or reparse point')
            if index < len(parts) - 1:
                require(current.is_dir(), 'evidence parent is missing')
        if missing and not current.exists():
            return current
        require(current.is_dir() if directory else current.is_file(), 'evidence is missing or not regular')
        return current

    def read(self, relative):
        path = self.path(relative)
        require(path.stat().st_size <= MAX_BYTES, 'evidence exceeds size limit')
        content = path.read_bytes()
        require(len(content) <= MAX_BYTES, 'evidence exceeds size limit')
        current = digest(content)
        require(relative not in self.observed or self.observed[relative] == current,
                'evidence changed during finalization')
        self.observed[relative] = current
        return content

    def document(self, relative):
        return json.loads(self.read(relative).decode('utf-8-sig'), object_pairs_hook=unique_object,
                          parse_constant=reject_constant)

    def canonical(self):
        aggregate_dir = self.path('domain/aggregates', directory=True)
        aggregates = sorted(('domain/aggregates/' + p.name for p in aggregate_dir.glob('*.md')),
                            key=lambda value: value.encode('utf-8'))
        require(aggregates, 'at least one aggregate is required')
        return CANONICAL + aggregates

    def precheck(self):
        precheck_path = self.relative + '/precheck-result.json'
        precheck = self.document(precheck_path)
        require(isinstance(precheck, dict) and
                precheck.get('schema') == 'domain-review-precheck/v1' and
                precheck.get('stage') == 'domain' and
                type(precheck.get('attempt')) is int and precheck['attempt'] == self.attempt and
                type(precheck.get('round')) is int and precheck['round'] == self.round and
                precheck.get('domain_model_status_field') == 'Pending', 'precheck identity is invalid')
        paths = self.canonical()
        self.canonical_paths = paths
        hashes = []
        for relative in paths:
            content = self.read(relative)
            if relative == 'domain/context-map.md':
                statuses = re.findall(rb'^Domain-Model-Status:[ \t]*([^\r\n]*)\r?$', content, re.M)
                statuses = [re.sub(r'\s', '', value.decode('utf-8')) for value in statuses]
                require(statuses == ['Pending'], 'domain status must remain Pending')
                content = re.sub(rb'^Domain-Model-Status:[^\r\n]*(\r?)$',
                                 rb'Domain-Model-Status: NORMALIZED\1', content, flags=re.M)
            hashes.append(digest(content))
        require(precheck.get('input_sha256') == digest(':'.join(hashes).encode()),
                'canonical inputs differ from the precheck')
        require(precheck.get('calibration_sha256') == digest(self.read(CALIBRATION)),
                'calibration differs from the precheck')
        return precheck, paths + [CALIBRATION, precheck_path]

    def verify_reservation(self, manifest, manifest_path, ledger):
        role = manifest.get('role')
        fields = ('sequence', 'stage', 'role', 'run_id', 'host_session_id', 'previous_record_sha256')
        records = ledger.get('records') if isinstance(ledger, dict) else None
        require(isinstance(records, list), 'identity ledger is malformed')
        matches = [record for record in records if isinstance(record, dict) and
                   all(record.get(field) == manifest.get(field) for field in fields)]
        require(len(matches) == 1, 'reviewer identity has no exact persisted reservation')
        input_binding = digest('\n'.join(item['path'] + '\t' + item['sha256']
                                        for item in manifest['allowed_input_manifest']).encode('utf-8'))
        require(matches[0].get('allowed_inputs_sha256') == input_binding,
                'persisted reservation does not bind these exact review inputs')
        validator = self.path('plugins/sdd-quality-loop/scripts/validate-review-context-set.' +
                              ('ps1' if self.runtime == 'powershell' else 'sh'))
        if self.runtime == 'powershell':
            host = shutil.which('pwsh') or shutil.which('powershell')
            require(host is not None, 'PowerShell validation runtime is unavailable')
            command = [host, '-NoProfile', '-File', str(validator), '-Manifest', str(manifest_path),
                       '-RepositoryRoot', str(self.root)]
        else:
            host = shutil.which('bash')
            require(host is not None, 'Bash validation runtime is unavailable')
            command = [host, str(validator), str(manifest_path), str(self.root)]
        result = subprocess.run(command, cwd=self.root, capture_output=True, text=True)
        require(result.returncode == 0 and result.stdout.startswith('REVIEW_CONTEXT_OK '),
                'shared reservation or current-input validation failed for ' + str(role))
        require(matches[0].get('record_sha256') == result.stdout.split()[1],
                'reservation receipt does not match the persisted record')

    def reviewer(self, letter, allowed, ledger):
        role = 'domain-reviewer-' + letter
        manifest_relative = self.relative + '/reviewer-' + letter + '-invocation.json'
        manifest = self.document(manifest_relative)
        require(isinstance(manifest, dict) and manifest.get('stage') == 'domain' and
                manifest.get('role') == role and manifest.get('feature') == 'sdd-domain-model',
                'review invocation role or feature is invalid')
        inputs = manifest.get('allowed_input_manifest')
        require(isinstance(inputs, list) and len(inputs) == len(allowed) and
                all(isinstance(item, dict) and set(item) == {'path', 'sha256'} for item in inputs),
                'review invocation input set is malformed')
        require(sorted(item['path'] for item in inputs) == sorted(allowed),
                'review invocation does not cover the exact canonical inputs')
        for item in inputs:
            require(item['sha256'] == digest(self.read(item['path'])), 'review input hash mismatch')
        self.verify_reservation(manifest, self.path(manifest_relative), ledger)
        output_relative = self.relative + '/reviewer-' + letter + '.json'
        output = self.document(output_relative)
        keys = {'schema', 'stage', 'role', 'run_id', 'host_session_id', 'allowed_input_manifest',
                'verdict', 'checks'}
        require(isinstance(output, dict) and set(output) == keys and
                output.get('schema') == role + '/v1', 'review output schema is invalid')
        for key in ('stage', 'role', 'run_id', 'host_session_id', 'allowed_input_manifest'):
            require(output[key] == manifest[key], 'review output does not match its reserved invocation')
        checks = output['checks']
        require(isinstance(checks, list) and all(isinstance(check, dict) for check in checks) and
                [check.get('id') for check in checks] == list(CHECKS[letter]),
                'review output check set or order is invalid')
        for check in checks:
            require(set(check) == {'id', 'result', 'severity', 'finding'} and
                    check['result'] in ('PASS', 'FAIL', 'SKIP') and
                    isinstance(check['finding'], str) and check['finding'].strip(),
                    'review finding is malformed')
            floor = CHECKS[letter][check['id']]
            severity = check['severity']
            require(severity == floor or (floor == 'Major' and severity == 'Critical'),
                    'review finding severity violates its check contract')
            if check['result'] == 'SKIP':
                god = next((row for row in checks if row['id'] == 'NO-GOD-AGGREGATE'), {})
                require(letter == 'b' and check['id'] == 'AGGREGATE-SIZE-PROPORTIONATE' and
                        god.get('result') == 'FAIL', 'review check is not eligible to skip')
        expected, _, _ = aggregate(checks, self.round)
        require(output['verdict'] == expected, 'reviewer verdict contradicts its checks')
        identity = {key: manifest[key] for key in ('role', 'run_id', 'host_session_id', 'sequence')}
        identity.update(invocation_sha256=self.observed[manifest_relative],
                        output_sha256=self.observed[output_relative])
        return output, identity

    def derive(self, summary_only=False):
        precheck, allowed = self.precheck()
        ledger = self.document('reports/review-context/identity-ledger.json')
        a, a_identity = self.reviewer('a', allowed, ledger)
        summary = summarize(a)
        if summary_only:
            return {'integrated-summary.json': encoded(summary)}
        summary_path = self.relative + '/integrated-summary.json'
        require(self.read(summary_path) == encoded(summary),
                'B summary is not exactly derived from reviewer A')
        b, b_identity = self.reviewer('b', allowed + [summary_path], ledger)
        require(a_identity['sequence'] < b_identity['sequence'], 'reviewers were not reserved sequentially')
        require(a_identity['run_id'] != b_identity['run_id'] and
                a_identity['host_session_id'] != b_identity['host_session_id'], 'reviewer identities are reused')
        hosts = [record for record in ledger['records'] if record.get('stage') == 'host' and
                 record.get('role') == 'orchestrator' and record['sequence'] < a_identity['sequence']]
        require(hosts, 'invoking host identity is missing')
        host = hosts[-1]
        verdict, warnings, counts = aggregate(a['checks'] + b['checks'], self.round)
        integrated = dict(schema='domain-review-integrated/v1', stage='domain', attempt=self.attempt,
                          round=self.round, verdict=verdict, warningCount=warnings, findings=counts,
                          reviewer_verdicts={'a': a['verdict'], 'b': b['verdict']})
        contract = dict(schema='domain-review-contract/v1', stage='domain', attempt=self.attempt,
                        round=self.round, run_id=host['run_id'], host_session_id=host['host_session_id'],
                        input_sha256=precheck['input_sha256'],
                        calibration_sha256=precheck['calibration_sha256'],
                        precheck_sha256=self.observed[self.relative + '/precheck-result.json'],
                        verdict=verdict, warningCount=warnings, findings=counts,
                        reviewers=[a_identity, b_identity], cross_model_required=True,
                        human_approval='Pending')
        report = (f'# Domain review: attempt {self.attempt}, round {self.round}\n\n'
                  f'Internal two-reviewer verdict: {verdict}\n\n'
                  f'Critical: {counts["Critical"]}; Major: {counts["Major"]}; Minor: {counts["Minor"]}; '
                  f'warningCount: {warnings}.\n\n'
                  'Cross-model verification is still required. Human approval: Pending.\n'
                  'This evidence does not authorize Approved or change the reviewed input bytes.\n')
        return {'integrated-verdict.json': encoded(integrated), 'report.md': report.encode(),
                'domain-review-contract.json': encoded(contract)}

    def unchanged(self):
        require(self.canonical() == self.canonical_paths, 'canonical input set changed during finalization')
        for relative, expected in self.observed.items():
            require(digest(self.path(relative).read_bytes()) == expected, 'evidence changed during finalization')

    def publish(self, outputs):
        # The contract is inserted last and acts as the complete-output marker.
        for name in outputs:
            target = self.path(self.relative + '/' + name, missing=True)
            require(not target.exists(), 'output already exists; replay is forbidden')
        self.unchanged()
        created = []
        try:
            for name, content in outputs.items():
                staged = None
                try:
                    with tempfile.NamedTemporaryFile(dir=self.round_dir, prefix='.finalize-', delete=False) as stream:
                        staged = Path(stream.name)
                        stream.write(content)
                        stream.flush()
                        os.fsync(stream.fileno())
                    target = self.path(self.relative + '/' + name, missing=True)
                    self.unchanged()
                    os.link(staged, target)
                    created.append(target)
                finally:
                    if staged is not None:
                        staged.unlink(missing_ok=True)
        except BaseException:
            for target in reversed(created):
                target.unlink(missing_ok=True)
            raise


def summarize(output):
    checks = output['checks']
    return {'checks': [{'id': row['id'], 'severity': row['severity'], 'counts': {row['result']: 1}}
                       for row in checks],
            'counts': {result: sum(row['result'] == result for row in checks)
                       for result in ('PASS', 'FAIL', 'SKIP')}}


def aggregate(checks, round_number):
    counts = {severity: sum(row['result'] == 'FAIL' and row['severity'] == severity for row in checks)
              for severity in ('Critical', 'Major', 'Minor')}
    if counts['Critical'] or counts['Major']:
        return ('BLOCKED' if round_number == 3 else 'NEEDS_WORK'), 0, counts
    if counts['Minor']:
        return ('PASS', counts['Minor'], counts) if round_number == 3 else ('NEEDS_WORK', 0, counts)
    return 'PASS', 0, counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--attempt', required=True, type=int)
    parser.add_argument('--round', required=True, type=int)
    parser.add_argument('--mode', choices=('summary', 'finalize', 'verify'), default='finalize')
    parser.add_argument('--runtime', choices=('bash', 'powershell'), default='bash')
    args = parser.parse_args()
    lock = None
    acquired = False
    try:
        require(args.attempt > 0 and 1 <= args.round <= 3, 'attempt or round is invalid')
        review = Review(args.root, args.attempt, args.round, args.runtime)
        lock = review.path('reports/domain-review', directory=True) / '.domain-review.lock'
        lock.mkdir()
        acquired = True
        outputs = review.derive(summary_only=args.mode == 'summary')
        if args.mode == 'verify':
            for name, content in outputs.items():
                require(review.read(review.relative + '/' + name) == content,
                        'persisted output differs from validated reviewer evidence')
            review.unchanged()
        else:
            review.publish(outputs)
        print('DOMAIN_REVIEW_' + ('VERIFIED' if args.mode == 'verify' else 'SUMMARY_READY' if args.mode == 'summary' else 'FINALIZED'))
        return 0
    except (OSError, ValueError, TypeError, KeyError, IndexError, UnicodeError) as error:
        message = str(error) if isinstance(error, Invalid) else 'malformed or unavailable review evidence'
        print('DOMAIN_REVIEW_BLOCKED: ' + message, file=sys.stderr)
        return 1
    finally:
        if acquired:
            lock.rmdir()


if __name__ == '__main__':
    sys.exit(main())
