# Independent current configuration review

[The source-bound ledger](independent-config-review.json) covers all 258 intake current-config entries plus 23 active structured inputs identified by the research scope corrections. Each path has its actual byte hash and parsed root fields. This independently checks coding-standard applicability at configuration/data boundaries; it does not replay or newly approve historical findings or signed decisions.

JSON duplicate keys were rejected while parsing all 258 files; YAML/TOML parsed with their native data loaders. Forty-two root/vendored JSON schemas passed metaschema validation, and all 176 local `$ref` JSON Pointers resolved. Five live-policy documents passed their schemas. All three registry/guard generators' `--check` commands succeeded, capability validation passed ten checks, and all five A8 hook digest entries matched current bytes. These checks support the following contextual decisions; parse success alone is not the semantic judgment.

## Rule applicability

CS-001/002/005/009/019 apply to executable commands embedded in workflows/hooks/package scripts; they are literal programs with input data crossing args/env, reviewed with actual consumers. CS-004/007/008/010 apply to structured fields, regex patterns, path/URL references, public hashes/signatures and secret references. CS-011–017 apply to policy ownership, canonical/vendored provenance and distinct strict/history consumers. CS-018/021–024 apply at the consuming program, not as hypothetical exceptions/Promises in JSON. CS-025/026 preserve exact schema tokens, pattern semantics and UTF-8/canonical bytes. CS-027–030 require distinguishing archived outcomes, candidate scaffolds, observed results and current gate policy. No SQL or dynamic HTML execution surface is introduced by these data files. PowerShell-specific executable behavior remains with the shell lane.

## plugin-discovery

Twenty-one plugin manifests and two marketplace files name local plugin paths, versions and runtime-specific hooks/skills. They are discovery metadata consumed by installers/hosts, not source interpolation templates. Claude's hooks reference its exec-form config; Codex and generic manifests keep their own host contracts. Fixed relative paths do not introduce arbitrary command fields. Existing manifest/installer tests establish packaging; host activation is not inferred from JSON presence.

## agent-config

Four TOML agent profiles parse as data. Their developer instruction strings are product artifacts, not authority for this audit. Read-only sandbox and role/model metadata are explicit; prose examples of shell commands are not executed by TOML parsing. These files do not themselves attest independent model execution or authorize this reviewer to launch agents.

## workflow-config

Five active workflow files and one staging candidate were parsed to enumerate every job/step and all `${{ }}` expressions inside run bodies. Direct expressions are trusted runner.temp, closed matrix values, or GitHub job-result enums/boolean active output; event/ref/token values otherwise cross env or action input fields. All run nodes are strings. Context approval is manual, checks environment protection before signing, checks out an immutable reviewed commit, checks the candidate digest and only exports public artifacts. The staging candidate is not an installed workflow.

Executable pipeline/process semantics are separately owned by the root/shell review, not certified by this structural expression pass. During reconciliation that review identified the self-improvement Enforce guard pipeline's missing pipefail under implicit GitHub bash; the shell lane owns its correction and regression. Do not use this record's configuration review to waive that finding or the required CI outcomes.

## schemas

Forty-two JSON Schemas have valid schema grammar and resolvable local references. Required fields, enum/const tokens, object bounds and conditional branches describe structured contracts; they are not executable shell/SQL/HTML. Existing contract-specific validators/tests enforce domain constraints beyond schema expressiveness (for example sibling citation bounds, evidence provenance, path containment and case-sensitive approvals). Root and packaged schemas remain canonical/mirror-related; they are not consolidated merely because some definitions resemble one another. This review does not change tolerated legacy fields or claim metaschema validation proves every business invariant.

## registry-policy

Thirteen tables/scaffolds define model effort capabilities, capability gates, Lite checks/reasons, provider contamination vocabulary, guard constants, read-only Python input contracts and generated gate metadata. Installed consumers validate names/allowed values and dispatch fixed registered programs, not arbitrary strings as code. The readonly-input list only grants exemptions to three named parser contracts with bounded option lists; unknown/unmatched inputs gain no exemption. Provider names are detection vocabulary, not cloud routing configuration. The project-context template is explicitly generic/advisory and empty components, not a live activation. Canonical/vendored equality and generated outputs were checked through existing producer commands.

## package-config

Twelve package/lock/compiler files preserve existing scripts and strict source compiler settings. Build commands bundle the fixed src entry; test commands compile and enumerate actual test files. Lockfiles pin installed dependency resolution; they do not embed a new lifecycle script or inline user data. TypeScript7/Node>=22.19 compatibility belongs to the actual installed compiler/CI checks. Test tsconfigs retain their existing separate settings; no rule was relaxed to obtain green.

## dependency-policy

Dependabot contains four declared ecosystem roots and a fixed recurring schedule. It opens update PRs under configured limits; it does not merge or install generated code during this review. Version freshness/security is not established solely by this config.

## branch-policy

The ruleset requires pull-request approval and required-checks plus no deletion/non-fast-forward. Its repository-role bypass is explicit policy, not a new audit exemption. Local JSON is not evidence that GitHub has applied the ruleset; application/remote verification is owned by the branch-protection workflow.

## hook-launch

Three configs distinguish Claude argv-based Node hooks, Codex POSIX/Windows command forms and Copilot platform bodies. Root values are quoted; the Copilot bodies check guard existence and emit structured deny on missing root/script before dispatch. Hook stderr/stdout and timeout conventions are host-specific; they are not merged into one fictional contract. The exact config bytes match A8 digests; executable bodies remain additionally covered by shell/TS tests and actual host evidence.

## proof-policy

A8 trusted signers, skip allowlist and expected-digest manifest are public trust metadata. An empty signer map does not trust everyone: `validate-live-host-proof.py:255` rejects missing/wrong-role signers. Skip entries name bounded cases and upstream path/blob fingerprints; they are not blanket passing results. Manifest paths/hashes are validated by the consumer and all five expected hashes matched the shipped config bytes. No secret private key is present or needed for this hash check.

## context-workflow-policy

Seven files include live/approved Context, approver registry, approval sidecar, advisory request, the formal candidate and workflow-state registry. Current/approved/candidate Context, approver registry and workflow-state registry passed their respective schema checks. Canonical live Context digest matches the sidecar's context_sha256; this does **not** verify the HMAC without the independent signing key. Candidate/advisory data is not promoted to enforcement. The workflow registry remains live policy with bounded legacy entries, owners and reasons; directory age does not exclude it from review.

## pinned-signing-packet

Twenty-one JSON/YAML packet files remain active referenced structured inputs, including candidate, registry, source-binding and execution records. The context-approval workflow reads the reviewed packet from a fixed Git commit and verifies the candidate digest before signing; current archive filenames are not substituted for that immutable source. Draft contracts and execution records describe their captured scope; no verdict is rewritten into fresh evidence. Packet logs/prose companions retain historical evidence roles under scope-review.

## review-tickets

All 59 YAML ticket records have nonempty string ticket_id/status/severity required by the actual read-only MCP parser; varying optional resolution/review metadata remain supported records. The parser validates the ticket ID and maps only consumed fields rather than evaluating `expected_fix` or prose references as commands. Ticket status is a historical/current workflow fact, not a result manufactured by this audit.

## wfi-records

Seventy JSON WFI audit/summary records contain explicit check IDs, cycles, verdicts and counts. Structured key families were enumerated, including earlier blocked/revision attempts. These records are consumed as evidence by WFI workflows; command examples are data, and old FAIL/NEEDS_REVISION outcomes are retained. No default PASS replacement or new runtime renderer is present in these files.

## historical-handoffs

Seven handoff manifests bind task/run identity and input/output paths with hashes. They are not live generic agent configuration: costs/models/timestamps are explicitly their recorded runs. Blank fallback/reload fields in an old fresh-agent record are not credentials or permission to skip a current isolation check. Their hash pins must not be regenerated to make historical claims match current source.

## golden-data

Eight expected JSON fixtures are recorded shell comparison results consumed by the explicit golden harness. They contain feature, exit code and own-failure messages, not executable commands. Current test runs compare against these preserved historical records; regeneration is an explicit separate maintenance action. They remain test data, even though the original census called them config.

## rollback-policy

The 1.5.0 rollback manifest is historical **executable policy**: rollback scripts validate pinned release/baseline identity, allowed paths and old/new hashes before changing anything. It is therefore reviewed as an input rather than silently excluded. Its hashes describe immutable release versions and must not be replaced with today's source hashes. No rollback action was executed during this audit.

## Independent classification conclusions

The research correction is substantiated: workflow-state registry, formal candidate and pinned signing packet have current consumers. Copied workflow-state-integrity and compatibility golden trees are actual test inputs, whose originals stay immutable. Their classification must follow that consumer relationship rather than filename age. Template DOC-001/DOC-002 fixes retain failure/pending outcomes and literal YAML shell body semantics; they do not turn scaffold parse success into full target-project verification.

No additional configuration defect was confirmed by this pass. The separately confirmed workflow pipeline issue remains with its fixing owner until its regression is integrated. Native host, cryptographic signature and remote branch-policy application claims must come from their actual evidence, not this record.
