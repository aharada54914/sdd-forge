# adversarial-review — standalone skill

Two-reviewer adversarial code review: blind parallel reviews, mutual
cross-critique with per-finding verdicts, orchestrator synthesis, and
fresh-context fix verification. See [SKILL.md](SKILL.md) for the protocol.

## Status

Standalone skill, deliberately **outside** `plugins/` and outside the plugin
skill-visibility contract enforced by `tests/validate-repository.ps1` (which
only scans `plugins/`). Per the handoff plan
([docs/handoff-adversarial-review-skill.md](../../docs/handoff-adversarial-review-skill.md)),
it graduates to a plugin only after 2–3 real uses prove it stable.

## Install

Copy the whole directory to wherever Claude Code discovers skills:

- Per user: `~/.claude/skills/adversarial-review/`
- Per project: `<repo>/.claude/skills/adversarial-review/`

## Files

- `SKILL.md` — protocol, iron rules, recovery procedures
- `references/reviewer-prompts.md` — verbatim prompt templates (Reviewer A,
  Reviewer B, cross-critique, fresh-context fix verification)
- `templates/report-template.md` — integrated report structure

## Provenance and evidence

Generalized from the review executed end-to-end on torque-system-manager
(2026-07-07, `docs/review-tickets/2026-07-07-dual-review-refactoring-plan.md`
in that repo, and its PR #7). That run's cross-critique and fresh verification
caught, among others: a target service with zero production call sites, two
HIGH defects in TDD-complete code, a ratio inversion inside a fix text, and
re-calibrated most initial severities — none of which the blind single reviews
produced on their own.

Prior art evaluated before writing (2026-07-08): `wan-huiyan/agent-review-panel`
(MIT; 16-phase panel — too heavy to adopt, mined for ideas),
`deep-review-2` (source repository deleted; unusable), `ng/adversarial-review`
(no license; its schemas were not copied — this skill's verdict vocabulary
derives from the torque protocol). Differentiators of this skill: the explicit
mutual cross-critique phase with per-finding verdicts, and the mandatory
"verified non-findings" rule (absent from all three).

## Skill-level TDD

Created following superpowers:writing-skills (RED → GREEN): baseline agents
without the skill consistently omitted the design/maintainability lens, the
"do not spawn subagents" clause, the fresh-context fix-verification phase, the
harm-path severity gate, and the phased remediation plan — exactly the
elements this skill pins down. Test log lives with the creating session; the
protocol itself was proven in the torque run above.
