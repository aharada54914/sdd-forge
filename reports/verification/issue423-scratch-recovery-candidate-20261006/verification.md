# Limited prototype verification

Command: `rtk proxy python3 -B reports/verification/issue423-scratch-recovery-candidate-20261006/normalization.tests.py`

Observed exit: 0.

```text
PASS: 54; prototype only; no original validator or reservation executed
```

SHA-256:

- `normalization_candidate.py`: `710ebaab1afc705aaa226795eceb3641374f97a7cbba98ea1182a55213afb0dc`
- `normalization.tests.py`: `d2c75deb2e84adf0a6df5d192958068eac14f6dc30e0e14a4d7f68509b731414`

The tests reuse the unchanged canonical, safe-path and overlap helpers extracted
from each existing Bash and PowerShell validator. Each runtime-helper path runs
27 assertions: the original relative declaration is rejected; a bound owner
observation can resolve it without creating a directory; mismatched or modified
evidence, malformed roots and symlink escape are rejected; equal, ancestor and
descendant collisions remain rejected and prefix siblings remain distinct.

This does not execute either full validator driver or constitute native activation,
independent review, a quality verdict, CI or a task transition. The observation is
transcribed evidence, not a signature, and its authenticity cannot be established
by the prototype. Existing historical reports remain unchanged and unexecuted
historical work remains unexecuted.

## Minimum lawful adoption still required

There is no source-application command for this prototype. Before source adoption,
the bounded recovery input and its independent observation-admission requirement
must be incorporated in the formally managed review-context contract. Both original
validators then need the same narrowly scoped comparison-value resolution, with
the existing direct current-task root checks unchanged. Run the existing complete
scratch-history drivers plus the new bound-input negatives against those candidate
validators, obtain independent review, then use the sanctioned protected-application
path. Historical records, ledger entries and reservations must not be rewritten.
