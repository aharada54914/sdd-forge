# Issue 290: available Codex model registration proposal

Status: investigation only; no model registry, reviewer role, reservation, or
review result changed. The user has authorized Sol/Luna use and limited repair.
This note separates verified host capability from a repository policy choice.

Supersession (2026-10-03): the initial proposal above is retained as history.
The primary orchestrator subsequently explicitly adopted standard as the
operational policy classification under the user's Sol delegation authority,
and authorized the minimal patch. The patch and verification below supersede
the initial investigation-only status and unresolved policy wording.

## Applied result and verification

- Appended only the Sol model row to the v2 registry and added dated provenance
  to its adjacent Markdown record; added `tests/sol-model-registration.tests.py`.
  No selector, role, hook, v1, old model row, fallback, risk matrix or
  role-default edits were made. A structural comparison against HEAD confirmed
  the v2 object is identical after removing its newly appended Sol row; v1
  bytes also equal HEAD. No guarded-write denial occurred for these edits.
- Focused regression: `rtk proxy python3 tests/sol-model-registration.tests.py`
  exited 0, 3 tests PASS including native shell and PowerShell selector paths.
  Exact registration, medium/high requested effort, unavailable candidate,
  strong-tier rejection and xhigh-without-reason rejection were exercised.
  Initially direct-only; the subsequent integration below supersedes that state.
- `rtk proxy bash tests/agent-capabilities-v2.tests.sh`: exit 0, 10 PASS / 0 FAIL.
- `rtk proxy pwsh -NoProfile -File tests/agent-capabilities-v2.tests.ps1`:
  exit 0, 14 PASS / 0 FAIL.
- `rtk proxy bash tests/agent-model-routing.tests.sh`: exit 0; final output
  `ok: turn-first model routing structure is defined` (includes PowerShell
  selector checks on this host).
- `rtk proxy bash tests/render-agent-frontmatter.tests.sh`: exit 0,
  23 PASS / 0 FAIL.
- `rtk proxy pwsh -NoProfile -File tests/render-agent-frontmatter.tests.ps1`:
  exit 0, 27 PASS / 0 FAIL.
- `rtk proxy bash render-agent-frontmatter.sh --check` before and after the
  registry patch: exit 0, 10 targets / 0 drift both times. No renderer writes.
- `rtk proxy git diff --check`: exit 0.

This is local registration/regression evidence, not formal review PASS.
CLI update completion and a fresh native model/list are still required before
the two-stage launch. No new reviewer identity has been reserved or used.

Automatic regression integration: `tests/agent-capabilities-v2.tests.sh` now
invokes the focused Python suite and incorporates its exit status. The existing
CI job already runs that shell suite (`.github/workflows/test.yml:502`), and the
POSIX run-all inventory includes it (`tests/suite-inventory.posix:31`). Thus no
workflow, inventory, or role change was required. The connected shell suite
was rerun successfully: 11 PASS / 0 FAIL, including the 3 focused tests.

## Verified host data

On 2026-10-03 the native `codex app-server --stdio` was initialized and queried
only with `model/list` (`includeHidden: true`, `limit: 100`). The successful
response had `nextCursor: null`. No thread or model turn was created.

The exact available model `gpt-5.6-sol` has description
`Older generation workhorse model.`, `defaultReasoningEffort: low`, and
supported reasoning efforts `low`, `medium`, `high`, `xhigh`, `max`, `ultra`.
The catalog also contains `gpt-5.6-luna`, whose default is `medium` and supported
efforts are `low`, `medium`, `high`, `xhigh`, `max`. Neither name exactly matches
a current checked-in OpenAI model name. These are availability/effort facts,
not a vendor assertion of SDD tier equivalence.

The inspected native schemas support empty `thread/start` with read-only
sandbox, no model fallback, and developer instructions, followed separately by
`turn/start` carrying `threadId` and first input. The prospective order is:
create independent empty thread -> receive actual ID -> reserve that unused ID
once -> submit first review input. This was not exercised. Full launch context,
hook compatibility, and identity binding remain prelaunch requirements.
See the round-local `reviewer-launch-compatibility-diagnostic-20261003.md`.

## Source of truth and classification boundary

- `PLUGIN-CONTRACTS.md:279-295` identifies the v2 JSON contract and consumers;
  v1 remains frozen. The live selector still defaults its registry path to v1
  (`plugins/sdd-implementation/scripts/select-agent-model.sh:10`), so this
  proposed route must explicitly pass the v2 registry; no default migration.
- `docs/adr/0003-turn-first-agent-routing.md:25-39` gives tier mappings and
  requires reviewers to use at least standard. It does not classify Sol/Luna.
- `docs/adr/0012-effort-tier-decoupling.md:87-101` preserves tier independently
  of effort. Supporting high/xhigh is not evidence that Sol is strong.
- `contracts/agent-model-capabilities.v2.md:99-104` explicitly says its previous
  generation labels/tier assignments were not independently live-verified.
  They must not be transferred to Sol based on a similar version/name.
- `PLUGIN-CONTRACTS.md:338-358` restricts the registry effort vocabulary to
  low/medium/high/xhigh. The extra host efforts max/ultra are not registered
  without a separate schema change.

The unresolved classification is a policy decision: explicitly adopt
`openai/gpt-5.6-sol` as standard for the user-selected independent reviewer
route, or obtain another authoritative classification. Calling it standard
must be recorded as that decision, not as measured equivalence or a model/list
field. This proposal does not classify it strong or qualify it as Done evaluator.

## Minimal conditional patch

Once that classification is recorded, append one entry to
`contracts/agent-model-capabilities.v2.json`:

```json
{
  "name": "openai/gpt-5.6-sol",
  "canonical_tier": "standard",
  "supported_efforts": ["low", "medium", "high", "xhigh"],
  "default_effort": "low",
  "effort_control": {"claude-code": "none", "codex-cli": "flag"}
}
```

`flag` denotes host-applicable effort control in the existing schema, not an
assertion that a literal `--effort` CLI switch exists. Native turn `effort` is
the inspected invocation surface. The review must explicitly request at least
the task-reviewer role's medium effort (high is available); it must not
silently inherit the model's low default. xhigh remains reason-gated.

Append confirmation/provenance to the adjacent v2 Markdown record, retaining
its dated history. Add focused regression coverage for the exact new entry.
Leave v1, all old model rows, fallback designations, role_defaults, risk matrix,
selector defaults, protected reviewer roles, and frozen feature inputs intact.
Do not add Luna until its independent classification is established.

There is no registry generator to run for an appended row in this contract.
`render-agent-frontmatter` consumes role_defaults and the first matching model
(`PLUGIN-CONTRACTS.md:374-408`); appending rather than prepending leaves that
selection unchanged. Do not rewrite generated/protected role files. Its
read-only `--check` is appropriate for regression comparison.

## Required regression before launch

1. Focused assertions: exact new model name, approved standard tier, catalog
   effort intersection/default, both host controls; no old-row/role-default/
   risk-matrix changes and unchanged v1 bytes.
2. Explicit-v2 selection with task-reviewer minimum standard and requested
   medium/high selects the available exact Sol ID and reports requested effort.
   Unavailable Sol fails closed; required strong does not admit Sol; xhigh
   without reason remains rejected. Exercise shell and PowerShell twins when
   available, without weakening old expected outcomes.
3. Existing `tests/agent-capabilities-v2.tests.sh`/`.ps1`,
   `tests/agent-model-routing.tests.sh` (including its PowerShell checks), and
   `tests/render-agent-frontmatter.tests.sh`/`.ps1`; run renderer `--check`
   before/after and distinguish any pre-existing drift.
4. Fresh native catalog confirmation, configured model fallback disabled,
   actual thread identity receipt, immediate task precheck `--verify-inputs`,
   then one canonical reservation. Only after these may A receive review input.

These regressions are proposed, not executed or reported PASS here. Existing
1207-1209 outputs/reservations remain unadopted and preserved. No new formal A,
B, counts-only summary, integration, or workflow-state success is claimed.
