#!/usr/bin/env python3
"""Validate supplemental delivery inputs without modifying review state."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('safe_inputs', Path(__file__).with_name('review-conditional-inputs.py'))
safe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(safe)


def resolve(root, manifest, verify_manifest_citation=False):
    document = json.loads(Path(manifest).read_bytes(), object_pairs_hook=safe.unique_object)
    if not isinstance(document, dict) or not isinstance(document.get('allowed_input_manifest'), list):
        raise ValueError('delivery invocation requires an input manifest array')
    feature, task = document['feature'], document['task_id']
    if document['stage'] != 'quality' or document['role'] != 'sdd-evaluator':
        raise ValueError('supplemental declaration is evaluator-only')

    def pinned(entry):
        if not isinstance(entry, dict) or set(entry) != {'path', 'sha256'}:
            raise ValueError('invalid delivery pin')
        name, digest = entry['path'], entry['sha256']
        if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*', name):
            raise ValueError('noncanonical delivery path')
        if not isinstance(digest, str) or not re.fullmatch('[0-9a-f]{64}', digest):
            raise ValueError('invalid delivery hash')
        raw = safe.read_safe(root, name)
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('delivery hash mismatch: ' + name)
        return raw

    pointer = document['supplemental_delivery_declaration']
    raw = pinned(pointer)
    prefix = f'specs/{feature}/verification/{task}/'
    if not pointer['path'].startswith(prefix) or not pointer['path'].endswith('.json'):
        raise ValueError('delivery declaration task path mismatch')
    if document['allowed_input_manifest'].count(pointer) != 1:
        raise ValueError('delivery declaration must be pinned once in inputs')
    declaration = json.loads(raw, object_pairs_hook=safe.unique_object)
    v2 = isinstance(declaration, dict) and declaration.get('schema') == 'supplemental-delivery-declaration/v2'
    keys = {'schema', 'feature', 'task_id', 'implementation_report', 'artifacts'}
    if v2:
        keys.add('implementation_manifest')
    if not isinstance(declaration, dict) or set(declaration) != keys:
        raise ValueError('invalid delivery declaration keys')
    if declaration['schema'] not in ('supplemental-delivery-declaration/v1', 'supplemental-delivery-declaration/v2') or declaration['feature'] != feature or declaration['task_id'] != task:
        raise ValueError('delivery declaration identity mismatch')
    report = declaration['implementation_report']
    report_raw = pinned(report)
    if report['path'] != f'reports/implementation/{feature}/{task}.md' or document['allowed_input_manifest'].count(report) != 1:
        raise ValueError('delivery implementation report binding mismatch')
    if verify_manifest_citation and not v2:
        raise ValueError('legacy manifest citation requires declaration v2')
    if v2:
        binding = declaration['implementation_manifest']
        pinned(binding)
        if binding != document.get('implementation_manifest') or document['allowed_input_manifest'].count(binding) != 1:
            raise ValueError('delivery implementation manifest binding mismatch')
        lines = report_raw.decode('utf-8').splitlines()
        if any(line.startswith('Input manifest:') for line in lines) or [line for line in lines if line.startswith('Manifest SHA-256:')] != ['Manifest SHA-256: ' + binding['sha256']]:
            raise ValueError('legacy manifest digest must occur exactly once without a modern citation')
    artifacts = declaration['artifacts']
    if not isinstance(artifacts, list) or not artifacts:
        raise ValueError('delivery artifacts must be nonempty')
    seen = {pointer['path'], report['path']}
    if v2:
        seen.add(binding['path'])
    for entry in artifacts:
        pinned(entry)
        name = entry['path']
        if name in seen:
            raise ValueError('duplicate delivery path')
        seen.add(name)
        if name.startswith('reports/') or (name.startswith('specs/') and not name.startswith(f'specs/{feature}/')):
            raise ValueError('review evidence or cross-feature delivery input forbidden')
    return [pointer] + artifacts


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--verify-manifest-citation', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(resolve(Path(args.root).resolve(strict=True), args.manifest, args.verify_manifest_citation)))
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print('supplemental-delivery: ' + str(exc), file=sys.stderr)
        sys.exit(1)
