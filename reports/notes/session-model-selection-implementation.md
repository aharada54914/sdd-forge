# Session model selection implementation

Date: 2026-11-15 UTC
Run ID: work-session-model-selection-20261115
Task Attempt Count: 1
Status: implemented and independently reviewed under the authorized development workflow; not a consumer SDD Done verdict

## Development authorization

The user explicitly authorized local development skills, independent review and tests
instead of the normal consumer SDD approval workflow for this Work session after
both the hook canary and Project Context key dependency were diagnosed. No native
runtime attestation, Project Context approval or review PASS was fabricated.
The original requirements are preserved in session-model-selection-readiness.md.

## Changes

- Project-private preferences, separate per-host main settings, per-role choices,
  supported effort choices, disabled optional roles, explicit session confirmation.
- Startup context hooks for Claude/Codex, a Gemini model-selection extension,
  bootstrap/ship fallback, and manual selection/reselection commands.
- Honest listed/unverified candidates; Codex documented discovery reused; no
  inference calls, credential-file reads or automatic login during discovery.
- Confirmed preferences bridge to pinned policy requests, isolated Codex reviewers,
  and the unchanged vendor panelist collection boundaries.
- Gemini install/uninstall registration parity and public JSON schema/ADR/user guide.

## Material limits

Main model switching uses the native CLI UI and explicit user acknowledgment.
A saved preference is never a proof of model delivery or inference access.
No generic Gemini independent-review adapter exists; unsupported routes stop and
require reselection rather than bypassing isolation. Claude/Gemini CLI binaries
are absent here, so their live startup and model execution remain unverified.

## Verification

| Check | Result |
|---|---|
| New session model suite (including real Bash/PowerShell installers with fake Gemini and actual PowerShell session bridge) | 40 passed |
| Existing Codex review launcher suite | 20 passed, 1 opt-in native permissions test skipped |
| Existing model policy selection suite | 62 passed |
| Existing model policy launch suite | 57 passed |
| Packaged selector parity suite | 8 passed |
| Full Bash installer regression | 79 assertions passed |
| Install/uninstall runtime matrix | 20 assertions passed |
| Existing uninstaller suite | 25 assertions passed |
| Existing installer idempotency suite | 7 assertions passed |
| Existing cross-model suite | 84 assertions passed plus its embedded Python checks |
| Ship track migration suite | 164 assertions passed |
| Mirror freshness/classification | passed, pending predecessor candidates preserved |
| Verification catalog suite | 14 passed, 1 environment-specific check skipped |
| Python compilation, Bash and PowerShell parsing, diff whitespace check | passed |

The first package/policy attempt lacked a configured PowerShell binary; rerunning
with the required local wrapper succeeded. The initial install check used the
host's Node 24 and correctly rejected its existing Node >=26.13 prerequisite.
A temporary official Node 26.13.0 distribution, verified against the official
SHA-256 manifest, was used for installer regression checks. These dependency
checks were not weakened. Existing installer expected dependency closures were
updated to include the newly required picker plugin for standalone bootstrap.
The final full installer regression completed with 79 assertions passed and zero failures.

Read-only live discovery was also run from the isolated verification workspace
with the verify profile's CODEX_HOME. Codex model/list returned 11 models;
Claude and Gemini correctly reported their absent CLI binaries. No inference,
login, model switch or native startup-hook activation was claimed from this check.

## Independent review and corrections

Read-only reviewer: `/root/design_review`, separate from the implementation author.
This is development code review, not a canonical consumer SDD review verdict.
Initial review found single-CLI confirmation deadlock, ambiguous headless startup
instructions, missing entry fallback, mismatched Gemini registration scope,
argparse option abbreviation breaking forwarded --model, and incomplete bootstrap
dependency closure. All were corrected and covered by relevant tests. Later review
confirmed the fixes and found no new major code defect. Its remaining recommendations
were adopted: resolve skills through the active host registry rather than guessing
cache paths, and require the panelist bridge in the installer payload closure.

Author review additionally rejected duplicate wrapper-owned vendor/shell controls
before forwarding collector arguments; its Bash CLI regression prevents replacing
the GPT wrapper's vendor. Persisted catalogs and confirmation records now fail
closed when malformed. Private preferences never become launch observations.

## Verification limits

No real Claude/Gemini CLI startup or inference was run because their binaries are
absent. Native model delivery and the host's main-model switch remain outside the
fixture proof. The opt-in native permissions canary was not rerun. Ruff is not
installed in this environment; no lint result is claimed. No release or merge was
performed. Existing consumer guard and approval mechanisms remain unchanged.

Final targeted independent review found no new Critical/Major finding. It separately
verified that both frozen ship predecessor mirrors and manifests exactly match the
task base. Only the permitted current-publication fixture's live hashes and change
notes were extended; historical predecessor bytes remain unchanged. The final
mirror freshness and ship-track migration checks passed.
