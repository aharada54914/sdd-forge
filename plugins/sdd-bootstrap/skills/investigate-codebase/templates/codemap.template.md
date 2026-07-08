# Codemap: {{feature_name}}

| Field | Value |
|-------|-------|
| Feature | {{feature_name}} |
| Date | {{date}} |
| Derived From | investigation.md ({{inv_id_range}}) |

Token-lean architecture map for downstream reuse. Skills read this file
first and limit fresh repository exploration to areas it does not cover.
Regenerate this file whenever `investigation.md` changes; never edit
downstream copies.

## Entry Points

| Path | Role | Evidence |
|------|------|----------|
| `{{file}}` | {{role}} | `{{file}}:{{line}}` |

## Module Topology

| Module / Directory | Responsibility | Key Files | Depends On |
|--------------------|----------------|-----------|------------|
| `{{module}}` | {{responsibility}} | `{{files}}` | {{dependencies}} |

## Key Symbols

| Symbol | Kind | Location | Referenced By |
|--------|------|----------|---------------|
| {{symbol}} | function \| class \| route \| table \| config | `{{file}}:{{line}}` | {{referenced_by}} |

## External Dependencies

| Dependency | Version / Source | Used From |
|------------|------------------|-----------|
| {{dependency}} | {{version_or_source}} | `{{file}}:{{line}}` |

## Test Map

| Test Suite | Covers | Location |
|------------|--------|----------|
| {{suite}} | {{covers}} | `{{path}}` |

## Not Covered

Areas intentionally out of scope for this map, with reason. Downstream
skills must run their own exploration for anything listed here.

- {{gap_and_reason}}
