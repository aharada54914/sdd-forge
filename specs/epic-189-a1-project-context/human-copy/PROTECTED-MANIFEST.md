# PROTECTED-MANIFEST.md — Epic A1 protected-path inventory

Feature: `epic-189-a1-project-context` — REQ-007, T-009.

This file is the **single canonical enumeration** of every repository path
Epic A1 registers as protected. `design.md`'s Protected-File Statement
("Single canonical manifest (revised — closes the 'five/sixteen/nineteen,
independently wrong' arithmetic gap, M15)") designates it as the ONE
authoritative source; every other count in this package (AC-021, AC-038,
the staged `guard-invariants.json` candidate's new entries, and the staged
`generate-guard-invariants.py` candidate's `EPIC_A1_TARGETS` tuple) is
DERIVED from the table below and never restated independently.

`tests/guard-invariants-epic-a1.tests.sh` / `.ps1` re-derive both staged
candidates from this table on every run and fail if either has drifted, so
a hand edit to the JSON or the Python that is not mirrored here is a test
failure rather than a silent divergence.

## Row grammar (normative — parsers depend on it)

Every inventory row matches, exactly:

```
| NN | <Category> | <ADR-0019 Item 3 Category> | `<repository-relative path>` | <Status> |
```

- `NN` is a zero-padded two-digit ordinal, `01`..`28`, contiguous and
  ascending. It fixes the append order used by both staged candidates.
- Fields are separated by ` | ` (space, pipe, space).
- The path field is wrapped in backticks and is a repository-relative
  POSIX path: never absolute, never containing `\`, `.`, or `..`
  segments (`generate-guard-invariants.py`'s `_validate_repo_path`).
- `<Status>` is exactly `concrete` or `reserved`.
- Only inventory rows begin with `| ` followed by two digits; the header
  and separator rows do not, so `^\| [0-9][0-9] \| ` selects the
  inventory and nothing else.

## The six ADR-0019 item 3 categories

`docs/adr/0019-approval-sidecar-protection.md` item 3 enumerates the
verification machinery that must become protected: "the canonicalizer,
hash generator, approval validator, policy-weakening detector, resolver,
and any generated projection". Those six, and only those six, are the
canonical protection categories AC-038 requires to be represented:

| Slug | ADR-0019 item 3 wording | Representation |
|---|---|---|
| `canonicalizer` | the canonicalizer | concrete |
| `hash-generator` | hash generator | concrete |
| `approval-validator` | approval validator | concrete |
| `policy-weakening-detector` | policy-weakening detector | concrete |
| `resolver` | resolver | reserved |
| `generated-projection` | any generated projection | reserved |

Two further categories in the table below are deliberate EXTENSIONS beyond
ADR-0019 item 3's machinery enumeration, and are marked `beyond-item-3`:

- `sidecar-data` — the sidecar/registry/sentinel/approved-context-anchor
  DATA files. These are protected under ADR-0019 item **1**
  (`PROTECTED_GATE_SUFFIXES` for `*.approval.json` and siblings), not
  item 3, which enumerates machinery only. design.md revised this row to
  close finding B3 (the two `sdd/.approved-context/*.approved.yaml`
  anchor snapshots).
- `human-copy-publisher` — `apply-human-copy.{sh,ps1}`, NEW in this
  design (decision B9), closing the gap where the publisher itself would
  otherwise remain agent-writable indefinitely.

The hook-activation handshake trio is NOT a seventh ADR-0019 category:
design.md groups it with the validator family, so its item-3 slug is
`approval-validator`.

## Inventory

| NN | Category | ADR-0019 Item 3 Category | Path | Status |
|---|---|---|---|---|
| 01 | Canonicalizer | canonicalizer | `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` | concrete |
| 02 | Canonicalizer | canonicalizer | `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.sh` | concrete |
| 03 | Canonicalizer | canonicalizer | `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.ps1` | concrete |
| 04 | Canonicalizer | canonicalizer | `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.js` | concrete |
| 05 | Hash generator | hash-generator | `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py` | concrete |
| 06 | Hash generator | hash-generator | `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh` | concrete |
| 07 | Hash generator | hash-generator | `plugins/sdd-quality-loop/scripts/generate-approval-sidecar.ps1` | concrete |
| 08 | Approval validator | approval-validator | `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | concrete |
| 09 | Approval validator | approval-validator | `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh` | concrete |
| 10 | Approval validator | approval-validator | `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.ps1` | concrete |
| 11 | Policy-weakening detector | policy-weakening-detector | `plugins/sdd-quality-loop/scripts/detect-policy-weakening.py` | concrete |
| 12 | Policy-weakening detector | policy-weakening-detector | `plugins/sdd-quality-loop/scripts/detect-policy-weakening.sh` | concrete |
| 13 | Policy-weakening detector | policy-weakening-detector | `plugins/sdd-quality-loop/scripts/detect-policy-weakening.ps1` | concrete |
| 14 | Hook-activation handshake | approval-validator | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | concrete |
| 15 | Hook-activation handshake | approval-validator | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh` | concrete |
| 16 | Hook-activation handshake | approval-validator | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1` | concrete |
| 17 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/project-context.approval.json` | concrete |
| 18 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/provider-bindings.approval.json` | concrete |
| 19 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/approver-registry.yaml` | concrete |
| 20 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/.hook-canary-sentinel` | concrete |
| 21 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/.approved-context/project-context.approved.yaml` | concrete |
| 22 | Sidecar/registry/sentinel/anchor data | beyond-item-3 | `sdd/.approved-context/provider-bindings.approved.yaml` | concrete |
| 23 | Human-copy publisher | beyond-item-3 | `plugins/sdd-quality-loop/scripts/apply-human-copy.sh` | concrete |
| 24 | Human-copy publisher | beyond-item-3 | `plugins/sdd-quality-loop/scripts/apply-human-copy.ps1` | concrete |
| 25 | Resolver | resolver | `plugins/sdd-quality-loop/scripts/resolve-project-context.py` | reserved |
| 26 | Resolver | resolver | `plugins/sdd-quality-loop/scripts/resolve-project-context.sh` | reserved |
| 27 | Resolver | resolver | `plugins/sdd-quality-loop/scripts/resolve-project-context.ps1` | reserved |
| 28 | Generated projection | generated-projection | `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json` | reserved |

## Counts (derived from the inventory above)

| Status | Count |
|---|---|
| concrete | 24 |
| reserved | 4 |
| total | 28 |

These are the numbers design.md's Protected-File Statement records as
"**Total: 24 concrete + 4 reserved = 28 entries**". The tests recompute
them from the rows rather than trusting these literals; this block exists
so a human reader sees the same arithmetic the tests enforce.

## Reserved entries

Rows 25-28 are a pure PATH RESERVATION. `resolve-project-context.{py,sh,ps1}`
and `generated/project-context.resolved.json` are **not built by A1** —
they are a forced handoff to A2/A5. They are registered protected now, in
the same batch as the concrete entries, so that whichever later epic
creates them cannot create them agent-writable.

This is sound because `generate-guard-invariants.py`'s validation is
path-existence-agnostic: `_validate_repo_path` checks path SHAPE only, so a
registered path that does not yet exist on disk is accepted. There is no
script to review for these four by design; they are a reservation, not a
pending review item.

## Sequencing (why registration comes after authoring)

The 24 concrete entries were authored UNPROTECTED first (agent-editable,
fully testable, T-002/T-003/T-005/T-006/T-007/T-008), and only then is this
registration staged. Never the reverse: staging protection first would
leave no reviewable, tested script for a human to actually apply.

Once this manifest's registration is human-applied, every path above is
denied to agent writes and can only change through `apply-human-copy`
(REQ-007) — including `apply-human-copy.{sh,ps1}` themselves, rows 23-24
(decision B9). That self-inclusion is what requires the ONE-TIME bootstrap
recorded in `tasks.md`'s T-009 "Human apply step": the publisher's own
installed bytes are established by a plain, human-verified `cp` +
SHA-256 check exactly once, matching how `apply-protected-files.ps1` was
originally installed (INV-011). Every subsequent application of any staged
artifact — including a future revision of `apply-human-copy` itself — goes
through the tool while it is already protected.

## What this manifest does NOT cover

- `PHASE2_TARGETS` and `BASELINE_SUFFIXES` in
  `generate-guard-invariants.py` are frozen, historical, epic-136-scoped
  constants. This epic adds a THIRD constant, `EPIC_A1_TARGETS`, and does
  not conflate its additions with either.
- `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` is
  pinned to its own frozen bootstrap inventory and is out of this epic's
  edit scope (INV-011).
- `EPIC_A1_TARGETS` gets no generated-output projection of its own. Its
  paths are folded into the same `protected_gate_suffixes` /
  `PROTECTED_GATE_SUFFIXES` list every existing consumer already reads, so
  no fifth generated-file consumer is needed (design.md, Design Decisions:
  "Decided: no new generated-file consumer is needed").
