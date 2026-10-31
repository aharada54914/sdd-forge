"""Read-only preparation checks; never invoke application mode."""
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location('candidate_apply', Path(__file__).with_name('human-apply.candidate.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checks = 0
assert module.RELEASED is True
checks += 1
for rel, old_hash, name, new_hash in module.ROWS:
    before = (module.ROOT / rel).read_bytes()
    candidate = (module.HERE / name).read_bytes()
    after = module.prepare(rel, before, old_hash, candidate, new_hash)
    assert module.sha(after) == new_hash
    checks += 1
    for changed, payload in ((after, candidate), (before + b'\n', candidate), (before, candidate + b'\n')):
        try:
            module.prepare(rel, changed, old_hash, payload, new_hash)
        except SystemExit:
            checks += 1
        else:
            raise AssertionError('accepted changed or already-applied target: ' + rel)
print(f'PASS: {checks} read-only preparation assertions; application/rollback NOT EXECUTED')
