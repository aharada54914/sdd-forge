# T011 integration evidence and limits

- Integrated starting revision: d901a3750d6b563622e8f06100c0043896022645,
  containing origin/main fcb8275a (#591). Canonical inventory remains
  tests/verification-catalog.json; both normal wrappers and CI consume
  verification.py. No retired duplicate inventory or path-based skipping added.
- All six suites are mandatory in local-posix/local-powershell and ci-cloud.
  The native test OS matrix consumes ci-cloud and writes a runner receipt.
  Existing required status names, required-checks aggregation, sharding and full
  fallback coverage are unchanged. Native Linux independently requires local
  preparation, so missing binaries fail rather than being tool-missing SKIPs.
- #423: the starting current suite executed 53 checks; the added normal-driver
  consumer proof brings it to 54. Inventory/contract-boundary/negative tests
  remain intact. The interviewer/seven-document source and historical evidence
  are byte-preserved. Current tests use actual catalog/YAML consumers and real
  wrapper listings, not obsolete run-all section parsing.
- Separate existing multitarget T004 compatibility test FAILS on
  check-contract.py hash 9bbc96658f775ed46c8d876e92803a8de46c9bf242bbc83d412776164e89e6b7
  versus pinned 2b94c174a534309c6b8744451a34bc6124406df373c45be6deb63c8a311249d3.
  The same assertion fails in the disposable pre-T011 base tree. Root then
  explicitly authorized current T004 regression integration. The new helper
  admits only the exact T009 reviewed bytes and reverses exactly the 14-line
  insertion to verify the original baseline hash. Six negative mutations and
  a wrong-baseline hash fail; ten actual original/current absent/v2 legacy CLI
  control pairs preserve exact exits/stdout/stderr with no cloud modules.
  T004 now passes all nine tests (t004-extension-green.log). Production bytes,
  frozen consumer-baseline.json and historical reports remain unchanged.
  Current Red and rollback evidence retain the original failure honestly.
- All cloud suites were inspected for temporary path aliases. Contract,
  Admission, AzureExecution, AwsExecution and observation-entry temporary roots
  now resolve physically. Packaging uses temporary children of its already
  physical root and resolves independently created workspaces. Production
  containment/no-follow checks are unchanged.
- Native Windows: explicitly skip POSIX-positive filesystem/operation fixtures;
  keep schema/reducer/graph tests, real native PowerShell installer lifecycle,
  typed CLI refusal (UNSAFE_ROOT for native drive paths), and direct shared
  filesystem UNSUPPORTED_FILESYSTEM assertions. These are refusals, not cloud
  execution. Existing junction checks are untouched. Hosted Windows and macOS
  execution remain pending T008 exact-commit CI; local Linux simulation is not
  claimed as native Windows proof.
- Newly reachable CI branch (WFI-015): all six newly registered suites now run
  in each native OS matrix cell; actual hosted execution pending. On Linux,
  actual pinned Bicep/CDK native compile/synthesis branches are mandatory. The
  equivalent Linux tools and tests were exercised locally with fresh public
  acquisitions; real hosted run remains pending. macOS/Windows unsupported
  binary guards are not broadened to manufacture coverage.
- The official pinned Node archive bundles npm 11.17.0. Initial CI setup's
  guessed 11.9.0 assertion failed; no acquisition success was relabeled.
  npm 11.17.0 reproduced the existing exact CDK tree digest/file count and
  passed native preparation tests without changing any production pin.
- No PowerShell source was changed; no .sh-to-.ps1 port/operator/cmdlet sweep
  applies. Native PowerShell listing/runner regression and existing real
  installer subprocess tests were run on Linux; Windows is not inferred.
- Native model-host preparation was initially PENDING. Root subsequently
  delivered native-host-trial-1/acceptance.json: two actual fresh provider
  contexts and ten installed CLI calls pass the routing/denial rubric.
  Root-owned delivery, not an implementer-launched host trial; exact identities
  and stable hashes are cited in the canonical report. Formal review admission
  remains root-owned. No cloud resource action or authentication bypass occurred.
- Live TEST-003/005/009 remain BLOCKED by OQ-001 (owner-supplied scope,
  OIDC/IAM, images, backup/health, budget and retention). Root owns full suite,
  independent review, status changes, exact-commit CI and release. No Done or
  quality-gate PASS is asserted by this addendum.
