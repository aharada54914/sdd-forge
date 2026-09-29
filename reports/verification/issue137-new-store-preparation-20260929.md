# New empty private store directory RED — 2026-09-29

T-001 scope: a new empty canonical `.sdd/context` directory only. The planned internal `prepareStore(raw, trusted)` helper reuses actual validation and the same core-owned owner/plannedPaths/deadline. No new authority input, file data/write, existing chmod, registry/installer/scheduler or Windows ACL success claim.

Creation modes/private access and preservation rules come from `specs/sdd-context-continuity/security-spec.md:35–36,39–54`; the locator is `design.md:118–119`. POSIX 0700 is the minimal creation-mode choice. WFI-001 counterparts/mismatch controls were recorded before test changes.

```text
rtk proxy node --test --test-name-pattern=^NEW-STORE- tests/sdd-context/validation.test.mjs
```

Executed once: **5 tests / 0 pass / 5 fail / 0 skip; Node exit 1**, corrections 0. Added 5 cases / 60 lines; original 100-case prefix unchanged, old 100/31 bodies not rerun.

All five fail the missing preparation-helper assertion. This is implementation-absence RED, not a syntax/environment failure or proof that mode/access/escape/no-mutation controls pass. Planned assertions cover fresh owning-account mode under permissive umask, unchanged existing directory/file, invalid/foreign input, escaping parent, ignore/Git/deadline failures. Native Windows ACL and concurrent ancestor replacement proof remain pending.

| Input/output | SHA-256 |
|---|---|
| Unchanged source | `5e4aee1b887ec82be5bf44f9ee38eaf24d48bcb3a8c72c0c0f731ed4e03a0659` |
| Expanded tests | `4da707518036f61ef89890038eec8facb276d1833d519b28c6aef174d0ed665f` |
| Actual stdout | `02f29e6bbf104bede67af1c9ca3cfbed0f4a1d44c28add343dab01fd495b2178` |

Production, approval/status and Git remain unchanged. T-001 is incomplete. Stop for root's RED checkpoint before production.
