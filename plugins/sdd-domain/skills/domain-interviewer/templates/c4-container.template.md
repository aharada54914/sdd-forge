# C4 Container: {{domain_name}}

Stage: 7 of 7 (C4 Container)
Seed-Source: {{seed_source}}

Container level only in this lane (Component/Code levels are out of scope
per requirements.md Non-goals). Actors, containers, and external systems are
drawn from the bounded contexts, aggregates, and message flows established
in the earlier stages.

## Diagram

```mermaid
C4Container
    title Container Diagram - {{domain_name}}
    Person(user, "{{actor_name}}", "{{actor_description}}")
    Container(app, "{{container_name}}", "{{technology}}", "{{container_description}}")
    ContainerDb(db, "{{db_name}}", "{{db_technology}}", "{{db_description}}")
    System_Ext(ext1, "{{external_system_1}}", "{{ext1_description}}")
    Rel(user, app, "{{interaction}}", "{{protocol}}")
    Rel(app, db, "{{interaction}}", "{{protocol}}")
    Rel(app, ext1, "{{interaction}}", "{{protocol}}")
```

## Elements

| Name | Type | Responsibility | Technology | Dependencies |
|---|---|---|---|---|
| {{container_name}} | Container | {{responsibility}} | {{technology}} | {{deps}} |
| {{db_name}} | Database | {{responsibility}} | {{technology}} | - |

## Context-to-Container Mapping

Which bounded context (from the Context Map, stage 4) each container
implements, so the C4 diagram stays traceable back to the domain model.

| Container | Implements Context(s) | Aggregates Hosted |
|---|---|---|
| {{container_name}} | {{implemented_contexts}} | {{hosted_aggregates}} |

## Related ADRs

- {{adr_link}}

## Open Questions

{{open_questions}}

## Unknowns

{{unknowns}}

Record anything the human could not yet answer here, verbatim. Never invent
an answer to fill this section.
