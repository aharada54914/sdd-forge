# Bounded review-ticket correction preflight

RT-20261018-CLOUD-PREVIEW-EXPIRY enforces the existing exact fresh-preview admission policy; no privilege or public schema changes.

| Persisted field | Counterpart | Executed Red mismatch |
|---|---|---|
| authorization expires_at | bound preview expires_at and credential/policy deadline | positive fixture receipt wrongly exceeds preview deadline in both providers |
| native submission decision | preview valid at final write boundary | both providers submit at and after preview expiration during third/final verify_binding |
| consumed authorization marker | failed final admission is not replayable | regression requires marker retained on denial |

`red.log` records six failing subcases (two receipt deadline mismatches and four missed denials). Tests were committed before the production change, with the exact previous source hash in `red-proof.json`. Root is the corrective implementer; independent cycle 3 is still required. The existing T-004 review does not admit the edited authorization module, execution tests, ticket or this addendum; its pinned inputs remain unchanged.
