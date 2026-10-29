# Actual authenticated Codex custom-skill invocation

The owner completed the official device-auth flow. The new credential was
created in a separate local native profile; the host runtime credential was
neither inspected nor overwritten. An explicit local preference now directs
the development and verification profiles to that credential by symlink. The
local auth-sync helper has 18 passing tests, including preference persistence,
missing-preference refusal and profile-cycle rejection. The supported account
probe reports `account_api_verified` for both profiles. A separate actual native
model turn completed with `NATIVE_AUTH_OK`; login status alone was not used as
model proof. Credentials and native profile state are not included here.

The existing isolated verification profile then exercised the real product
seal/project commands. Native skills/list found exactly the generated wrapper.
An actual Codex model turn explicitly invoked `$inspect-issue-602-fixture`, read
the note and quoted its complete actual sentence. The native trace is retained.
All fixture bytes remained unchanged; cleanup restored the workspace entries,
and native discovery confirmed the custom wrapper was absent afterward.

`result.json` binds the product scripts, generated wrapper and helper hashes,
actual command results, model completion and cleanup checks. Original discovery
evidence from 2026-10-25 remains unchanged. This closes the previously
authentication-blocked local Codex invocation observation. It does not establish
Claude/Copilot behavior, protected human-input issuance or general project-skill
quality; no such success is claimed.
