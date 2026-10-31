"""Collect and verify public Git bytes without carrying peer review blobs."""
# shortcut: SHA-1 Git trees only, extend before SHA-256 repositories or submodule/type changes.
import base64
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def peer(path):
    return bool(re.search(r'^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$|(^|/)reviewer-[ab]\.json$', path))


def git(public, *args):
    return subprocess.check_output(['rtk', 'proxy', 'git', *args], cwd=public)


def encode(raw):
    return base64.b64encode(raw).decode('ascii')


def decode(value):
    return base64.b64decode(value, validate=True)


def oid(kind, raw):
    return hashlib.sha1(f'{kind} {len(raw)}\0'.encode() + raw).hexdigest()


def tree_entries(raw):
    result = {}
    while raw:
        header, raw = raw.split(b'\0', 1)
        mode, name = header.decode('utf-8').split(' ', 1)
        require(name not in ('', '.', '..') and '/' not in name and name not in result, 'tree name')
        require(mode in ('40000', '100644', '100755', '120000') and len(raw) >= 20, 'tree entry')
        result[name] = (mode, raw[:20].hex())
        raw = raw[20:]
    return result


def changes(base_tree, head_tree, read_tree, prefix=''):
    if base_tree == head_tree:
        return {}
    before = tree_entries(read_tree(base_tree)) if base_tree else {}
    after = tree_entries(read_tree(head_tree)) if head_tree else {}
    result = {}
    for name in sorted(before.keys() | after.keys()):
        old, new = before.get(name), after.get(name)
        if old == new:
            continue
        path = prefix + name
        old_dir, new_dir = old and old[0] == '40000', new and new[0] == '40000'
        if old_dir or new_dir:
            require(not (old and not old_dir) and not (new and not new_dir), 'directory type change')
            result.update(changes(old[1] if old else None, new[1] if new else None, read_tree, path + '/'))
        else:
            result[path] = (old, new)
    return result


def commit_tree(raw):
    first = raw.split(b'\n', 1)[0].decode('ascii')
    require(re.fullmatch(r'tree [0-9a-f]{40}', first), 'commit tree')
    return first[5:]


def collect(public, projection):
    commits, trees = {}, {}
    for commit in (projection['base'], projection['head']):
        commits[commit] = encode(git(public, 'cat-file', 'commit', commit))

    def read_tree(key):
        if key not in trees:
            trees[key] = encode(git(public, 'cat-file', 'tree', key))
        return decode(trees[key])

    changed = changes(*(commit_tree(decode(commits[projection[k]])) for k in ('base', 'head')), read_tree)
    before = {path: encode(git(public, 'cat-file', 'blob', old[1]))
              for path, (old, _) in changed.items() if old and not peer(path)}
    return {'base': projection['base'], 'head': projection['head'],
            'commits': commits, 'trees': trees, 'before_blobs': before}


def verify(root, projection, proof, expected_base, expected_head):
    require(proof['base'] == projection['base'] == expected_base, 'base binding')
    require(proof['head'] == projection['head'] == expected_head, 'head binding')
    require(set(proof['commits']) == {expected_base, expected_head}, 'commit set')
    for kind, objects in (('commit', proof['commits']), ('tree', proof['trees'])):
        for key, value in objects.items():
            require(oid(kind, decode(value)) == key, kind + ' object hash')
    used = set()

    def read_tree(key):
        used.add(key)
        return decode(proof['trees'][key])

    changed = changes(*(commit_tree(decode(proof['commits'][key]))
                        for key in (expected_base, expected_head)), read_tree)
    require(used == set(proof['trees']), 'tree set')
    entries = {item['source_path']: item for item in projection['artifacts']}
    require(len(entries) == len(projection['artifacts']), 'duplicate projection path')
    require(set(entries) == {p for p, (_, new) in changed.items() if new}, 'changed path set')
    require(sorted(projection['deleted_paths']) == sorted(p for p, (_, new) in changed.items() if not new), 'deleted path set')
    require(set(proof['before_blobs']) == {p for p, (old, _) in changed.items() if old and not peer(p)}, 'before path set')
    for path, (old, new) in changed.items():
        if peer(path):
            if new:
                require('admitted_path' not in entries[path] and entries[path].get('omitted_reason'), 'peer exclusion')
                require('sha256' not in entries[path] and entries[path].get('git_blob_oid') == new[1], 'peer blob identity')
            continue
        if old:
            require(oid('blob', decode(proof['before_blobs'][path])) == old[1], 'before blob hash: ' + path)
        if new:
            item = entries[path]
            relative = Path(item['admitted_path'])
            require(not relative.is_absolute() and '..' not in relative.parts, 'admitted path')
            target = Path(root) / relative
            require(target.is_file() and not target.is_symlink(), 'admitted file')
            require(target.resolve().is_relative_to(Path(root).resolve()), 'admitted root')
            raw = target.read_bytes()
            require(oid('blob', raw) == new[1], 'after blob hash: ' + path)
            require(hashlib.sha256(raw).hexdigest() == item['sha256'], 'after sha256: ' + path)
    return {'changed_paths': len(changed), 'tree_objects': len(used),
            'before_blobs': len(proof['before_blobs']), 'peer_blobs_excluded': sum(map(peer, changed))}


def self_test(public):
    base = '0b2951b6855bbd136938fafa901ee8af8bbe4855'
    for head in ('e97de1c849e05313fdebbd4c4901ff69a7f6b5c2', '2f1ea5bab59609af66323f053a356a45f0666e49'):
        with tempfile.TemporaryDirectory(prefix='public-git-proof-test-') as temp:
            root = Path(temp)
            projection = {'base': base, 'head': head, 'artifacts': [], 'deleted_paths': []}
            for path in filter(None, git(public, 'diff', '--no-renames', '--name-only', '-z', base, head).decode().split('\0')):
                raw = git(public, 'show', head + ':' + path)
                entry = {'source_path': path, 'sha256': hashlib.sha256(raw).hexdigest()}
                if peer(path):
                    del entry['sha256']
                    entry['git_blob_oid'] = oid('blob', raw)
                    entry['omitted_reason'] = 'Peer raw output excluded.'
                else:
                    target = root / path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(raw)
                    entry['admitted_path'] = path
                projection['artifacts'].append(entry)
            proof = collect(public, projection)
            summary = verify(root, projection, proof, base, head)
            rejected = []

            def reject(label, changed_proof, changed_projection=projection):
                try:
                    verify(root, changed_projection, changed_proof, base, head)
                except (ValueError, KeyError):
                    rejected.append(label)
                else:
                    raise AssertionError('accepted: ' + label)

            for field in ('commits', 'trees', 'before_blobs'):
                bad = copy.deepcopy(proof)
                key = next(iter(bad[field]))
                bad[field][key] = encode(decode(bad[field][key]) + b'!')
                reject(field, bad)
            bad = copy.deepcopy(proof)
            bad['head'] = base
            reject('head binding', bad)
            bad = copy.deepcopy(proof)
            bad['trees'].pop(next(iter(bad['trees'])))
            reject('missing tree', bad)
            bad_projection = copy.deepcopy(projection)
            bad_projection['artifacts'].pop()
            reject('missing path', proof, bad_projection)
            bad_projection = copy.deepcopy(projection)
            next(e for e in bad_projection['artifacts'] if peer(e['source_path']))['admitted_path'] = 'peer.json'
            reject('peer inclusion', proof, bad_projection)
            bad_projection = copy.deepcopy(projection)
            next(e for e in bad_projection['artifacts'] if peer(e['source_path']))['git_blob_oid'] = '0' * 40
            reject('peer blob identity', proof, bad_projection)
            target = root / next(e['admitted_path'] for e in projection['artifacts'] if 'admitted_path' in e)
            target.write_bytes(target.read_bytes() + b'!')
            reject('after bytes', proof)
            print(json.dumps({'head': head, **summary, 'tamper_rejected': rejected}))


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--self-test':
        self_test(Path(sys.argv[2]))
    elif len(sys.argv) == 6 and sys.argv[1] == '--verify':
        root, bundle, base, head = Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4], sys.argv[5]
        print(json.dumps(verify(root, json.loads((bundle / 'projection.json').read_bytes()),
                                json.loads((bundle / 'public-git-evidence.json').read_bytes()), base, head)))
    else:
        sys.exit('usage: public-git-evidence.py --self-test PUBLIC | --verify ROOT BUNDLE BASE HEAD')
