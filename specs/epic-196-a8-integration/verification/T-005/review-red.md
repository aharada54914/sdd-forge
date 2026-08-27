# T-005 reviewer correction Red evidence

Date: 2026-08-09

After the initial 83-case Green run, the independent reviewer pass added
security-boundary cases for the signer registry, expected-config manifest,
synthetic-capture fixtures, SKIP citations, nonce-ledger publication mode, and
an RFC 8032 known-answer oracle.

Command:

```text
bash tests/validate-live-host-proof.tests.sh
```

Observed before the reviewer corrections:

```text
live-host-proof: 81 passed, 6 failed
```

The six expected failures were:

- `ERR_SYNTHETIC_SUBSTITUTION`: a committed direct-guard request fixture was not detected.
- `malformed-public-key`: malformed registry data was classified only at point of use.
- `unused-signer-malformed-public-key`: unused registry entries were not fully validated.
- `manifest-config-path-traversal`: `config_path` was not constrained to a canonical relative path.
- `skip-allowlist-substring-not-citation`: a containing token was treated as an exact AC citation.
- `idempotent-repeat`: atomic replacement changed the ledger mode from `0644` to `0600`.

The independent RFC 8032 vector already passed; the failures were therefore
localized to the boundary checks above rather than the curve arithmetic.
