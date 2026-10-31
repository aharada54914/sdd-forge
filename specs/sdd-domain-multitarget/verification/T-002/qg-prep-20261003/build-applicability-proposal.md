# T-002 build applicability proposal — not applied

**Superseded investigation note:** The existing `install.sh
--source-directory ... --target FilesOnly --skip-mcp` path assembles current
working-tree bytes into a real installed plugin tree. It supplies an applicable
build check for T-002, so the waiver proposal below is **not recommended** and
must not be applied. Current-byte execution was blocked before launch by the
PreToolUse hook; see `python-toolchain-evidence.md`.

The contract already has a per-check `waiver_reason`, but the current
`stack: code` medium-tier rule still requires `build` to be `required:true`.
Merely populating `waiver_reason` or changing `build` to `required:false`
cannot pass `check-contract`. The existing `shell`/`docs`/`spec` stacks waive
all three compile-oriented checks; none accurately describes this production
Python validator, for which real lint and strict typecheck now pass.

The narrow proposal is a versioned `python-script` stack classification for
an interpreted production Python script with no configured packaging/build
artifact. Under this value, only `build` may be `required:false`, with a
non-empty `waiver_reason` describing the absent build output. `lint` and
`typecheck` remain mandatory, as do every test and quality check in the
medium tier. `code` remains the default and retains all three requirements.
This adds one explicit classification to the existing stack contract; it
does not introduce a general exemption expression or infer PASS from a
syntax check. The reviewer must verify the absence of a build product.

After approval, update the stack contract/version and its documented matrix,
both Python and PowerShell `check-contract` implementations, the corresponding
parity tests, and finally T-002's contract. The T-002 `build` entry would be
`required:false`, `passes:false`, with a specific reason such as: “Standalone
interpreted Registry validator and JSON Schemas have no configured artifact
build; runtime and schema behavior are covered by the required checks.”
The task's lint and typecheck entries remain `required:true` and use real
evidence. This is an applicability decision, not a quality PASS.

Required rejection fixtures in both validator test suites:

1. `stack: code` with `build.required:false` fails, even with a reason.
2. `stack: python-script` with `build.required:false` and an empty reason fails.
3. `stack: python-script` with `lint.required:false` fails.
4. `stack: python-script` with `typecheck.required:false` fails.
5. `stack: python-script` with any medium-tier test/quality requirement disabled fails.
6. Unknown or mis-cased stack values fail closed.
7. `stack: python-script` with only `build` waived and a reason passes, when
   every other required check has genuine passing evidence.

This proposal does not modify shared policy, validators, task status, or the
T-002 build check. Current protected/shared file SHA-256 values for review:

- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`:
  `57d70a7d615f60862ac3a7259b28f8452a0a32b50b58fe7aa3d7cbe336a6c725`
- `plugins/sdd-quality-loop/scripts/check-contract.py`:
  `2b94c174a534309c6b8744451a34bc6124406df373c45be6deb63c8a311249d3`
- `plugins/sdd-quality-loop/scripts/check-contract.ps1`:
  `1ce796d91352a488d479a335af08b663a430b0c1d9858dc2593382181d54344a`
