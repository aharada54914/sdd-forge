# Project skill acceptance follow-up

## Project skill acceptance follow-up — 2026-10-31

Observation v3 binds actual runtime bytes, declared tools, runner/validators,
execution environment and executable permission bits. Historical v1/v2
observations remain readable but cannot supply current execution fields.
Manifest v2 adds document procedures without a fictitious command:
creation remains draft and execution remains not-run. Maintenance now lists
unexecuted check IDs and the indexed features mapped to them, including missing
runtime and document-only cases.

Current local checks: lifecycle 43, observation 40, profiles 5 and collector 21 passed.
An independent review reproduced both multiple-document-check and missing-runtime
diagnostics. Actual HTTP route/auth repair and product regression behavior is in
[maintenance follow-up](../../reports/verification/project-maintenance-behavior-followup-20261031/README.md);
the original red diagnostic evidence is preserved separately. The Git/SQLite/CSV
profiles and network migration dry-run exercise real operations; the original
SQLite database remains byte-identical after successful and failed dry-runs.

[Owner connectivity](../../reports/verification/project-observation-owner-evaluation-20261031/README.md)
records real runner-to-collector-to-selected-plan and POSIX/PowerShell Lite
execution. Its other baseline evidence is synthetic; it does not certify a real
Full project approval or native Windows/macOS. Each packet records its own tested
source, rather than claiming historical observations cover later source changes.

After official user login, [Codex native execution](../../reports/verification/codex-project-skill-native-20261031/README.md)
and [Copilot native execution](../../reports/verification/copilot-project-skill-v3-native-20261031/README.md)
passed on source `b3b997ed`: discovery of the generated wrapper, invocation of
the same canonical synthetic check, exactly one documented runner execution,
and actual reading of its v3 owner observation and stdout. Temporary paths and
host projection locations differ; the procedure and expected marker are shared.
Earlier authentication and permission failures remain separate evidence.
Revalidation from a different collector environment correctly refused the
observations because the environment fingerprint changed; that projection is
not counted as successful.

Claude invocation remains pending. These bounded native fixture results do not
establish full application acceptance, cross-host model equivalence, or trusted
human-input issuance. The native human-verification provider needed for #616
remains unavailable; successful account login does not supply that capability.
