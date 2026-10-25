# Security: verification-measurement

- No subprocess execution, network access, credential, prompt or private
  identity-ledger read. No raw environment variables or arbitrary argv are
  recorded; the measurement header key set is a fixed allowlist (TEST-022).
- Writes are confined to the given measurement directory, which must not be a
  symlink; record names are validated identifiers (TEST-024). Files are
  create-exclusive; different bytes under an existing name are a conflict.
- Inputs are bounded strict JSON with duplicate-key rejection.
- Measurement cannot change a verdict, required set, approval, review identity
  or cache decision. It changes no exit code once execution starts; the only
  exception is an invalid measurement configuration detected before
  execution, which exits 2 with nothing executed. Referenced artifacts are
  only hashed, never modified; opaque experiment/decision references are
  never evidence. Publishing logs or results is a separate human decision.
