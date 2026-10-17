# Current-product reachability validation

The original current-generator mutation printed unexpected output and exited
42. The previous byte suite incorrectly reported 25 passed, 0 failed. With the
same mutated working-tree product root, the corrected suite reports 19 passed,
6 failed: output, stdout/stderr, and exit status fail for both F1 and F2.

Local verification on Linux:

- Current-product byte twins: Bash 25/0; real PowerShell 25/0.
- Current-product reachability regressions: eleven passed using Bash executables;
  the same eleven passed using real PowerShell validator/installer and suite
  executables. These are Linux executions of PowerShell, not native Windows
  results.
- The copy regression additionally checks discovered unexpected template and
  plugin-manifest files. Its final version passed in both runtimes.
- Python suite runner preference/fallback/failure propagation: four passed.
- Historical baseline contract suite: 10/0.
- Live-contract proof: four targeted negative cases with valid controls across
  Bash and PowerShell.
- Baseline mutation proof: both runtimes reject the changed historical bytes
  for the canonical-hash diagnostic and pass after restoration.
- Historical canonical files and golden capture scripts are unchanged.

The new regression suite is explicitly registered in the required POSIX job
and native Windows-heavy job, and in both local regression runners. CI and
post-merge results must be checked on the final integrated commit; local results
above do not claim those runs have completed. No live model authentication or
fixed-model comparison is asserted by this deterministic acceptance test.

Before the final project-metadata isolation change, the exhaustive assertion
harness detected all 25 mutations per runtime and restored green controls. Its
capture helper SHA-256 was
`151253886fedd7ce9a41acd22c95a009891c615bf9407896b2aceca6eadf4062`.
A concurrent test-source edit was correctly detected as additional install
drift in one PowerShell negative case; that case was separately rerun against
frozen input and produced only its intended failure, then restored green.

The final root-project-metadata boundary was demonstrated RED before its fix:
a tracked product Project Context polluted the absent fixture. The final
eleven-case suites and byte twins cover the corrected boundary, including
rejection when the running product itself creates Context. The earlier
exhaustive run is not described as an execution of the later helper bytes.

Final eleven-case and byte-twin helper SHA-256:
`3cdee3f37d93c8249cd2265f69861343d2e3dfcdd0222a982bb2182d3aa00c40`.
