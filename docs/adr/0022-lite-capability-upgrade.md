# ADR 0022: Lite Capability Upgrade

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code, per
`docs/ai-dlc-foundation-decision-v2.md` §6 (Q5: relationship with the lite
track).

The existing lite track's real, code-verified behavior — three-file
generation, skipped review loops, a pre-generation risk-upgrade gate, a
ship-time recheck, and `lite-gate`'s independent re-verification — is a
deliberate, already-working design. Extending Capability enforcement
(ADR-0016, ADR-0020) to the lite track must preserve that design's
lightness rather than forcing every lite project through the full
Capability pipeline.

## Decision

1. **Combination matrix** (v2 adds two fallback rows to the v1 matrix):

   | spec_profile | artifact_layout | enforcement | Verdict |
   |---|---|---|---|
   | lite | lite-three-file | advisory | Only Lite-allowed Capabilities may be used |
   | lite | lite-three-file | required | Only Capabilities with a Lite-specific Gate may be used |
   | lite | lite-three-file | (inactive) | **Compatibility fallback (no Context). Capability mechanism does not run.** |
   | full | legacy-seven-layer | (inactive) | **Compatibility fallback (no Context). Capability mechanism does not run.** |
   | lite | legacy-seven-layer / facet-* | any | Invalid combination |
   | full | lite-three-file | any | Invalid combination |
   | full | legacy-seven-layer | advisory / required | Migration compatibility mode |
   | full | facet-hybrid | required | Recommended mode |
   | full | facet-native | required | Future standard mode |

2. **Per-Capability lite eligibility**, added to the Registry:

   ```yaml
   lite_policy:
     eligible: false
     upgrade_reasons: [public_distribution, production_cloud_runtime, durable_workflow, external_identity, pii]
   ```

   Lite-allowed examples: a fully local small internal tool, an internal
   CLI, a simple utility that handles no sensitive information, a small
   UI that is never exposed externally.

   Forced upgrade to `full`: cloud production, a Durable Workflow, a
   public package registry, Store distribution, auto-update, Stable
   distribution involving code signing, external authentication, PII,
   payments, multiple tenants, or a high-risk migration.

3. **Lite Capability Summary**: the lite track does not generate
   individual Facet files. It generates only
   `specs/<feature>/capability-summary.yaml`:

   ```yaml
   capabilities: [desktop-local]
   required_lite_checks: [build, test, installer-dry-run]
   full_upgrade_required: false
   ```

4. **`lite-gate` stays lightweight.** In addition to its current
   placeholder / lint / typecheck / build / test checks, `lite-gate` runs
   only the Lite-specific checks defined by the Registry. Its existing
   lightness and independent re-verification are preserved unchanged —
   `lite-gate` never grows into a second `quality-gate`.

5. **Protected-file changes go through human-copy.** `lite-spec`'s
   `SKILL.md`, `risk-upgrade-policy.md`, and `check-risk-upgrade.*` are
   already protected files (agent-unwritable, `sudo`-unbypassable) as of
   epic-136 Phase 2. Epic A6's changes to these files must be carried out
   through the human-copy flow (`specs/<feature>/human-copy/` +
   `apply-protected-files`, per ADR-0011), not by direct agent edit.

## Consequences

- The lite track gains an opt-in, bounded Capability surface instead of
  either being exempt from Capability enforcement entirely or being forced
  onto the full facet pipeline.
- The two new fallback rows make the "no Project Context" case an
  explicit, tested matrix entry rather than an implicit default, closing
  a gap where Epic A6 test coverage could otherwise silently miss it.
- `lite_policy.upgrade_reasons` gives the risk-upgrade mechanism a
  Capability-aware trigger list; Epic A6 must wire these reasons into the
  existing risk-upgrade gate rather than duplicating upgrade logic.
- Because `lite-spec`'s core files are protected, every Epic A6 task that
  touches them carries the extra human-copy step as a planned cost, not a
  surprise blocked by guard-invariants late in implementation.

## References

- Decision document v2 §6 (Q5) — `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0011 (Handle-relative protected-file publication, human-copy flow),
  ADR-0016 (Workflow Axes Separation, `spec_profile`/`artifact_layout`
  axes), ADR-0017 (Gate Stage Model, Implementation Gate scope)
