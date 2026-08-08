# Investigation: review-cross-critique

| Field | Value |
|-------|-------|
| Feature | review-cross-critique (high/critical-gated cross-critique phase inside `sdd-review-loop`) |
| Mode | feature (workflow / gate change) |
| Date | 2026-08-04 |
| Source | GitHub issue [#130](https://github.com/aharada54914/sdd-forge/issues/130) — "feat: review-loop に high/critical 限定の cross-critique フェーズを追加", including its 2026-07-10 runtime addendum. Key: **ENH-23**. |
| Investigated at | worktree `sdd-forge-wt-phase4`, branch `docs/wfi-021-gate-masking`, HEAD `c19b40f8` |

Read-only survey. Every claim below carries `file:line` evidence, per AGENTS.md
"Spec factual-claim evidence citations" (`AGENTS.md:138-146`, WFI-011). Line
numbers were read at HEAD `c19b40f8` and **must be re-verified at
spec-review time and again at implementation start** — several of the cited
files are shared, git-tracked state this branch does not exclusively own
(AGENTS.md `## Rules` sweep 3, `AGENTS.md:203-211`, WFI-013).

## Scope

Issue #130 asks for a **cross-critique phase** appended to the existing blind
dual-review loop: reviewer A and reviewer B are handed each other's findings and
return a per-finding verdict drawn from `SUPPORT / REJECT / SEVERITY_CHANGE /
SUPPLEMENT`; the orchestrator folds those verdicts into synthesis. Three stated
acceptance criteria: the phase fires on high/critical; routine tasks incur no
extra cost; the result is consistent with ENH-21's shared protocol. The
2026-07-10 addendum adds that both runtimes (Claude Code and Codex) must return
the same four verdicts, and warns that Codex has no reviewer role definitions.

Named target files (issue body, `## 対象ファイル / Files`):

- `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`
- `plugins/sdd-review-loop/skills/spec-review-loop/*`
- `plugins/sdd-review-loop/skills/task-review-loop/*`

## Summary

The existing loop is not "blind by convention". Blind independence is enforced
at **five mutually independent layers**, one of which is a deterministic
validator with no exception clause (INV-007 … INV-011). Cross-critique's only
possible input is the exact artifact those five layers exist to withhold. That
is a head-on collision, not an integration detail, and it is stated as such in
`## The blind-independence tension` below rather than smoothed over.

Beyond that, the issue underdetermines almost every mechanical decision: the
trigger vocabulary does not exist in the repository (INV-017), the round counter
is deterministically capped and requires the reviewed document to change between
rounds (INV-002, INV-003), the merged verdict is recomputed from raw severities
by three separate validators so no downstream "synthesis" can move it
(INV-014), the orchestrator is forbidden from waiving findings (INV-015), every
round artifact is pinned to an exact key set (INV-016), and the cost-saving
mechanism the source protocol relies on — resuming the same agent — is
structurally impossible under the identity ledger (INV-012). Fifteen decisions
are recorded as Open Questions and **none is answered here**.

Four of the six reviewer role files and two of the three target SKILL files are
guard-protected (INV-020), which changes how Phase 2 must plan the work.

## Findings

### Stream A — the existing three-stage loop

#### INV-001: three stages, two blind reviewers each, up to three rounds per attempt

`AGENTS.md:5-14` states the required workflow: Phase 1 → `spec-review-loop` →
`impl-review-loop` → Phase 2 + `task-review-loop` → human approval →
`implement-task` → `quality-gate`.

Each review stage is a two-reviewer loop with a round/attempt state machine:
`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:59-86` (independent
reviewer sequence) and `:88-98` (state transition table);
`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:67-242` (STEP 1 …
STEP 7); `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md:52-240`.

Reviewer roles are `{spec,impl,task}-reviewer-{a,b}` —
`plugins/sdd-review-loop/agents/` holds exactly six files.

#### INV-002: the three-round cap is deterministic, not advisory

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:35`

```sh
[[ "$round" -le 3 ]] || fail "round must be between 1 and 3"
```

The SKILL prose describes a three-round loop
(`spec-review-loop/SKILL.md:88-98`; `impl-review-loop/SKILL.md:198-232`;
`task-review-loop/SKILL.md:199-230`), but the precheck is what actually refuses
a fourth round. Any proposal that spends rounds on cross-critique is spending a
budget of three that a shell script enforces.

#### INV-003: a round is only legal if the reviewed document changed

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:286-287`

```sh
[[ "$requirements_sha" != "$prior_requirements_sha" || "$acceptance_sha" != "$prior_acceptance_sha" ]] \
  || fail "reviewed inputs are unchanged from the prior round"
```

and `:36-38` requires a non-empty `--edit-summary` for rounds 2 and 3.

This is decisive for OQ-4. A cross-critique pass does not edit `requirements.md`
or `acceptance-tests.md` — it critiques findings about them. So a cross-critique
pass **cannot be modelled as an additional round** of the existing counter
without either editing the spec (which is the human's job, not the phase's) or
relaxing this check.

#### INV-004: replay is forbidden; a round directory may not pre-exist

`spec-review-precheck.sh:138` and `:314`

```sh
[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"
```

So a cross-critique phase cannot re-open a completed round directory to append
its outputs by re-running the precheck.

#### INV-005: the sanitized bridge at the **spec** stage carries id + result + severity

`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:71-72`

> 3. Create `integrated-summary.json` containing only check IDs, severities, and
>    counts. It must not reproduce any raw finding text.

Enforced at `spec-review-precheck.sh:214-220` — the summary's key set is exactly
`["attempt","generated_at","reviewer_a_checks","reviewer_a_fail_count",
"reviewer_a_pass_count","reviewer_a_skip_count","round","schema"]` and each
`reviewer_a_checks[]` entry has exactly `["id","result","severity"]` — and
cross-checked at `:250`:

```sh
[[ "$(jq -c '[.checks[] | {id, result, severity}]' "$reviewer_a")" == "$(jq -c '.reviewer_a_checks' "$summary")" ]] || return 1
```

So at the spec stage reviewer B already learns **which** of A's checks failed and
**at what severity** — it is denied only the `finding` prose.

#### INV-006: the bridge at the **impl**, **task** and **domain** stages is strictly narrower — a stage asymmetry

`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:114-126` and
`plugins/sdd-review-loop/skills/task-review-loop/SKILL.md:112-124` specify
`reviewer_a_check_ids` — a bare array of ID strings — plus three aggregate
counts. The persisted-state validator branches on exactly this difference:

`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:508-510`

```jq
([$a.checks[] | .id] | sort) ==
  ((if $stage == "spec" then [$summary[0].reviewer_a_checks[] | .id]
    else $summary[0].reviewer_a_check_ids end) | sort) and
```

confirmed in the PowerShell twin at `check-workflow-state.ps1:679-680` and in the
test drivers (`tests/lib/loop-driver.sh:650` uses `reviewer_a_checks`;
`:844`, `:1103`, `:1311` use `reviewer_a_check_ids`).

**Consequence for this feature:** at impl and task stages reviewer B today does
not even learn *which* check A failed. The distance from that to "B examines A's
findings" is larger than at the spec stage, so a single uniform design across
three stages is not obviously available. Recorded as OQ-2.

### Stream B — the five layers that enforce blind independence

#### INV-007: layer 1 — the role prose forbids reading the other reviewer's report

`plugins/sdd-review-loop/agents/spec-reviewer-b.md:34-35`

> Never read `reviewer-a.json`, any `reviewer-*.json`, or another
> stage's review evidence.

`plugins/sdd-review-loop/agents/spec-reviewer-a.md:32-33` carries the mirror
prohibition. `spec-review-loop/SKILL.md:75-76` states it from the orchestrator
side ("It must never receive `reviewer-a.json`"), and
`impl-review-loop/SKILL.md:268-269` and `task-review-loop/SKILL.md:295-296` both
state:

> Never pass reviewer-a output directly to reviewer-b. Use integrated-summary.json
> (counts and IDs only) as the only bridge.

#### INV-008: layer 2 — agent capability

`plugins/sdd-review-loop/agents/spec-reviewer-b.md:4-9`

```yaml
tools: Read, Grep, Glob
disallowedTools: Write, Edit, NotebookEdit
disallowedPaths:
  - "reports/spec-review/**/reviewer-*.json"
  - "reports/impl-review/**/reviewer-*.json"
  - "reports/task-review/**/reviewer-*.json"
```

Identical blocks appear in the other five role files (`spec-reviewer-a.md:4-9`,
`impl-reviewer-a.md`, `impl-reviewer-b.md`, `task-reviewer-a.md`,
`task-reviewer-b.md`). Reviewers are also read-only, so a reviewer cannot persist
a cross-critique output itself — `spec-review-loop/SKILL.md:69-70` says the host
captures the returned JSON.

#### INV-009: layer 3 — the deterministic validator, with no exception clause

`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:57-61`

```sh
is_forbidden_review_output() {
  local path=$1
  [[ "$path" =~ ^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$ ]] ||
    [[ "$path" =~ (^|/)reviewer-[ab]\.json$ ]]
}
```

applied unconditionally to every manifest entry at `:287-288`:

```sh
is_forbidden_review_output "$path" &&
  fail PATH "$role contains a forbidden raw reviewer report: $path"
```

`plugins/sdd-review-loop/references/review-context-boundary.md:134-136` states
the consequence in the reviewers' own reference document:

> `reviewer-a.json` and `reviewer-b.json` are a different matter: those are
> categorically forbidden in any manifest (`is_forbidden_review_output`),
> enforced by the validator, with no exception.

This is the layer that makes cross-critique a gate change rather than a prompt
change. It applies to **every** role, not only reviewer B.

#### INV-010: layer 4 — the contract replay recomputes the exact expected manifest

`spec-review-precheck.sh:231-240` builds `expected_a` (requirements, acceptance,
precheck-result, calibration, plus `investigation.md` when present) and
`expected_b` (`expected_a` + `integrated-summary.json`), then:

```sh
[[ "$actual_a" == "$expected_a" && "$actual_b" == "$expected_b" ]] || return 1
```

Exact list equality, not a subset test. Adding *any* extra input to a reviewer's
manifest — including one that `path_is_authorized` would accept — fails the
contract. `check-workflow-state.sh:455-458` states the only tolerated excess:

```jq
# Reviewer manifest may only exceed the contract with the four
# implementation layer specs; any other extra entry is a fail.
(($reviewer_norm - $contract_norm) | all(.path | is_allowed_layer_superset_path));
```

#### INV-011: layer 5 — calibration forbids raw prior reviewer reports outright

`plugins/sdd-review-loop/references/reviewer-calibration.md:119-121`

> Reviewer prompts must remain deterministic and reproducible. Do not use learned
> memories, prior raw reviewer reports, or adaptive prompt evolution while running
> the gate.

This document is in both reviewers' manifests at every non-spec stage
(`impl-review-loop/SKILL.md:88-89`, `:136-137`;
`task-review-loop/SKILL.md:84-86`, `:134-136`), so it is not background reading —
it is a hash-bound input.

### Stream C — the mechanisms a cross-critique phase would have to pass through

#### INV-012: the identity ledger forbids reusing a session, so "resume the same agent" is not available

`validate-review-context-set.sh:234-235` requires, of the ledger itself:

```jq
([.records[].run_id] | unique | length) == (.records | length) and
([.records[].host_session_id] | unique | length) == (.records | length)
```

and `:262-265` rejects a reservation whose identity already appears:

```sh
jq -e --arg run "$run_id" --arg session "$host_session_id" '
  all(.records[]; .run_id != $run and .host_session_id != $session)
' "$ledger" >/dev/null 2>&1 ||
  fail IDENTITY 'run or host-session identity was already persisted'
```

`:260-261` additionally requires the reservation to extend the chain by exactly
one sequence with a matching `previous_record_sha256`.

The source protocol's cost argument depends on the opposite:
`skills/adversarial-review/SKILL.md:37` describes Phase 2 as

> | 2 Cross-critique | Same two agents, resumed | SendMessage each reviewer the
> other's full report verbatim (context preserved — no re-reading cost). |

A resumed agent carries the same host session. Under `:262-265` its reservation
fails. So inside `sdd-review-loop` a cross-critique participant must be a **fresh
context that re-reads every input**, which is exactly the cost the source
protocol avoids. This is the sharpest constraint on acceptance criterion 2
("通常タスクはコスト増なし") and is recorded as OQ-6.

#### INV-013: the authorized `stage:role` pairs are a closed enumeration of nine

`validate-review-context-set.sh:189-192`

```sh
case "$stage:$role" in
  spec:spec-reviewer-a|spec:spec-reviewer-b|impl:impl-reviewer-a|impl:impl-reviewer-b|task:task-reviewer-a|task:task-reviewer-b|quality:sdd-evaluator|domain:domain-reviewer-a|domain:domain-reviewer-b) ;;
  *) fail CONTRACT 'stage and role are not an authorized invocation pair' ;;
esac
```

with `path_is_authorized` defaulting to `return 1` for an unknown pair at `:126`.
A new role name (`spec-critic-a`, say) or a new stage (`cross-critique`) is
rejected at launch until this file changes — and this file is a
`PROTECTED_GATE_SUFFIXES` neighbour by function though not by listing
(see INV-020 for what is actually listed).

#### INV-014: the merged verdict is recomputed from raw severities by three independent validators

1. `spec-review-precheck.sh:255-267` recomputes critical/major/minor from the
   union of both reviewers' `checks[]` and derives the expected merged verdict
   and `warningCount`, then requires the contract to match (`:275`).
2. `impl-review-loop/SKILL.md:160-165` and `task-review-loop/SKILL.md:161-167`
   specify the same derivation for the orchestrator.
3. `check-workflow-state.sh:517-544` recomputes the counts a third time from the
   persisted reviewer outputs and requires the contract and integrated verdict to
   agree, and `:498-499` requires each reviewer's own verdict to equal the
   deterministic function of its own findings:

```jq
$a.verdict == expected_reviewer_verdict($a) and
$b.verdict == expected_reviewer_verdict($b) and
```

**Consequence:** a `SEVERITY_CHANGE` verdict cannot change the gate outcome
unless the severity is changed in `reviewer-a.json` / `reviewer-b.json`
themselves. Reviewers cannot write (INV-008), the orchestrator may not waive
(INV-015), and the contract hash-binds the reviewer outputs. So either
cross-critique is advisory-only, or all three derivations change together.
Recorded as OQ-7.

#### INV-015: the orchestrator may never waive or override a finding

`impl-review-loop/SKILL.md:261-262`, `task-review-loop/SKILL.md:289-290`:

> Never self-approve any finding. Findings from reviewers are facts; the
> orchestrator counts them but does not waive or override them.

and `spec-review-loop/SKILL.md:97`: "Never waive findings."

A `REJECT` verdict from the opposing reviewer is, on its face, a request to waive
a finding. Who is allowed to act on it — and whether "the orchestrator counts
them" survives — is undetermined. Recorded as OQ-8.

#### INV-016: every round artifact is pinned to an exact key set

`spec-review-precheck.sh:150` (reviewer output, 8 keys), `:199` (contract,
11 keys), `:214` (integrated summary, 8 keys), `:271` (integrated verdict,
12 keys) all use `keys == [...]` equality, not a superset test. `:153-155`
additionally pins each `checks[]` entry to exactly
`["finding","id","result","severity"]` with `severity` restricted to
`"Critical" | "Major" | "Minor"`.

So a cross-critique verdict cannot be added as a field to any existing artifact
without a schema version bump propagated to the precheck, the PowerShell twin
(`spec-review-precheck.ps1:300`), `check-workflow-state.{sh,ps1}`, the templates
under `plugins/sdd-review-loop/templates/`, and the test drivers under
`tests/lib/`. Recorded as OQ-10.

#### INV-017: "high" is not a severity anywhere in this loop; "critical" is two different things

Review findings use `Critical | Major | Minor` — enforced at
`spec-review-precheck.sh:155` and calibrated at
`plugins/sdd-review-loop/references/reviewer-calibration.md:103-115`.

Task **risk tiers** use `low | medium | high | critical` —
`plugins/sdd-quality-loop/references/risk-classification-policy.md:10-17`, with
`high`/`critical` deriving `Required Workflow: tdd` at `:21-27`.

The issue's trigger phrase "high/critical" matches the risk-tier vocabulary, not
the finding-severity vocabulary. But the issue's own AC says "high/critical で
**相互批判段が走る**" in the same breath as "findings", and the parent framing is
"gated to high/critical findings". The two readings differ materially:

- **severity reading** — the phase fires when a round produced a Critical (and
  possibly Major) finding. Available at all three stages.
- **risk-tier reading** — the phase fires for a task tiered `high`/`critical`.
  But risk tiers are assigned per task in Phase 2
  (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:178-193`),
  which runs *after* spec-review and impl-review. At those two stages there is no
  tier to read.

This is not a wording nit; it decides whether the feature is even applicable to
two of its three named target files. Recorded as OQ-1.

### Stream D — the source protocol and the sibling issue

#### INV-018: `skills/adversarial-review` already implements this protocol, is unreferenced, and self-excludes from SDD gates

The skill exists at `skills/adversarial-review/` with `SKILL.md`, `README.md`,
`references/reviewer-prompts.md` and `templates/report-template.md`.
`SKILL.md:36-39` is the four-phase protocol (blind → cross-critique → synthesis →
fresh fix verification). The per-finding verdict vocabulary is at
`skills/adversarial-review/references/reviewer-prompts.md:154-155`:

```
- Verdict: SUPPORT | PROPOSE-SEVERITY-CHANGE (to <severity>) | PROPOSE-REJECT
  | SUPPLEMENT
```

Note the spelling: `PROPOSE-REJECT` and `PROPOSE-SEVERITY-CHANGE`, not the
issue's `REJECT` / `SEVERITY_CHANGE`. The `PROPOSE-` prefix is load-bearing given
INV-015 — it marks the verdict as a request to the orchestrator rather than a
decision. Recorded as OQ-9.

`SKILL.md:25-26` excludes itself from exactly this use:

> - NOT for sdd-forge SDD gate reviews (spec/impl/task-review-loop have their
>   own deterministic contracts)

and `SKILL.md:55` ("No subagents") plus `:37` ("Same two agents, resumed")
describe an orchestration shape the identity ledger forbids (INV-012).

#### INV-019: `skills/adversarial-review` is not wired into any plugin — confirming the sibling issue's premise

`grep -rn adversarial plugins/ docs/ tests/` returns no reference to
`skills/adversarial-review`; the only `adversarial` hits under `specs/` are
unrelated (adversarial *test fixtures* in `epic-159-pillar-d` and
`epic-136-phase3`). Issue [#128](https://github.com/aharada54914/sdd-forge/issues/128)
(**ENH-21**) proposes formalizing this skill as a risk-adaptive lane and declares
`Depends on: ENH-23` — that is, on this issue.

So #130's third acceptance criterion ("ENH-21 の共通プロトコルと整合") refers to a
protocol that **does not exist yet** and whose own issue is blocked on this one.
Recorded as OQ-13.

#### INV-020: protected-gate membership of the target files — the asymmetry that shapes Phase 2

Read from `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`
(`PROTECTED_GATE_SUFFIXES`, 42 entries) and evaluated by `endswith()` on the
repo-relative path, which is how the guard matches
(`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1007`).

| Repo-relative path | Protected? |
|---|---|
| `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` | **YES** |
| `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` | **YES** |
| `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | no |
| `plugins/sdd-review-loop/agents/impl-reviewer-a.md` | **YES** |
| `plugins/sdd-review-loop/agents/impl-reviewer-b.md` | **YES** |
| `plugins/sdd-review-loop/agents/task-reviewer-a.md` | **YES** |
| `plugins/sdd-review-loop/agents/task-reviewer-b.md` | **YES** |
| `plugins/sdd-review-loop/agents/spec-reviewer-a.md` | no |
| `plugins/sdd-review-loop/agents/spec-reviewer-b.md` | no |
| `plugins/sdd-review-loop/references/reviewer-calibration.md` | no |
| `plugins/sdd-review-loop/references/spec-review-calibration.md` | no |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | no |
| `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` | no |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` | no |
| `plugins/sdd-review-loop/scripts/task-review-precheck.sh` | no |
| `plugins/sdd-review-loop/templates/*.json`, `*.md` | no |
| `plugins/sdd-quality-loop/references/guard-invariants.json` | **YES** |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` | **YES** |
| `tests/gates.tests.sh` | **YES** |
| `.github/workflows/test.yml` | **YES** |

**Two consequences.**

1. The blast radius is *asymmetric across the three stages the issue names*: the
   spec stage is entirely writable by an agent; the impl and task stages have
   both the SKILL and both role files protected. A design that changes all three
   stages symmetrically produces a task plan that is half agent-writable and half
   human-applied.
2. `plugins/sdd-quality-loop/scripts/validate-review-context-set.{sh,ps1}` is
   **not** on the list, so the layer-3 enforcement (INV-009) and the role
   enumeration (INV-013) are agent-editable — while the role *prose* stating the
   same rule is not. Changing the enforcement without being able to change the
   role text is precisely the shape of the recorded contradiction in INV-023.

The staging convention for protected targets is `specs/<feature>/human-copy/`
with a `MANIFEST.sha256` and an `apply-protected-files.ps1`, as used by
`specs/epic-136-phase2-gates/human-copy/` and `specs/epic-136-phase3/human-copy/`.
Note that `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` is
itself on the protected list (`guard_invariants.py:4`).

**Re-verification instruction (AGENTS.md `## Rules` sweep 3, `AGENTS.md:203-211`,
WFI-013).** `PROTECTED_GATE_SUFFIXES` is repository-wide, git-tracked, shared
state that this branch does not own. The table above must be re-derived — by
reading `guard_invariants.py:4` and testing `endswith()` against each
repo-relative target path — at spec-review time (it gates a reviewer's conclusion
about task planning) and again at implementation start for each target actually
written.

#### INV-021: there is no cost or token telemetry surface in the review loop

The only cost-adjacent annotation on a reviewer is the HTML comment
`<!-- x-sdd-effort: medium -->` at line 12 of all six role files
(`spec-reviewer-a.md:12`, `spec-reviewer-b.md:12`, `impl-reviewer-a.md:12`,
`impl-reviewer-b.md:12`, `task-reviewer-a.md:12`, `task-reviewer-b.md:12`), and
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:99` describes the
equivalent annotation on the evaluator as **"record-only"**. No round artifact
carries a token count, a duration, or an invocation count: the schemas at
`spec-review-precheck.sh:150/199/214/271` have no such field.

So "通常タスクはコスト増なし" has no existing measurement surface. It can be made
observable structurally — *no additional agent launch and no additional ledger
reservation occurs for a non-triggering run* — because ledger reservations are
persisted and countable (`reports/review-context/identity-ledger.json`,
`validate-review-context-set.sh:198-206`). Whether that is the intended meaning is
OQ-11.

#### INV-022: check-ID lists are pinned per role, and are extensible only by appending

`spec-review-precheck.sh:162` and `:165` hard-code the exact ordered ID lists for
`spec-reviewer-a` and `spec-reviewer-b`. `:184` accepts a **prefix** of today's
list, with the reasoning at `:172-183`: IDs are appended, never inserted,
reordered or renamed, so historical evidence stays valid.

Any cross-critique check that a reviewer emits as part of its ordered `checks[]`
array must therefore be **appended** to these lists — and appending changes a
list that historical evidence is validated against, which the comment at
`:176-178` shows has already caused a repository-wide incident once
(`epic-136-phase3` attempt 2, commits `95479bb2`, `d528cbed`).

#### INV-023: a role-text-versus-gate contradiction of exactly this shape occurred, was fixed in the protected role file, and the shared reference document is now stale about it

**The precedent.** `plugins/sdd-review-loop/references/review-context-boundary.md:110-132`
documents that `impl-reviewer-a.md:43` forbade reading a file
(`integrated-summary.json` from the prior round) that the impl precheck
**requires** the same role to carry, and that
`validate-review-context-set.sh:86-97` authorizes with an explicit Issue #143
comment. The requirement is real and still live at
`plugins/sdd-review-loop/scripts/impl-review-precheck.sh:248-252`:

```sh
if [[ "$stage" == "impl" && "$stored_round" -gt 1 ]]; then
  local previous_summary="reports/impl-review/${FEATURE}/attempt-${stored_attempt}/round-$((stored_round - 1))/integrated-summary.json"
  manifest_has "$role_a" "$previous_summary" "$(sha256 "${repo_root}/${previous_summary}")" ||
    fail "persisted impl reviewer-a manifest is missing previous-round summary"
fi
```

**The correction — verified directly, not taken from the reference document.**
The role text has since been fixed. `impl-reviewer-a.md:43` now reads only

> Do not read any reviewer-b.json from prior rounds.

and `:45-48` adds the carve-out explicitly:

> One deliberate exception, per Issue #143: at round > 1 your manifest carries the
> PREVIOUS round's integrated-summary.json, and `impl-review-precheck.sh` fails the
> round if it is absent. Read it only as counts and check IDs -- it carries no
> narrative. Do not reason from reviewer-b's findings.

Landed in commit `fea5ccd0` ("fix(review-loop): resolve the impl-reviewer-a /
precheck contradiction"), i.e. a human applied it to a protected file.

**The finding.** `review-context-boundary.md:110-132` still describes the
contradiction in the present tense, and `:165-168` still lists it as an open item
for a human:

> The role file is in `PROTECTED_GATE_SUFFIXES`, so an agent cannot edit it. A
> human decides whether the role text gains the Issue #143 carve-out, or the
> precheck stops requiring the file.

That decision has been made. The reference document is stale — and it is not
background reading: it is named as required reading in every reviewer role file
(`spec-reviewer-a.md:49-54`, `spec-reviewer-b.md:51-56`). A reviewer reading it
today is told a resolved contradiction is unresolved.

**Why this matters to this feature.** It is the precise failure mode this feature
is at risk of reproducing at larger scale — enforcement changed on the writable
side while the statement of the rule lives somewhere else, here in the opposite
direction (the protected file was fixed and the writable reference document was
not). Any cross-critique design that changes `validate-review-context-set.sh`
(writable, INV-020) must change the role prose (protected) and
`review-context-boundary.md` (writable) in the same delivery, or it creates a
third instance. Cited in OQ-5 and OQ-15.

#### INV-024: the Codex runtime has no reviewer roles, confirming the issue addendum

The Codex agent role directory contains exactly four TOML files:
`sdd-evaluator.toml`, `sdd-investigator.toml`, `sdd-panelist-gemini.toml`,
`sdd-panelist-gpt.toml`. There is no `*-reviewer-*.toml`. The addendum's claim is
accurate.

The deterministic guard refuses agent-authored creation of such a file: attempting
a command naming that directory during this investigation returned

> SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの
> 書き込みを拒否しました … 新規作成せず、同梱の sdd-investigator / sdd-evaluator
> ロールを使用してください。

**Separate hazard, recorded because it cost a command here** (the same hazard
`specs/epic-136-phase4-docs/investigation.md:168` records): the guard's
Bash-command matcher is broader than its write-path suffix list
(`sdd-hook-guard.py:1350` substring-matches the whole command string against
`PROTECTED_GATE_SUFFIXES`). A purely read-only command whose *text* merely
mentions a protected path can be denied. Implementation agents should restructure
the command rather than work around the guard.

## The blind-independence tension

Stated explicitly, as required, and not resolved here.

**The property.** Reviewer B's verdict is independent evidence *because* B never
saw A's reasoning. That is what makes two FAILs on the same check corroboration
rather than an echo, and it is why the merged verdict is allowed to be a
mechanical union of two check arrays (INV-014) instead of a judgement call. The
repository defends it at five independent layers — role prose (INV-007), agent
capability (INV-008), a deterministic validator with no exception clause
(INV-009), exact-equality contract replay (INV-010), and calibration text that is
itself a hash-bound reviewer input (INV-011) — and it deliberately narrows the
one permitted channel to counts and IDs, more narrowly still at the impl and task
stages than at the spec stage (INV-005, INV-006).

**The collision.** Cross-critique's required input is reviewer A's raw finding
text. There is no formulation of "A and B examine each other's findings" that
does not transport that text across the boundary those five layers exist to
close. This is not a matter of choosing a safe file path: `is_forbidden_review_output`
(`validate-review-context-set.sh:57-61`) matches on the *filename shape*
`reviewer-[ab].json` and on the whole `reports/*-review/**/reviewer-*.json`
subtree, for every role, and `review-context-boundary.md:134-136` states there is
no exception. Copying the findings into a differently-named file would evade the
regex while defeating the property the regex protects — which is worse than
changing the gate, because it leaves the written contract claiming an isolation
the system no longer has.

**Why "it runs afterwards" is a partial answer, not a free one.** Confining
cross-critique to a phase that begins only after both reviewers' verdicts are
final and persisted does preserve the *primary* independence: the two verdicts
that the merged verdict is computed from were each produced blind. But it buys
that at a stated price. Per INV-014, the merged verdict is recomputed from those
same persisted severities by three separate validators, so a phase running after
them can annotate but cannot change the gate outcome — unless all three
derivations change together. A cross-critique that cannot change the outcome does
not deliver the issue's stated purpose ("severity calibration が弱く"); a
cross-critique that can change it re-opens the question of what the merged
verdict is now evidence of. Both branches are live. Which one the issue intends
is not stated anywhere in it.

**What is not in tension.** Nothing here argues against the feature. Blind
independence is load-bearing for the *first* pass; the tension is entirely about
what may cross the boundary afterwards, who is authorized to act on it, and
whether the gate's arithmetic changes. Those are OQ-5, OQ-7 and OQ-8, and they
are decisions for a human, because this feature modifies the gate that decides
whether work is acceptable.

## Open Questions

None of these is answered by this investigation, and none may be answered by
inference during design. Each is a decision the issue leaves open; picking one
silently would create a contract nobody agreed to on the gate that decides
whether work is acceptable.

### OQ-1 — what does the trigger "high/critical" name?

Finding severity (`Critical | Major | Minor`, INV-017) or task risk tier
(`low | medium | high | critical`, INV-017)? "high" exists only in the tier
vocabulary; "critical" exists in both with different meanings. If tiers, the
spec and impl stages have no tier to read at the time they run
(`sdd-bootstrap-interviewer/SKILL.md:178-193`) and two of the three named target
files are out of scope. **Blocking**: OQ-2 and the whole trigger design depend on
it.

### OQ-2 — which of the three stages gain the phase, and must they be uniform?

The issue names all three. But the sanitized bridge differs between spec and
impl/task (INV-005 vs INV-006), the protected-file blast radius differs
(INV-020), and under the tier reading of OQ-1 only the task stage has a tier.
Is a stage-uniform design required, or is per-stage divergence acceptable?

### OQ-3 — how many cross-critique exchanges?

One round-trip (A critiques B, B critiques A, done)? Iterated to convergence?
Bounded at N? The source protocol runs exactly one (`adversarial-review/SKILL.md:37`).
No default is stated in #130.

### OQ-4 — how does the phase interact with the existing three-round cap?

`spec-review-precheck.sh:35` caps rounds at 3 (INV-002) and `:286-287` requires
the reviewed document to have changed between rounds (INV-003) — which a
cross-critique pass does not do. Candidate shapes, none chosen: (a) a sub-phase
*inside* a round, invisible to the round counter; (b) a separate counter with its
own directory level; (c) consuming a round, reducing the human-edit budget from
three to two. Each has a different failure mode and (c) changes an existing
guarantee.

### OQ-5 — how is blind independence preserved once reviewers see each other's output?

See `## The blind-independence tension`. Candidate shapes, none chosen: run the
phase strictly after both verdicts are persisted and treat it as advisory; relax
`is_forbidden_review_output` for a narrowly-scoped new stage/role pair; introduce
a third, uninvolved critic role that reads both reports so neither original
reviewer is contaminated. The third avoids the contamination question entirely
but is not what the issue asks for ("A/B に相手の findings を渡し").

### OQ-6 — fresh context or resumed session, and what does that do to cost?

The identity ledger requires globally unique `run_id` **and** `host_session_id`
per reservation (INV-012), so the source protocol's "same two agents, resumed"
is unavailable. A fresh context re-reads every input, which is the cost the
source protocol's design exists to avoid. Is the cross-critique participant
exempt from ledger reservation (and if so, what replaces the identity
guarantee), or is the re-read cost accepted?

### OQ-7 — how do the four verdicts feed synthesis, and may they move the gate?

The merged verdict is recomputed from raw `checks[].severity` by three
independent validators (INV-014). A `SEVERITY_CHANGE` therefore has no effect
unless all three change together, or unless a reviewer output is rewritten —
which reviewers cannot do (INV-008) and which the contract hash-binds. Is the
phase advisory-only, or does the verdict derivation change?

### OQ-8 — what happens on disagreement?

A `REJECT` against a finding the other reviewer stands by. The orchestrator is
forbidden from waiving findings (INV-015). Candidate shapes, none chosen: the
finding stands (REJECT is recorded but inert); a human breaks the tie; the
disagreement itself is escalated as a finding. This directly determines whether
the phase can ever *reduce* a verdict, which is the severity-calibration purpose
the issue states.

### OQ-9 — which verdict vocabulary is normative?

Issue #130 says `SUPPORT / REJECT / SEVERITY_CHANGE / SUPPLEMENT`. The existing
protocol says `SUPPORT / PROPOSE-SEVERITY-CHANGE / PROPOSE-REJECT / SUPPLEMENT`
(`adversarial-review/references/reviewer-prompts.md:154-155`). The `PROPOSE-`
prefix is semantically load-bearing under INV-015. The addendum requires both
runtimes to return "the same 判定", so exactly one spelling must be normative.

### OQ-10 — where do cross-critique outputs live, and what validates them?

Every existing round artifact is key-set-exact (INV-016), so no field can be
added to one without a coordinated schema bump across the precheck, its
PowerShell twin, `check-workflow-state.{sh,ps1}`, the templates and the test
drivers. Candidate shapes, none chosen: a new sibling artifact with its own
schema; a `/v2` bump of the existing ones; an out-of-contract file that no gate
validates (which would make the phase unauditable).

### OQ-11 — what does "no cost increase for routine tasks" mean, and how is it verified?

No cost telemetry exists (INV-021). Candidate readings, none chosen:
(a) structural — a non-triggering run performs exactly the agent launches and
ledger reservations it performs today, countable from the ledger; (b) measured —
a token or wall-clock budget, which requires a measurement surface this
repository does not have. (a) is verifiable today; (b) is a second feature.

### OQ-12 — how is the Codex runtime covered?

No reviewer roles exist there (INV-024), the guard blocks agent creation of new
ones, and any new role needs `developer_instructions`. Candidate shapes, none
chosen: a runtime-neutral design carried entirely by shared SKILL prose plus
structured files (the addendum's own first suggestion); or new Codex role files
placed by a human. The addendum's AC — both runtimes return the same verdicts —
holds either way but is only *testable* under the first.

### OQ-13 — what exactly must be "consistent with ENH-21's shared protocol"?

ENH-21 is issue #128, which declares `Depends on: ENH-23` (this issue) and
proposes formalizing `skills/adversarial-review` as a risk-adaptive lane
(INV-018, INV-019). The shared protocol does not exist yet. Is this feature
expected to *define* it (so #128 consumes it), to *consume* something #128 will
define, or merely not to contradict `skills/adversarial-review` as it stands
today?

### OQ-14 — does the phase run when only one reviewer produced findings?

If A raises a Critical and B raises nothing, there is nothing of B's for A to
critique. Is it a one-directional critique, is it skipped, or does the
no-findings reviewer's clean report itself become the critique target
(the source protocol's "verified non-findings are mandatory",
`adversarial-review/SKILL.md:48-49`)?

### OQ-15 — how are the protected targets changed?

Four of six role files and two of three target SKILLs are protected (INV-020),
and an agent cannot write them. Candidate shapes, none chosen: a
`specs/review-cross-critique/human-copy/` staging round on the
`epic-136-phase2-gates` model; confining the change to the writable surfaces
(which risks reproducing INV-023 — enforcement relaxed while the role prose still
forbids); or splitting delivery so the writable half lands first. This is a
task-planning decision that Phase 2 cannot make without an answer.

## Acceptance Criteria Verification (issue #130 as stated)

| Issue AC | Status against the current repository |
|---|---|
| "high/critical で相互批判段が走る" | **Not specifiable yet** — the trigger vocabulary does not exist in the loop (INV-017, OQ-1). |
| "通常タスクはコスト増なし" | **Specifiable structurally, not measurably** — no cost surface exists (INV-021, OQ-11); the ledger makes launch counts observable. |
| "ENH-21 の共通プロトコルと整合" | **Blocked** — ENH-21 (#128) depends on this issue and its protocol does not exist (INV-018, INV-019, OQ-13). |
| Addendum: "両ランタイムで cross-critique が同じ判定を返すこと" | **Specifiable**, with the Codex role gap as the constraint (INV-024, OQ-12). |
