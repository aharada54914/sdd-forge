# T-001 native launch

- Fresh native thread: `01a0e682-61e2-7370-a241-7646661b372e`; turn: `01a0e688-26c9-7d12-8ecf-37b7279ea5e8`.
- Selected model: `gpt-6-astra`, effort `high`; declared output roots only; network disabled.
- Snapshot preparation: exit 0, `TASK_INPUT_OK`.
- Initial combined batch/single validation invocation: exit 1, `batch mode does not accept --manifest`; no validation PASS claimed for it. Correct separate batch and snapshot validation invocations each returned exit 0, `TASK_INPUT_OK`.
- The first worker turn was accepted before those corrected validations completed. It was restricted to input inspection and the RED/preflight stage; production remains forbidden until the committed RED receipt exists. This ordering is recorded rather than described as a successful pre-launch validation.
- This is launch/fixture boundary evidence, not native product activation, implementation completion, independent review or quality-gate PASS.

