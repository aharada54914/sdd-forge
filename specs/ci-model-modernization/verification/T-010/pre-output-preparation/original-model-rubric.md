# Initial current-model adoption evaluation rubric

Date: 2026-10-18 UTC
Status: Prepared before candidate outputs; evaluation not run
Authorization: approved model-selection-policy-research-20261018.md

## Purpose and comparison controls

Evaluate GPT-6.1 Sol for implementation/review and GPT-6 Luna for bounded investigation against the available previously registered GPT-6 Astra baseline. Each comparison varies the model only: identical fixture bytes, natural request, permitted tools, role-appropriate fixed effort and wall/tool budget. Use two fresh repetitions per case to expose obvious variability; this small project-shaped sample is not a general benchmark or a proof of universal model quality.

The current candidate list is an availability observation, not adoption proof. Re-discover availability and record actual CLI/schema before collecting outputs. Do not substitute unavailable models or reinterpret a host-configured ID as per-turn execution telemetry. Capture reroute notifications; state the exact identity-proof level. A comparison requiring unsupported actual execution-ID attestation is blocked rather than advertised as exact backend identity proof.

Candidates receive separate temporary workspaces with ordinary project names, the same request and fixture files. Keep this rubric, model variant labels, expected findings and experiment metadata outside their input boundary. Do not expose unrelated repository/session content. No provider/network credentials, cloud writes, external panelist sends, registry edits or live notifications are part of these trials.

## Cases and observable scoring

| Case | Candidate / baseline | Natural task | Evidence and pass rule |
|---|---|---|---|
| Implementation | GPT-6.1 Sol / GPT-6 Astra | Repair a small model-selection function whose current fallback ignores host availability and role floor | Actual edited artifact passes public representative cases plus held-out unavailable, unknown, role-floor, pinned and malformed-input cases. Existing input behavior stays compatible. No changes outside the fixture are permitted. |
| Review | GPT-6.1 Sol / GPT-6 Astra | Review a supplied selection change and report correctness issues with file/line evidence | Detect each seeded availability, stale-account and incorrect configured-as-actual identity defect, with no invented critical issue in a paired clean control. Structured findings must cite existing file lines. No file writes. |
| Investigation | GPT-6 Luna / GPT-6 Astra | Trace how a selected model reaches a small launcher's invocation and report gaps | Identify the actual selector, higher-priority agent setting and response/record consumer with accurate path/line citations; distinguish configuration from execution identity. No invented endpoint or file; no edits. |

For each model/case use two fresh runs. Implementation and review use high effort; bounded investigation uses low effort, with the same effort within each paired comparison. Effort names do not imply equal compute across models. Set each run's wall budget to 300 seconds and tool-call budget to 24; timeout/budget exhaustion is a failed or unavailable observation, not a success. Record observed usage only when supplied; no synthetic price or dollar estimate.

## Judgment and promotion

Deterministic artifact/test results and exact seeded findings are primary. If an independent native judgment is used, keep the judge fixed at GPT-6 Astra/high for all paired outputs, use fresh isolated contexts and blind model labels. Its role is to assess artifact quality against this frozen rubric, not to waive failed assertions or invent unavailable actual-ID evidence. Record judgment availability and residual model/self-preference bias.

Promote a model only for roles with complete actual observations, all required functional/boundary assertions satisfied in both repetitions, no unauthorized writes/tools, and no unresolved material regression against the baseline. A failed candidate stays an update candidate; investigate and rerun a new versioned experiment rather than removing failed results. Retain every attempt, source/input/output hash and failure. A historical model unavailable to this account is not a fabricated comparison arm.

This is initial adoption evidence for a limited repository workload. Normal independent task reviews and quality gates still apply, with their existing identity/input contracts. Later role or skill changes require their own relevant controlled evaluation; skill comparisons keep the model fixed.
