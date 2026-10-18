# T-010 exact local code rollback and reapply

Executed by evidence/rollback-experiment.py run2, in disposable detached checkout:
`/tmp/cloud-T010-01a14f3e-b525-78c0-9d78-d79635e2a5de/rollback`.
No cloud action or resource rollback occurred. The main checkout's five candidate
files were hash-checked unchanged throughout the experiment.

## Reconstruction and scope

Entry commit: `f2d51e4a2d4b2c2f440222351684f3162ec88fc4`. Because task entry already
contained uncommitted predecessor work, Git checkout alone is NOT the baseline.
The exact original scratch snapshot inputs were overlaid using initial-input-map.json.
Explicit supplemental unchanged regression dependencies were also overlaid, including
T009 guard membership omitted from the original input map. These are recorded as
supplemental inputs, not silently substituted initial product bytes. The run1
reconstruction failure is preserved separately; see diagnosis.md.

The rollback/reapply set is exactly:
- plugins/sdd-quality-loop/scripts/cloud_dependencies.py (absent at entry)
- plugins/sdd-quality-loop/scripts/cloud_authorization.py
- plugins/sdd-azure-cloud/scripts/azure_governed.py
- plugins/sdd-aws-cloud/scripts/aws_governed.py
- tests/cloud-orchestration-verification.tests.py

No task/approval/traceability/release state was modified. Existing initial snapshots
were never changed. The script refuses to overwrite a previous experiment directory.

## Actual sequence and outcomes

1. Assert each entry file hash equals the authoritative initial map, with absence of
   new cloud_dependencies.py. Preserve current candidate bytes separately.
2. Entry verification: 78 tests pass. Entry Admission: 26 tests pass.
3. Overlay candidate's exact five files. Candidate dependency suite: 28 tests pass.
4. Restore the four entry files byte-for-byte and remove only the new dependency
   module. `restored` hashes exactly equal `initial` (including absence).
5. Restored verification: 78 tests pass; restored Admission: 26 tests pass.
6. Temporarily run only the candidate's matched dependency control against restored
   product code: expected exit 1 (four public WRITE_ADMISSION_BLOCKED errors against the
   original blanket dependency boundary; the internal guard is not exposed by these
   exception logs). Restore initial test bytes again. This is
   current rollback feature-loss sensitivity, NOT retroactive pre-implementation Red.
7. Reapply candidate bytes. `reapplied` hashes exactly equal `candidate`.
   Reapplied dependency suite: 28 tests pass. Main candidate still matches hashes.

Every test invocation used the offline runner and exercised parent/direct Python/
shell/PowerShell-child urllib sentinels. Native tool paths and the required PowerShell
wrapper were explicitly configured. The final checkout is retained with reapplied
candidate code for inspection. Original operation/resource state was never touched.

## Stable evidence

- rollback-run2/result.json: exact per-file entry/candidate/restored/reapplied SHA-256,
  actual argv, start timestamps, expected/actual exit statuses and completed=true.
- rollback-run2/*.log: genuine outputs for every step above.
- rollback-run2-commands.log: driver completion/exit output.
- rollback-run1/: preserved incomplete reconstruction result; never claimed successful.
- task-delta.patch / task-delta.json: scoped original-input-to-candidate changes.
