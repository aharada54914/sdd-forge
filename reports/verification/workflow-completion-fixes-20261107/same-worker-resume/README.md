# Same task worker resume (#745)

The original SQLite T-003 report is unchanged (SHA256 `5bb928bbee3b1ed5ee165c912393739d01b1a8d606d2cdf0b037f8371836f2d6`). The installed validator rejects its truthful account-limit resume narrative; the corrected source accepts it. `actual-before-after.json` records both invocations, exits, source hashes and the observed native worker identity.

The report guard now distinguishes affirmative orchestrator implementation takeover from interruption/resumption of an independent task worker. It does not establish identity from prose: canonical manifest and identity validation remain responsible for that boundary. Existing WFI044 takeover rejection is retained, with 12 additional positive/negative controls including negation, citation, passive takeover and contradictory continuity claims.

`results.json` lists verification commands and logs. Turn-first tests pass; Bash template suite passes 25 checks and PowerShell template suite passes 18. Both hosts exercise the shared Bash/Python implementation-report validator; there is no PowerShell validator twin. Human-copy mirror check passes without mirror changes. Native Windows PowerShell 5.1 was not tested. The global plugin cache was not changed by this repair.

## Related RED proof guidance (#734)

The final source also adds documentation to implement-task step 3 and the report's Test Evidence section. Bootstrap requires an actual pre-implementation failing-test commit, but the implementation guidance previously described only saving run logs. Authors now receive instructions to save read-only scoped Git tree/blob, ancestry and execution-revision evidence, declare its exact hashes and include it in fixed evaluator inputs. This grants no commit authority and allows pre-existing other-task code. The template suites were rerun successfully after this prose addition; source-hashes.json reflects the final documents. No additional validator or runtime was introduced. This closes a guidance gap, not a demonstrated guarantee of compliance by future sessions.
