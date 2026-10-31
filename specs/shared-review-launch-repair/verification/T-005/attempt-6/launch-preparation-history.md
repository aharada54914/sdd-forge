# Launch preparation history — not test proof

This note records earlier tool results in this same conversation. It is a transcript-derived history note, not a newly executed command log. No refused command was retried before explicit parent repair and authorization.

The original Python here-document was stopped by zsh before Python executed, with exit code 1:

```text
zsh:1: can't create temp file for here document: operation not permitted
```

Work stopped at that refusal. The user then authorized named-variable-only diagnostics. The `printenv TMPDIR TMP TEMP TMPPREFIX` probe did not establish the unexported shell variable. The subsequent `typeset -p TMPPREFIX TMPDIR TMP TEMP` probe showed shell TMPPREFIX `/tmp/zsh`, while TMPDIR/TMP/TEMP pointed to this attempt's output/tmp.

The parent then set TMPPREFIX in the child and shell environment policy to `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge/handoffs/shared-review-launch-repair-T-005-attempt-6/output/tmp/zsh`, without expanding sandbox permissions. The authorized builtin diagnostic confirmed the corrected variables; the authorized Python here-document printed:

```text
TMP_PREFIX_HEREDOC_OK
```

That diagnostic exited 0. The user explicitly authorized continuation of the original bounded revalidation afterward. The refusal and diagnostic are retained as history; neither is a regression result, native model launch proof, or a formal review verdict. Fresh regression execution records begin with `prepare-fixture.json` and the named suite JSON/log pairs in this directory. `environment-versions.log` independently records the currently observed four temporary variables.

Historical attempt 2's RED, two implementation iterations, rollback and reapply are described only by the manifest-bound historical report. They were not repeated or relabeled in attempt 6. The historical report remains byte-identical. Historical attempt 3's mode-copy failure and previous attempt failures remain historical user-supplied context; their external logs were not read or promoted. No attempt 4 or 5 evidence was rewritten.
