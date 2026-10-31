# Proposed Changes: specification review attempt 2 round 1

- Extend REQ-005 and AC-013 so TEST-013 injects a rename failure after a known
  inventory index in an isolated, fixture-instrumented runner.
- Require the observable failure state to be exactly the new candidate prefix
  followed by the previous live suffix, with exit 2 and no outside-alias write.
- Require a reviewed complete rollback batch to restore every target to its
  recorded pre-install digest and pass post-install verification.
