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

## GREEN continuation

After root's RED commit and authorization, added 6 production lines: existing closed/owner/opaque/UTC/state helpers plus exact canonical store comparison in both shared path checks. Fixed tests were unchanged.

`rtk proxy node --test tests/sdd-context/validation.test.mjs`: **100/100 pass** (new 9 and old 91), once, exit 0, failures/skips 0. JSON admission/privacy/privacy grammar: **31/31 pass**, once, exit 0, failures/skips 0. Corrections: 0. All six WFI-001 field/counterpart rows have passing fixed positive and mismatch evidence; negative entry controls now execute supported admission validation.

| GREEN input/output | SHA-256 |
|---|---|
| Source | `5e4aee1b887ec82be5bf44f9ee38eaf24d48bcb3a8c72c0c0f731ed4e03a0659` |
| 100-case stdout | `b5ab18ea4c2471c98e19e6f048b175b152391fe8195b2e7aceebadfba9be4706` |
| 31-case stdout | `e31b9a6d46c75bb38c172e4a042f00b02cf9db0d97b68147ff6148850459cf25` |

Independent ordinary review verified the fixed source/tests and saved output hashes: 0 findings; it did not rerun tests or issue a formal verdict. Approval/status remain unchanged; T-001 is incomplete. OwnerRegistry, scheduler updates, persistence and other entity types remain outside this slice; local checks do not establish native/CI or a formal verdict.
