# RT004 ADR binding: scope correction and concrete Bash candidate

The previous goal turn produced a new initial-open diagnostic (4 controls pass,
4 deliberately scheduled substitutions fail). It did not fix ADR admission.
The user's objection led to the scope correction at the top of ADR0034.
Independent reviewer `rt004_snapshot_static_review` found the correction
consistent with the original ticket, provided launch-time/downstream checks and
post-precheck ADR change rejection remain required. This is advisory review,
not a formal gate verdict.

The new diagnostic is now opt-in (`--initial-open-only`), with unchanged
expectations and its historical failures preserved. The inherited default
admission/history/JSON/path cases remain unchanged. Observed symlink rejection
is not a concurrency guarantee. No native ACL/handle backend is claimed.

DATA candidate: `rt004-adr-binding-bash-20260911.patch`.
`rtk proxy git apply --recount --check reports/verification/rt004-adr-binding-bash-20260911.patch`
exited 0 after correcting context in the initially inapplicable draft.
No candidate was executed or applied to the product.

The candidate orders impl non-ADR entries before ADRs. The unchanged input loop
hash-checks and captures design/precheck bytes before a complete-set binding
function can authorize an ADR. The function checks extension structure, exact
feature/attempt/round path, raw design pin, restricted inline declarations,
unique sorted ADR paths and matching invocation pins. Missing invocation ADRs
do not skip extension validation. Absent extensions preserve legacy authority.
ADR entries still traverse existing canonical/exact-name/no-link/regular-file
and SHA checks. No temporary executable or weaker parser is introduced.

The previous full original-path run (session90797) remains RED:348pass/64fail.
No prediction of repaired test counts is made. Independent security review of
the concrete Bash diff was requested before protected application. PowerShell
binding and actual original-path re-verification remain to do. Original-path
tests must follow application, not be replaced by execution of copied scripts.

Fresh GitHub check:11open PRs, zero queued/in-progress CheckRuns. Failure counts:
404/402/401/371=4each;394/390=2each;381=11. 405/403/245 conflict.
PR400 has no failing checks but retains the documented formal-entry dependency;
this status alone is not permission to ignore that dependency or manufacture
its evidence. No CI dispatch, commit, push, merge or issue closure this step.
