# RT004 outer Bash snapshot continuity — required source evidence

Status: blocked on human source inspection, not on another identical RED run.

The composed Bash patch validates private snapshots inside
workflow_adr_history_bindings, returns only ADR bindings and cleans snapshots
on helper exit. Its outer hunk then continues with the original contract and
reviewer paths. The known caller continuity gap is also explicitly retained
in rt004-bash-snapshot-composition-20260909.md. PowerShell's composed patch
instead passes the verified objects to subsequent stage checks. No claim of
runtime safety or complete parity is made for either unapplied patch.

The new interrupted-output RED is already complete (14/104, exit 1); repeating
it unchanged cannot close this gap. Existing candidate check-count and verdict
validation addresses those incomplete outputs statically, but candidate GREEN
must wait for complete integration and authorized application.

An earlier source search for stage/opening/cleanup sites was rejected, as
recorded in rt004-output-binding-handoff-20260909.json. Do not retry this
inspection through another agent, executor, renamed file or plugin cache.
The human can supply the original outer function and caller context using:

```bash
cd /Users/jrmag/sdd-forge || exit 1
/bin/bash <<'BASH'
set -eu
source_file='plugins/sdd-quality-loop/scripts/check-workflow-state.sh'
/usr/bin/shasum -a 256 "$source_file"
/usr/bin/sed -n '700,1020p' "$source_file"
/usr/bin/shasum -a 256 "$source_file"
printf '\nRead-only source collection complete. Send all output to Codex.\n'
BASH
```

This only reads the existing source. It performs no patch application, evidence
changes, commit, push or merge. Matching before/after hashes help identify the
source inspected but do not establish atomic acquisition. If the requested
range omits a needed caller, request that exact missing context separately.

Next: use the supplied source to design lifecycle-safe snapshot ownership for
the entire outer stage, preserving every opening branch, legacy behavior,
exit/cleanup rule and manifest path interpretation. Review the candidate
independently before human protected application. No success is inferred from
the patch's parse-only numstat results.
