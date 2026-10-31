# Independent candidate diff review — 2026-10-06

Result: NEEDS_WORK (candidate safety review only; not a formal SDD verdict).
Critical: 0. Major: 1.

Scope: A7 A21 recovery candidate. Owner checkout `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`; HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Candidate patch SHA-256 `acc253dc8ac375e97035da3e8ffbaac32393f7fc881de7933e5e4d846f8d1c5e`. Existing dirty work was retained. This new non-frozen diagnostic report is the only authored file; no implementation, reservation, ledger, approval or verdict changes. The candidate affects high-risk recovery evidence boundaries. Correction budget 3/3 already consumed; no fix attempted.

## Major: final assistant is not necessarily the final meaningful transcript event

`failed-last-attempt.candidate.py:210-212` selects assistant events and checks only the last assistant's `stop_reason`. `validate-nontty-spec-launch.candidate.py:177-187` permits subsequent tool-result user events without enforcing that the final meaningful event is an assistant completion. Consequently, a transcript ending with an unanswered tool-result user message is admitted as a completed failed turn. This contradicts proposal step 3's final completed assistant requirement. The old truncated branch explicitly checks the final meaningful event (`failed-last-attempt.candidate.py:248-249`).

Reproduction copies the actual retained fixture into a disposable temporary tree, appends one trailing tool-result user message, and recomputes only the fixture transcript pin. The helper and canonical ledger checks then accept it. This is a semantic-validation negative case with matching fixture pins; it does not claim that an attacker can alter original evidence without invalidating its existing pins. No existing evidence was changed.

Run from the owner checkout:

```sh
rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import runpy, contextlib, io, json
from pathlib import Path
p = Path('reports/verification/a7-attempt21-recovery-candidate-20261006/recovery.tests.py')
with contextlib.redirect_stdout(io.StringIO()):
    m = runpy.run_path(str(p))
def mutate(root, hashes, turn):
    path = root / turn['transcript_path']
    with path.open('a') as out:
        out.write(json.dumps({'type': 'user', 'sessionId': m['SESSION'],
            'message': {'content': [{'type': 'tool_result', 'tool_use_id': 'pending',
                                     'content': 'unfinished followup'}]}}) + '\n')
    m['repin'](root, turn)
m['check']('trailing tool-result user after final assistant is accepted', mutate, accept=True)
PY
```

Observed exit 0:

```text
PASS accept trailing tool-result user after final assistant is accepted
```

Minimum correction direction, not applied: in the new diagnostic branch require the last meaningful user/assistant event itself to be an assistant with `end_turn`, and add this trailing-user negative case. Preserve ordinary postflight behavior.

## Verification and limits

- Independently ran `additional.tests.py` with `PYTHONDONTWRITEBYTECODE=1`: exit 0, 34 reported PASS cases. It also executes the 18-case `recovery.tests.py` suite with stdout captured. The separate reproduction executes that same 18-case suite again before its extra case.
- Verified historical caller uses the pinned historical precheck hashes and recomputes its composite input hash; immediately preceding caller still passes current hashes. Outer exact evidence equality, canonical ledger validation, scoped new-mode approval binding and the ordinary raw JSON postflight remain present.
- Read shell and PowerShell callers: completed NEEDS_WORK contracts are validated and recovery admission is repeated after locking. Both runtime fixture paths passed in the additional suite.
- Original three source hashes match status.md; final candidate patch/fresh-helper hashes match the final addendum. Historical original evidence and normal postflight were not modified.
- These fixture successes do not discharge the Major finding. No installed native-host execution, exact-HEAD CI, formal review/quality gate, original-source application or A21 reservation was performed. This report does not authorize any of those actions.
