# Issue618: standard BuildKit local RUN-cache evaluation

Decision: do NOT introduce a product cache on this result. The existing standard cache works mechanically, but this measured pure-suite workload is slower than ordinary native execution even before initial runtime image preparation. No extra requests were invented to make economics favorable; guard time dependencies were not ignored or frozen with additional machinery.

## Setup and provenance

Source b3b997ed full snapshot from the previous sealed-image experiment, not mutable current main. Same original bootstrap-cross-layer-index suite and verification.py owner; no product edits, reduced tests, artificial delay/load, new service or generic cache. Existing Docker28.4/BuildKit(vfs backend) and fixed local runtime/source image. Dockerfile has root-owned source/runtime, nonroot UID10001 verification RUN, RUN --network=none, fresh tmpfs for /tmp and PowerShell XDG paths, clearenv, original54 assertions including PowerShell parity. Build rootfs is not globally read-only: root-owned source/runtime permissions protect inputs, /evidence is the intended writable output, then made read-only in the final layer.

Protocol fixed before work. First measured build forced --no-cache, no --cache-from/import-cache supplied. Warm requests used local standard RUN cache. First actual result's exact imageID/artifact hashes remain known to the same evaluation process; each warm export must match those actual original bytes and ID. Arbitrary disk PASS files were never admitted as execution evidence. This bounded trust model is stronger than simply reading whatever PASS file a cached image claims to contain.

All measured warm images were sha256:026dbc30caf8be6b0e1a5eee118ba2edebf179a53b44926c5ab39785309087ae. Original run8b6f6bdddc034413bb999769b59393c3 is preserved in all copies. RUN reports CACHED for requests2/3, original54PASS/0FAIL output/receipt/measurement are byte-identical, and the underlying original inner execution time8.335334seconds remains historical. We do not count these repeated original records as3 actual suite executions. Raw verification receipts still say reusable:false; the product has no implemented cache acceptance route.

## Three-request comparison

| Path | Request1 | Request2 | Request3 | Total seconds |
|---|---:|---:|---:|---:|
| native existing owner | 5.886720 | 5.791844 | 5.684286 | 17.362851 |
| BuildKit existing owner RUN/cache | 33.616703 | 5.757246 | 6.748619 | 46.122568 |

BuildKit times include build, artifact retrieval from pinned image and exact original-byte validation. Actual prior runtime/source image prepare cost24.907200seconds gives at least71.029768seconds total. Initial artifact-export setup failure and context assembly are additional costs, not hidden wins. Even excluding all image preparation, measured three-request path has no benefit. Warm layer hits eliminate compilation/test execution but filesystem/image/export overhead consumes the saving on this vfs-backed environment. This is not a universal claim that BuildKit caches never help; platform/load and retrieval strategy differ. No larger request count or time-dependent guard cache was introduced after observing the result.

Native runs use host Debian Python/Pwsh dependencies; BuildKit pins its userspace. Same source/suite, different isolation overhead and runtime packaging. OS caches/load were not controlled, samples n=3 operational comparison, not a causal cross-platform performance claim. Source export/Git metadata handling is explicit; exported trees have no .git and receipts' missing revision is not silently replaced with approval.

## Actual invalidation and artifact controls

- Actual owner argv changed by adding --timings tests/verification-timings.json. RUN executed anew (14.883747second build), different image and original run1fd01958b3d7468a8fb779b52c0192db, expected54 checks passed. It did not return baseline run.
- Actual child locale changed from C.UTF-8 to C. RUN executed anew (14.545027second build), different image and runb919a691d9c04c379bd9bb7d5798a0f2; baseline run was not reused.
- Real template source's required Cross-Layer Dependencies heading removed. Build invalidated prior RUN, reran original suite and failed (18.228027second build, exit1,53PASS/1FAIL). Original source restored afterward. Expected property was not weakened.
- Retained original exported stdout replaced by forged PASS: known-cold artifact integrity check rejected it. Original receipt removed: rejected. artifact-controls.json records both false acceptance flags. These tests cover retained/exported artifacts against the known original reference, NOT corruption of Docker daemon internal cache storage. No arbitrary replacement manifest can supersede the in-process original hash reference.
- Failed RUN layers do not become usable final images. The harness therefore prints original failure stdout/stderr/receipt/measurement bytes into the build log before returning failure. source-negative-original-artifacts.json extracts those exact strings; raw source-changed.log remains authoritative. Without such streaming, a naive 'save evidence only inside failed layer' loses failure evidence.

## Preserved setup failures

Initial host measurement rejected abbreviated source revision before any workload; fixed to full40-character SHA. Initial cold BuildKit execution passed, but docker cp attempted to restore read-only nested output directory permissions before children and failed. Its log/image/partial export remain in initial-export-failure; host measurement retains the incomplete span, not invented success/time. Corrected transport reads docker cp tar stream, records original tar metadata, extracts bytes to a private host directory and validates original hashes. Native3 runs were not unnecessarily repeated. First corrected build forced no-cache again so the comparison starts from an actual fresh owner execution.

## Trust boundary and missing product connection

BuildKit local cache keys bind actual Dockerfile command, referenced ARG/ENV, copied source content and base image dependency. They do not prove that arbitrary live repository input was coherently captured, that an existing cache entry was produced by an authorized caller, or that all relevant kernel/clock/external dependencies are closed. No external cache import was used; a shared daemon populated by other importers remains a provenance concern. This experiment accepts only known-cold results produced in this process and verifies exact original ID/artifacts. An unrestricted persistent cross-session importer would need more trust evidence and is not authorized by this test.

Daemon/kernel and content-addressed image store remain trusted. We did not mutate daemon files or simulate malicious root/cache administration. Docker COPY cache behavior is not a substitute for filesystem ctime/inode/topology admission; mtime-only changes may not invalidate. Unknown time/network/device/current external state dependencies must cold-run or BLOCKED. The prior guard suite's realtime synthetic token behavior remains outside this pure reuse trial.

Full source snapshot lives in base image; template overlay is an explicit controlled mutation. Live dirty/untracked source acquisition, addition/removal/move races, loaded owner version binding, final current-input equality and execution-time mutation/ABA checks are still missing from product integration. A pinned base tag was checked against expected imageID; a hostile tag/daemon swap is outside the demonstrated boundary. An owner implementation should consume coherently captured bytes and bind an immutable ID, not trust tag strings or Git commit equality alone.

Existing verification.execute is still the only appropriate check-selection owner; standard BuildKit could be an optional execution backend beneath already-selected registered checks. There is currently no genuine same-process repeated-request caller, no versioned reused-result acceptance, and no independently validated current contract/bundle projection for this cache. Old raw receipt is original evidence, not a fresh PASS or approval. Required checks and independent reviewer materials must remain unchanged. No second selector, generic cache engine or mandatory Docker service is proposed.

Final conclusion: standard local RUN caching has been demonstrated with original-run retention and these bounded negatives, but measured economics and incomplete admission/caller integration do not justify product cache implementation. Preserve this as a measured no-go for the current pure workload, not as fulfillment of every original #618 AC or evidence against all possible workloads.
