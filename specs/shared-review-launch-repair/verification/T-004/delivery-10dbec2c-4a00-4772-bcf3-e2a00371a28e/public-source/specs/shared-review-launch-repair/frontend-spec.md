# Frontend Specification: shared-review-launch-repair

## Technology stack and component tree

No browser or frontend component is changed. The affected operator surface is the existing CLI and Markdown skill entrypoint; its stage/role prompts, argument construction, and output parsing are covered by requirements REQ-001/002 and the existing launcher at `plugins/sdd-review-loop/scripts/launch-impl-review.py:143-230,321-365`.

## State, routes, API client, and performance

No new frontend state, route, API client, or bundle. The command boundary must continue to distinguish preflight, delivery, reservation, and validated verdict; see `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:22-110`.

## Dependencies and testing

The installed CLI's actual help/permission behavior and existing runtime dependencies are checked by TEST-001 through TEST-005. No mocked fixture is accepted as proof of native host behavior.

## Open questions

None in the frontend layer.
