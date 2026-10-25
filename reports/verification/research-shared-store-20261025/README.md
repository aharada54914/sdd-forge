# Licensed local-group originals

The Linux shared profile reuses save_cache / purge_cache, Source v1 and fresh
original verification. It requires a preconfigured publisher-owned 0750 directory
and existing reader GID, records 0640 snapshots with a permission/expiry/hash-bound
receipt, and rechecks the current filesystem profile and receipt on shared reads.
The publisher and root administrator are trusted. Remote filesystems and other
operating systems are unsupported; existing private-cache behavior is unchanged.

Local acquisition: 31 tests, 30 passing and 1 explicit skip. Metadata 21,
consumers 15, and Bash/PowerShell owner integration 8 passed. The skipped test
needs root to create distinct allowed and denied reader identities; this cloud
session has UID 1000 and no such capability. A dedicated Linux CI step now runs
that exact test with separate UIDs, empty supplementary groups and zero effective
capabilities, checking allowed read/verification, denied read, no writes, expiry
and deletion. Its hosted result remains pending; local mode checks are not a
substitute for that result.

Independent actual-filesystem controls reject group-writable ancestors, symlinks,
hardlinks, a real named POSIX ACL, changed expiry and forged publisher identity.
The final review also checks PermissionError classification and opened-directory
mount-ID selection. No originals from third parties are used or published.
Expiry rejects fresh verification; explicit purge removes files. Already-read
copies/open descriptors and background expiry deletion are not promised.

inputs.json contains the exact tested source digests, not a reusable PASS receipt.
