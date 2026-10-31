# T-009 four-row mutation cycle

After the initial RED run proved the two new capability branches were absent,
independent review identified that the Done When requires every row of the
four-combination matrix to fail against a deliberately incorrect
implementation. A second RED cycle therefore applied a temporary, explicit
mutation to both emitter twins:

- effort-only wrongly added `capability`;
- no flags wrongly emitted v2;
- capability-only wrongly emitted a record successfully; and
- both families persisted an incorrect enforcement value.

`matrix-red.log` records explicit failures for all four rows in both suites.
The mutation was then removed with `apply_patch` before the final GREEN run.

| File | Before mutation | After restoration |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | `2286b1a88ec01eaf4217aae62fdc5cfb842f5c783fc95ca80d17714339513955` | `2286b1a88ec01eaf4217aae62fdc5cfb842f5c783fc95ca80d17714339513955` |
| `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` | `8dc9081a476cc986cd57cc996260abc88e8050b4555ffa78c4410c17b2ccb2c8` | `8dc9081a476cc986cd57cc996260abc88e8050b4555ffa78c4410c17b2ccb2c8` |

The identical hashes prove that no deliberate mutation remains in either
product file. The permanent test-label and null-safe assertion improvements
made during this cycle are included in the subsequent GREEN evidence.
