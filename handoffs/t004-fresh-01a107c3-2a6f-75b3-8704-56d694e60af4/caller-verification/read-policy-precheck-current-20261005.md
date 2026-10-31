# Read-policy formal launch: current read-only check

Date: 2026-10-05. No reservation, precheck publication, host allocation or
review turn. No protected/code changes. Existing approvals are not requested again.
The local and installed spec-review-loop skills and local AGENTS were read.

Source root: `/private/tmp/sdd-guard-main.3JEj4I/repo`.

## Corrected current blockers

1. The earlier TEST-RCB-011 boundary-path repair IS applied. Current raw
   shasum values match `reports/verification/spec-boundary-repair-validation-20261004.md`:
   validate-review-context-set.sh `1fd2b934a0ffa49f4a62db1f90231e8cee887e59ad71fbc2f4dc3a146aa9348f`,
   .ps1 `588e5c225e9fb102b1a8a4d38c73c47ee887056594b10b7c3ff3d8f0c239dd92`,
   tests/review-context-boundary.tests.sh `56d57329973a4a5d737362ec1ac7c4f3ac1ff38de814d465e4df396527d359b8`.
   Existing completion records exit 0 and final sub-suite 84 PASS, not a new run.
   Do not reapply this obsolete three-file action.
2. Manifest consumers remain unsynchronized. All eight live hashes equal the
   BEFORE pins in `reports/verification/spec-boundary-consumers-human-apply.py`.
   This is static source comparison, not execution or approval of that script.
   The local skill still omits boundary from the prescribed input list; precheck
   sh:288 and ps1:382–386 construct exact expected manifests without it.
   Unlike the older candidate note, the current contract template ALREADY includes
   boundary at lines 19 and 30. Do not assume every file named by a dated note
   remains unapplied. Audit the prepared eight-file package against this state
   and use only its normal authorized protected-application route.
3. guard-role-read-regression round 1 has exactly the three files precheck,
   A invocation and A host receipt; no saved reviewer verdict/contract. The
   current precheck sh:28–35 accepts edit-summary/reset only, not recovery;
   sh:369–372 requires a NEEDS_WORK predecessor for advance, 394–397 requires
   PASS/BLOCKED for reset. No unchanged failure was rerun.
4. More importantly, guard-role-read live requirements/acceptance differ from
   that round's pins. Requirements live
   `bd5434d414bffa1344a4249c56b325fbd8a22322c12bb5eb91cc49cf429ab672`
   versus precheck `4683d30289101edd00c1d0399c01e7275975f2be12ccfaf1f39cb3c6dc3e4358`;
   acceptance live `05423a3aedc0914406f33708d2e78b3eda2b64bc57c1c75fe21e8b90b3d10095`
   versus precheck `4d6d475ba78ee3d8f8298080b7259cf07fbdf6784c36071f26857511333e48c4`.
   Do not alter old pins or restore older specs to escape the boundary.

## Can the existing fresh recovery be reused?

Not as an executable recovery of the current amended read policy. The proposed
`contracts/spec-review-prelaunch-recovery.v1.data-contract.md` remains Draft,
the precheck has no recovery implementation, and that proposal deliberately
requires unchanged live source pins (requirements REQ-004/AC-006;
acceptance-tests TEST-006). Therefore even completing that proposal unchanged
would reject the current input mismatch. This is a material contract gap, not
missing repeated user approval. Root must reconcile the changed-input case
through the established specification workflow, preserving the old round and
human authorization; do not silently broaden recovery or manufacture a verdict.

The separate `spec-review-prelaunch-recovery` specification itself has only an
existing attempt-1/round-1 precheck in its round inventory. Its live requirements
`0292973fba72eb5dbd23114a1012607f06ffd66a064f8ebff24d577bc0c40c90`, acceptance
`d664997d9fc9fbebbcde8a216525f23418434cee00072a860a37f9303b25de66`, and calibration
`537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385` match its precheck.
This is a potentially resumable REVIEW lane after consumer consistency and
host/identity checks, not an Approved implementation task. Round inventory alone
does not prove absence of opaque identity-ledger attribution; validate the whole
ledger and relevant receipt history before any new reservation.

## Plan to present before any new reservation

1. Root resolves the existing eight-file manifest-consumer repair via its normal
   protected route and verifies the existing targeted boundary/spec-loop and
   runtime-parity positive/negative tests. No gate bypass or alternative executor.
2. Root reconciles the recovery specification's unchanged-input constraint with
   the actually amended read-policy inputs. If amended, obtain a legal current
   precheck for those bytes rather than reusing the stale precheck above.
3. Only after these checks select the normal host. A dated Claude allocation
   refusal in `spec-review-prelaunch-recovery-native-allocation-20261004.md` says
   this canonical workspace was untrusted. This turn did not probe or alter trust;
   success in another worktree does not establish trust here. No --print/trust
   file workaround and no replacement host solely to evade that refusal.
4. Fresh empty idle allocation, exact host receipt, current ordered canonical
   manifest, then one reservation and exact REVIEW_CONTEXT_OK before first turn.
   Ship manifest and receipt as complete bounded structured messages over the
   host's normal non-TTY transport, not a long pasted terminal command. Before
   dispatch require parsed full JSON, byte-length/hash agreement at sender and
   transport, exact reserved role/run/session IDs, all allowed-input hashes and
   precheck pins, and recomputation of the spec allowed-inputs-v1 receipt digest.
   Preserve the full request/result envelopes after secret-key filtering, before
   summaries; correlate RPC allocation responses separately from tool events.
5. A reviewer may read only manifest entries and must not rehash the post-append
   ledger. Use the exact permitted hash tool `rtk proxy shasum -a 256 -- <path>`;
   verify host tool grants before reservation, no sha256sum substitution. The
   in-memory receipt-hash method must also be actually admitted; arbitrary node -e
   is not presumed allowed. No evaluator write canary. Delivery/tool agreement is
   still UNVERIFIED for this spec host, not proved by the A8 synthetic controller's
   14 PASS. Reviewer B receives only sanitized check IDs/counts/severities from A.

Reservation and launch remain withheld for the above concrete conditions.
No new model/cost identity values, synthetic approvals or review verdicts were made.
