# T-001 evaluator result not adopted

Owner: shared-review-launch-integration/sdd-forge; HEAD
`9ce19abe90df0cb83e385f96855e4843318a8807`. Existing dirty work is preserved.

Run `fbe735ad-d472-4b5e-957d-4b246fe04636` completed native delivery, but its
PASS is not accepted as quality-gate evidence. Its transcript shows implementation
and log inspection without reading the mandatory requirements/design and other
normative inputs. Hash verification is input identity evidence, not review coverage.
The original transcript, result and reservation remain unchanged.

The bounded T-001 repair clarifies the existing evaluator obligations in the common
diagnostic/formal prompt and asserts them in the existing transport regression.
It adds no permission, reservation exception or weakened acceptance condition.
Affected caller: launch-impl-review.py via expected_prompt; native_delivery checks
the same canonical bytes. Required validation: transport and affected launch suites,
static checks, then a fresh independent evaluation of current pinned inputs.

No new verdict, task-state transition, CI success or merge is claimed here.
