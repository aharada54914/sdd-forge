# Independent bounded review of the PowerShell cache correction

**ACCEPT the bounded harness correction for integration and corrected-revision CI.** No open finding in this change. Corrected macOS execution remains required. This is not proof of the previous crashes' root cause, full-platform PASS, formal quality verdict or T-001 completion.

Reviewed manifest `/workspace/a9-macos-cache-correction-20261024/final-manifest.json`, SHA256 `65be178764bfe153d3c66f8efb08cfb99cbd931ba294214ed4219d81fd08b3e6`; patch SHA256 `80c566d9ba8161fe4d415a9bc90bf712489c5f4efef57ad9c1850ede9c3560fa`; harness SHA256 `9ad841a45612250dbff1284d92615e7ffd4fd1936872f12c3bdc959aa29835f9`. Every manifest evidence hash and all six current source pins were independently verified. Only the Bash test file's embedded Python harness changes; production validators, PowerShell launcher and other listed source pins remain unchanged.

The 19-insertion/4-deletion patch routes the three existing child launch sites through one helper. On Unix PowerShell, it creates a unique temporary cache beside the synthetic fixture, copies the environment, changes only the child's XDG_CACHE_HOME, waits for subprocess.run and cleans its owned directory. No global environment mutation, HOME/config/data change, user-cache deletion, retry or signal-to-success conversion occurs. Cache paths are outside fixture snapshots, so immutable-input assertions remain meaningful. Native Windows and Bash retain the original launch call. Four workers, case definitions and expected exits remain unchanged. Independently reversing only the helper, three call substitutions and startup-probe insertion in memory reproduced the exact baseline bytes.

CompletedProcess return codes, stdout and stderr return unchanged, including nonzero/signal results. Subprocess/cleanup exceptions cannot silently become success. Child timing and ownership retain the existing synchronous model; no timeout or detached/background process is introduced. TemporaryDirectory cleans after normal completion/error unwinding, including failed child exits. Failure caches are not retained, and abrupt parent termination is not newly guaranteed to clean them. Neither capability is claimed by this patch.

The metadata probe also uses the helper and records actual executable, PowerShell/runtime version, OS and architecture. Nonzero exit stops the suite with failure; invalid JSON cannot silently pass. It adds no named acceptance case and replaces no assertion.

## Evidence

The actual prechange isolation check observes two native children using the same cache and fails the isolation assertion. It does not reproduce SIGABRT. The postchange check observes distinct actual cache paths, completed cleanup, unchanged parent environment/HOME/config/data, and exact exit-7 preservation. H13 records nine passes (three controls and six H13 variants).

One full corrected Linux PowerShell run records 731 PASS/0 FAIL in 161.58 seconds. Every mutation retains immutable=True and no_target=True. All 731 parsed result names and order independently match the retained previous macOS log; no sampling or removal occurred. Observed local runtime: PowerShell 7.6.7, .NET 10.0.13, Debian 13, X64. This reviewer inspected these receipts; no suite was repeated.

Diagnosis SHA256 `3d0cece0c2d1488e7340e56e22ea680f84fb4cfcae10cd148e967e663cb12f92` separates observed shared-cache use from unproven CI cache corruption. Its cited open PowerShell issue 26528 and dotnet/runtime issue 121977 support the proposed mechanism but are not execution evidence for this candidate. Existing macOS attempts remain failed and their exact launched runtime versions were not captured. Even a corrected macOS PASS would establish that run's result, not retrospectively prove root cause.

Recommendation: retain original failures/history, bind the changed harness and new Linux evidence into the candidate, and assess the authorized corrected macOS/CI run. Do not claim full-platform completion beforehand. If it still aborts, preserve actual runtime/output evidence and investigate before another retry. Current cleanup means child-cache bytes will not be available unless separately authorized diagnostics capture them.

Reviewer: Work `/root/review_mode_compat`. No source edits, Git mutations, provider calls, live-ledger reads or repeated full-suite executions were performed.
