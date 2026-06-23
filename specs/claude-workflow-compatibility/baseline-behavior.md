# Baseline Behavior: Claude workflow compatibility

## BL-001: Valid plugin skill layout

`sdd-ship`, `sdd-implementation`, and `sdd-lite` pass `claude plugin validate`.
Their `skills/<command>/SKILL.md` directories are discoverable by Claude Code.

## BL-002: Public command name convention

Claude Code derives a plugin skill command from the plugin name and the skill
directory. Therefore `plugins/sdd-bootstrap/skills/run/SKILL.md` is intended to
be invoked manually as `/sdd-bootstrap:run`.

## BL-003: Manual-only orchestration is intentional

The public `run` skills set `disable-model-invocation: true`. This prevents
automatic model invocation but does not prevent a human from using the slash
command.

## BL-004: Deterministic quality enforcement is retained

`sdd-quality-loop` supplies PreToolUse hooks. The compatibility correction must
not remove or weaken these hooks.
## BL-005: Current regression

`sdd-bootstrap` fails to load, so `/sdd-bootstrap:run` is absent even though the
marketplace and documentation advertise it.
