# Direct subtitle extraction and quote timing

The WebVTT/SRT fixtures exercise the actual shared extraction and fresh-original
verification paths. Acquisition: 29 tests; consumers: 15; Bash/PowerShell research
owners: 8, all passing. Independent negative controls reject 10 malformed or
forged timing/payload cases and verify a second-cue quote's time range. Existing
plain-text results retain source-evidence-result/v1 without time_range.

The original caption bytes and complete regenerated extraction must agree before
quote timing is issued. The supported plain-cue subset rejects settings, markup,
timestamp maps and other unsupported semantics. These fixture results do not
prove alignment with a real video, live provider availability or semantic support
for a claim. Existing proxy/rights restrictions remain effective.

inputs.json records tested source hashes and is not a reusable PASS receipt.
The separate CI-fixed shared-launch Python check also passes after adding the
missing all_pins type annotation; it does not lint every research module.

Independent Linux Chromium 154 evaluation passed 13 browser checks and 4 CLI
cases (subtitle, plain v1, tampered timing, unsupported markup). The original
and translation remain separate; the caption timing and synchronization limit
are visible. Failure preserves the existing HTML. browser/ contains synthetic
fixtures, exact CLI products and screenshots. Reports were loaded through an
offline fixture route; direct file:// and real video synchronization were not
tested. No third-party originals are included.
