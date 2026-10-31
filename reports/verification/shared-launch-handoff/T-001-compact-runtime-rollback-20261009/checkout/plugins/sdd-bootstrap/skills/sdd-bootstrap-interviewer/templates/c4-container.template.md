# C4 Container: {{system_name}}

## Diagram

```mermaid
C4Container
    title Container Diagram — {{system_name}}
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
|------|------|---------------|-----------|-------------|
| {{container_name}} | Container | {{responsibility}} | {{technology}} | {{deps}} |
| {{db_name}} | Database | {{responsibility}} | {{technology}} | — |

## Related ADRs

- {{adr_link}}
