# ADR 0038: Role policy with live model availability and immutable run selection

Status: Proposed
Date: 2026-10-18
Normative design: specs/ci-model-modernization/design.md. Initial direction approved by the user; formal implementation-policy review remains pending.

## Context

Current model names occur in a capability registry, generated role references, host launchers, panelists and automation. The approved model policy requires current compatible models with reproducible run settings, not repeated manual replacement or an unverifiable universal latest alias. Host model access and identity-reporting capabilities differ.

## Decision

Extend the existing selector; do not add a parallel capability/risk algorithm. A versioned role/lifecycle policy references the capability registry and exact host-native IDs. Documented live availability intersects verified current candidates with role/risk/effort/access conditions. Managed callers use latest-compatible by default and validated explicit pins when requested. Legacy selector schemas remain usable explicitly.

Bind selected model/effort and provenance to each run. Preserve configured/resolved versus actual-reported identity. In particular, Codex Thread.model is configuration metadata rather than per-turn telemetry; collect scoped reroute events and mark absent actual proof unverified. Gates requiring unavailable actual-ID proof stop. Preserve role isolation, canonical input/identity preflight and external-send consent.

Use existing weekly/manual freshness maintenance for update candidates and deprecations. Adoption follows source/capability mapping and representative controlled behavior evaluation. No automatic registry rewrite, automatic maximum effort, provider SDK, new credential or additional scheduler is required.

## Alternatives

Environment variables alone cannot overcome higher-priority agent definitions or prove availability. Fixed names with periodic global replacement invite omissions and do not handle account differences. Blind latest/auto aliases can select unverified preview models and obscure comparisons. A universal model gateway introduces a separate service and permission boundary without a task requirement.

## Consequences

Host adapters and lifecycle metadata need maintenance, and explicit pins may become unavailable. Supported managed paths can select current verified models automatically after adoption without editing each role file. Unsupported metadata is reported honestly; parent ChatGPT UI and unmanaged direct native invocations remain outside product control. A newer model may increase cost or regress, so known budgets and actual adoption evidence remain necessary.
