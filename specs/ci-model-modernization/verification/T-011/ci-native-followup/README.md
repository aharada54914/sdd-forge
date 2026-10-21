# T-011 shared CI failure corrections

The Windows cloud and capability job steps failed in hosted run 39598838307. Authorized log and receipt downloads returned HTTP 403, so this record does not claim that local findings are the exhaustive hosted causes.

The exact original source hashes match the hosted e845fbc8 commit. Locally, the foundation suite reproduced three stale inventory failures and one invalid synthetic planner fixture error. The Bash and PowerShell ship migration suites each reproduced three failures because the current managed dispatch differed from the historical staged ship file.

The current inventory now resolves the original keywords inside named sections. The foundation coverage check preserves the planner and verifies the actual cloud-native job, including removal-of-execution detection. Historical inventory and staged snapshots remain unchanged.

The successor fixture separately pins both historical predecessor paths and the full current ship bytes. The predecessor bytes are identical; track-selection, handshake, and capability-scope contract blocks are unchanged. The original full-file equality path and pair-consistency checks remain. Successor acceptance is exact and rejects changed/missing predecessors, unknown live changes, altered contract markers, absent/stale/malformed baselines, duplicate pairs, case mismatches, and half-published states. Each twin includes mutations and a restoration control. This is a regression baseline for the scoped managed dispatch change, not publication authorization or a quality-gate verdict.

Root-applied verification passed: foundation 54 tests, Bash ship migration 161 assertions, and Linux PowerShell ship migration 167 assertions. Replacing the four candidate files with original bytes reproduced all original failures; restoration was byte-exact. Source pins, combined public logs, rollback results, contract hashes, and actual Claude coding provenance accompany this note. Native Windows/macOS verification and the final release gate remain separate.
