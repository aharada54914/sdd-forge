# C4 Context: {{system_name}}

## Diagram

```mermaid
C4Context
    title System Context — {{system_name}}
    Person(user, "{{actor_name}}", "{{actor_description}}")
    System(system, "{{system_name}}", "{{system_description}}")
    System_Ext(ext1, "{{external_system_1}}", "{{ext1_description}}")
    Rel(user, system, "{{user_interaction}}")
    Rel(system, ext1, "{{system_ext1_interaction}}")
```

## Elements

| Name | Type | Responsibility | Technology |
|------|------|---------------|-----------|
| {{actor_name}} | Person | {{responsibility}} | — |
| {{system_name}} | System | {{responsibility}} | {{technology}} |
| {{external_system_1}} | External System | {{responsibility}} | {{technology}} |

## Related ADRs

- {{adr_link}}
