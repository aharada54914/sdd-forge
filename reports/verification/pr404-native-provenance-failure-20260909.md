# PR404: native Ubuntu provenance failure

Head: e1e019be691b40dcb292fa16c3fb14f578d4433f.
Run: 34288587300. Job: 102269800600.
Checkout merge recorded in raw log: 5729fb5392975429a31c159e0beb39bff2874ac8.

The completed job logs API reports at 2026-09-08T23:00:20.0939687Z:

    workflow-state: epic-195-a7-compatibility: stage-provenance: implementation design hash is stale

The following error reports exit 1. Earlier investigation.md amendment-growth
messages explicitly say tolerated and are not the failing condition. Generated
guard/capability checks and vendored-registry checks completed before this step.
The full CI run remains active; this is one completed job, not a full result.

Three-dot design diff against main4366438 changes External Integrations from
internal-only to a sanctioned T-012 live-model refresh exception (21 additional
lines). The failure is consistent with a changed hash-bound implementation
design, rather than a platform timing boundary or fixture process hang.
Current validator source check-workflow-state.ps1:1345 emits this exact error.

Required resolution: preserve the approved live integration meaning and old
review records, reconcile sibling declarations, then perform the authorized
new formal provenance review on the exact integrated artifacts. Do not alter
old hashes, claim PASS, revert the authorized requirement merely to turn CI
green, or weaken the stale-design check. Local recovery work is not included
in this remote head. Repair attempts in this investigation: zero.
