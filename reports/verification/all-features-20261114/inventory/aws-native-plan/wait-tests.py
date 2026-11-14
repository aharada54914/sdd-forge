"""Offline waiter checks only; these are not provider observations."""
import ast
import contextlib
import io
import json
from pathlib import Path

path = Path(__file__).with_name('cycle.py')
module = ast.parse(path.read_text())
wait_node = next(n for n in module.body if isinstance(n, ast.FunctionDef) and n.name == 'wait')
code = compile(ast.Module(body=[wait_node], type_ignores=[]), str(path), 'exec')

class Clock:
    now = 0
    def monotonic(self):
        return self.now
    def sleep(self, seconds):
        self.now += seconds

cases = [
    ('update eventual consistency', ['CREATE_COMPLETE', 'UPDATE_IN_PROGRESS', 'UPDATE_ROLLBACK_COMPLETE'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', None, 60, 30),
    ('delete eventual consistency', ['UPDATE_ROLLBACK_COMPLETE', 'DELETE_IN_PROGRESS', 'DELETE_COMPLETE'], 'DELETE_COMPLETE', 'UPDATE_ROLLBACK_COMPLETE', None, 60, 30),
    ('fast completion', ['UPDATE_ROLLBACK_COMPLETE'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', None, 60, 30),
    ('wrong terminal immediately', ['UPDATE_ROLLBACK_FAILED'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', 'unexpected terminal', 60, 30),
    ('prior forbidden after progress', ['UPDATE_IN_PROGRESS', 'CREATE_COMPLETE'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', 'unexpected terminal', 60, 30),
    ('prior grace expires', ['CREATE_COMPLETE'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', 'unexpected terminal', 60, 3),
    ('overall timeout bounds grace', ['CREATE_COMPLETE'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', 'bounded wait expired', 3, 30),
    ('progress timeout', ['UPDATE_IN_PROGRESS'], 'UPDATE_ROLLBACK_COMPLETE', 'CREATE_COMPLETE', 'bounded wait expired', 3, 30),
]
results = []
for name, statuses, expected, prior, error, seconds, grace in cases:
    clock = Clock()
    index = [0]
    def describe():
        value = statuses[min(index[0], len(statuses) - 1)]
        index[0] += 1
        return {'StackStatus': value}
    namespace = {'time': clock, 'describe': describe}
    exec(code, namespace)
    actual = None
    with contextlib.redirect_stdout(io.StringIO()):
        try:
            namespace['wait'](expected, seconds=seconds, prior=prior, prior_grace=grace)
        except RuntimeError as exc:
            actual = str(exc)
    assert (actual is None if error is None else actual and error in actual), (name, actual)
    assert clock.now <= seconds, (name, clock.now)
    results.append({'case': name, 'result': 'PASS', 'elapsed_simulated_seconds': clock.now})
print(json.dumps({'scope': 'offline wait() semantics only; no AWS calls', 'cases': results}, indent=2))
