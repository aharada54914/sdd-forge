# Design: {{feature_name}}

Impl-Review-Status: Pending
Feature Type: {{project_or_feature_type}}

## Technical Summary

{{technical_summary}}

## Architecture

{{architecture}}

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| {{component_name}} | {{responsibility}} | {{technology}} | {{new_or_existing}} |

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | {{ux_summary}} | [UX specification](ux-spec.md#scope-and-user-journeys) | {{ux_owner}} | {{ux_status}} |
| Frontend | {{frontend_summary}} | [Frontend specification](frontend-spec.md#technology-stack) | {{frontend_owner}} | {{frontend_status}} |
| Infrastructure | {{infra_summary}} | [Infrastructure specification](infra-spec.md#deployment-topology) | {{infra_owner}} | {{infra_status}} |
| Security | {{security_summary}} | [Security specification](security-spec.md#trust-boundaries) | {{security_owner}} | {{security_status}} |

Use `N/A — no change: <reason>` for an unaffected layer. Security impact must
still be assessed.

## Design System Compliance

Applies when the project has a `design-system/` directory (`ds_profile:
custom`); otherwise record exactly `N/A — ds_profile: none`.

- Design-System-Version: {{design_system_version}} (design-tokens.json meta.version)
- Tokens Used: {{tokens_used}}
- New Components: {{new_components_with_reasons}} (reuse existing components
  first; record the reason for every new component)

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| requirements.md | {{layer_spec}} | {{owned_constraint}} | REQ-NNN | AC-NNN | TEST-NNN |
| ux-spec.md | frontend-spec.md | {{view_state_component_contract}} | REQ-NNN | AC-NNN | TEST-NNN |
| security-spec.md | infra-spec.md | {{control_and_runtime_contract}} | REQ-NNN | AC-NNN | TEST-NNN |

## ADR Change Log

| ADR | Decision | Status | Layer Impact | Supersedes | Date |
|---|---|---|---|---|---|
| {{adr_ref}} | {{decision_summary}} | {{status}} | {{layers}} | {{prior_adr_or_none}} | {{iso_date}} |

## Data Plan

Data Entities: {{data_entities}}

Existing Data Affected: {{existing_data_affected}}

Migration Strategy: {{migration_strategy}}

{{data_plan_details}}

## API / Contract Plan

{{api_contract_plan}}

## Test Strategy

{{test_strategy}}

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| {{boundary}} | {{auth_mechanism}} | {{data_classification}} | {{owasp_concerns}} |

Detailed controls: [Security specification](security-spec.md#trust-boundaries).

## Deployment / CI Plan

{{deployment_ci_plan}}

Detailed topology and operations:
[Infrastructure specification](infra-spec.md#deployment-topology).

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| {{constraint}} | {{compliance_statement}} |

## Assumptions

{{assumptions}}

## Open Questions

### OQ-001: {{question_title}}

{{question_description}}

Owner: {{owner_role}}
Blocks Implementation: yes | no
Resolution Path: {{resolution_path}}

## Risks

{{risks}}
