# RegistryEntryV1 standalone RED — 2026-09-29

Test-only scope: the closed five-field entry (`owner`, `storeRoot`, `registrationId`, `schedulerState`, `checkedAtUtc`), matching trusted owner and exact canonical `.sdd/context` locator. WFI-001 counterparts and mismatch controls were recorded before the test append.

```text
rtk proxy node --test --test-name-pattern=^REGISTRY-ENTRY- tests/sdd-context/validation.test.mjs
```

Executed once: **9 tests / 8 pass / 1 fail / 0 skip; Node exit 1**. Added 9 cases / 83 lines; preserved the original 91-case prefix. Prior 91/31 test bodies were not rerun.

`REGISTRY-ENTRY-VALID` fails with content-free `validation-rejected`: unchanged dispatch does not yet admit this type. The eight negative controls currently pass default rejection; they do not establish field validation.

| Input/output | SHA-256 |
|---|---|
| Unchanged source | `5e083fe7165247b4716cf06dba2b87ac730e829830aa4b7b97362278bbd151f7` |
| Expanded tests | `6014e026fc934628b1642cf7ee32a8e0235361d1899947b9f0e5d27dca2d8865` |
| Actual stdout | `86888b3a61ed27972cdac8d3701ea4bb002179d40774c6d8be8e4db133eafd4b` |

Production and approval/status remain unchanged. T-001 is incomplete. Stop for root's RED commit and subsequent GREEN authorization; OwnerRegistry, scheduler updates, persistence and other entity types are outside this slice.
