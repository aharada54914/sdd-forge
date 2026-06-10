# C4 Component: {{container_name}}

## Diagram

```mermaid
C4Component
    title Component Diagram — {{container_name}}
    Container_Boundary(boundary, "{{container_name}}") {
        Component(comp1, "{{component_1}}", "{{technology}}", "{{comp1_description}}")
        Component(comp2, "{{component_2}}", "{{technology}}", "{{comp2_description}}")
    }
    ContainerDb(db, "{{db_name}}", "{{db_technology}}", "{{db_description}}")
    Rel(comp1, comp2, "{{interaction}}")
    Rel(comp2, db, "{{interaction}}", "{{protocol}}")
```

## Elements

| Name | Responsibility | Technology | Dependencies |
|------|---------------|-----------|-------------|
| {{component_1}} | {{responsibility}} | {{technology}} | {{deps}} |
| {{component_2}} | {{responsibility}} | {{technology}} | {{deps}} |

## Related ADRs

- {{adr_link}}
