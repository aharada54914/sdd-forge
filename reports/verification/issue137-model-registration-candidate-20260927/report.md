# Issue137 candidate registration boundary — 2026-09-27

Candidate only. Production registries, selector, frozen continuity artifacts and task status are unchanged. No worker or gate was launched.

The smallest proposed governing change is one exact `gpt-6-sol` entry in the existing v2 registry, retaining the existing schema/selector and high-risk tier. Its proposed `strong` classification is NOT established by host callability or supported effort. ADR0003 defines existing strong routes and requires same-tier registration; it supplies no rule mapping new Sol products to that tier (`docs/adr/0003-turn-first-agent-routing.md`, Decision). A human-approved routing classification or documented capability evaluation against the existing strong-tier baseline is therefore still required before registration becomes authoritative.

Exact identity/high effort support were supplied by the root's official documentation check and native tool inventory. Existing selector v2 accepts only low/medium/high/xhigh (`plugins/sdd-implementation/scripts/select-agent-model.sh:147`); proposed metadata uses that intersection, without extending its vocabulary to max/ultra. Host callability is declared availability, not evidence of a completed implementation invocation. No `openai/` alias is added because this native mechanism exposes `gpt-6-sol` verbatim.

The existing `--registry` option (`select-agent-model.sh:49`) provides a configuration route; registered-name lookup (`:316-397`) remains unchanged. Selector script is protected (`plugins/sdd-quality-loop/references/guard-invariants.json:60`). Neither candidate files nor continuity frozen inputs are amended by the check. Model registry change is outside continuity task scope and requires a separately authorized routing-metadata repair; do not amend frozen tasks to absorb it.

Attempt cost remains absent. `docs/agent-capability-matrix.md:122-123` requires invocation-supplied estimated cost per attempt plus source/timestamp; ADR0003 explicitly distinguishes token price from runtime attempt estimates. Required missing evidence: a finite nonnegative decimal estimate for this route, its invocation/workload assumptions, source and timestamp. API token price by itself is insufficient; zero was not invented to pass validation.

Runnable check: `rtk proxy python3 reports/verification/issue137-model-registration-candidate-20260927/check.py`.
Actual execution: exit 0, metadata/intersection checks PASS. It proves old registry has no exact host intersection, proposed exact name supports high, empty candidates BLOCK, and missing name/unknown name/missing cost inputs are rejected by the existing selector. It intentionally does NOT demonstrate successful selector routing, strong capability or actual launch: those require the missing tier and attempt-cost evidence. No temporary candidate cost is fabricated.

Next step: obtain the narrowly scoped strong-tier classification and provenance-bearing attempt estimate, then review/apply the single registry entry through the authorized route and rerun selection against actual host candidates. Existing launcher registry policy must also be verified by the root before using an override; the configuration option alone does not authorize bypassing a launch contract.

## Bounded classification/cost audit follow-up

`docs/agent-capability-matrix.md:107-110` says concrete model IDs are examples and availability is invocation-time; this permits a metadata refresh in principle. However `:113-119` is a predicted-attempt matrix by pre-existing tier, not a measured model benchmark or classification acceptance criterion. `:145-150` explicitly requires registry-assigned same-tier substitution. ADR0003:31 names the baseline route, but neither baseline callability nor a recorded comparable workload result is available on this host. No existing threshold or runnable strong-equivalence check was found in the bounded routing-contract/document search. A single easy synthetic puzzle would not establish the high-risk one-attempt prediction or equivalence; do not relabel its PASS as classification proof.

The launcher requires checked-in routing and validated immutable input before launching an actual T-NNN worker (`plugins/sdd-implementation/skills/implement-tasks/SKILL.md:130-144`). Thus T001 cannot be used as a pre-registration capability experiment. This is a concrete contract boundary, not a request to re-approve its already-approved implementation. A separate non-secret synthetic model evaluation could be proposed, but without an existing acceptance criterion it would remain exploratory evidence rather than authorization to assign strong.

A bounded search for token_budget/max-tokens/input_tokens/output_tokens/cost provenance across routing docs, contracts, implementation code and verification reports found cost provenance fields in `contracts/task-input-manifest.schema.json:17-18,56-60`, but no existing T001 token workload budget. Continuity's 8,192 UTF-8-byte response budget and native timing budgets concern product runtime; they cannot be substituted for model invocation tokens. No actual per-attempt model usage receipt was supplied. Therefore there is no supported numerical multiplicand for official per-token prices. An arbitrary finite token allowance would manufacture the workload estimate rather than derive it from existing facts.

Minimal separate repair plan candidate: (1) establish new-route strong classification with an explicitly stated comparable workload/acceptance rationale, retaining the current tier floor; (2) record actual invocation workload/token estimate and official price source/date, or host billing evidence applicable to this native subscription route; (3) add only exact-name v2 metadata and provenance-bearing invocation candidates; (4) run existing selector success plus fail-closed regressions and manifest validation; (5) resume the already-approved T001 immutable launch. Items 1/2 are still missing evidence. No benchmark suite, production change, external model send, or implementation experiment was started.

## Independent safe-action audit

Re-read current continuity tasks: T001–T004/T006 remain Approved/Planned; T005 remains Draft/Planned awaiting two distinct human approvers. No task/status change is made. Sol/Luna delegation is authority to use the native mechanism within the governing routing contract, not evidence that an unregistered model already satisfies strong classification or that historical preflight totals are completed-attempt costs. No additional product requirement choice was identified: the missing inputs concern routing metadata governance and estimation provenance, outside the frozen continuity task scope.

The existing candidate regression was rerun on 2026-09-27 and exited 0. It is registration-independent diagnostic evidence only, not T001 implementation or acceptance coverage. Product implementation cannot start independently of registration because the mandatory capable-host launch contract requires checked-in routing before the fresh immutable T001 worker. Later Approved tasks depend on T001, so they are not independent implementation alternatives. Do not use a root inline implementation, different tier, fictional alias/cost, or optional registry override to evade that launch prerequisite.

Smallest remaining step is the separately scoped exact-name metadata repair already proposed: establish authoritative strong classification and explicitly adopt a workload-qualified finite estimate, then register the exact name and rerun existing routing/manifest checks. The pending narrow routing decision should be resolved once, without re-requesting approval for the already-approved product tasks. No model invocation, production edit, guard retry or frozen-artifact amendment occurred during this audit.

## Existing native usage receipts

Read only allowlisted `turn_context` model/effort/timestamp and `event_msg/token_count` usage fields from the two previously identified local session JSONL logs. No prompts, responses, tool contents, credentials or personal metadata were emitted. Each listed turn_context identifies exact `gpt-6-sol`, effort `high`.

| Existing session | Final UTC usage receipt | Input | Cached input | Uncached input (difference) | Output | Reasoning output (subset) | Cache write |
|---|---|---:|---:|---:|---:|---:|---:|
| Issue137 native preflight | 2026-09-27T13:26:35.972Z | 1,596,223 | 1,502,080 | 94,143 | 9,384 | 1,637 | 0 |
| A7 native preflight | 2026-09-27T13:26:23.488Z | 2,359,194 | 2,183,296 | 175,898 | 13,741 | 2,068 | 0 |

Source session IDs are already bound in the existing private native-preflight reports: Issue137 `01a0e2ab-2879-7920-a92a-2b0c2fee5017` (23 usage events/two turns), A7 `01a0e2b3-55e3-7091-8ad0-fc7ab8b36140` (35 events/four turns). These are cumulative multi-turn preflight/blocked-launch workloads, not completed implementation attempts or subscription billing receipts. They establish a real same-model workload sample, while its transfer to a fresh isolated implementation attempt requires an explicit estimation assumption.

API-equivalent computation, if standard per-million prices are I/C/O and applicable uniformly to each request: Issue137 estimate = `(94143*I + 1502080*C + 9384*O)/1000000`; A7 = `(175898*I + 2183296*C + 13741*O)/1000000`. Do not add reasoning output twice. If context-dependent price thresholds apply, calculate request by request from last_token_usage, not cumulative totals. Official price/version/context-threshold evidence is still required before filling a USD decimal. Native subscription actual cash charge is not inferred from API-equivalent price. No new invocation/API/charge operation was performed.

### Price-grounded conditional bounds

Root verified the official [GPT-6-Sol model page](https://developers.openai.com/api/docs/models/gpt-6-sol), lines 889–916, on 2026-09-27: Standard USD per million tokens input 2, cached input 0.20, cache write 2.50, output 10. For a single prompt over 272K tokens, input/cache prices multiply by 2 and output by 1.5; Fast multiplies by 2 and regional processing by 1.1. This subagent relies on the root's verified extraction, not a separate page fetch.

Using exact decimal arithmetic and zero recorded cache-write tokens:

| Historical sample | Standard all-short equivalent USD | Standard all-long equivalent USD |
|---|---:|---:|
| Issue137 native preflight | 0.582542 | 1.118164 |
| A7 native preflight | 0.9258652 | 1.7830254 |

Checked with Python Decimal: short=`(uncached*2+cached*0.20+output*10)/1000000`; all-long=`((uncached*2+cached*0.20)*2+output*10*1.5)/1000000`. These are conditional Standard API-equivalent lower/upper bounds over the aggregate, assuming all requests respectively short/long. Cumulative input above 272K does not establish any individual request's long-context charge. Unknown service tier, region and request-level pricing remain unknown; the Standard upper bound is not an upper bound across Fast/regional settings. Reasoning remains included in output, never added separately. These amounts are neither native subscription invoices nor T001 completed-attempt costs and cannot silently become authoritative launch estimates.
