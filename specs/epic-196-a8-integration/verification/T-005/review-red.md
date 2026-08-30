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

## Security-review Red expansion (2026-08-30)

Before changing production code, the security review added four regression
tests for boundaries not covered by the first implementation wave:

- an AC-006 SKIP becomes stale once T-005 is `In Progress`, even when only the
  three handshake paths (and no unrelated consumer path) are present;
- an Ed25519 public key in a mixed-order subgroup is rejected in addition to
  the existing small-order and non-canonical negatives;
- a nonce-ledger lock release failure is reported instead of silently ignored;
- both platform wrappers use the shared byte-preserving Python dispatchers.

Command:

```text
bash tests/validate-live-host-proof.tests.sh
```

Observed before the corresponding production changes:

```text
live-host-proof: 87 passed, 4 failed
```

The four expected failures were `ac006-started-is-stale`,
`lock-release-failure-is-not-silent`,
`rfc8032-known-answer-and-strict-negatives` (mixed-order subcase), and
`shared-byte-preserving-wrapper-dispatch`.
