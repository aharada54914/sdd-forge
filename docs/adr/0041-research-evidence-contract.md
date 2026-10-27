# ADR-0041: Separate external evidence from gate authority

Status: Proposed

Issue #605 needs a versioned record for external sources, claims, citations,
revisions, retrieval status and storage rights. Existing investigation records
describe code behavior; existing task and review owners decide approval and
quality. Mixing those responsibilities would make metadata look like authority.

Use the closed `research-evidence/v1` schema and passive validation. Raw source
hashes, exact excerpt hashes and canonical metadata hashes have distinct meanings.
Default reference-only storage retains metadata and bounded excerpts; an unknown
permission does not authorize storing or redistributing the original. Source
retrieval, original comparison, human judgment and gate outcomes are separate.

Validation alone does not establish source truth, legal permission or gate PASS.
Acquisition, review integration, stale analysis and graph queries are separate
follow-up work. This proposed decision does not grant task approval.
