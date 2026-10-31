# Applied receipt validator: focused regression

Scope: A7 non-TTY receipt-control repair; diagnostic evidence only.

- Owner: `a7-t005-intake/sdd-forge`.
- Applied validator SHA-256: `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd`.
- Executed the existing `receipt_prompt.tests.py` unittest module with its `candidate` module binding replaced in memory by the original-path `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` module. Neither source nor test files were edited.
- Result: 8 tests, 0 failures, exit 0 (0.051 seconds).
- Covered: receipt hash, ordered input binding, identity, chain fields, duplicate/control-character paths, terminal newline sensitivity, stable explicit prompt, and execution of emitted literal hash commands.

This is not native admission, independent formal review, CI, merge, or a task-status transition.

Remaining separate inventory-recovery application was checked by current hashes: `fresh-review-recovery.py` remains `0461760864371ed8995de5caa6631117ed674b2a7a16ab5988af11e54e26a6de`; `spec-review-loop/SKILL.md` remains `f860a4449e7a2edfc35a61f17c88f62399a8bf425df2f3743356d08da6a2f4af`. Do not infer that repair was applied from this receipt regression.
